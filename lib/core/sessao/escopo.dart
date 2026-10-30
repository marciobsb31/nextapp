import 'sessao.dart';

/// O que o aplicativo pode anexar a uma chamada.
///
/// O identificador digitado na tela não vira autorização. Para quem não é
/// superadministrador, o contrato é o da sessão. A API ignora um
/// `X-Tenant-ID` divergente nesse caso; o app nem chega a enviá-lo.
abstract final class EscopoRequisicao {
  static Map<String, String> cabecalhos(Sessao sessao, {int? unidadeId}) {
    if (!sessao.autenticada) {
      throw StateError('Não há sessão para autorizar esta chamada.');
    }
    final cabecalhos = {'Authorization': 'Bearer ${sessao.token}'};
    if (!sessao.cliente && unidadeId != null) {
      cabecalhos['X-Loja-ID'] = '$unidadeId';
    }
    return cabecalhos;
  }

  static bool podeConfirmarLoja({
    required String tenantId,
    required int lojaId,
    required List<LojaOferecida> oferecidas,
  }) {
    return oferecidas.any(
      (loja) => loja.tenantId == tenantId && loja.lojaId == lojaId,
    );
  }
}

class LojaOferecida {
  const LojaOferecida({required this.tenantId, required this.lojaId, required this.nome});

  final String tenantId;
  final int lojaId;
  final String nome;
}
