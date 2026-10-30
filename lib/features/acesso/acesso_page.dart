import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/provedores.dart';
import '../../core/rede/falha_api.dart';
import '../descoberta/descoberta_page.dart';
import '../inicio/inicio_page.dart';
import '../lojista/lojista_page.dart';

class AcessoPage extends ConsumerStatefulWidget {
  const AcessoPage({super.key});

  @override
  ConsumerState<AcessoPage> createState() => _AcessoPageState();
}

class _AcessoPageState extends ConsumerState<AcessoPage> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  var _ocupado = false;
  String? _aviso;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    await HapticFeedback.lightImpact();
    setState(() {
      _ocupado = true;
      _aviso = null;
    });
    final aviso = await ref.read(sessaoProvider.notifier).entrar(_email.text, _senha.text);
    if (!mounted) return;
    setState(() {
      _ocupado = false;
      _aviso = aviso;
    });
  }

  Future<void> _esqueci() async {
    await HapticFeedback.selectionClick();
    setState(() => _ocupado = true);
    try {
      final mensagem = await ref.read(apiProvider).esqueci(_email.text);
      if (!mounted) return;
      setState(() => _aviso = mensagem);
    } catch (erro) {
      if (!mounted) return;
      setState(() => _aviso = falhaDe(erro).mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Text('PDV Market', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Boas-vinda', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Entre com a conta da unidade. A proximidade não abre a porta nem mistura a compra de outra loja.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF5C6570)),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'E-mail'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _senha,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Senha'),
              onSubmitted: (_) => _ocupado ? null : _entrar(),
            ),
            if (_aviso != null) ...[
              const SizedBox(height: 16),
              Text(_aviso!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _ocupado ? null : _entrar,
              child: Text(_ocupado ? 'Entrando...' : 'Entrar'),
            ),
            TextButton(onPressed: _ocupado ? null : _esqueci, child: const Text('Esqueci a senha')),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _ocupado
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DescobertaPage()));
                    },
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              child: const Text('Criar conta em uma unidade'),
            ),
          ],
        ),
      ),
    );
  }
}

class PortaApp extends ConsumerWidget {
  const PortaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessaoProvider);
    return sessao.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (erro, _) => Scaffold(body: Center(child: Text(falhaDe(erro).mensagem))),
      data: (valor) {
        if (valor == null || !valor.autenticada) return const AcessoPage();
        if (valor.cliente) return const InicioPage();
        if (valor.operacao) return const LojistaPage();
        return const Scaffold(body: Center(child: Text('Este perfil não abre o aplicativo.')));
      },
    );
  }
}
