import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

/// Cartão digitado no app, só em memória e só até virar o `encrypted` do PagBank.
///
/// O número e o CVV nunca vão para a API do PDV nem ficam salvos no aparelho:
/// seguem criptografados com a chave pública da conta PagBank da loja, no
/// mesmo formato do SDK oficial (`numero;cvv;mes;ano;titular;timestamp`,
/// RSA PKCS#1 v1.5, Base64).
class CartaoDigitado {
  CartaoDigitado({
    required String numero,
    required this.titular,
    required String validade,
    required this.cvv,
  })  : numero = numero.replaceAll(RegExp(r'\D'), ''),
        validade = validade.trim();

  final String numero;
  final String titular;
  final String validade; // MM/AA
  final String cvv;

  String get finalCartao => numero.length >= 4 ? numero.substring(numero.length - 4) : '';

  /// Bandeiras que a API aceita: VISA, MASTERCARD, ELO, AMEX, HIPERCARD.
  String get bandeira => bandeiraDe(numero);

  /// Primeiro problema encontrado, ou `null` quando o cartão está completo.
  String? problema() {
    if (numero.length < 13 || numero.length > 19 || !luhn(numero)) return 'Confira o número do cartão.';
    if (bandeira.isEmpty) return 'Esta bandeira não é aceita nesta unidade.';
    if (titular.trim().length < 3) return 'Informe o nome impresso no cartão.';
    final mesAno = _mesAno();
    if (mesAno == null) return 'Informe a validade no formato MM/AA.';
    final agora = DateTime.now();
    final vence = DateTime(mesAno.$2, mesAno.$1 + 1);
    if (!vence.isAfter(DateTime(agora.year, agora.month))) return 'Este cartão está vencido.';
    final digitos = bandeira == 'AMEX' ? 4 : 3;
    if (!RegExp('^\\d{$digitos}\$').hasMatch(cvv)) return 'Confira o código de segurança.';
    return null;
  }

  (int, int)? _mesAno() {
    final m = RegExp(r'^(\d{2})\s*/\s*(\d{2}|\d{4})$').firstMatch(validade);
    if (m == null) return null;
    final mes = int.parse(m.group(1)!);
    var ano = int.parse(m.group(2)!);
    if (ano < 100) ano += 2000;
    if (mes < 1 || mes > 12) return null;
    return (mes, ano);
  }

  /// Texto criptografado que o PagBank aceita em `card.encrypted`.
  String criptografar(String chavePublicaBase64, {DateTime? agora, SecureRandom? sorte}) {
    final mesAno = _mesAno();
    if (mesAno == null) throw const FormatException('Validade inválida.');
    final quando = (agora ?? DateTime.now()).millisecondsSinceEpoch;
    final texto = '$numero;$cvv;${mesAno.$1.toString().padLeft(2, '0')};${mesAno.$2};${titular.trim()};$quando';
    final motor = PKCS1Encoding(RSAEngine())
      ..init(true, ParametersWithRandom(PublicKeyParameter<RSAPublicKey>(chavePublica(chavePublicaBase64)), sorte ?? _sorte()));
    return base64Encode(motor.process(Uint8List.fromList(utf8.encode(texto))));
  }
}

String bandeiraDe(String numero) {
  final n = numero.replaceAll(RegExp(r'\D'), '');
  if (n.isEmpty) return '';
  if (RegExp(r'^(4011(78|79)|43(1274|8935)|45(1416|7393|763(1|2))|50(4175|6699|67[0-7][0-9]|9000)|627780|63(6297|6368)|650(03([^4])|04([0-9])|05(0|1)|4(0[5-9]|3[0-9]|8[5-9]|9[0-9])|5([0-2][0-9]|3[0-8])|9([2-6][0-9]|7[0-8])|541|700|720|901)|651652|655000|655021)').hasMatch(n)) {
    return 'ELO';
  }
  if (RegExp(r'^(606282|3841)').hasMatch(n)) return 'HIPERCARD';
  if (RegExp(r'^3[47]').hasMatch(n)) return 'AMEX';
  if (RegExp(r'^4').hasMatch(n)) return 'VISA';
  if (RegExp(r'^(5[1-5]|2(2[2-9]|[3-6]\d|7[01]|720))').hasMatch(n)) return 'MASTERCARD';
  return '';
}

bool luhn(String numero) {
  var soma = 0;
  var dobrar = false;
  for (var i = numero.length - 1; i >= 0; i--) {
    var d = numero.codeUnitAt(i) - 48;
    if (d < 0 || d > 9) return false;
    if (dobrar) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    soma += d;
    dobrar = !dobrar;
  }
  return soma % 10 == 0;
}

/// Lê a chave pública do PagBank (SubjectPublicKeyInfo em Base64, com ou sem cabeçalho PEM).
RSAPublicKey chavePublica(String base64OuPem) {
  final limpo = base64OuPem
      .replaceAll(RegExp(r'-----(BEGIN|END) PUBLIC KEY-----'), '')
      .replaceAll(RegExp(r'\s'), '');
  final der = base64Decode(limpo);
  final raiz = ASN1Parser(der).nextObject() as ASN1Sequence;
  final bits = raiz.elements![1] as ASN1BitString;
  final rsa = ASN1Parser(Uint8List.fromList(bits.stringValues!)).nextObject() as ASN1Sequence;
  final modulo = (rsa.elements![0] as ASN1Integer).integer!;
  final expoente = (rsa.elements![1] as ASN1Integer).integer!;
  return RSAPublicKey(modulo, expoente);
}

SecureRandom _sorte() {
  final semente = Random.secure();
  return FortunaRandom()..seed(KeyParameter(Uint8List.fromList(List.generate(32, (_) => semente.nextInt(256)))));
}
