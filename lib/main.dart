import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'controllers/auth_controller.dart';
import 'core/rede/api.dart';
import 'core/rede/falha_api.dart';
import 'core/sessao/acesso_lembrado.dart';
import 'core/util/link_entrada.dart';
import 'features/admin/painel_admin.dart';
import 'theme/app_theme.dart';
import 'theme/tema_loja.dart';
import 'views/auth/login_page.dart';
import 'views/geladeira/geladeira_page.dart';
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

  /// Administrador ou operador que tocou em "Usar como cliente" para comprar no app.
  bool _modoCliente = false;

  final _navegador = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _restaurarSessao();
    LinkEntrada.instancia.addListener(_abrirGeladeiraPendente);
    _authController.addListener(_abrirGeladeiraPendente);
    LinkEntrada.instancia.iniciar();
  }

  /// QR da geladeira lido pela câmera do celular: com a pessoa dentro, abre a compra dela.
  void _abrirGeladeiraPendente() {
    final sessao = _authController.sessaoAtual;
    if (!_authController.isAuthenticated || sessao == null || !sessao.cliente) return;
    final geladeira = LinkEntrada.instancia.consumir();
    if (geladeira == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navegador = _navegador.currentState;
      if (navegador == null) return;
      if (geladeira.contrato != null && geladeira.contrato != sessao.tenantId) {
        ScaffoldMessenger.maybeOf(navegador.context)?.showSnackBar(const SnackBar(
          content: Text('Esta geladeira é de outro condomínio. Entre com a conta de lá para comprar nela.'),
        ));
        return;
      }
      navegador.push(MaterialPageRoute<void>(builder: (_) => GeladeiraPage(sessao: sessao, geladeiraId: geladeira.id)));
    });
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

  void _sair() {
    _acesso.esquecerSessao();
    _modoCliente = false;
    _authController.logout();
  }

  @override
  void dispose() {
    LinkEntrada.instancia.removeListener(_abrirGeladeiraPendente);
    _authController.removeListener(_abrirGeladeiraPendente);
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
          navigatorKey: _navegador,
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
              : _authController.sessaoAtual?.operacao == true && !_modoCliente
              ? PainelAdmin(
                  sessao: _authController.sessaoAtual!,
                  aoUsarComoCliente: () => setState(() => _modoCliente = true),
                  aoSair: _sair,
                )
              : MainNavigationShell(
                  authController: _authController,
                  onLogout: _sair,
                ),
        );
      },
    );
  }
}

typedef PdvMarketApp = NextPdvApp;
typedef FastGoApp = NextPdvApp;
