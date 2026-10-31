import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/provedores.dart';
import '../../app/tema.dart';
import '../../core/rede/falha_api.dart';
import '../../core/sessao/sessao.dart';
import 'gestao_comum.dart';

/// Clientes e moradores cadastrados, e os avisos em massa para quem usa o app.
class ClientesAvisosPage extends ConsumerStatefulWidget {
  const ClientesAvisosPage({super.key});

  @override
  ConsumerState<ClientesAvisosPage> createState() => _ClientesAvisosPageState();
}

class _ClientesAvisosPageState extends ConsumerState<ClientesAvisosPage> {
  final _busca = TextEditingController();
  var _carregando = true;
  String? _erro;
  List<Map<String, dynamic>> _clientes = const [];
  List<Map<String, dynamic>> _avisos = const [];
  int? _ativos;

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
    setState(() {
      _carregando = true;
      _erro = null;
    });
    final api = ref.read(apiProvider);
    try {
      final clientes = mapas(await api.gestao(sessao, '/api/clientes'));
      clientes.sort((a, b) => texto(a['nome']).toLowerCase().compareTo(texto(b['nome']).toLowerCase()));
      List<Map<String, dynamic>> avisos = const [];
      int? ativos;
      try {
        avisos = mapas(await api.gestao(sessao, '/api/app/avisos'));
        final cadastrados = await api.gestao(sessao, '/api/app/cadastrados');
        if (cadastrados is Map && cadastrados['pessoas'] is num) ativos = (cadastrados['pessoas'] as num).toInt();
      } catch (_) {
        // Avisos dependem do módulo do app; sem ele a aba mostra só o botão bloqueado.
      }
      if (!mounted) return;
      setState(() {
        _clientes = clientes;
        _avisos = avisos;
        _ativos = ativos;
      });
    } catch (erro) {
      if (mounted) setState(() => _erro = falhaDe(erro).mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: TelaGestao(
        titulo: 'Clientes e avisos',
        acoes: [IconButton(onPressed: _carregar, icon: const Icon(Icons.refresh))],
        corpo: Column(
          children: [
            TabBar(
              labelColor: Cores.laranja,
              indicatorColor: Cores.laranja,
              unselectedLabelColor: Cores.tinta,
              tabs: [Tab(text: 'Clientes (${_clientes.length})'), const Tab(text: 'Avisos')],
            ),
            Expanded(child: TabBarView(children: [_listaClientes(), _listaAvisos()])),
          ],
        ),
      ),
    );
  }

  Widget _listaClientes() {
    final termo = _busca.text.trim().toLowerCase();
    final lista = [
      for (final c in _clientes)
        if (termo.isEmpty || '${c['nome']} ${c['email']} ${c['telefone']} ${c['cpf']}'.toLowerCase().contains(termo)) c,
    ];
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
        children: [
          TextField(
            controller: _busca,
            decoration: InputDecoration(
              hintText: 'Buscar por nome, e-mail, telefone ou CPF',
              prefixIcon: const Icon(Icons.search, color: Cores.tinta),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          EstadoLista(carregando: _carregando, erro: _erro, vazia: !_carregando && lista.isEmpty, textoVazio: 'Nenhum cliente.'),
          for (final c in lista)
            CartaoGestao(
              titulo: texto(c['nome']).isEmpty ? 'Sem nome' : texto(c['nome']),
              detalhe: [texto(c['email']), texto(c['telefone'])].where((t) => t.isNotEmpty).join(' · '),
              valor: '${c['pontos'] ?? 0} pts',
              icone: Icons.person_outline,
              aoTocar: () => _detalhe(c),
            ),
        ],
      ),
    );
  }

  void _detalhe(Map<String, dynamic> c) {
    final endereco = [texto(c['logradouro']), texto(c['numeroEndereco']), texto(c['complemento']), texto(c['bairro']), texto(c['cep'])]
        .where((t) => t.isNotEmpty)
        .join(', ');
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(texto(c['nome']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final linha in [
              ('E-mail', texto(c['email'])),
              ('Telefone', texto(c['telefone'])),
              ('CPF', texto(c['cpf'])),
              ('Endereço', endereco),
              ('Pontos', '${c['pontos'] ?? 0}'),
              ('Recebe avisos', c['aceitaNotificacao'] == true ? 'Sim' : 'Não'),
            ])
              if (linha.$2.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '${linha.$1}: ', style: const TextStyle(color: Cores.tinta)),
                    TextSpan(text: linha.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ])),
                ),
          ],
        ),
      ),
    );
  }

  Widget _listaAvisos() {
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(gradient: Cores.gradienteMarinho, borderRadius: BorderRadius.circular(Cores.raio), boxShadow: Cores.sombra),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Aviso para todos', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  _ativos == null
                      ? 'Vai para os moradores e clientes com o app ativo.'
                      : 'Vai para $_ativos pessoa(s) com o app ativo neste contrato.',
                  style: const TextStyle(color: Color(0xFFCBD5E1)),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Cores.laranja),
                  onPressed: _novoAviso,
                  icon: const Icon(Icons.campaign_outlined),
                  label: const Text('Escrever aviso'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Enviados', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          EstadoLista(carregando: _carregando, vazia: !_carregando && _avisos.isEmpty, textoVazio: 'Nenhum aviso enviado ainda.'),
          for (final a in _avisos)
            CartaoGestao(
              titulo: texto(a['titulo']),
              detalhe: '${dataCurta(a['criadoEm'])} · ${texto(a['mensagem'])}',
              valor: '${a['entregues'] ?? 0}/${a['enviados'] ?? 0}',
              icone: Icons.campaign_outlined,
            ),
        ],
      ),
    );
  }

  Future<void> _novoAviso() async {
    final titulo = TextEditingController();
    final mensagem = TextEditingController();
    final enviar = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Novo aviso', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(controller: titulo, maxLength: 150, decoration: const InputDecoration(labelText: 'Título')),
            TextField(controller: mensagem, maxLength: 4000, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Mensagem')),
            const SizedBox(height: 8),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enviar para todos')),
          ],
        ),
      ),
    );
    if (enviar != true || !mounted) return;
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null) return;
    try {
      final r = await ref.read(apiProvider).gestaoEnviar(sessao, 'POST', '/api/app/avisos',
          corpo: {'titulo': titulo.text.trim(), 'mensagem': mensagem.text.trim()});
      if (mounted) avisar(context, 'Aviso enviado para ${r is Map ? r['enviados'] ?? 0 : 0} pessoa(s).');
      await _carregar();
    } catch (erro) {
      if (mounted) avisar(context, falhaDe(erro).mensagem, erro: true);
    }
  }
}
