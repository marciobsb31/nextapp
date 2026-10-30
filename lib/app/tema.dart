import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class Cores {
  static const laranja = Color(0xFFFF6A00);
  static const laranjaEscuro = Color(0xFFE25300);
  static const marinho = Color(0xFF14233A);
  static const tinta = Color(0xFF5C6570);
  static const fundo = Color(0xFFFFF6F1);
  static const cartao = Color(0xFFFFFFFF);
  static const linha = Color(0xFFE7E4E1);
}

ThemeData temaPdv() {
  final texto = GoogleFonts.poppinsTextTheme();
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Cores.fundo,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Cores.laranja,
      primary: Cores.laranja,
      surface: Cores.cartao,
    ),
    textTheme: texto.apply(bodyColor: Cores.marinho, displayColor: Cores.marinho),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Cores.laranja,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        textStyle: texto.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        shape: const ContinuousRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Cores.linha),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Cores.linha),
      ),
    ),
  );
}
