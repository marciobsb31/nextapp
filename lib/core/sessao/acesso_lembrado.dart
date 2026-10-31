import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'cofre_sessao.dart';
import 'sessao.dart';

/// "Lembrar de mim" e biometria.
///
/// Com "Lembrar de mim" marcado, a sessão emitida pela API fica no cofre do
/// aparelho. Na próxima abertura o app revalida o token na API antes de
/// entrar. A biometria só destrava uma sessão já lembrada; ela nunca cria
/// acesso sozinha.
///
/// Toda leitura e escrita tolera a falta do plugin (testes e navegadores
/// sem armazenamento), e nesse caso o app só não lembra.
class AcessoLembrado {
  AcessoLembrado({CofreSessao? cofre, FlutterSecureStorage? caixa, LocalAuthentication? digital})
      : _cofre = cofre ?? CofreSeguro(caixa),
        _caixa = caixa ?? const FlutterSecureStorage(),
        _digital = digital ?? LocalAuthentication();

  static const _chaveLembrar = 'pdv_market_lembrar';
  static const _chaveEmail = 'pdv_market_email_lembrado';
  static const _chaveBiometriaOferecida = 'pdv_market_biometria_oferecida';

  final CofreSessao _cofre;
  final FlutterSecureStorage _caixa;
  final LocalAuthentication _digital;

  /// No celular o padrão é lembrar; só fica desmarcado se a pessoa desmarcou da última vez.
  Future<bool> lembrarMarcado() async {
    try {
      return await _caixa.read(key: _chaveLembrar) != 'nao';
    } catch (_) {
      return false;
    }
  }

  /// A pergunta "usar a digital da próxima vez?" aparece uma vez por aparelho.
  Future<bool> biometriaJaOferecida() async {
    try {
      return await _caixa.read(key: _chaveBiometriaOferecida) == 'sim';
    } catch (_) {
      return true;
    }
  }

  Future<void> marcarBiometriaOferecida() async {
    try {
      await _caixa.write(key: _chaveBiometriaOferecida, value: 'sim');
    } catch (_) {}
  }

  Future<String> emailLembrado() async {
    try {
      return await _caixa.read(key: _chaveEmail) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> aposEntrar(Sessao sessao, {required bool lembrar}) async {
    try {
      if (lembrar) {
        await _cofre.guardar(sessao);
        await _caixa.write(key: _chaveLembrar, value: 'sim');
        await _caixa.write(key: _chaveEmail, value: sessao.email);
      } else {
        await _cofre.limpar();
        await _caixa.write(key: _chaveLembrar, value: 'nao');
        await _caixa.delete(key: _chaveEmail);
      }
    } catch (_) {}
  }

  Future<Sessao?> sessaoGuardada() async {
    try {
      if (await _caixa.read(key: _chaveLembrar) != 'sim') return null;
      final sessao = await _cofre.ler();
      return sessao != null && sessao.autenticada ? sessao : null;
    } catch (_) {
      return null;
    }
  }

  /// Sair apaga o token; o e-mail continua preenchido se "Lembrar de mim" estava marcado.
  Future<void> esquecerSessao() async {
    try {
      await _cofre.limpar();
    } catch (_) {}
  }

  Future<bool> biometriaDisponivel() async {
    if (kIsWeb) return false;
    try {
      return await _digital.isDeviceSupported() && await _digital.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> confirmarBiometria() async {
    try {
      return await _digital.authenticate(
        localizedReason: 'Confirme sua identidade para entrar no NextPDV',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
