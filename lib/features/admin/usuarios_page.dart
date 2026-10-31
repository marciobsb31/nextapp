import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/provedores.dart';
import '../../app/tema.dart';
import '../../core/rede/falha_api.dart';
import '../../core/sessao/sessao.dart';
import 'gestao_comum.dart';

String rotuloPerfil(String perfil) => switch (perfil) {
      'TENANT_ADMIN' => 'Administrador',
      'OPERADOR' => 'Operador',
      'CLIENTE' => 'Cliente do app',
      'SUPER_ADMIN' => 'Super Admin',
      _ => perfil,
    };

/// Equipe da loja: administradores e operadores. O administrador cria operadores, ativa e
/// desativa o acesso. Clientes do app aparecem só para consulta.
class UsuariosPage extends ConsumerStatefulWidget {
  const UsuariosPage({super.key});

  @override
  ConsumerState<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends ConsumerState<UsuariosPage> {
  var _verClientes = false;
  var _carregando = true;
  String? _erro;
  List<Map<String, dynamic>> _usuarios = const [];

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
      final lista = mapas(await ref.read(apiProvider).gestao(sessao, '/api/usuarios'));
      lista.sort((a, b) => texto(a['nome']).toLowerCase().compareTo(texto(b['nome']).toLowerCase()));
      if (mounted) setState(() => _usuarios = lista);
    } catch (erro) {
      if (mounted) setState(() => _erro = falhaDe(erro).mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final equipe = _usuarios.where((u) => u['perfil'] != 'CLIENTE').toList();
    final clientes = _usuarios.where((u) => u['perfil'] == 'CLIENTE').toList();
    final lista = _verClientes ? clientes : equipe;
    return TelaGestao(
      titulo: 'Usuários',
      acoes: [IconButton(onPressed: _carregar, icon: const Icon(Icons.refresh))],
      botao: FloatingActionButton.extended(
        backgroundColor: Cores.laranja,
        foregroundColor: Colors.white,
        onPressed: () => _editar(null),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Novo operador'),
      ),
      corpo: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            Wrap(spacing: 8, children: [
              ChoiceChip(label: Text('Equipe (${equipe.length})'), selected: !_verClientes, onSelected: (_) => setState(() => _verClientes = false)),
              ChoiceChip(label: Text('Clientes (${clientes.length})'), selected: _verClientes, onSelected: (_) => setState(() => _verClientes = true)),
            ]),
            const SizedBox(height: 8),
            const Text('Operador vê vendas, pedidos e estoque. Administrador também mexe em financeiro, usuários e Smart Access.',
                style: TextStyle(color: Cores.tinta, fontSize: 12)),
            const SizedBox(height: 12),
            EstadoLista(carregando: _carregando, erro: _erro, vazia: !_carregando && lista.isEmpty, textoVazio: 'Ninguém aqui ainda.'),
            for (final u in lista)
              CartaoGestao(
                titulo: texto(u['nome']),
                detalhe: '${texto(u['email'])} · ${rotuloPerfil(texto(u['perfil']))}${u['emailConfirmado'] == true ? '' : ' · e-mail não confirmado'}',
                icone: u['perfil'] == 'TENANT_ADMIN' ? Icons.admin_panel_settings_outlined : Icons.person_outline,
                corIcone: u['ativo'] == true ? Cores.laranja : Cores.tinta,
                fim: u['perfil'] == 'OPERADOR'
                    ? Switch(value: u['ativo'] == true, activeThumbColor: Cores.laranja, onChanged: (v) => _salvar(u, {'ativo': v}))
                    : Text(u['ativo'] == true ? 'Ativo' : 'Inativo', style: const TextStyle(color: Cores.tinta)),
                aoTocar: u['perfil'] == 'OPERADOR' ? () => _editar(u) : null,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _salvar(Map<String, dynamic> usuario, Map<String, Object?> mudanca) async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null) return;
    try {
      await ref.read(apiProvider).gestaoEnviar(sessao, 'PUT', '/api/usuarios/${usuario['id']}', corpo: {
        'nome': usuario['nome'],
        'email': usuario['email'],
        'ativo': usuario['ativo'],
        ...mudanca,
      });
      await _carregar();
    } catch (erro) {
      if (mounted) avisar(context, falhaDe(erro).mensagem, erro: true);
    }
  }

  Future<void> _editar(Map<String, dynamic>? usuario) async {
    final nome = TextEditingController(text: texto(usuario?['nome']));
    final email = TextEditingController(text: texto(usuario?['email']));
    final senha = TextEditingController();
    final salvar = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(usuario == null ? 'Novo operador' : 'Editar operador', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            TextField(controller: nome, decoration: const InputDecoration(labelText: 'Nome')),
            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail')),
            TextField(
              controller: senha,
              obscureText: true,
              decoration: InputDecoration(labelText: usuario == null ? 'Senha inicial (8 ou mais)' : 'Nova senha (deixe vazio para manter)'),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
          ],
        ),
      ),
    );
    if (salvar != true || !mounted) return;
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null) return;
    try {
      final api = ref.read(apiProvider);
      if (usuario == null) {
        final r = await api.gestaoEnviar(sessao, 'POST', '/api/usuarios', corpo: {
          'nome': nome.text.trim(),
          'email': email.text.trim(),
          'senha': senha.text,
          'perfil': 'OPERADOR',
          'ativo': 'true',
        });
        if (mounted) avisar(context, r is Map && r['message'] != null ? texto(r['message']) : 'Operador criado.');
      } else {
        await api.gestaoEnviar(sessao, 'PUT', '/api/usuarios/${usuario['id']}', corpo: {
          'nome': nome.text.trim(),
          'email': email.text.trim(),
          'ativo': usuario['ativo'],
          if (senha.text.isNotEmpty) 'senha': senha.text,
        });
      }
      await _carregar();
    } catch (erro) {
      if (mounted) avisar(context, falhaDe(erro).mensagem, erro: true);
    }
  }
}
