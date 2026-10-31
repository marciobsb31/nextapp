import 'package:dio/dio.dart';

class FalhaApi implements Exception {
  const FalhaApi(this.mensagem, {this.codigo, this.status});

  final String mensagem;
  final String? codigo;
  final int? status;

  /// A chamada nem chegou à API (sem internet, servidor fora do ar ou tempo esgotado).
  bool get semConexao => codigo == 'SEM_CONEXAO';

  @override
  String toString() => mensagem;
}

FalhaApi falhaDe(Object erro) {
  if (erro is FalhaApi) return erro;
  if (erro is DioException) {
    final dados = erro.response?.data;
    if (dados is Map && dados['message'] is String) {
      return FalhaApi(
        dados['message'] as String,
        codigo: dados['codigo'] as String?,
        status: erro.response?.statusCode,
      );
    }
    if (erro.type == DioExceptionType.connectionError ||
        erro.type == DioExceptionType.connectionTimeout ||
        erro.type == DioExceptionType.sendTimeout ||
        erro.type == DioExceptionType.receiveTimeout ||
        (erro.type == DioExceptionType.unknown && erro.response == null)) {
      return const FalhaApi('Não consegui falar com a API. Confirme se o servidor está ligado.', codigo: 'SEM_CONEXAO');
    }
  }
  return const FalhaApi('Não foi possível concluir agora. Tente de novo.');
}
