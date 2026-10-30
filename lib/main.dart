import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'controllers/auth_controller.dart';
import 'theme/app_theme.dart';
import 'views/auth/login_page.dart';
import 'views/main_navigation_shell.dart';

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

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _authController,
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
          home: !_authController.isAuthenticated
              ? LoginPage(
                  authController: _authController,
                  onLoginSuccess: () => setState(() {}),
                )
              : MainNavigationShell(
                  authController: _authController,
                  onLogout: () {
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
