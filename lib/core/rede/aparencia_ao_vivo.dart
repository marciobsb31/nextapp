import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../theme/tema_loja.dart';
import '../sessao/sessao.dart';
import 'api.dart';

/// Mantém as cores do app iguais às do painel web.
///
/// Ao entrar, busca a unidade do morador (`/api/app/eu`) e a paleta dela.
/// No celular escuta o canal SSE do contrato e recarrega a paleta quando o
/// painel avisa `APARENCIA`. No navegador o Dio não entrega o SSE aos poucos,
/// então a paleta é conferida a cada 30 segundos.
class AparenciaAoVivo {
  AparenciaAoVivo(this._api, {TemaLoja? tema}) : _tema = tema ?? TemaLoja.instancia;

  final ApiPdv _api;
  final TemaLoja _tema;
  Sessao? _sessao;
  int? _lojaId;
  StreamSubscription<({String evento, String dados})>? _canal;
  Timer? _espera;
  int _tentativas = 0;

  Future<void> iniciar(Sessao sessao) async {
    parar();
    if (!TemaLoja.usarPaletaDaUnidade) {
      _tema.restaurarPadrao();
      return;
    }
    _sessao = sessao;
    try {
      final eu = await _api.eu(sessao);
      final loja = eu['lojaId'];
      _lojaId = loja is num ? loja.toInt() : int.tryParse('$loja');
    } catch (_) {
      _lojaId = null;
    }
    if (_lojaId == null || _sessao != sessao) return;
    await recarregar();
    if (_sessao != sessao) return;
    if (kIsWeb) {
      _espera = Timer.periodic(const Duration(seconds: 30), (_) => recarregar());
    } else {
      _ouvir();
    }
  }

  Future<void> recarregar() async {
    final sessao = _sessao;
    final lojaId = _lojaId;
    if (sessao == null || lojaId == null) return;
    try {
      _tema.aplicar(PaletaApp.daApi(await _api.aparencia(sessao, lojaId)));
    } catch (_) {
      // Sem resposta, o app segue com a paleta atual.
    }
  }

  void _ouvir() {
    final sessao = _sessao;
    if (sessao == null) return;
    _canal = _api.eventosTempoReal(sessao).listen(
      (mensagem) {
        _tentativas = 0;
        if (mensagem.evento != 'mudou') return;
        try {
          final dados = jsonDecode(mensagem.dados);
          if (dados is! Map || dados['tipo'] != 'APARENCIA') return;
          final loja = dados['lojaId'];
          if (loja == null || (loja is num && loja.toInt() == _lojaId)) recarregar();
        } catch (_) {}
      },
      onError: (_) => _reconectar(),
      onDone: _reconectar,
      cancelOnError: true,
    );
  }

  /// Reconecta com espera crescente (2 s, 4 s, ... até 60 s) e recarrega a
  /// paleta, para não perder uma troca feita enquanto estava desconectado.
  void _reconectar() {
    _canal = null;
    if (_sessao == null) return;
    _tentativas++;
    final segundos = (1 << _tentativas.clamp(1, 5)).clamp(2, 60);
    _espera?.cancel();
    _espera = Timer(Duration(seconds: segundos), () {
      if (_sessao == null) return;
      recarregar();
      _ouvir();
    });
  }

  void parar() {
    _sessao = null;
    _lojaId = null;
    _tentativas = 0;
    _canal?.cancel();
    _canal = null;
    _espera?.cancel();
    _espera = null;
  }
}
