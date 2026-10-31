import 'package:flutter_test/flutter_test.dart';
import 'package:pdv_market/core/util/qr_equipamento.dart';

void main() {
  test('QR colado na geladeira (URL) abre a compra', () {
    final qr = QrEquipamento.ler('http://143.95.211.23/geladeira/tenant_1/7');
    expect(qr, isNotNull);
    expect(qr!.geladeira, isTrue);
    expect(qr.contrato, 'tenant_1');
    expect(qr.id, 7);
    expect(QrEquipamento.ler('https://pdv.exemplo.com.br/geladeira/tenant_x/12/')!.id, 12);
  });

  test('QR do painel e formatos antigos são aparelhos do Smart Access', () {
    final painel = QrEquipamento.ler('pdvmarket:smart-access:tenant_1:4')!;
    expect(painel.geladeira, isFalse);
    expect(painel.contrato, 'tenant_1');
    expect(painel.id, 4);
    expect(QrEquipamento.ler('QR-9')!.id, 9);
    expect(QrEquipamento.ler('15')!.contrato, isNull);
  });

  test('Texto qualquer não vira equipamento', () {
    expect(QrEquipamento.ler('https://site.com/promo'), isNull);
    expect(QrEquipamento.ler('http://143.95.211.23/geladeira/TENANT/7'), isNull);
    expect(QrEquipamento.ler('pdvmarket:geladeira:tenant_1:codigo-de-abertura-xyz'), isNull);
  });
}
