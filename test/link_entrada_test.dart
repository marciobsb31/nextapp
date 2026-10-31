import 'package:flutter_test/flutter_test.dart';
import 'package:pdv_market/core/util/link_entrada.dart';

void main() {
  test('Link da geladeira fica pendente até ser usado, uma vez só', () {
    final links = LinkEntrada.instancia;
    links.receber('nextpdv://geladeira/tenant_1/7');
    expect(links.geladeira?.id, 7);
    expect(links.geladeira?.contrato, 'tenant_1');
    expect(links.consumir()?.id, 7);
    expect(links.consumir(), isNull);
  });

  test('Link de outra coisa não vira geladeira', () {
    final links = LinkEntrada.instancia;
    links.receber('pdvmarket:smart-access:tenant_1:4');
    links.receber('https://site.com/promo');
    expect(links.geladeira, isNull);
  });
}
