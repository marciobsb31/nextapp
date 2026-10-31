import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'controllers/auth_controller.dart';
import 'core/rede/api.dart';
import 'core/rede/falha_api.dart';
import 'core/sessao/acesso_lembrado.dart';
import 'theme/app_theme.dart';
import 'theme/tema_loja.dart';
import 'views/auth/login_page.dart';
import 'views/main_navigation_shell.dart';
import 'widgets/logo_animada.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;
  runApp(const ProviderScope(child: NextPdvApp()));
}

class NextPdvApp extends StatefulWidget {
  const NextPdvApp({super.key});

  @override
  State<NextPdvApp> createState() => _NextPdvAppState();
}

class _NextPdvAppState extends State<NextPdvApp> {
  final AuthController _authController = AuthController();
  final AcessoLembrado _acesso = AcessoLembrado();
  bool _restaurando = true;

  @override
  void initState() {
    super.initState();
    _restaurarSessao();
  }

  /// "Lembrar de mim": entra direto com a sessão guardada, depois de a API
  /// confirmar o token. Com biometria no aparelho, quem destrava é a tela de login.
  Future<void> _restaurarSessao() async {
    try {
      final sessao = await _acesso.sessaoGuardada();
      if (sessao == null || await _acesso.biometriaDisponivel()) return;
      await ApiPdv.padrao().eu(sessao);
      _authController.entrarComSessao(sessao);
    } catch (erro) {
      final falha = falhaDe(erro);
      if (falha.status == 401 || falha.status == 403) await _acesso.esquecerSessao();
    } finally {
      if (mounted) setState(() => _restaurando = false);
    }
  }

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      // Repinta o app quando a sessão muda ou quando a loja troca as cores no painel.
      animation: Listenable.merge([_authController, TemaLoja.instancia]),
      builder: (context, _) {
        return MaterialApp(
          title: 'Next PDV - Mercado Autônomo & Smart Access',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _authController.themeMode,
          builder: (context, child) {
            if (!kIsWeb || child == null) return child ?? const SizedBox.shrink();
            final largura = MediaQuery.sizeOf(context).width;
            if (largura <= 520) return child;
            final altura = MediaQuery.sizeOf(context).height;
            return ColoredBox(
              color: const Color(0xFF0F172A),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: SizedBox(
                    width: 420,
                    height: altura > 920 ? 880 : altura - 32,
                    child: child,
                  ),
                ),
              ),
            );
          },
          home: _restaurando
              ? const Scaffold(
                  backgroundColor: Color(0xFF0C233F),
                  body: Center(child: LogoAnimada(largura: 200)),
                )
              : !_authController.isAuthenticated
              ? LoginPage(
                  authController: _authController,
                  acesso: _acesso,
                  onLoginSuccess: () => setState(() {}),
                )
              : MainNavigationShell(
                  authController: _authController,
                  onLogout: () {
                    _acesso.esquecerSessao();
                    _authController.logout();
                  },
                ),
        );
      },
    );
  }
}

typedef PdvMarketApp = NextPdvApp;
typedef FastGoApp = NextPdvApp;
