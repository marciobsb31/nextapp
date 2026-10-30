import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'sessao.dart';

abstract class CofreSessao {
  Future<Sessao?> ler();

  Future<void> guardar(Sessao sessao);

  Future<void> limpar();
}

class CofreSeguro implements CofreSessao {
  CofreSeguro([FlutterSecureStorage? caixa]) : _caixa = caixa ?? const FlutterSecureStorage();

  static const _chave = 'pdv_market_sessao';
  final FlutterSecureStorage _caixa;

  @override
  Future<Sessao?> ler() async {
    final valores = await _caixa.readAll();
    final token = valores['$_chave.token'] ?? '';
    if (token.isEmpty) return null;
    return Sessao.doCofre({
      'token': token,
      'tenantId': valores['$_chave.tenantId'] ?? '',
      'nome': valores['$_chave.nome'] ?? '',
      'email': valores['$_chave.email'] ?? '',
      'perfil': valores['$_chave.perfil'] ?? '',
      'fotoUrl': valores['$_chave.fotoUrl'] ?? '',
    });
  }

  @override
  Future<void> guardar(Sessao sessao) async {
    final valores = sessao.paraCofre();
    for (final item in valores.entries) {
      await _caixa.write(key: '$_chave.${item.key}', value: item.value);
    }
  }

  @override
  Future<void> limpar() async {
    for (final campo in const ['token', 'tenantId', 'nome', 'email', 'perfil', 'fotoUrl']) {
      await _caixa.delete(key: '$_chave.$campo');
    }
  }
}

class CofreMemoria implements CofreSessao {
  Sessao? atual;

  @override
  Future<void> guardar(Sessao sessao) async => atual = sessao;

  @override
  Future<void> limpar() async => atual = null;

  @override
  Future<Sessao?> ler() async => atual;
}

final cofreSessaoProvider = Provider<CofreSessao>((ref) => CofreSeguro());
