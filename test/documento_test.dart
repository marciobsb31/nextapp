import 'package:flutter_test/flutter_test.dart';
import 'package:pdv_market/core/documento/documentos.dart';

void main() {
  test('o CPF válido passa e os dígitos repetidos não', () {
    expect(cpfValido('529.982.247-25'), isTrue);
    expect(cpfValido('111.111.111-11'), isFalse);
    expect(mensagemCpf('123'), 'O CPF tem 11 números.');
    expect(mensagemCpf('52998224725'), isNull);
  });

  test('o CNPJ válido passa e o CNPJ vazio pode ficar em branco', () {
    expect(cnpjValido('11.444.777/0001-61'), isTrue);
    expect(cnpjValido('11.111.111/1111-11'), isFalse);
    expect(mensagemCnpj(''), isNull);
    expect(mensagemCnpj('11444777000161'), isNull);
    expect(formatarCnpj('11444777000161'), '11.444.777/0001-61');
  });

  test('o endereço do ViaCEP entra nos campos do cadastro', () {
    final endereco = EnderecoViaCep.deJson({
      'cep': '01310-100',
      'logradouro': 'Avenida Paulista',
      'complemento': 'de 612 a 1510 - lado par',
      'bairro': 'Bela Vista',
      'cidade': 'São Paulo',
      'uf': 'sp',
    });
    expect(endereco.completo, isTrue);
    expect(endereco.uf, 'SP');
    expect(endereco.resumo, 'Avenida Paulista, Bela Vista, São Paulo-SP');
    expect(formatarCep('01310100'), '01310-100');
  });
}
