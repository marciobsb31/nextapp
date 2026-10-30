import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/entrada.dart';
import '../../app/provedores.dart';
import '../../app/tema.dart';
import '../../core/rede/falha_api.dart';
import '../../core/sessao/sessao.dart';
import '../inicio/produto_resumo.dart';

/// Fila da equipe. A etapa seguinte é a que `AppOperacaoService` já aceita.
String? proximaSituacao(String atual, {required bool pagarNaLoja}) {
  return switch (atual) {
    'RECEBIDO' => 'EM_SEPARACAO',
    'EM_SEPARACAO' => 'PRONTO',
    'PRONTO' when !pagarNaLoja => 'RETIRADO',
    _ => null,
  };
}

bool podeCancelar(String atual, String pagamento) {
  return pagamento != 'PAGO' && (atual == 'RECEBIDO' || atual == 'EM_SEPARACAO' || atual == 'PRONTO');
}

String rotuloAcao(String destino) {
  return switch (destino) {
    'EM_SEPARACAO' => 'Separar',
    'PRONTO' => 'Marcar pronto',
    'RETIRADO' => 'Entregar',
    _ => 'Atualizar',
  };
}

String rotuloSituacao(String situacao) {
  return switch (situacao) {
    'RECEBIDO' => 'Recebidos',
    'EM_SEPARACAO' => 'Separação',
    'PRONTO' => 'Prontos',
    'ENCERRADOS' => 'Encerrados',
    'RETIRADO' => 'Retirado',
    'CANCELADO' => 'Cancelado',
    _ => situacao,
  };
}

class PedidosLoja extends ConsumerStatefulWidget {
  const PedidosLoja({required this.unidadeId, super.key});

  final int unidadeId;

  @override
  ConsumerState<PedidosLoja> createState() => _PedidosLojaState();
}

class _PedidosLojaState extends ConsumerState<PedidosLoja> {
  static const _etapas = ['RECEBIDO', 'EM_SEPARACAO', 'PRONTO', 'ENCERRADOS'];

  String _situacao = 'RECEBIDO';
  List<Map<String, dynamic>> _itens = const [];
  Map<String, dynamic> _contagens = const {};
  var _carregando = true;
  String? _aviso;
  int? _ocupado;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_carregar);
  }

  @override
  void didUpdateWidget(PedidosLoja oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.unidadeId != widget.unidadeId) _carregar();
  }

  Future<void> _carregar() async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null) return;
    setState(() {
      _carregando = true;
      _aviso = null;
    });
    try {
      final corpo = await ref.read(apiProvider).pedidosOperacao(sessao, unidadeId: widget.unidadeId, situacao: _situacao);
      final itens = corpo['itens'];
      if (!mounted) return;
      setState(() {
        _itens = [
          if (itens is List)
            for (final item in itens)
              if (item is Map) Map<String, dynamic>.from(item),
        ];
        final contagens = corpo['contagens'];
        _contagens = contagens is Map ? Map<String, dynamic>.from(contagens) : const {};
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() => _aviso = falhaDe(erro).mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _avancar(Map<String, dynamic> pedido, String destino, {String? motivo}) async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    final id = pedido['id'];
    if (sessao == null || id is! num) return;
    setState(() => _ocupado = id.toInt());
    try {
      await ref.read(apiProvider).situacaoPedido(
            sessao,
            unidadeId: widget.unidadeId,
            pedidoId: id.toInt(),
            situacao: destino,
            motivo: motivo,
          );
      await HapticFeedback.mediumImpact();
      await _carregar();
    } catch (erro) {
      if (!mounted) return;
      setState(() => _aviso = falhaDe(erro).mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = null);
    }
  }

  Future<void> _receber(Map<String, dynamic> pedido, String metodo) async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    final id = pedido['id'];
    if (sessao == null || id is! num) return;
    setState(() => _ocupado = id.toInt());
    try {
      await ref.read(apiProvider).receberPedido(sessao, unidadeId: widget.unidadeId, pedidoId: id.toInt(), metodo: metodo);
      await HapticFeedback.mediumImpact();
      await _carregar();
    } catch (erro) {
      if (!mounted) return;
      setState(() => _aviso = falhaDe(erro).mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          const Text('Pedidos', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Pedidos feitos no aplicativo desta unidade.', style: TextStyle(color: Cores.tinta)),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final etapa in _etapas)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${rotuloSituacao(etapa)} ${_contagens[etapa] ?? ''}'),
                      selected: _situacao == etapa,
                      selectedColor: Cores.laranja,
                      labelStyle: TextStyle(color: _situacao == etapa ? Colors.white : Cores.marinho, fontWeight: FontWeight.w700),
                      onSelected: (_) {
                        setState(() => _situacao = etapa);
                        _carregar();
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_carregando) const LinearProgressIndicator(),
          if (_aviso != null) ...[
            const SizedBox(height: 12),
            AvisoAnimado(texto: _aviso!, erro: true),
          ],
          if (!_carregando && _aviso == null && _itens.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Column(
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 48, color: Cores.laranja),
                  SizedBox(height: 12),
                  Text('Nenhum pedido nesta etapa.', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          for (final pedido in _itens) _cartao(pedido),
        ],
      ),
    );
  }

  Widget _cartao(Map<String, dynamic> pedido) {
    final id = pedido['id'];
    final atual = texto(pedido['statusPedido']);
    final pagarNaLoja = pedido['naLoja'] == true;
    final destino = proximaSituacao(atual, pagarNaLoja: pagarNaLoja);
    final ocupado = id is num && _ocupado == id.toInt();
    final itens = pedido['itens'];
    final nomes = [
      if (itens is List)
        for (final item in itens)
          if (item is Map) '${item['quantidade']}× ${texto(item['nome'])}',
    ];
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(texto(pedido['numero']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const Spacer(),
              Text(reais(pedido['total']), style: const TextStyle(fontWeight: FontWeight.w800, color: Cores.laranja)),
            ],
          ),
          if (texto(pedido['clienteNome']).isNotEmpty)
            Text(
              texto(pedido['telefoneFinal']).isEmpty
                  ? texto(pedido['clienteNome'])
                  : '${texto(pedido['clienteNome'])} · final ${texto(pedido['telefoneFinal'])}',
              style: const TextStyle(color: Cores.tinta),
            ),
          if (nomes.isNotEmpty) Text(nomes.join(', '), style: const TextStyle(fontSize: 13)),
          if (pagarNaLoja)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Pagamento na loja ainda pendente.', style: TextStyle(color: Cores.laranjaEscuro, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 12),
          if (destino != null)
            FilledButton(
              onPressed: ocupado ? null : () => _avancar(pedido, destino),
              child: Text(ocupado ? 'Aguarde...' : rotuloAcao(destino)),
            ),
          if (pagarNaLoja && atual != 'CANCELADO' && atual != 'RETIRADO')
            OutlinedButton(onPressed: ocupado ? null : () => _folhaReceber(pedido), child: const Text('Receber na loja')),
          if (podeCancelar(atual, texto(pedido['statusPagamento'])))
            TextButton(onPressed: ocupado ? null : () => _pedirMotivo(pedido), child: const Text('Cancelar pedido')),
        ],
      ),
    );
  }

  Future<void> _folhaReceber(Map<String, dynamic> pedido) async {
    final metodo = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Receber ${texto(pedido['numero'])}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 8),
            const Text('O valor já está no pedido. Escolha como a loja recebeu.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => Navigator.pop(context, 'DINHEIRO'), child: const Text('Dinheiro')),
            const SizedBox(height: 8),
            FilledButton(onPressed: () => Navigator.pop(context, 'CREDITO'), child: const Text('Crédito')),
            const SizedBox(height: 8),
            FilledButton(onPressed: () => Navigator.pop(context, 'DEBITO'), child: const Text('Débito')),
          ],
        ),
      ),
    );
    if (metodo != null) await _receber(pedido, metodo);
  }

  Future<void> _pedirMotivo(Map<String, dynamic> pedido) async {
    final motivo = TextEditingController();
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancelar ${texto(pedido['numero'])}'),
        content: TextField(controller: motivo, decoration: const InputDecoration(labelText: 'Motivo'), maxLength: 200),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancelar pedido')),
        ],
      ),
    );
    final textoMotivo = motivo.text.trim();
    motivo.dispose();
    if (confirmou == true && textoMotivo.isNotEmpty) {
      await _avancar(pedido, 'CANCELADO', motivo: textoMotivo);
    } else if (confirmou == true && mounted) {
      setState(() => _aviso = 'Conte o motivo do cancelamento.');
    }
  }
}
