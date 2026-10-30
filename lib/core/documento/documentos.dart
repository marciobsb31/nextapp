String somenteDigitos(String valor) => valor.replaceAll(RegExp(r'\D'), '');

String formatarCep(String valor) {
  final digitos = somenteDigitos(valor);
  final limite = digitos.length > 8 ? 8 : digitos.length;
  final corte = digitos.substring(0, limite);
  if (corte.length <= 5) return corte;
  return '${corte.substring(0, 5)}-${corte.substring(5)}';
}

String formatarCpf(String valor) {
  final digitos = somenteDigitos(valor);
  final limite = digitos.length > 11 ? 11 : digitos.length;
  final corte = digitos.substring(0, limite);
  final buffer = StringBuffer();
  for (var i = 0; i < corte.length; i++) {
    if (i == 3 || i == 6) buffer.write('.');
    if (i == 9) buffer.write('-');
    buffer.write(corte[i]);
  }
  return buffer.toString();
}

String formatarTelefone(String valor) {
  final digitos = somenteDigitos(valor);
  final limite = digitos.length > 11 ? 11 : digitos.length;
  final corte = digitos.substring(0, limite);
  if (corte.length <= 2) return corte;
  if (corte.length <= 6) return '(${corte.substring(0, 2)}) ${corte.substring(2)}';
  if (corte.length <= 10) {
    return '(${corte.substring(0, 2)}) ${corte.substring(2, 6)}-${corte.substring(6)}';
  }
  return '(${corte.substring(0, 2)}) ${corte.substring(2, 7)}-${corte.substring(7)}';
}

String? mensagemCep(String valor) {
  final digitos = somenteDigitos(valor);
  if (digitos.isEmpty) return 'Digite o CEP com 8 números.';
  if (digitos.length < 8) return 'Faltam ${8 - digitos.length} números. O CEP tem 8.';
  return null;
}

bool cpfValido(String valor) {
  final cpf = somenteDigitos(valor);
  if (cpf.length != 11) return false;
  if (cpf.split('').toSet().length == 1) return false;
  var soma = 0;
  for (var i = 0; i < 9; i++) {
    soma += int.parse(cpf[i]) * (10 - i);
  }
  var digito = 11 - (soma % 11);
  if (digito > 9) digito = 0;
  if (digito != int.parse(cpf[9])) return false;
  soma = 0;
  for (var i = 0; i < 10; i++) {
    soma += int.parse(cpf[i]) * (11 - i);
  }
  digito = 11 - (soma % 11);
  if (digito > 9) digito = 0;
  return digito == int.parse(cpf[10]);
}

String formatarCnpj(String valor) {
  final digitos = somenteDigitos(valor);
  final limite = digitos.length > 14 ? 14 : digitos.length;
  final corte = digitos.substring(0, limite);
  final buffer = StringBuffer();
  for (var i = 0; i < corte.length; i++) {
    if (i == 2 || i == 5) buffer.write('.');
    if (i == 8) buffer.write('/');
    if (i == 12) buffer.write('-');
    buffer.write(corte[i]);
  }
  return buffer.toString();
}

bool cnpjValido(String valor) {
  final cnpj = somenteDigitos(valor);
  if (cnpj.length != 14) return false;
  if (cnpj.split('').toSet().length == 1) return false;
  return _digitoCnpj(cnpj, 12) == int.parse(cnpj[12]) && _digitoCnpj(cnpj, 13) == int.parse(cnpj[13]);
}

int _digitoCnpj(String cnpj, int tamanho) {
  var peso = tamanho - 7;
  var soma = 0;
  for (var i = 0; i < tamanho; i++) {
    soma += int.parse(cnpj[i]) * peso;
    peso = peso == 2 ? 9 : peso - 1;
  }
  final resto = soma % 11;
  return resto < 2 ? 0 : 11 - resto;
}

String? mensagemCnpj(String valor) {
  final digitos = somenteDigitos(valor);
  if (digitos.isEmpty) return null;
  if (digitos.length < 14) return 'O CNPJ tem 14 números.';
  if (!cnpjValido(valor)) return 'Esse CNPJ não confere. Confira os dígitos.';
  return null;
}

String? mensagemCpf(String valor) {
  final digitos = somenteDigitos(valor);
  if (digitos.isEmpty) return 'Informe o CPF.';
  if (digitos.length < 11) return 'O CPF tem 11 números.';
  if (!cpfValido(valor)) return 'Esse CPF não confere. Confira os dígitos.';
  return null;
}

String? mensagemTelefone(String valor) {
  final digitos = somenteDigitos(valor);
  if (digitos.isEmpty) return 'Informe o DDD e o telefone.';
  if (digitos.length < 10 || digitos.length > 11) {
    return 'O telefone precisa do DDD e de 10 ou 11 números.';
  }
  return null;
}

String? mensagemEmail(String valor) {
  final email = valor.trim().toLowerCase();
  if (email.isEmpty) return 'Informe o e-mail.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Esse e-mail não está completo.';
  }
  return null;
}

class EnderecoViaCep {
  const EnderecoViaCep({
    required this.cep,
    required this.logradouro,
    required this.complemento,
    required this.bairro,
    required this.cidade,
    required this.uf,
  });

  final String cep;
  final String logradouro;
  final String complemento;
  final String bairro;
  final String cidade;
  final String uf;

  bool get temRua => logradouro.trim().isNotEmpty;

  bool get completo =>
      temRua && bairro.trim().isNotEmpty && cidade.trim().isNotEmpty && uf.trim().length == 2;

  String get resumo {
    final partes = [
      if (logradouro.isNotEmpty) logradouro,
      if (bairro.isNotEmpty) bairro,
      if (cidade.isNotEmpty && uf.isNotEmpty) '$cidade-$uf' else cidade,
    ];
    return partes.join(', ');
  }

  factory EnderecoViaCep.deJson(Map<String, dynamic> json) {
    String campo(String chave) => json[chave] == null ? '' : json[chave].toString().trim();
    return EnderecoViaCep(
      cep: campo('cep'),
      logradouro: campo('logradouro'),
      complemento: campo('complemento'),
      bairro: campo('bairro'),
      cidade: campo('cidade'),
      uf: campo('uf').toUpperCase(),
    );
  }
}
