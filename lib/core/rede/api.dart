import 'package:dio/dio.dart';

import '../config/ambiente.dart';
import '../sessao/escopo.dart';
import '../sessao/sessao.dart';
import 'falha_api.dart';

class ApiPdv {
  ApiPdv(this._dio);

  final Dio _dio;

  factory ApiPdv.padrao() {
    return ApiPdv(
      Dio(
        BaseOptions(
          baseUrl: Ambiente.resolveBaseUrl(),
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 20),
          headers: const {'Accept': 'application/json'},
        ),
      ),
    );
  }

  Future<Sessao> entrar(String email, String senha) async {
    final resposta = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {'email': email.trim().toLowerCase(), 'password': senha},
      ),
    );
    return Sessao.deLogin(resposta.data ?? {});
  }

  Future<Map<String, dynamic>> entrarComGoogle(String idToken) async {
    final resposta = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/api/auth/google',
        data: {'idToken': idToken},
      ),
    );
    return resposta.data ?? {};
  }

  Future<Map<String, dynamic>> obterGoogleConfig() async {
    final resposta = await _enviar(
      () => _dio.get<Map<String, dynamic>>('/api/auth/google/config'),
    );
    return resposta.data ?? {};
  }

  Future<String> esqueci(String email) async {
    final resposta = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/api/auth/esqueci',
        data: {'email': email.trim().toLowerCase()},
      ),
    );
    return texto(resposta.data?['message']).isEmpty
        ? 'Se este e-mail estiver cadastrado, o link chega em instantes.'
        : texto(resposta.data?['message']);
  }

  Future<void> sair(Sessao sessao) async {
    await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/api/auth/sair',
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao)),
      ),
    );
  }

  Future<Map<String, dynamic>> eu(Sessao sessao) async {
    final resposta = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/api/app/eu',
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao)),
      ),
    );
    return resposta.data ?? {};
  }

  Future<Map<String, dynamic>> enviarFotoPerfil(
    Sessao sessao, {
    required List<int> bytes,
    required String nomeArquivo,
  }) async {
    final resposta = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/api/app/eu/foto',
        data: FormData.fromMap({
          'arquivo': MultipartFile.fromBytes(bytes, filename: nomeArquivo),
        }),
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao)),
      ),
    );
    return resposta.data ?? {};
  }

  Future<Map<String, dynamic>> produtos(
    Sessao sessao, {
    String busca = '',
    int? categoriaId,
    bool soDesconto = false,
    int? unidadeId,
    int pagina = 0,
    int tamanho = 24,
  }) async {
    final resposta = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/api/app/produtos',
        queryParameters: {
          'q': busca,
          'pagina': pagina,
          'tamanho': tamanho,
          'ordem': 'RELEVANCIA',
          'categoriaId': ?categoriaId,
          if (soDesconto) 'desconto': true,
        },
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao, unidadeId: unidadeId)),
      ),
    );
    return resposta.data ?? {};
  }

  Future<List<Map<String, dynamic>>> categorias(Sessao sessao, {int? unidadeId}) async {
    final resposta = await _enviar(
      () => _dio.get<List<dynamic>>(
        '/api/app/categorias',
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao, unidadeId: unidadeId)),
      ),
    );
    return [
      for (final item in resposta.data ?? const [])
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  Future<List<Map<String, dynamic>>> banners(Sessao sessao, int lojaId) async {
    final resposta = await _enviar(
      () => _dio.get<List<dynamic>>(
        '/api/app/banners/ativos',
        queryParameters: {'lojaId': lojaId},
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao, unidadeId: lojaId)),
      ),
    );
    return [
      for (final item in resposta.data ?? const [])
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  Future<Map<String, dynamic>> painelLoja(
    Sessao sessao, {
    int? unidadeId,
    int periodo = 1,
    bool todas = false,
  }) async {
    final resposta = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/api/app/admin/dashboard',
        queryParameters: {
          'periodo': periodo,
          'lojaId': ?unidadeId,
          if (todas) 'todas': true,
        },
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao, unidadeId: todas ? null : unidadeId)),
      ),
    );
    return resposta.data ?? {};
  }

  Future<Map<String, dynamic>> produto(Sessao sessao, int id, {int? unidadeId}) async {
    final resposta = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/api/app/produtos/$id',
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao, unidadeId: unidadeId)),
      ),
    );
    return resposta.data ?? {};
  }

  Future<Map<String, dynamic>> pedidosOperacao(
    Sessao sessao, {
    required int unidadeId,
    String situacao = 'RECEBIDO',
    int pagina = 0,
  }) async {
    final resposta = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/api/app/operacao/pedidos',
        queryParameters: {'situacao': situacao, 'lojaId': unidadeId, 'pagina': pagina},
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao, unidadeId: unidadeId)),
      ),
    );
    return resposta.data ?? {};
  }

  Future<Map<String, dynamic>> situacaoPedido(
    Sessao sessao, {
    required int unidadeId,
    required int pedidoId,
    required String situacao,
    String? motivo,
  }) async {
    final resposta = await _enviar(
      () => _dio.put<Map<String, dynamic>>(
        '/api/app/operacao/pedidos/$pedidoId/situacao',
        data: {'situacao': situacao, 'motivo': ?motivo},
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao, unidadeId: unidadeId)),
      ),
    );
    return resposta.data ?? {};
  }

  Future<Map<String, dynamic>> receberPedido(
    Sessao sessao, {
    required int unidadeId,
    required int pedidoId,
    required String metodo,
  }) async {
    final resposta = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/api/app/operacao/pedidos/$pedidoId/receber',
        data: {'metodoPagamento': metodo},
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao, unidadeId: unidadeId)),
      ),
    );
    return resposta.data ?? {};
  }

  Future<Map<String, dynamic>> simularCarrinho(
    Sessao sessao,
    List<Map<String, Object>> itens, {
    int? unidadeId,
  }) async {
    final resposta = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/api/app/carrinho/simular',
        data: {'itens': itens},
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao, unidadeId: unidadeId)),
      ),
    );
    return resposta.data ?? {};
  }

  Future<List<Map<String, dynamic>>> fornecedores(Sessao sessao) async {
    final resposta = await _enviar(
      () => _dio.get<List<dynamic>>(
        '/api/fornecedores',
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao)),
      ),
    );
    return [
      for (final item in resposta.data ?? const [])
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  Future<Map<String, dynamic>> consultarCnpjFornecedor(Sessao sessao, String cnpj) async {
    final resposta = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/api/fornecedores/cnpj/$cnpj',
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao)),
      ),
    );
    return resposta.data ?? {};
  }

  Future<Map<String, dynamic>> consultarCepFornecedor(Sessao sessao, String cep) async {
    final resposta = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/api/fornecedores/cep/$cep',
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao)),
      ),
    );
    return resposta.data ?? {};
  }

  Future<List<Map<String, dynamic>>> cupons(Sessao sessao) async {
    final resposta = await _enviar(
      () => _dio.get<List<dynamic>>(
        '/api/cupons',
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao)),
      ),
    );
    return [
      for (final item in resposta.data ?? const [])
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  Future<Map<String, dynamic>> salvarCupom(Sessao sessao, Map<String, Object?> corpo, {int? id}) async {
    final cabecalhos = Options(headers: EscopoRequisicao.cabecalhos(sessao));
    final resposta = await _enviar(
      () => id == null
          ? _dio.post<Map<String, dynamic>>('/api/cupons', data: corpo, options: cabecalhos)
          : _dio.put<Map<String, dynamic>>('/api/cupons/$id', data: corpo, options: cabecalhos),
    );
    return resposta.data ?? {};
  }

  Future<List<String>> categoriasContrato(Sessao sessao) async {
    final resposta = await _enviar(
      () => _dio.get<List<dynamic>>(
        '/api/categorias',
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao)),
      ),
    );
    return [
      for (final item in resposta.data ?? const [])
        if (item is Map && texto(item['nome']).isNotEmpty) texto(item['nome']),
    ];
  }

  Future<List<Map<String, dynamic>>> clientesCupom(Sessao sessao) async {
    final resposta = await _enviar(
      () => _dio.get<List<dynamic>>(
        '/api/clientes',
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao)),
      ),
    );
    return [
      for (final item in resposta.data ?? const [])
        if (item is Map && item['id'] is num)
          {
            'id': (item['id'] as num).toInt(),
            'nome': texto(item['nome']),
            'telefone': texto(item['telefone']),
          },
    ];
  }

  Future<Map<String, dynamic>> salvarFornecedor(Sessao sessao, Map<String, Object?> corpo, {int? id}) async {
    final cabecalhos = Options(headers: EscopoRequisicao.cabecalhos(sessao));
    final resposta = await _enviar(
      () => id == null
          ? _dio.post<Map<String, dynamic>>('/api/fornecedores', data: corpo, options: cabecalhos)
          : _dio.put<Map<String, dynamic>>('/api/fornecedores/$id', data: corpo, options: cabecalhos),
    );
    return resposta.data ?? {};
  }

  Future<Map<String, dynamic>> lojasPorCep(String cep) async {
    final resposta = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/api/publico/lojas',
        queryParameters: {'cep': cep},
      ),
    );
    return resposta.data ?? {};
  }

  Future<Map<String, dynamic>> lojasProximas(double latitude, double longitude) async {
    final resposta = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/api/publico/lojas/proximas',
        queryParameters: {'lat': latitude, 'lng': longitude},
      ),
    );
    return resposta.data ?? {};
  }

  Future<Map<String, dynamic>> cadastrarConta(Map<String, Object?> corpo) async {
    final resposta = await _enviar(
      () => _dio.post<Map<String, dynamic>>('/api/publico/moradores/conta', data: corpo),
    );
    return resposta.data ?? {};
  }

  Future<bool> reenviarAviso(String email) async {
    final resposta = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/api/publico/moradores/aviso',
        data: {'email': email.trim().toLowerCase()},
      ),
    );
    return resposta.data?['emailEnviado'] == true;
  }

  Future<T> _enviar<T>(Future<T> Function() chamada) async {
    try {
      return await chamada();
    } catch (erro) {
      throw falhaDe(erro);
    }
  }
}
