import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/provedores.dart';
import '../../app/tema.dart';
import '../../core/rede/falha_api.dart';
import '../../core/sessao/sessao.dart';
import '../inicio/inicio_page.dart';
import '../inicio/produto_resumo.dart';
import 'gestao_comum.dart';

/// Produtos cadastrados, com estoque e a chave de disponibilidade (some do totem e do app quando desligada).
class CatalogoAdmin extends ConsumerStatefulWidget {
  const CatalogoAdmin({super.key, required this.unidadeId});

  final int? unidadeId;

  @override
  ConsumerState<CatalogoAdmin> createState() => _CatalogoAdminState();
}

class _CatalogoAdminState extends ConsumerState<CatalogoAdmin> {
  final _busca = TextEditingController();
  var _filtro = 'TODOS';
  var _carregando = true;
  String? _erro;
  List<Map<String, dynamic>> _produtos = const [];
  final Set<int> _salvando = {};

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_carregar);
  }

  @override
  void didUpdateWidget(CatalogoAdmin antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.unidadeId != widget.unidadeId) _carregar();
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final lista = mapas(await ref.read(apiProvider).gestao(sessao, '/api/produtos',
          consulta: {'lojaId': ?widget.unidadeId}, unidadeId: widget.unidadeId));
      lista.sort((a, b) => texto(a['nome']).toLowerCase().compareTo(texto(b['nome']).toLowerCase()));
      if (mounted) setState(() => _produtos = lista);
    } catch (erro) {
      if (mounted) setState(() => _erro = falhaDe(erro).mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  int _estoque(Map<String, dynamic> p) => p['estoque'] is Map ? ((p['estoque'] as Map)['quantidade'] as num?)?.toInt() ?? 0 : 0;

  Future<void> _alternar(Map<String, dynamic> produto, bool disponivel) async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    final id = (produto['id'] as num).toInt();
    if (sessao == null) return;
    setState(() => _salvando.add(id));
    try {
      await ref.read(apiProvider).gestaoEnviar(sessao, 'PUT', '/api/produtos/$id/disponibilidade', corpo: {'disponivel': disponivel});
      setState(() => produto['disponivel'] = disponivel);
    } catch (erro) {
      if (mounted) avisar(context, falhaDe(erro).mensagem, erro: true);
    } finally {
      if (mounted) setState(() => _salvando.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final termo = _busca.text.trim().toLowerCase();
    final lista = [
      for (final p in _produtos)
        if ((termo.isEmpty || texto(p['nome']).toLowerCase().contains(termo) || texto(p['codigoBarras']).contains(termo)) &&
            switch (_filtro) {
              'DISPONIVEIS' => p['disponivel'] == true,
              'INDISPONIVEIS' => p['disponivel'] != true,
              'SEM_ESTOQUE' => _estoque(p) <= 0,
              _ => true,
            })
          p,
    ];
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          const Text('Catálogo', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          Text('${_produtos.length} produtos · ${_produtos.where((p) => p['disponivel'] == true).length} disponíveis',
              style: const TextStyle(color: Cores.tinta)),
          const SizedBox(height: 12),
          TextField(
            controller: _busca,
            decoration: InputDecoration(
              hintText: 'Buscar por nome ou código',
              prefixIcon: const Icon(Icons.search, color: Cores.tinta),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final opcao in const [('TODOS', 'Todos'), ('DISPONIVEIS', 'Disponíveis'), ('INDISPONIVEIS', 'Indisponíveis'), ('SEM_ESTOQUE', 'Sem estoque')])
                ChoiceChip(label: Text(opcao.$2), selected: _filtro == opcao.$1, onSelected: (_) => setState(() => _filtro = opcao.$1)),
            ],
          ),
          const SizedBox(height: 12),
          EstadoLista(carregando: _carregando, erro: _erro, vazia: !_carregando && lista.isEmpty, textoVazio: 'Nenhum produto.'),
          for (final p in lista) _linha(p),
        ],
      ),
    );
  }

  Widget _linha(Map<String, dynamic> p) {
    final foto = urlMidia(texto(p['imagemUrl']));
    final id = (p['id'] as num).toInt();
    final estoque = _estoque(p);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Cores.raio),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Cores.raio)),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 48,
              height: 48,
              child: foto == null
                  ? ColoredBox(color: Cores.suave, child: Icon(Icons.shopping_bag_outlined, color: Cores.laranja))
                  : Image.network(foto, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(color: Cores.suave, child: Icon(Icons.shopping_bag_outlined, color: Cores.laranja))),
            ),
          ),
          title: Text(texto(p['nome']), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${reais(p['preco'])} · estoque $estoque${p['disponivel'] == true ? '' : ' · indisponível'}',
              style: TextStyle(color: estoque <= 0 ? Cores.erro : Cores.tinta, fontSize: 12)),
          trailing: _salvando.contains(id)
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : Switch(value: p['disponivel'] == true, activeThumbColor: Cores.laranja, onChanged: (v) => _alternar(p, v)),
        ),
      ),
    );
  }
}

/// Lista de compras: o que está abaixo do mínimo e quanto falta para repor.
class ReposicaoPage extends ConsumerStatefulWidget {
  const ReposicaoPage({super.key});

  @override
  ConsumerState<ReposicaoPage> createState() => _ReposicaoPageState();
}

class _ReposicaoPageState extends ConsumerState<ReposicaoPage> {
  var _carregando = true;
  String? _erro;
  List<Map<String, dynamic>> _itens = const [];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_carregar);
  }

  Future<void> _carregar() async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null) return;
    setState(() => _carregando = true);
    try {
      final itens = mapas(await ref.read(apiProvider).gestao(sessao, '/api/compras/reposicao'));
      if (mounted) setState(() => _itens = itens);
    } catch (erro) {
      if (mounted) setState(() => _erro = falhaDe(erro).mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final custo = _itens.fold<double>(0, (s, i) => s + (double.tryParse(texto(i['custo'])) ?? 0) * ((i['faltam'] as num?) ?? 0));
    return TelaGestao(
      titulo: 'Lista de compras',
      acoes: [IconButton(onPressed: _carregar, icon: const Icon(Icons.refresh))],
      corpo: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Row(children: [
              Indicador(rotulo: 'Para repor', valor: '${_itens.length} itens'),
              const SizedBox(width: 8),
              Indicador(rotulo: 'Custo estimado', valor: reais(custo.toStringAsFixed(2)), cor: Cores.laranja),
            ]),
            const SizedBox(height: 12),
            EstadoLista(carregando: _carregando, erro: _erro, vazia: !_carregando && _itens.isEmpty, textoVazio: 'Nada abaixo do mínimo.'),
            for (final item in _itens)
              CartaoGestao(
                titulo: texto(item['nome']),
                detalhe: 'Tem ${item['atual']} · mínimo ${item['minimo']} · ${texto(item['categoria'])}',
                valor: 'Comprar ${item['faltam']}',
                icone: Icons.shopping_cart_outlined,
              ),
          ],
        ),
      ),
    );
  }
}
