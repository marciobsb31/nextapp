import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdv_market/views/scanner/smart_access_modal.dart';

void main() {
  // Mesmo padrão que a API exige em chaveIdempotencia (UUID v1–v8, variante RFC 4122).
  final formatoDaApi = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  test('Chave de leitura sai no formato que a API aceita', () {
    for (var i = 0; i < 200; i++) {
      expect(formatoDaApi.hasMatch(novaChaveLeitura()), isTrue);
    }
  });

  test('Cada leitura tem chave própria', () {
    final chaves = {for (var i = 0; i < 500; i++) novaChaveLeitura(Random(i))};
    expect(chaves.length, 500);
  });
}
