/// O que um QR lido pelo app identifica.
///
/// * Geladeira autônoma (QR colado na geladeira): `http(s)://<servidor>/geladeira/<contrato>/<id>`.
/// * Aparelho do Smart Access (QR impresso pelo painel): `pdvmarket:smart-access:<contrato>:<id>`,
///   ou os formatos antigos `QR-<id>` e `<id>`.
class QrEquipamento {
  const QrEquipamento._({required this.geladeira, this.contrato, required this.id});

  final bool geladeira;
  final String? contrato;
  final int id;

  static final _url = RegExp(r'^https?://[^/\s]+/geladeira/([a-z][a-z0-9_]{0,62})/(\d{1,18})/?$');
  static final _painel = RegExp(r'^pdvmarket:smart-access:([a-z][a-z0-9_]{0,62}):(\d{1,18})$');

  /// `null` quando o texto não é de nenhum equipamento conhecido.
  static QrEquipamento? ler(String texto) {
    final t = texto.trim();
    final url = _url.firstMatch(t);
    if (url != null) return QrEquipamento._(geladeira: true, contrato: url.group(1), id: int.parse(url.group(2)!));
    final painel = _painel.firstMatch(t);
    if (painel != null) return QrEquipamento._(geladeira: false, contrato: painel.group(1), id: int.parse(painel.group(2)!));
    final antigo = RegExp(r'^(?:QR-)?(\d{1,18})$', caseSensitive: false).firstMatch(t);
    if (antigo != null) return QrEquipamento._(geladeira: false, id: int.parse(antigo.group(1)!));
    return null;
  }
}
