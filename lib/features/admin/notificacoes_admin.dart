import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/provedores.dart';
import '../../app/tema.dart';
import '../../core/rede/falha_api.dart';
import '../../core/sessao/sessao.dart';
import 'gestao_comum.dart';

IconData iconeDoAviso(String tipo) => switch (tipo) {
      'VENDA' => Icons.point_of_sale,
      'PEDIDO' || 'PEDIDO_APP' => Icons.receipt_long,
      'ESTOQUE' || 'ESTOQUE_ESGOTADO' => Icons.inventory_2_outlined,
      'SUSPEITA' => Icons.report_gmailerrorred,
      'VALIDADE' => Icons.event_busy,
      'TOTEM_OFFLINE' || 'TOTEM_ONLINE' => Icons.tv,
      _ => Icons.notifications_none,
    };

Color corDoAviso(String tipo) => switch (tipo) {
      'SUSPEITA' || 'ESTOQUE_ESGOTADO' || 'TOTEM_OFFLINE' => Cores.erro,
      'ESTOQUE' || 'VALIDADE' => Cores.alerta,
      'VENDA' || 'TOTEM_ONLINE' => Cores.sucesso,
      _ => Cores.laranja,
    };

/// Sino do painel: confere os avisos da equipe a cada 20 segundos enquanto o app está aberto
/// e mostra na hora venda nova, estoque baixo e venda suspeita.
class SinoAdmin extends ConsumerStatefulWidget {
  const SinoAdmin({super.key, this.unidadeId});

  final int? unidadeId;

  @override
  ConsumerState<SinoAdmin> createState() => _SinoAdminState();
}

class _SinoAdminState extends ConsumerState<SinoAdmin> {
  Timer? _relogio;
  int _naoLidas = 0;
  int? _ultimoVisto;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_conferir);
    _relogio = Timer.periodic(const Duration(seconds: 20), (_) => _conferir());
  }

  @override
  void dispose() {
    _relogio?.cancel();
    super.dispose();
  }

  Future<void> _conferir() async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null || !mounted) return;
    try {
      final pagina = await ref.read(apiProvider).gestao(sessao, '/api/app/admin/notificacoes');
      if (pagina is! Map || !mounted) return;
      final itens = mapas(pagina['itens']);
      final maior = itens.isEmpty ? 0 : itens.map((i) => (i['id'] as num).toInt()).reduce((a, b) => a > b ? a : b);
      final novos = _ultimoVisto == null ? const <Map<String, dynamic>>[] : itens.where((i) => (i['id'] as num).toInt() > _ultimoVisto! && i['lida'] != true).toList();
      setState(() {
        _naoLidas = (pagina['naoLidas'] as num?)?.toInt() ?? 0;
        _ultimoVisto = maior > (_ultimoVisto ?? 0) ? maior : _ultimoVisto ?? maior;
      });
      if (novos.isNotEmpty) _mostrar(novos.first, novos.length);
    } catch (_) {
      // Sem rede: tenta de novo na próxima volta.
    }
  }

  void _mostrar(Map<String, dynamic> aviso, int quantos) {
    unawaited(HapticFeedback.heavyImpact());
    final tipo = texto(aviso['tipo']);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        backgroundColor: corDoAviso(tipo),
        content: Row(
          children: [
            Icon(iconeDoAviso(tipo), color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text('${texto(aviso['titulo'])}: ${texto(aviso['mensagem'])}${quantos > 1 ? ' (+${quantos - 1})' : ''}'),
            ),
          ],
        ),
        action: SnackBarAction(label: 'Ver', textColor: Colors.white, onPressed: _abrir),
      ));
  }

  Future<void> _abrir() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NotificacoesAdminPage()));
    await _conferir();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _abrir,
      icon: Badge(
        isLabelVisible: _naoLidas > 0,
        label: Text(_naoLidas > 99 ? '99+' : '$_naoLidas'),
        child: const Icon(Icons.notifications_none, color: Cores.marinho, size: 28),
      ),
    );
  }
}

class NotificacoesAdminPage extends ConsumerStatefulWidget {
  const NotificacoesAdminPage({super.key});

  @override
  ConsumerState<NotificacoesAdminPage> createState() => _NotificacoesAdminPageState();
}

class _NotificacoesAdminPageState extends ConsumerState<NotificacoesAdminPage> {
  var _tipo = 'TODAS';
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
      final pagina = await ref.read(apiProvider).gestao(sessao, '/api/app/admin/notificacoes', consulta: {'tipo': _tipo});
      if (mounted) setState(() => _itens = pagina is Map ? mapas(pagina['itens']) : const []);
    } catch (erro) {
      if (mounted) setState(() => _erro = falhaDe(erro).mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _lerTodas() async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null) return;
    try {
      await ref.read(apiProvider).gestaoEnviar(sessao, 'POST', '/api/app/admin/notificacoes/lidas');
      await _carregar();
    } catch (erro) {
      if (mounted) avisar(context, falhaDe(erro).mensagem, erro: true);
    }
  }

  Future<void> _ler(Map<String, dynamic> aviso) async {
    if (aviso['lida'] == true) return;
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null) return;
    try {
      await ref.read(apiProvider).gestaoEnviar(sessao, 'POST', '/api/app/admin/notificacoes/${aviso['id']}/lida');
      setState(() => aviso['lida'] = true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return TelaGestao(
      titulo: 'Notificações',
      acoes: [TextButton(onPressed: _lerTodas, child: const Text('Marcar todas'))],
      corpo: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final opcao in const [('TODAS', 'Todas'), ('VENDAS', 'Vendas'), ('ALERTAS', 'Alertas'), ('SUSPEITA', 'Suspeitas'), ('PEDIDOS', 'Pedidos')])
                  ChoiceChip(
                    label: Text(opcao.$2),
                    selected: _tipo == opcao.$1,
                    onSelected: (_) {
                      setState(() => _tipo = opcao.$1);
                      _carregar();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Os avisos chegam com o app aberto. Para receber com o app fechado, falta ligar o Firebase.',
                style: TextStyle(color: Cores.tinta, fontSize: 12)),
            const SizedBox(height: 12),
            EstadoLista(carregando: _carregando, erro: _erro, vazia: !_carregando && _itens.isEmpty, textoVazio: 'Nenhuma notificação.'),
            for (final aviso in _itens)
              Opacity(
                opacity: aviso['lida'] == true ? 0.6 : 1,
                child: CartaoGestao(
                  titulo: texto(aviso['titulo']),
                  detalhe: '${dataCurta(aviso['criadoEm'])} · ${texto(aviso['mensagem'])}',
                  icone: iconeDoAviso(texto(aviso['tipo'])),
                  corIcone: corDoAviso(texto(aviso['tipo'])),
                  aoTocar: () => _ler(aviso),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
