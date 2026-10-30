import 'package:dio/dio.dart';

class FalhaApi implements Exception {
  const FalhaApi(this.mensagem, {this.codigo, this.status});

  final String mensagem;
  final String? codigo;
  final int? status;

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
        erro.type == DioExceptionType.receiveTimeout) {
      return const FalhaApi('Não consegui falar com a API. Confirme se o servidor está ligado.');
    }
  }
  return const FalhaApi('Não foi possível concluir agora. Tente de novo.');
}
