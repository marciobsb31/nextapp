import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdv_market/theme/app_theme.dart';
import 'package:pdv_market/theme/tema_loja.dart';

void main() {
  tearDown(() => TemaLoja.instancia.restaurarPadrao());

  test('Lê a paleta como a API devolve', () {
    final paleta = PaletaApp.daApi({
      'lojaId': 1,
      'paleta': 'verde',
      'cores': {'primaria': '#1F9A45', 'primariaEscura': '#127A34', 'suave': '#E5F6EB', 'destaque': '#F5B942', 'fundo': '#F4FBF6'},
    });
    expect(paleta.id, 'verde');
    expect(paleta.primaria, const Color(0xFF1F9A45));
    expect(paleta.fundo, const Color(0xFFF4FBF6));
  });

  test('Cor inválida da API cai no padrão', () {
    final paleta = PaletaApp.daApi({'paleta': 'x', 'cores': {'primaria': 'vermelho', 'fundo': '#12'}});
    expect(paleta.primaria, PaletaApp.padrao.primaria);
    expect(paleta.fundo, PaletaApp.padrao.fundo);
  });

  test('Trocar a paleta avisa o app e muda as cores de marca', () {
    var avisos = 0;
    void ouvir() => avisos++;
    TemaLoja.instancia.addListener(ouvir);
    TemaLoja.instancia.aplicar(PaletaApp.daApi({'paleta': 'verde', 'cores': {'primaria': '#1F9A45'}}));
    expect(avisos, 1);
    expect(AppColors.primaryOrange, const Color(0xFF1F9A45));

    // A mesma paleta de novo não repinta à toa.
    TemaLoja.instancia.aplicar(PaletaApp.daApi({'paleta': 'verde', 'cores': {'primaria': '#1F9A45'}}));
    expect(avisos, 1);
    TemaLoja.instancia.removeListener(ouvir);
  });

  test('Sair volta ao laranja da casa', () {
    TemaLoja.instancia.aplicar(PaletaApp.daApi({'paleta': 'verde', 'cores': {'primaria': '#1F9A45'}}));
    TemaLoja.instancia.restaurarPadrao();
    expect(AppColors.primaryOrange, const Color(0xFFFF6B00));
  });
}
