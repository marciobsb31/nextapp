import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'qr_equipamento.dart';

/// Link que abriu o app (a página do QR da geladeira chama `nextpdv://geladeira/<contrato>/<id>`).
///
/// A geladeira fica pendente até a pessoa entrar ou criar a conta; depois do login o app
/// abre a compra dela direto. Sem o plugin (testes, web), simplesmente não há link.
class LinkEntrada extends ChangeNotifier {
  LinkEntrada._();

  static final instancia = LinkEntrada._();

  QrEquipamento? _geladeira;
  StreamSubscription<Uri>? _escuta;
  var _iniciado = false;

  /// Geladeira que a pessoa quer abrir, ainda não aberta.
  QrEquipamento? get geladeira => _geladeira;

  Future<void> iniciar() async {
    if (_iniciado || kIsWeb) return;
    _iniciado = true;
    try {
      final links = AppLinks();
      final inicial = await links.getInitialLink();
      if (inicial != null) receber(inicial.toString());
      _escuta = links.uriLinkStream.listen((uri) => receber(uri.toString()), onError: (_) {});
    } catch (_) {
      // Plugin indisponível: o app abre normalmente.
    }
  }

  /// Também usado nos testes e por quem já tem o texto do link em mãos.
  void receber(String link) {
    final lido = QrEquipamento.ler(link);
    if (lido == null || !lido.geladeira) return;
    _geladeira = lido;
    notifyListeners();
  }

  /// Entrega a geladeira pendente uma vez só.
  QrEquipamento? consumir() {
    final pendente = _geladeira;
    _geladeira = null;
    if (pendente != null) notifyListeners();
    return pendente;
  }

  @override
  void dispose() {
    _escuta?.cancel();
    super.dispose();
  }
}
