/// Valor em reais no formato brasileiro: `R$ 1.234,56`.
String reaisBr(num? valor) {
  final centavos = ((valor ?? 0) * 100).round();
  final sinal = centavos < 0 ? '-' : '';
  final abs = centavos.abs();
  final inteiro = (abs ~/ 100).toString();
  final grupos = <String>[];
  for (var fim = inteiro.length; fim > 0; fim -= 3) {
    grupos.insert(0, inteiro.substring(fim - 3 < 0 ? 0 : fim - 3, fim));
  }
  return '${sinal}R\$ ${grupos.join('.')},${(abs % 100).toString().padLeft(2, '0')}';
}
