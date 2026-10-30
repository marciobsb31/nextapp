import 'package:flutter_test/flutter_test.dart';
import 'package:pdv_market/features/lojista/pedidos_loja.dart';

void main() {
  test('a fila segue a etapa que a API aceita', () {
    expect(proximaSituacao('RECEBIDO', pagarNaLoja: false), 'EM_SEPARACAO');
    expect(proximaSituacao('EM_SEPARACAO', pagarNaLoja: true), 'PRONTO');
    expect(proximaSituacao('PRONTO', pagarNaLoja: true), isNull);
    expect(proximaSituacao('PRONTO', pagarNaLoja: false), 'RETIRADO');
    expect(rotuloAcao('EM_SEPARACAO'), 'Separar');
    expect(podeCancelar('RECEBIDO', 'PENDENTE'), isTrue);
    expect(podeCancelar('RECEBIDO', 'PAGO'), isFalse);
    expect(podeCancelar('RETIRADO', 'PENDENTE'), isFalse);
  });
}
