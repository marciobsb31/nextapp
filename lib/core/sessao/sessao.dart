/// Sessão devolvida por `POST /api/auth/login`.
///
/// O contrato vem do token emitido pelo servidor. A interface não escolhe
/// outro `tenantId` depois do login.
class Sessao {
  const Sessao({
    required this.token,
    required this.tenantId,
    required this.nome,
    required this.email,
    required this.perfil,
    this.fotoUrl = '',
    this.trocarSenha = false,
    this.trocaToken = '',
  });

  final String token;
  final String tenantId;
  final String nome;
  final String email;
  final String perfil;
  final String fotoUrl;
  final bool trocarSenha;
  final String trocaToken;

  bool get autenticada => token.isNotEmpty && !trocarSenha;

  bool get cliente => perfil == 'CLIENTE';

  bool get admin => perfil == 'TENANT_ADMIN' || perfil == 'SUPER_ADMIN';

  bool get operacao => perfil == 'OPERADOR' || admin;

  factory Sessao.deLogin(Map<String, dynamic> json) {
    if (json['trocarSenha'] == true) {
      return Sessao(
        token: '',
        tenantId: '',
        nome: '',
        email: texto(json['email']),
        perfil: '',
        trocarSenha: true,
        trocaToken: texto(json['trocaToken']),
      );
    }
    final usuario = json['user'];
    final mapa = usuario is Map ? Map<String, dynamic>.from(usuario) : const <String, dynamic>{};
    return Sessao(
      token: texto(json['token']),
      tenantId: texto(json['tenantId']),
      nome: texto(mapa['nome']),
      email: texto(mapa['email']),
      perfil: texto(mapa['perfil']),
      fotoUrl: texto(mapa['fotoUrl']),
    );
  }

  Map<String, String> paraCofre() {
    return {
      'token': token,
      'tenantId': tenantId,
      'nome': nome,
      'email': email,
      'perfil': perfil,
      'fotoUrl': fotoUrl,
    };
  }

  factory Sessao.doCofre(Map<String, String> valores) {
    return Sessao(
      token: valores['token'] ?? '',
      tenantId: valores['tenantId'] ?? '',
      nome: valores['nome'] ?? '',
      email: valores['email'] ?? '',
      perfil: valores['perfil'] ?? '',
      fotoUrl: valores['fotoUrl'] ?? '',
    );
  }
}

String texto(Object? valor) => valor == null ? '' : valor.toString();
