import 'package:flutter/foundation.dart';

/// Endereço da API do PDV Market.
///
/// Desenvolvimento (debug/profile): `http://localhost:9000`.
/// Release (todo APK gerado com `flutter build apk`): produção em
/// `http://143.95.211.23`, com produtos e isolamento do banco de produção.
/// Outro servidor entra na compilação com
/// `--dart-define=API_BASE_URL=https://...`.
/// O aplicativo não abre o PostgreSQL.
abstract final class Ambiente {
  static const producaoBaseUrl = 'http://143.95.211.23';
  static const desenvolvimentoBaseUrl = 'http://localhost:9000';

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kReleaseMode ? producaoBaseUrl : desenvolvimentoBaseUrl,
  );

  static bool get local => apiBaseUrl.contains('localhost');

  static String resolveBaseUrl() {
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        local) {
      return apiBaseUrl.replaceFirst('localhost', '10.0.2.2');
    }
    return apiBaseUrl;
  }
}
