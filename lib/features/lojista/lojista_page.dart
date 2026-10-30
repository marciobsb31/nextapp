import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/entrada.dart';
import '../../app/provedores.dart';
import '../../app/tema.dart';
import '../../core/rede/falha_api.dart';
import '../../core/sessao/sessao.dart';
import '../inicio/inicio_page.dart';
import '../inicio/produto_resumo.dart';
import 'cupons_page.dart';
import 'fornecedores_page.dart';
import 'pedidos_loja.dart';

/// Painel de quem opera a loja. O cliente compra em outra tela.
/// Os números vêm de `GET /api/app/admin/dashboard`. O aplicativo não soma venda.
class LojistaPage extends ConsumerStatefulWidget {
  const LojistaPage({super.key});

  @override
  ConsumerState<LojistaPage> createState() => _LojistaPageState();
}

class _LojistaPageState extends ConsumerState<LojistaPage> {
  final _busca = TextEditingController();
  Map<String, dynamic>? _conta;
  Map<String, dynamic>? _painel;
  List<_Unidade> _lojas = const [];
  int? _lojaEscolhida;
  var _todas = false;
  var _periodo = 1;
  var _aba = 0;
  var _carregando = true;
  String? _aviso;
  List<ProdutoResumo> _produtos = const [];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_carregar);
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null) return;
    setState(() => _carregando = true);
    try {
      final conta = await ref.read(apiProvider).eu(sessao);
      final lojas = _unidades(conta['lojasPermitidas']);
      final daConta = conta['lojaId'];
      var unidade = daConta is num ? daConta.toInt() : _lojaEscolhida;
      var todas = sessao.admin && _todas;
      if (daConta is num) todas = false;
      if (!todas && unidade == null && lojas.length == 1) unidade = lojas.first.id;
      Map<String, dynamic>? painel;
      String? aviso;
      List<ProdutoResumo> produtos = const [];
      if (!todas && unidade == null) {
        aviso = null;
      } else {
        try {
          painel = await ref.read(apiProvider).painelLoja(
                sessao,
                unidadeId: todas ? null : unidade,
                periodo: _periodo,
                todas: todas,
              );
        } catch (erro) {
          aviso = falhaDe(erro).mensagem;
        }
        if (unidade != null && _aba == 2) {
          try {
            final catalogo = await ref.read(apiProvider).produtos(sessao, busca: _busca.text, unidadeId: unidade);
            final itens = catalogo['itens'];
            produtos = [
              if (itens is List)
                for (final item in itens)
                  if (item is Map) ProdutoResumo.deJson(Map<String, dynamic>.from(item)),
            ];
          } catch (erro) {
            aviso ??= falhaDe(erro).mensagem;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _conta = conta;
        _lojas = lojas;
        _lojaEscolhida = unidade;
        _todas = todas;
        _painel = painel;
        _produtos = produtos;
        _aviso = aviso;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() => _aviso = falhaDe(erro).mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _escolher(int? id, {required bool todas}) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _lojaEscolhida = id;
      _todas = todas;
      _aba = 0;
      _produtos = const [];
    });
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final nome = texto(_conta?['nome']);
    final primeiro = nome.split(' ').first;
    return Scaffold(
      backgroundColor: Cores.fundo,
      extendBody: true,
      body: SafeArea(
        child: switch (_aba) {
          1 => _pedidos(),
          2 => _produtosDaUnidade(),
          3 => _estoque(),
          4 => _perfil(nome),
          _ => _resumo(primeiro.isEmpty ? 'Olá' : 'Olá, $primeiro'),
        },
      ),
      bottomNavigationBar: _barra(),
    );
  }

  Widget _resumo(String saudacao) {
    final painel = _painel;
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        children: [
          Text(saudacao, style: const TextStyle(color: Cores.tinta)),
          const Text('Sua loja', style: TextStyle(color: Cores.laranja, fontWeight: FontWeight.w900, fontSize: 28, height: 1)),
          Text(_nomeLoja(), style: const TextStyle(color: Cores.tinta, fontSize: 13)),
          const SizedBox(height: 16),
          if (_carregando) const LinearProgressIndicator(),
          if (_aviso != null) ...[
            const SizedBox(height: 12),
            AvisoAnimado(texto: _aviso!, erro: true),
          ],
          if (_unidadePronta) ...[
            _periodos(),
            const SizedBox(height: 14),
            if (painel != null) ...[
              _faixaFaturamento(painel),
              const SizedBox(height: 12),
              _metricas(painel),
              const SizedBox(height: 18),
              _secao('Mais vendidos', _linhasVenda(painel['maisVendidos'])),
              const SizedBox(height: 8),
              Text(
                texto(painel['premissas']).isEmpty
                    ? 'Faturamento é a soma do que foi vendido. Não é lucro.'
                    : texto(painel['premissas']),
                style: const TextStyle(color: Cores.tinta, fontSize: 12),
              ),
            ],
          ] else
            _escolhaUnidade(),
        ],
      ),
    );
  }

  bool get _unidadePronta => _todas || _lojaEscolhida != null;

  Widget _periodos() {
    const opcoes = [(1, 'Hoje'), (7, '7 dias'), (30, '30 dias')];
    return Row(
      children: [
        for (final opcao in opcoes) ...[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(opcao.$2),
                selected: _periodo == opcao.$1,
                selectedColor: Cores.laranja,
                labelStyle: TextStyle(color: _periodo == opcao.$1 ? Colors.white : Cores.marinho, fontWeight: FontWeight.w700),
                onSelected: (_) {
                  setState(() => _periodo = opcao.$1);
                  _carregar();
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _faixaFaturamento(Map<String, dynamic> painel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Cores.laranja, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_periodo == 1 ? 'Faturamento de hoje' : 'Faturamento do período', style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 6),
          Text(reais(painel['faturamento']), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
          Text('${painel['vendas'] ?? 0} vendas', style: const TextStyle(color: Color(0xFFFFE8D6))),
        ],
      ),
    );
  }

  Widget _metricas(Map<String, dynamic> painel) {
    return Row(
      children: [
        _metrica('Ticket', reais(painel['ticketMedio'])),
        const SizedBox(width: 8),
        _metrica('Itens', '${painel['itens'] ?? 0}'),
        const SizedBox(width: 8),
        _metrica('Vendas', '${painel['vendas'] ?? 0}'),
      ],
    );
  }

  Widget _metrica(String rotulo, String valor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rotulo, style: const TextStyle(color: Cores.tinta, fontSize: 12)),
            const SizedBox(height: 4),
            Text(valor, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _secao(String titulo, List<Widget> linhas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        if (linhas.isEmpty)
          const Text('Nada neste período.', style: TextStyle(color: Cores.tinta))
        else
          ...linhas,
      ],
    );
  }

  List<Widget> _linhasVenda(Object? valor) {
    return [
      for (final item in _mapas(valor))
        _linha(texto(item['nome']), '${item['quantidade']} un', reais(item['faturamento'])),
    ];
  }

  Widget _linha(String titulo, String detalhe, String valor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          const CircleAvatar(backgroundColor: Color(0xFFFFE8D6), child: Icon(Icons.shopping_bag_outlined, color: Cores.laranja)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(detalhe, style: const TextStyle(color: Cores.tinta, fontSize: 12)),
              ],
            ),
          ),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _escolhaUnidade() {
    final sessao = ref.read(sessaoProvider).asData?.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Qual unidade?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('O movimento fica na unidade escolhida.', style: TextStyle(color: Cores.tinta)),
        if (sessao?.admin == true)
          _atalhoUnidade('Todas as unidades', () => _escolher(null, todas: true)),
        for (final loja in _lojas) _atalhoUnidade(loja.nome, () => _escolher(loja.id, todas: false)),
      ],
    );
  }

  Widget _atalhoUnidade(String nome, VoidCallback aoTocar) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(nome, style: const TextStyle(fontWeight: FontWeight.w800)),
          trailing: const Icon(Icons.chevron_right, color: Cores.laranja),
          onTap: aoTocar,
        ),
      ),
    );
  }

  Widget _pedidos() {
    final unidade = _lojaEscolhida;
    if (unidade == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        children: [
          const Text('Pedidos', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Escolha a unidade para ver os pedidos do aplicativo.', style: TextStyle(color: Cores.tinta)),
          _escolhaUnidade(),
        ],
      );
    }
    return PedidosLoja(unidadeId: unidade);
  }

  Widget _linhaProduto(ProdutoResumo produto) {
    final foto = urlMidia(produto.imagemUrl);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 48,
              height: 48,
              child: foto == null
                  ? const ColoredBox(color: Color(0xFFFFE8D6), child: Icon(Icons.shopping_bag_outlined, color: Cores.laranja))
                  : Image.network(foto, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFFFE8D6), child: Icon(Icons.shopping_bag_outlined, color: Cores.laranja))),
            ),
          ),
          title: Text(produto.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(produto.categoriaNome, style: const TextStyle(color: Cores.tinta)),
          trailing: Text(produto.preco, style: const TextStyle(fontWeight: FontWeight.w800)),
          onTap: () => _abrirProduto(produto),
        ),
      ),
    );
  }

  Future<void> _abrirProduto(ProdutoResumo produto) async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    final unidade = _lojaEscolhida;
    if (sessao == null || unidade == null) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => FutureBuilder<Map<String, dynamic>>(
        future: ref.read(apiProvider).produto(sessao, produto.id, unidadeId: unidade),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError) return Padding(padding: const EdgeInsets.all(20), child: Text(falhaDe(snapshot.error!).mensagem));
          final corpo = snapshot.data ?? {};
          final foto = urlMidia(texto(corpo['imagemUrl']));
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (foto != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(foto, height: 160, width: double.infinity, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 12),
                Text(texto(corpo['nome']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                Text(reais(corpo['preco']), style: const TextStyle(color: Cores.laranja, fontWeight: FontWeight.w800, fontSize: 18)),
                if (texto(corpo['descricao']).isNotEmpty) Text(texto(corpo['descricao']), style: const TextStyle(color: Cores.tinta)),
                const SizedBox(height: 8),
                Text(corpo['disponivel'] == true ? 'Disponível nesta unidade' : 'Indisponível nesta unidade'),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _produtosDaUnidade() {
    if (_lojaEscolhida == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        children: [
          const Text('Produtos', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Escolha uma unidade para ver os produtos dela.', style: TextStyle(color: Cores.tinta)),
          _escolhaUnidade(),
        ],
      );
    }
    final termo = _busca.text.trim().toLowerCase();
    final lista = [
      for (final produto in _produtos)
        if (termo.isEmpty || produto.nome.toLowerCase().contains(termo)) produto,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        const Text('Produtos', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        Text(_nomeLoja(), style: const TextStyle(color: Cores.tinta)),
        const SizedBox(height: 12),
        TextField(
          controller: _busca,
          decoration: InputDecoration(
            hintText: 'Buscar produto',
            prefixIcon: const Icon(Icons.search, color: Cores.tinta),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _carregar(),
        ),
        const SizedBox(height: 12),
        if (_carregando) const LinearProgressIndicator(),
        if (_aviso != null) AvisoAnimado(texto: _aviso!, erro: true),
        if (!_carregando && lista.isEmpty)
          const Padding(padding: EdgeInsets.only(top: 16), child: Text('Nenhum produto nesta unidade.')),
        for (final produto in lista) _linhaProduto(produto),
      ],
    );
  }

  Widget _estoque() {
    final painel = _painel;
    final baixo = _mapas(painel?['baixoEstoque']);
    final validades = _mapas(painel?['validades']).where((item) => item['situacao'] == 'VENCIDO' || item['situacao'] == 'PROXIMO').toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        const Text('Estoque', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        Text(_nomeLoja(), style: const TextStyle(color: Cores.tinta)),
        const SizedBox(height: 16),
        if (!_unidadePronta) _escolhaUnidade(),
        if (_aviso != null) AvisoAnimado(texto: _aviso!, erro: true),
        if (_unidadePronta && painel != null) ...[
          _secao('Abaixo do mínimo', [
            for (final item in baixo) _linha(texto(item['nome']), 'Mínimo ${item['minimo']}', '${item['quantidade']}'),
          ]),
          const SizedBox(height: 16),
          _secao('Validade', [
            for (final item in validades) _linha(texto(item['nome']), _rotuloValidade(texto(item['situacao'])), texto(item['validade'])),
          ]),
        ],
      ],
    );
  }

  Widget _perfil(String nome) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      children: [
        const Text('Minha conta', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Cores.marinho)),
        const SizedBox(height: 8),
        Text(nome.isEmpty ? 'Lojista' : nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        Text(texto(_conta?['email']), style: const TextStyle(color: Cores.tinta)),
        const SizedBox(height: 4),
        const Text('Perfil de lojista', style: TextStyle(color: Cores.laranja, fontWeight: FontWeight.w700)),
        Text(_nomeLoja()),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FornecedoresPage()));
          },
          child: const Text('Fornecedores'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CuponsPage()));
          },
          child: const Text('Cupons'),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: () => ref.read(sessaoProvider.notifier).sair(), child: const Text('Sair')),
      ],
    );
  }

  Widget _barra() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [BoxShadow(color: Color(0x1414233A), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: SizedBox(
          height: 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _item(0, Icons.home_outlined, Icons.home, 'Início'),
              _item(1, Icons.receipt_long_outlined, Icons.receipt_long, 'Pedidos'),
              _item(2, Icons.inventory_2_outlined, Icons.inventory_2, 'Produtos'),
              _item(3, Icons.warning_amber_outlined, Icons.warning_amber, 'Estoque'),
              _item(4, Icons.person_outline, Icons.person, 'Perfil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(int aba, IconData icone, IconData ativo, String rotulo) {
    final ligada = _aba == aba;
    return InkWell(
      onTap: () {
        unawaited(HapticFeedback.selectionClick());
        setState(() => _aba = aba);
        if (aba == 2) _carregar();
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(ligada ? ativo : icone, color: ligada ? Cores.laranja : Cores.tinta),
          Text(rotulo, style: TextStyle(fontSize: 11, color: ligada ? Cores.laranja : Cores.tinta, fontWeight: ligada ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }

  String _nomeLoja() {
    if (_todas) return 'Todas as unidades';
    for (final loja in _lojas) {
      if (loja.id == _lojaEscolhida) return loja.nome;
    }
    return 'Escolha a unidade';
  }

  List<_Unidade> _unidades(Object? valor) {
    if (valor is! List) return const [];
    return [
      for (final item in valor)
        if (item is Map && item['id'] is num)
          _Unidade((item['id'] as num).toInt(), texto(item['nome']).isEmpty ? 'Unidade ${item['id']}' : texto(item['nome'])),
    ];
  }

  List<Map<String, dynamic>> _mapas(Object? valor) {
    if (valor is! List) return const [];
    return [for (final item in valor) if (item is Map) Map<String, dynamic>.from(item)];
  }

  String _rotuloValidade(String situacao) {
    return switch (situacao) {
      'VENCIDO' => 'Vencido',
      'PROXIMO' => 'Próximo do vencimento',
      'DENTRO' => 'Dentro da validade',
      _ => 'Sem validade informada',
    };
  }
}

class _Unidade {
  const _Unidade(this.id, this.nome);

  final int id;
  final String nome;
}
