import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/provedores.dart';
import '../../app/tema.dart';
import '../../core/sessao/sessao.dart';
import '../lojista/lojista_page.dart';

/// Entrada do administrador e do operador no app: a gestão da loja, com a sessão do login.
///
/// As telas de gestão leem a sessão pelo `sessaoProvider`. Aqui ele é a sessão de quem entrou,
/// e "Sair" volta para o login do app. A navegação própria mantém as telas abertas a partir
/// do painel dentro deste escopo (a navegação do app fica fora dele e não teria a sessão).
class PainelAdmin extends StatefulWidget {
  const PainelAdmin({super.key, required this.sessao, required this.aoSair, required this.aoUsarComoCliente});

  final Sessao sessao;
  final VoidCallback aoSair;
  final VoidCallback aoUsarComoCliente;

  @override
  State<PainelAdmin> createState() => _PainelAdminState();
}

class _PainelAdminState extends State<PainelAdmin> {
  final _navegacao = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [sessaoProvider.overrideWith(() => _SessaoDoLogin(widget.sessao, widget.aoSair))],
      child: Theme(
        data: temaGestao(Theme.of(context)),
        child: NavigatorPopHandler(
        onPopWithResult: (_) => _navegacao.currentState?.maybePop(),
        child: Navigator(
          key: _navegacao,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => LojistaPage(aoUsarComoCliente: widget.aoUsarComoCliente),
          ),
        ),
        ),
      ),
    );
  }
}

class _SessaoDoLogin extends SessaoController {
  _SessaoDoLogin(this._sessao, this._aoSair);

  final Sessao _sessao;
  final VoidCallback _aoSair;

  @override
  Future<Sessao?> build() async => _sessao;

  @override
  Future<void> sair() async {
    try {
      await ref.read(apiProvider).sair(_sessao);
    } catch (_) {
      // Sai do aparelho mesmo se o servidor não responder.
    }
    _aoSair();
  }
}

/// Design system do app aplicado aos componentes Material da gestão.
ThemeData temaGestao(ThemeData base) {
  final raio = BorderRadius.circular(Cores.raio);
  return base.copyWith(
    scaffoldBackgroundColor: Cores.fundo,
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Cores.cartao,
      selectedColor: Cores.laranja,
      checkmarkColor: Colors.white,
      side: const BorderSide(color: Cores.linha),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(color: Cores.marinho, fontWeight: FontWeight.w600, fontSize: 13),
      secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: Cores.laranja,
      unselectedLabelColor: Cores.tinta,
      indicatorColor: Cores.laranja,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Cores.linha,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Cores.laranja,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Cores.marinho,
        minimumSize: const Size(0, 52),
        side: const BorderSide(color: Cores.linha),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Cores.laranja)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Cores.laranja,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Cores.laranja : null),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.transparent : null),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Cores.laranja : null),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: Cores.laranja, linearTrackColor: Cores.suave),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Cores.cartao,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Cores.cartao,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: raio),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    listTileTheme: const ListTileThemeData(iconColor: Cores.tinta),
  );
}
