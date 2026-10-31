import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/provedores.dart';
import '../../app/tema.dart';
import '../../core/rede/falha_api.dart';
import '../../core/sessao/sessao.dart';
import 'gestao_comum.dart';

/// Portas e geladeiras do Smart Access: se a placa está online, abrir à distância e o QR mestre
/// para a equipe abrir qualquer porta pelo leitor durante a manutenção ou a reposição.
class SmartAccessAdminPage extends ConsumerStatefulWidget {
  const SmartAccessAdminPage({super.key});

  @override
  ConsumerState<SmartAccessAdminPage> createState() => _SmartAccessAdminPageState();
}

class _SmartAccessAdminPageState extends ConsumerState<SmartAccessAdminPage> {
  var _carregando = true;
  String? _erro;
  List<Map<String, dynamic>> _portas = const [];
  Map<int, String> _estados = const {};
  List<Map<String, dynamic>> _auditoria = const [];
  List<Map<String, dynamic>> _mestres = const [];
  final Set<int> _abrindo = {};
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_carregar);
    _relogio = Timer.periodic(const Duration(seconds: 15), (_) => _carregar(silencioso: true));
  }

  @override
  void dispose() {
    _relogio?.cancel();
    super.dispose();
  }

  Future<void> _carregar({bool silencioso = false}) async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null) return;
    if (!silencioso) setState(() => _carregando = true);
    final api = ref.read(apiProvider);
    try {
      final painel = await api.gestao(sessao, '/api/smart-access');
      final mestres = mapas(await api.gestao(sessao, '/api/smart-access/qr-mestre'));
      if (!mounted || painel is! Map) return;
      final estados = <int, String>{};
      for (final placa in mapas(painel['placas'])) {
        final id = placa['dispositivo_id'];
        if (id is num) estados[id.toInt()] = texto(placa['estado']);
      }
      setState(() {
        _portas = mapas(painel['dispositivos']);
        _estados = estados;
        _auditoria = mapas(painel['auditoria']).take(15).toList();
        _mestres = mestres;
        _erro = null;
      });
    } catch (erro) {
      if (mounted && !silencioso) setState(() => _erro = falhaDe(erro).mensagem);
    } finally {
      if (mounted && !silencioso) setState(() => _carregando = false);
    }
  }

  Future<void> _abrir(Map<String, dynamic> porta) async {
    final id = (porta['id'] as num).toInt();
    final certo = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Abrir ${texto(porta['nome'])}?'),
        content: const Text('A ordem vai direto para a placa e fica registrada na auditoria com o seu nome.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Abrir agora')),
        ],
      ),
    );
    if (certo != true || !mounted) return;
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null) return;
    setState(() => _abrindo.add(id));
    try {
      final r = await ref.read(apiProvider).gestaoEnviar(sessao, 'POST', '/api/smart-access/dispositivos/$id/abrir',
          corpo: {'motivo': 'Abertura remota pelo app.'});
      if (mounted) avisar(context, r is Map ? texto(r['motivo']) : 'Ordem enviada.');
      await _carregar(silencioso: true);
    } catch (erro) {
      if (mounted) avisar(context, falhaDe(erro).mensagem, erro: true);
    } finally {
      if (mounted) setState(() => _abrindo.remove(id));
    }
  }

  Future<void> _gerarMestre() async {
    final motivo = TextEditingController(text: 'Reposição de estoque');
    var horas = 2;
    final gerar = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, atualizar) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('QR mestre', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const Text('Abre qualquer porta ou geladeira do contrato pelo leitor, quantas vezes precisar, até vencer.',
                  style: TextStyle(color: Cores.tinta)),
              TextField(controller: motivo, decoration: const InputDecoration(labelText: 'Para quê')),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                for (final h in const [1, 2, 4, 8, 12])
                  ChoiceChip(label: Text('$h h'), selected: horas == h, onSelected: (_) => atualizar(() => horas = h)),
              ]),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Gerar QR')),
            ],
          ),
        ),
      ),
    );
    if (gerar != true || !mounted) return;
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null) return;
    try {
      final r = await ref.read(apiProvider).gestaoEnviar(sessao, 'POST', '/api/smart-access/qr-mestre',
          corpo: {'horas': horas, 'motivo': motivo.text.trim()});
      if (!mounted || r is! Map) return;
      await _carregar(silencioso: true);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => QrMestrePage(dados: Map<String, dynamic>.from(r))));
    } catch (erro) {
      if (mounted) avisar(context, falhaDe(erro).mensagem, erro: true);
    }
  }

  Future<void> _revogar(Map<String, dynamic> mestre) async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null) return;
    try {
      await ref.read(apiProvider).gestaoEnviar(sessao, 'DELETE', '/api/smart-access/qr-mestre/${mestre['id']}');
      if (mounted) avisar(context, 'QR mestre revogado.');
      await _carregar(silencioso: true);
    } catch (erro) {
      if (mounted) avisar(context, falhaDe(erro).mensagem, erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = _portas.where((p) => _estados[(p['id'] as num).toInt()] == 'ONLINE').length;
    return TelaGestao(
      titulo: 'Smart Access',
      acoes: [IconButton(onPressed: _carregar, icon: const Icon(Icons.refresh))],
      corpo: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Row(children: [
              Indicador(rotulo: 'Portas e geladeiras', valor: '${_portas.length}'),
              const SizedBox(width: 8),
              Indicador(rotulo: 'Online', valor: '$online', cor: Cores.sucesso),
              const SizedBox(width: 8),
              Indicador(rotulo: 'Offline', valor: '${_portas.length - online}', cor: Cores.erro),
            ]),
            const SizedBox(height: 12),
            EstadoLista(carregando: _carregando, erro: _erro, vazia: !_carregando && _erro == null && _portas.isEmpty, textoVazio: 'Nenhum aparelho cadastrado.'),
            for (final p in _portas) _porta(p),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Text('QR mestre', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Cores.marinho),
                  onPressed: _gerarMestre,
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Gerar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_mestres.isEmpty) const Text('Nenhum QR mestre ativo.', style: TextStyle(color: Cores.tinta)),
            for (final m in _mestres)
              CartaoGestao(
                titulo: texto(m['motivo']),
                detalhe: 'Vence ${dataCurta(m['expira_em'])} · ${m['usos'] ?? 0} uso(s) · ${texto(m['criado_por'])}',
                icone: Icons.qr_code_2,
                corIcone: Cores.marinho,
                fim: TextButton(onPressed: () => _revogar(m), child: const Text('Revogar')),
              ),
            const SizedBox(height: 16),
            const Text('Últimos acessos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final a in _auditoria)
              CartaoGestao(
                titulo: '${_operacao(texto(a['operacao']))}${texto(a['resultado']) == 'AUTORIZADO' ? '' : ' · negado'}',
                detalhe: '${dataCurta(a['quando'])} · ${texto(a['quem'])} · ${texto(a['detalhe']).isEmpty ? texto(a['motivo']) : texto(a['detalhe'])}',
                icone: texto(a['resultado']) == 'AUTORIZADO' ? Icons.lock_open : Icons.lock_outline,
                corIcone: texto(a['resultado']) == 'AUTORIZADO' ? Cores.sucesso : Cores.erro,
              ),
          ],
        ),
      ),
    );
  }

  Widget _porta(Map<String, dynamic> p) {
    final id = (p['id'] as num).toInt();
    final estado = _estados[id] ?? 'SEM_PLACA';
    final ligada = estado == 'ONLINE';
    return CartaoGestao(
      titulo: texto(p['nome']),
      detalhe: '${_rotuloEstado(estado)} · ${_tipo(texto(p['tipo']))}${p['habilitado'] == true ? '' : ' · desligado'}',
      icone: ligada ? Icons.sensor_door_outlined : Icons.portable_wifi_off,
      corIcone: ligada ? Cores.sucesso : Cores.erro,
      fim: _abrindo.contains(id)
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Cores.laranja),
              onPressed: ligada && p['habilitado'] == true ? () => _abrir(p) : null,
              child: const Text('Abrir'),
            ),
    );
  }

  String _operacao(String codigo) => switch (codigo) {
        'ACESSO_QR' => 'QR do app',
        'EXECUCAO' || 'AUTORIZACAO' => 'Abertura',
        'ABERTURA_REMOTA' => 'Abertura à distância',
        'QR_MESTRE' => 'QR mestre',
        'GELADEIRA' => 'Geladeira',
        'TESTE_CENTRAL' => 'Teste da central',
        'TRAVA' => 'Trava',
        _ => codigo,
      };

  String _rotuloEstado(String estado) => switch (estado) {
        'ONLINE' => 'Online',
        'OFFLINE' => 'Offline',
        'AGUARDANDO_REDE' => 'Aguardando rede',
        'EM_REVISAO' => 'Em revisão',
        'REVOGADO' => 'Placa revogada',
        _ => 'Sem placa',
      };

  String _tipo(String tipo) => switch (tipo) {
        'PORTA' => 'Porta',
        'CATRACA' => 'Catraca',
        'REFRIGERADOR' || 'GELADEIRA' => 'Geladeira',
        'FREEZER' => 'Freezer',
        'EXPOSITOR' => 'Expositor',
        _ => tipo.isEmpty ? 'Aparelho' : tipo,
      };
}

/// QR mestre em tela cheia para mostrar ao leitor, com o prazo que falta.
class QrMestrePage extends StatefulWidget {
  const QrMestrePage({super.key, required this.dados});

  final Map<String, dynamic> dados;

  @override
  State<QrMestrePage> createState() => _QrMestrePageState();
}

class _QrMestrePageState extends State<QrMestrePage> {
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    _relogio = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _relogio?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expira = DateTime.tryParse(texto(widget.dados['expiraEm']));
    final falta = expira?.difference(DateTime.now());
    final vencido = falta != null && falta.isNegative;
    return TelaGestao(
      titulo: 'QR mestre',
      corpo: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(texto(widget.dados['motivo']), textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: cartaoApp(),
              child: vencido
                  ? const SizedBox(width: 260, height: 260, child: Center(child: Text('Venceu. Gere outro.')))
                  : QrImageView(data: texto(widget.dados['qr']), size: 260),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            vencido || falta == null ? 'Vencido' : 'Vale por mais ${falta.inHours} h ${falta.inMinutes % 60} min',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Cores.tinta),
          ),
          const SizedBox(height: 8),
          const Text('Mostre ao leitor da porta ou da geladeira. Cada uso fica na auditoria. Revogue na tela do Smart Access quando terminar.',
              textAlign: TextAlign.center, style: TextStyle(color: Cores.tinta, fontSize: 12)),
        ],
      ),
    );
  }
}
