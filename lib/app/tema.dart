import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tema_loja.dart';

/// Tokens das telas de gestão (lojista e administrador).
///
/// Vêm do design system do app (`AppColors` / `AppTheme`): a mesma fonte, os mesmos tons
/// de texto e superfície e a paleta que a loja escolhe no painel web. Trocar a paleta
/// no painel repinta a gestão junto com o app do cliente.
abstract final class Cores {
  static Color get laranja => AppColors.primaryOrange;
  static Color get laranjaEscuro => TemaLoja.instancia.paleta.primariaEscura;
  static Color get suave => TemaLoja.instancia.paleta.suave;
  static const marinho = AppColors.navyDark;
  static const tinta = AppColors.textSecondary;
  static Color get fundo => AppColors.backgroundLight;
  static const cartao = AppColors.cardSurface;
  static const linha = AppColors.accentBorder;
  static const sucesso = Color(0xFF059669);
  static const erro = Color(0xFFDC2626);
  static const alerta = Color(0xFFD97706);

  /// Cantos dos cartões do app.
  static const raio = 20.0;

  static List<BoxShadow> get sombra => AppColors.cardShadow;
  static LinearGradient get gradienteMarca => AppColors.orangeGradient;
  static List<BoxShadow> get brilhoMarca => AppColors.orangeGlowShadow;
  static const gradienteMarinho = AppColors.cardNavyGradient;
}

/// Cartão branco padrão do app: cantos de 20 e a sombra suave do design system.
BoxDecoration cartaoApp({Color? cor}) => BoxDecoration(
      color: cor ?? Cores.cartao,
      borderRadius: BorderRadius.circular(Cores.raio),
      boxShadow: Cores.sombra,
    );

ThemeData temaPdv() => AppTheme.lightTheme;
