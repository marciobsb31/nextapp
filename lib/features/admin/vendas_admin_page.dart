import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/provedores.dart';
import '../../app/tema.dart';
import '../../core/rede/falha_api.dart';
import '../../core/sessao/sessao.dart';
import '../inicio/produto_resumo.dart';
import 'gestao_comum.dart';

/// Vendas da unidade (totem e app) com os itens de cada uma, e as vendas suspeitas do totem.
class VendasAdminPage extends ConsumerStatefulWidget {
  const VendasAdminPage({super.key, this.unidadeId, this.abrirSuspeitas = false});

  final int? unidadeId;
  final bool abrirSuspeitas;

  @override
  ConsumerState<VendasAdminPage> createState() => _VendasAdminPageState();
}

class _VendasAdminPageState extends ConsumerState<VendasAdminPage> {
  var _dias = 1;
  var _origem = '';
  var _carregando = true;
  String? _erro;
  List<Map<String, dynamic>> _vendas = const [];
  List<Map<String, dynamic>> _suspeitas = const [];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_carregar);
  }

  Future<void> _carregar() async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final api = ref.read(apiProvider);
      final consulta = {'lojaId': ?widget.unidadeId};
      final vendas = mapas(await api.gestao(sessao, '/api/vendas', consulta: consulta, unidadeId: widget.unidadeId));
      List<Map<String, dynamic>> suspeitas = const [];
      try {
        suspeitas = mapas(await api.gestao(sessao, '/api/vendas-suspeitas',
            consulta: {'dias': _dias < 7 ? 7 : _dias, 'lojaId': ?widget.unidadeId}, unidadeId: widget.unidadeId));
      } catch (_) {
        // Contrato sem totem: a aba fica vazia.
      }
      if (!mounted) return;
      setState(() {
        _vendas = vendas;
        _suspeitas = suspeitas;
      });
    } catch (erro) {
      if (mounted) setState(() => _erro = falhaDe(erro).mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  List<Map<String, dynamic>> get _filtradas {
    final hoje = DateTime.now();
    final inicio = DateTime(hoje.year, hoje.month, hoje.day).subtract(Duration(days: _dias - 1));
    return [
      for (final venda in _vendas)
        if ((DateTime.tryParse(texto(venda['dataVenda'])) ?? DateTime(2000)).isAfter(inicio) &&
            (_origem.isEmpty || texto(venda['origem']).toUpperCase() == _origem))
          venda,
    ]..sort((a, b) => texto(b['dataVenda']).compareTo(texto(a['dataVenda'])));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.abrirSuspeitas ? 1 : 0,
      child: TelaGestao(
        titulo: 'Vendas',
        acoes: [IconButton(onPressed: _carregar, icon: const Icon(Icons.refresh))],
        corpo: Column(
          children: [
            TabBar(
              labelColor: Cores.laranja,
              indicatorColor: Cores.laranja,
              unselectedLabelColor: Cores.tinta,
              tabs: [const Tab(text: 'Vendas'), Tab(text: 'Suspeitas (${_suspeitas.where((s) => s['revisao'] == null).length})')],
            ),
            Expanded(child: TabBarView(children: [_listaVendas(), _listaSuspeitas()])),
          ],
        ),
      ),
    );
  }

  Widget _listaVendas() {
    final lista = _filtradas;
    final total = lista.fold<double>(0, (soma, v) => soma + (double.tryParse(texto(v['valorTotal'])) ?? 0));
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
        children: [
          EscolhaPeriodo(dias: _dias, aoEscolher: (d) => setState(() => _dias = d)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final opcao in const [('', 'Todas'), ('TOTEM', 'Totem'), ('APP', 'App')])
                ChoiceChip(
                  label: Text(opcao.$2),
                  selected: _origem == opcao.$1,
                  onSelected: (_) => setState(() => _origem = opcao.$1),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            Indicador(rotulo: 'Vendas', valor: '${lista.length}'),
            const SizedBox(width: 8),
            Indicador(rotulo: 'Total', valor: reais(total.toStringAsFixed(2)), cor: Cores.laranja),
          ]),
          const SizedBox(height: 12),
          EstadoLista(carregando: _carregando, erro: _erro, vazia: !_carregando && lista.isEmpty, textoVazio: 'Nenhuma venda neste período.'),
          for (final venda in lista)
            CartaoGestao(
              titulo: 'Venda #${venda['id']} · ${_rotuloOrigem(texto(venda['origem']))}',
              detalhe: '${dataCurta(venda['dataVenda'])} · ${_pagamento(texto(venda['metodoPagamento']))} · ${_situacao(texto(venda['statusPagamento']))}',
              valor: reais(venda['valorTotal']),
              icone: texto(venda['origem']).toUpperCase() == 'APP' ? Icons.phone_iphone : Icons.point_of_sale,
              aoTocar: () => _detalhe(venda),
            ),
        ],
      ),
    );
  }

  Widget _listaSuspeitas() {
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
        children: [
          const Text('Sessões do totem com sinais de retirada sem pagamento. Revise pela gravação.', style: TextStyle(color: Cores.tinta)),
          const SizedBox(height: 12),
          EstadoLista(carregando: _carregando, vazia: !_carregando && _suspeitas.isEmpty, textoVazio: 'Nenhuma venda suspeita nos últimos dias.'),
          for (final s in _suspeitas)
            CartaoGestao(
              titulo: '${texto(s['nivel']) == 'ALTO' ? 'Risco alto' : texto(s['nivel']) == 'MEDIO' ? 'Risco médio' : 'Risco baixo'} · ${texto(s['clienteNome']).isEmpty ? 'Sem cadastro' : texto(s['clienteNome'])}',
              detalhe: '${dataCurta(s['inicio'])} · ${mapas(s['motivos']).map((m) => texto(m['titulo'])).take(2).join(' · ')}'
                  '${s['revisao'] is Map ? ' · ${(s['revisao'] as Map)['decisao'] == 'PROCEDENTE' ? 'Procedente' : 'Descartada'}' : ''}',
              valor: reais(s['valorRetirado']),
              icone: Icons.report_gmailerrorred,
              corIcone: texto(s['nivel']) == 'ALTO' ? Cores.erro : Cores.alerta,
              aoTocar: s['revisao'] == null ? () => _revisar(s) : null,
            ),
        ],
      ),
    );
  }

  Future<void> _revisar(Map<String, dynamic> suspeita) async {
    final decisao = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(12), child: Text('Depois de ver a gravação:', style: TextStyle(fontWeight: FontWeight.w800))),
            ListTile(leading: const Icon(Icons.gavel), title: const Text('Procedente (houve retirada sem pagar)'), onTap: () => Navigator.pop(context, 'PROCEDENTE')),
            ListTile(leading: const Icon(Icons.check_circle_outline), title: const Text('Descartar (estava tudo certo)'), onTap: () => Navigator.pop(context, 'DESCARTADO')),
          ],
        ),
      ),
    );
    if (decisao == null || !mounted) return;
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null) return;
    try {
      await ref.read(apiProvider).gestaoEnviar(sessao, 'PUT', '/api/vendas-suspeitas/${suspeita['sessao']}/revisao',
          corpo: {'decisao': decisao, 'observacao': 'Revisado pelo app.'});
      if (mounted) avisar(context, 'Revisão registrada.');
      await _carregar();
    } catch (erro) {
      if (mounted) avisar(context, falhaDe(erro).mensagem, erro: true);
    }
  }

  void _detalhe(Map<String, dynamic> venda) {
    final itens = mapas(venda['itens']);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, rolagem) => ListView(
          controller: rolagem,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Text('Venda #${venda['id']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text('${dataCurta(venda['dataVenda'])} · ${_rotuloOrigem(texto(venda['origem']))}', style: const TextStyle(color: Cores.tinta)),
            const SizedBox(height: 6),
            Text('${_pagamento(texto(venda['metodoPagamento']))} · ${_situacao(texto(venda['statusPagamento']))}'),
            if (texto(venda['cupomCodigo']).isNotEmpty) Text('Cupom ${venda['cupomCodigo']}'),
            const Divider(height: 24),
            for (final item in itens)
              CartaoGestao(
                titulo: texto((item['produto'] is Map ? item['produto'] as Map : const {})['nome']),
                detalhe: '${item['quantidade']} × ${reais(item['valorUnitario'])}',
                icone: Icons.shopping_bag_outlined,
              ),
            const SizedBox(height: 8),
            Text('Total ${reais(venda['valorTotal'])}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Cores.laranja)),
          ],
        ),
      ),
    );
  }

  String _rotuloOrigem(String origem) => switch (origem.toUpperCase()) {
        'APP' => 'App',
        'TOTEM' => 'Totem',
        '' => 'Totem',
        _ => origem,
      };

  String _pagamento(String metodo) => switch (metodo.toUpperCase()) {
        'PIX' => 'PIX',
        'CREDITO' || 'CREDIT_CARD' => 'Crédito',
        'DEBITO' || 'DEBIT_CARD' => 'Débito',
        'NA_LOJA' || 'MAQUININHA' => 'Maquininha',
        '' => 'Pagamento',
        _ => metodo,
      };

  String _situacao(String status) => switch (status.toUpperCase()) {
        'PAGO' => 'Pago',
        'PENDENTE' || 'AGUARDANDO' => 'Aguardando',
        'CANCELADO' || 'RECUSADO' => 'Não pago',
        '' => 'Concluída',
        _ => status,
      };
}
