import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/entrada.dart';
import '../../app/provedores.dart';
import '../../app/tema.dart';
import '../../core/config/ambiente.dart';
import '../../core/rede/falha_api.dart';
import '../../core/sessao/sessao.dart';
import 'produto_resumo.dart';

class InicioPage extends ConsumerStatefulWidget {
  const InicioPage({super.key});

  @override
  ConsumerState<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends ConsumerState<InicioPage> {
  final _busca = TextEditingController();
  final _rolagem = ScrollController();
  static const _porPagina = 40;

  Map<String, dynamic>? _conta;
  List<ProdutoResumo> _produtos = const [];
  List<CategoriaResumo> _categorias = const [];
  Map<String, dynamic>? _banner;
  final Map<int, int> _carrinho = {};
  int? _categoriaId;
  var _soOferta = false;
  var _aba = 0;
  var _pagina = 0;
  var _total = 0;
  var _geracao = 0;
  String? _aviso;
  var _carregando = true;
  var _buscandoMais = false;
  var _pedido = false;
  Timer? _esperaBusca;

  @override
  void initState() {
    super.initState();
    _rolagem.addListener(_aoRolar);
  }

  @override
  void dispose() {
    _esperaBusca?.cancel();
    _busca.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  void _aoRolar() {
    if (!_rolagem.hasClients || _carregando || _buscandoMais) return;
    if (_produtos.length >= _total) return;
    final posicao = _rolagem.position;
    if (posicao.pixels < posicao.maxScrollExtent - 480) return;
    _carregar(mais: true);
  }

  void _buscarDeNovo() {
    _esperaBusca?.cancel();
    _esperaBusca = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _carregar();
    });
  }

  Future<void> _carregar({bool mais = false}) async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null) return;
    if (mais && (_buscandoMais || _carregando || _produtos.length >= _total)) {
      return;
    }
    final geracao = mais ? _geracao : ++_geracao;
    final pagina = mais ? _pagina + 1 : 0;
    setState(() {
      if (mais) {
        _buscandoMais = true;
      } else {
        _carregando = true;
        _aviso = null;
      }
    });
    try {
      final conta = mais && _conta != null
          ? _conta!
          : await ref.read(apiProvider).eu(sessao);
      final unidade = unidadeDaConta(conta);
      if (unidade == null) {
        if (!mounted || geracao != _geracao) return;
        setState(() {
          _conta = conta;
          _produtos = const [];
          _categorias = const [];
          _banner = null;
          _total = 0;
          _aviso = 'Sua conta ainda não está ligada a uma unidade.';
        });
        return;
      }
      final catalogo = await ref
          .read(apiProvider)
          .produtos(
            sessao,
            busca: _busca.text,
            categoriaId: _categoriaId,
            soDesconto: _soOferta,
            pagina: pagina,
            tamanho: _porPagina,
          );
      final itens = catalogo['itens'];
      final paginaAtual = [
        if (itens is List)
          for (final item in itens)
            if (item is Map)
              ProdutoResumo.deJson(Map<String, dynamic>.from(item)),
      ];
      var categorias = _categorias;
      var banner = _banner;
      if (!mais) {
        final lista = await ref.read(apiProvider).categorias(sessao);
        categorias = [for (final item in lista) CategoriaResumo.deJson(item)];
        try {
          final banners = await ref.read(apiProvider).banners(sessao, unidade);
          banner = banners.isEmpty ? null : banners.first;
        } catch (_) {
          banner = null;
        }
      }
      if (!mounted || geracao != _geracao) return;
      final total = catalogo['total'];
      setState(() {
        _conta = conta;
        _produtos = mais
            ? acrescentarPagina(_produtos, paginaAtual)
            : paginaAtual;
        _categorias = categorias;
        _banner = banner;
        _pagina = pagina;
        _total = total is num ? total.toInt() : _produtos.length;
        _aviso = null;
      });
    } catch (erro) {
      if (!mounted || geracao != _geracao) return;
      final falha = falhaDe(erro);
      setState(() {
        _aviso = falha.codigo == 'SOMENTE_SMART_ACCESS'
            ? 'Este contrato é só Smart Access. A loja fica oculta.'
            : falha.mensagem;
        if (!mais) {
          _produtos = const [];
          _total = 0;
        }
      });
    } finally {
      if (mounted && geracao == _geracao) {
        setState(() {
          _carregando = false;
          _buscandoMais = false;
        });
      }
    }
  }

  int get _quantidadeCarrinho =>
      _carrinho.values.fold(0, (soma, item) => soma + item);

  void _somar(ProdutoResumo produto) {
    unawaited(HapticFeedback.lightImpact());
    setState(() => _carrinho[produto.id] = (_carrinho[produto.id] ?? 0) + 1);
  }

  Future<void> _abrirPedido() async {
    unawaited(HapticFeedback.mediumImpact());
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null || _carrinho.isEmpty) {
      _folha(
        'Seu pedido',
        const Text(
          'Toque no + de um produto para montar o pedido desta unidade.',
        ),
      );
      return;
    }
    _folha(
      'Seu pedido',
      FutureBuilder<Map<String, dynamic>>(
        future: ref.read(apiProvider).simularCarrinho(sessao, [
          for (final item in _carrinho.entries)
            {'produtoId': item.key, 'quantidade': item.value},
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Text(falhaDe(snapshot.error!).mensagem);
          }
          final corpo = snapshot.data ?? {};
          final itens = corpo['itens'];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (itens is List)
                for (final item in itens)
                  if (item is Map)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(texto(item['nome'])),
                      trailing: Text(
                        '${item['quantidade']} × ${reais(item['preco'])}',
                      ),
                    ),
              const SizedBox(height: 8),
              Text(
                'Total ${reais(corpo['total'])}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Este valor veio da API desta unidade. O pagamento ainda confirma o pedido no servidor.',
              ),
            ],
          );
        },
      ),
    );
  }

  void _folha(String titulo, Widget corpo) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            const SizedBox(height: 12),
            corpo,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Sessao?>>(sessaoProvider, (anterior, proximo) {
      if (proximo.asData?.value != null && !_pedido && mounted) {
        _pedido = true;
        _carregar();
      }
    });
    final sessao = ref.watch(sessaoProvider).asData?.value;
    if (sessao != null && !_pedido) {
      _pedido = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _carregar();
      });
    }
    final conta = _conta;
    final nome = texto(conta?['nome']);
    final primeiro = nome.split(' ').first;
    return Scaffold(
      backgroundColor: Cores.fundo,
      extendBody: true,
      body: SafeArea(
        child: switch (_aba) {
          4 => _perfil(nome),
          1 => _listaCategorias(),
          _ => _vitrineHome(primeiro),
        },
      ),
      bottomNavigationBar: _barra(),
    );
  }

  Widget _vitrineHome(String primeiro) {
    final unidade = unidadeDaConta(_conta);
    return RefreshIndicator(
      onRefresh: _carregar,
      child: CustomScrollView(
        controller: _rolagem,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _cabecalho(primeiro),
                const SizedBox(height: 12),
                _cartaoUnidade(),
                const SizedBox(height: 16),
                _buscaCampo(),
                const SizedBox(height: 16),
                if (_carregando) const LinearProgressIndicator(),
                if (_aviso != null) ...[
                  const SizedBox(height: 12),
                  AvisoAnimado(texto: _aviso!, erro: true),
                ],
                if (_aviso == null && unidade != null) ...[
                  EntradaSuave(indice: 0, child: _hero()),
                  const SizedBox(height: 18),
                  _faixaCategorias(),
                  const SizedBox(height: 18),
                  _tituloSecao(
                    _soOferta ? 'Ofertas da unidade' : _nomeCategoria(),
                  ),
                  const SizedBox(height: 12),
                  if (!_carregando && _produtos.isEmpty)
                    const Text(
                      'Nenhum produto desta unidade combina com a busca.',
                    ),
                ],
              ]),
            ),
          ),
          if (_aviso == null && unidade != null && _produtos.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.48,
                ),
                delegate: SliverChildBuilderDelegate((context, indice) {
                  final produto = _produtos[indice];
                  return _CardProduto(
                    produto: produto,
                    quantidade: _carrinho[produto.id] ?? 0,
                    aoSomar: () => _somar(produto),
                    aoAbrir: () => _abrirProduto(produto),
                  );
                }, childCount: _produtos.length),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              child: _buscandoMais
                  ? const Center(child: CircularProgressIndicator())
                  : const SizedBox(height: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cabecalho(String primeiro) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                primeiro.isEmpty ? 'Olá' : 'Olá, $primeiro',
                style: const TextStyle(color: Cores.tinta),
              ),
              Text(
                'PDV Market',
                style: TextStyle(
                  color: Cores.laranja,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        _icone(
          Icons.notifications_none,
          onTap: () => _folha(
            'Avisos',
            const Text(
              'Os avisos desta unidade aparecem aqui quando a API tiver mensagens novas.',
            ),
          ),
        ),
        const SizedBox(width: 8),
        _icone(
          Icons.shopping_bag_outlined,
          selo: _quantidadeCarrinho,
          onTap: _abrirPedido,
        ),
      ],
    );
  }

  Widget _cartaoUnidade() {
    final endereco = _conta?['endereco'];
    final mapaEndereco = endereco is Map
        ? Map<String, dynamic>.from(endereco)
        : const <String, dynamic>{};
    final rua = [
      texto(mapaEndereco['logradouro']),
      texto(mapaEndereco['numero']),
    ].where((parte) => parte.isNotEmpty).join(', ');
    final localidade = [
      texto(mapaEndereco['bairro']),
      [
        texto(mapaEndereco['cidade']),
        texto(mapaEndereco['uf']),
      ].where((parte) => parte.isNotEmpty).join('/'),
    ].where((parte) => parte.isNotEmpty).join(' · ');
    final enderecoResumo = [
      rua,
      localidade,
    ].where((parte) => parte.isNotEmpty).join(' · ');
    final unidade = unidadeDaConta(_conta);
    final raio = _conta?['raioKm'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Cores.marinho,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nomeLoja(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  enderecoResumo.isEmpty
                      ? 'Unidade vinculada à sua conta'
                      : enderecoResumo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD8E1EF),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _seloUnidade(
                      unidade == null
                          ? 'Unidade vinculada'
                          : 'Unidade #$unidade',
                    ),
                    if (raio is num)
                      _seloUnidade(
                        'Raio ${raio.toStringAsFixed(raio % 1 == 0 ? 0 : 1)} km',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _seloUnidade(String rotulo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x332D83E6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        rotulo,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _abrirProduto(ProdutoResumo produto) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 220,
                  child: urlMidia(produto.imagemUrl) == null
                      ? ColoredBox(
                          color: Color(0xFFFFF1E8),
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: Cores.laranja,
                            size: 56,
                          ),
                        )
                      : Image.network(
                          urlMidia(produto.imagemUrl)!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: Color(0xFFFFF1E8),
                            child: Icon(
                              Icons.shopping_bag_outlined,
                              color: Cores.laranja,
                              size: 56,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              if (produto.categoriaNome.isNotEmpty)
                Text(
                  produto.categoriaNome,
                  style: const TextStyle(color: Cores.tinta, fontSize: 13),
                ),
              Text(
                produto.nome,
                style: const TextStyle(
                  color: Cores.marinho,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                produto.descricao.isEmpty
                    ? 'Consulte a loja para mais informações sobre este produto.'
                    : produto.descricao,
                style: const TextStyle(color: Cores.tinta, height: 1.45),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    produto.preco,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (produto.precoOriginal != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      produto.precoOriginal!,
                      style: const TextStyle(
                        color: Cores.tinta,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: produto.disponivel
                      ? () {
                          _somar(produto);
                          Navigator.of(context).pop();
                        }
                      : null,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(
                    produto.disponivel
                        ? 'Adicionar ao carrinho'
                        : 'Produto indisponível',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buscaCampo() {
    return TextField(
      controller: _busca,
      decoration: InputDecoration(
        hintText: 'Buscar produto',
        prefixIcon: const Icon(Icons.search, color: Cores.tinta),
        suffixIcon: IconButton(
          onPressed: _carregar,
          icon: const Icon(Icons.search, color: Cores.marinho),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (_) => _buscarDeNovo(),
      onSubmitted: (_) => _carregar(),
    );
  }

  Widget _hero() {
    final banner = _banner;
    final titulo = texto(banner?['titulo']).isEmpty
        ? 'Produtos da sua unidade'
        : texto(banner?['titulo']);
    final subtitulo = texto(banner?['subtitulo']).isEmpty
        ? 'Preço e estoque confirmados pela loja.'
        : texto(banner?['subtitulo']);
    final selo = texto(banner?['selo']);
    final imagem = urlMidia(texto(banner?['imagemUrl']));
    return Container(
      height: 196,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Cores.laranja,
        borderRadius: BorderRadius.circular(28),
        image: imagem == null
            ? null
            : DecorationImage(
                image: NetworkImage(imagem),
                fit: BoxFit.cover,
                colorFilter: const ColorFilter.mode(
                  Color(0x8814233A),
                  BlendMode.darken,
                ),
              ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selo.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Cores.laranja,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                selo,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          const Spacer(),
          Text(
            titulo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitulo, style: const TextStyle(color: Color(0xFFFFD7BF))),
        ],
      ),
    );
  }

  Widget _faixaCategorias() {
    final itens = [null, ..._categorias];
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: itens.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, indice) {
          final categoria = itens[indice];
          final ativa = categoria == null
              ? _categoriaId == null && !_soOferta
              : _categoriaId == categoria.id;
          final nome = categoria == null ? 'Tudo' : categoria.nome;
          return GestureDetector(
            onTap: () {
              unawaited(HapticFeedback.selectionClick());
              setState(() {
                _soOferta = false;
                _aba = 0;
                _categoriaId = categoria?.id;
              });
              _carregar();
            },
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: ativa ? Cores.laranja : Cores.suave,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _iconeCategoria(nome),
                    color: ativa ? Colors.white : Cores.laranjaEscuro,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 72,
                  child: Text(
                    nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _nomeCategoria() {
    for (final categoria in _categorias) {
      if (categoria.id == _categoriaId) return categoria.nome;
    }
    return 'Produtos em destaque';
  }

  Widget _listaCategorias() {
    if (_carregando) return const Center(child: CircularProgressIndicator());
    if (_aviso != null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [AvisoAnimado(texto: _aviso!, erro: true)],
      );
    }
    if (_categorias.isEmpty) {
      return const Center(
        child: Text('Esta unidade ainda não tem categorias.'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      itemCount: _categorias.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, indice) {
        if (indice == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Categorias',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
          );
        }
        final categoria = _categorias[indice - 1];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            leading: CircleAvatar(
              backgroundColor: Cores.suave,
              child: Icon(
                _iconeCategoria(categoria.nome),
                color: Cores.laranjaEscuro,
              ),
            ),
            title: Text(
              categoria.nome,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('${categoria.quantidade}'),
            trailing: const Icon(Icons.chevron_right, color: Cores.tinta),
            onTap: () {
              unawaited(HapticFeedback.selectionClick());
              setState(() {
                _categoriaId = categoria.id;
                _soOferta = false;
                _aba = 0;
              });
              _carregar();
            },
          ),
        );
      },
    );
  }

  Widget _tituloSecao(String titulo) {
    return Row(
      children: [
        Expanded(
          child: Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$_total',
          style: TextStyle(
            color: Cores.laranja,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _perfil(String nome) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      children: [
        const Text(
          'Sua conta',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Cores.marinho,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          nome.isEmpty ? 'PDV Market' : nome,
          style: const TextStyle(fontSize: 18),
        ),
        Text(
          texto(_conta?['email']),
          style: const TextStyle(color: Cores.tinta),
        ),
        const SizedBox(height: 8),
        Text(_nomeLoja().isEmpty ? 'Unidade da sessão' : _nomeLoja()),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => ref.read(sessaoProvider.notifier).sair(),
          child: const Text('Sair'),
        ),
      ],
    );
  }

  Widget _barra() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Cores.marinho,
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1414233A),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: SizedBox(
          height: 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: _itemBarra(0, Icons.home_outlined, Icons.home, 'Início'),
              ),
              Expanded(
                child: _itemBarra(
                  1,
                  Icons.grid_view_outlined,
                  Icons.grid_view,
                  'Categorias',
                ),
              ),
              _pedidoCentro(),
              Expanded(
                child: _itemBarra(
                  3,
                  Icons.local_offer_outlined,
                  Icons.local_offer,
                  'Ofertas',
                ),
              ),
              Expanded(
                child: _itemBarra(
                  4,
                  Icons.person_outline,
                  Icons.person,
                  'Perfil',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemBarra(int aba, IconData icone, IconData ativo, String rotulo) {
    final ligada = _aba == aba;
    return InkWell(
      onTap: () {
        unawaited(HapticFeedback.selectionClick());
        final oferta = aba == 3;
        final mudou = oferta != _soOferta || (aba == 0 && _soOferta);
        setState(() {
          _aba = aba;
          if (aba == 1 || aba == 3) _categoriaId = null;
          if (aba == 3) _soOferta = true;
          if (aba == 0) _soOferta = false;
        });
        if (mudou) _carregar();
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            ligada ? ativo : icone,
            color: ligada ? Cores.laranja : Colors.white70,
          ),
          SizedBox(
            width: 58,
            child: Text(
              rotulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: ligada ? Cores.laranja : Colors.white70,
                fontWeight: ligada ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pedidoCentro() {
    return Transform.translate(
      offset: const Offset(0, -16),
      child: GestureDetector(
        onTap: _abrirPedido,
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Cores.laranja,
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.shopping_bag, color: Colors.white),
              if (_quantidadeCarrinho > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_quantidadeCarrinho',
                      style: const TextStyle(
                        color: Cores.marinho,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _icone(IconData icone, {required VoidCallback onTap, int selo = 0}) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icone, color: Cores.marinho),
              if (selo > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Cores.laranja,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$selo',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _nomeLoja() {
    final nome = texto(_conta?['lojaNome']);
    if (nome.isNotEmpty) return nome;
    return unidadeDaConta(_conta) == null ? 'Sem unidade' : 'Sua unidade';
  }

  IconData _iconeCategoria(String nome) {
    final textoNome = nome.toLowerCase();
    if (textoNome.contains('beb')) return Icons.local_drink_outlined;
    if (textoNome.contains('pad') || textoNome.contains('pão')) {
      return Icons.bakery_dining_outlined;
    }
    if (textoNome.contains('fruta') || textoNome.contains('hort')) {
      return Icons.eco_outlined;
    }
    if (textoNome.contains('limpeza')) {
      return Icons.cleaning_services_outlined;
    }
    if (nome == 'Tudo') {
      return Icons.apps;
    }
    return Icons.shopping_basket_outlined;
  }
}

String? urlMidia(String caminho) {
  if (caminho.isEmpty) return null;
  if (caminho.startsWith('http')) return caminho;
  final base = Ambiente.resolveBaseUrl();
  return caminho.startsWith('/') ? '$base$caminho' : '$base/$caminho';
}

class _CardProduto extends StatelessWidget {
  const _CardProduto({
    required this.produto,
    required this.quantidade,
    required this.aoSomar,
    required this.aoAbrir,
  });

  final ProdutoResumo produto;
  final int quantidade;
  final VoidCallback aoSomar;
  final VoidCallback aoAbrir;

  @override
  Widget build(BuildContext context) {
    final imagem = urlMidia(produto.imagemUrl);
    return Material(
      key: ValueKey('produto-card-${produto.id}'),
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: aoAbrir,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  height: 72,
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1E8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: imagem == null
                      ? Icon(
                          Icons.shopping_bag_outlined,
                          color: Cores.laranja,
                          size: 30,
                        )
                      : Image.network(
                          imagem,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.shopping_bag_outlined,
                            color: Cores.laranja,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              if (produto.emOferta)
                Text(
                  'OFERTA',
                  style: TextStyle(
                    color: Cores.laranja,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              Text(
                produto.nome,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              if (produto.descricao.isNotEmpty)
                Text(
                  produto.descricao,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Cores.tinta, fontSize: 10),
                ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          produto.preco,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                        if (produto.precoOriginal != null)
                          Text(
                            produto.precoOriginal!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Cores.tinta,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: aoSomar,
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Cores.laranja,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        quantidade == 0 ? '+' : '$quantidade',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
