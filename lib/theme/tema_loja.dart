import 'package:flutter/material.dart';

/// Paleta que a loja escolhe no painel web (Aplicativo > Cores).
///
/// Os campos seguem `GET /api/app/aparencia`. Sem paleta carregada o app usa
/// o laranja da casa, que é o visual de sempre.
class PaletaApp {
  const PaletaApp({
    required this.id,
    required this.primaria,
    required this.primariaEscura,
    required this.suave,
    required this.destaque,
    required this.fundo,
  });

  final String id;
  final Color primaria;
  final Color primariaEscura;
  final Color suave;
  final Color destaque;
  final Color fundo;

  static const padrao = PaletaApp(
    id: '',
    primaria: Color(0xFFFF6B00),
    primariaEscura: Color(0xFFFF5500),
    suave: Color(0xFFFFF0E6),
    destaque: Color(0xFFFF8C00),
    fundo: Color(0xFFF8FAFC),
  );

  /// Lê a resposta da API; cor inválida fica com o valor padrão.
  factory PaletaApp.daApi(Map<String, dynamic> json) {
    final cores = json['cores'] is Map ? Map<String, dynamic>.from(json['cores'] as Map) : json;
    return PaletaApp(
      id: (json['paleta'] ?? json['id'] ?? '').toString(),
      primaria: _cor(cores['primaria'], padrao.primaria),
      primariaEscura: _cor(cores['primariaEscura'], padrao.primariaEscura),
      suave: _cor(cores['suave'], padrao.suave),
      destaque: _cor(cores['destaque'], padrao.destaque),
      fundo: _cor(cores['fundo'], padrao.fundo),
    );
  }

  static Color _cor(Object? valor, Color padrao) {
    final texto = (valor ?? '').toString().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(texto)) return padrao;
    return Color(int.parse('FF$texto', radix: 16));
  }

  /// Tom mais claro da primária, para o início do gradiente.
  Color get primariaClara => Color.lerp(primaria, Colors.white, 0.18)!;
}

/// Paleta em uso. Trocar aqui repinta o app inteiro na hora.
class TemaLoja extends ChangeNotifier {
  TemaLoja._();

  static final instancia = TemaLoja._();

  /// O app usa o laranja da casa em todas as telas. Com `true`, voltaria a seguir a paleta que
  /// cada unidade escolhe no painel (Aplicativo > Cores), que hoje deixava telas verdes e laranjas misturadas.
  static const usarPaletaDaUnidade = false;

  PaletaApp _paleta = PaletaApp.padrao;

  PaletaApp get paleta => _paleta;

  void aplicar(PaletaApp nova) {
    if (nova.id == _paleta.id && nova.primaria == _paleta.primaria && nova.fundo == _paleta.fundo) return;
    _paleta = nova;
    notifyListeners();
  }

  void restaurarPadrao() => aplicar(PaletaApp.padrao);
}
