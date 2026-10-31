import 'dart:convert';

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

  /// Formas de cartão da unidade e a chave pública do PagBank para criptografar.
  Future<Map<String, dynamic>> configCartao(Sessao sessao) async {
    final resposta = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/api/app/pagamento/cartao/config',
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao)),
      ),
    );
    return resposta.data ?? {};
  }

  /// Cria o pedido. A mesma `idempotencia` nunca gera dois pedidos, então
  /// reenviar depois de uma queda de conexão é seguro.
  Future<Map<String, dynamic>> criarPedido(Sessao sessao, Map<String, Object?> corpo) async {
    final resposta = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/api/app/pedidos',
        data: corpo,
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao)),
      ),
    );
    return resposta.data ?? {};
  }

  /// Situação do pagamento; para PIX a API também confere no PagBank.
  Future<Map<String, dynamic>> pagamentoDoPedido(Sessao sessao, int vendaId) async {
    final resposta = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/api/app/pedidos/$vendaId/pagamento',
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao)),
      ),
    );
    return resposta.data ?? {};
  }

  /// Geladeira autônoma lida pelo morador (nome, unidade, se exige compra, se está online).
  Future<Map<String, dynamic>> geladeira(Sessao sessao, int id) async {
    final resposta = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/api/app/geladeiras/$id',
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao)),
      ),
    );
    return resposta.data ?? {};
  }

  /// QR de abertura de uso único para um pedido pago nesta geladeira.
  Future<Map<String, dynamic>> gerarAberturaGeladeira(Sessao sessao, int id, int vendaId) async {
    final resposta = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/api/app/geladeiras/$id/abertura',
        data: {'vendaId': vendaId},
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao)),
      ),
    );
    return resposta.data ?? {};
  }

  /// Geladeira sem leitor: o próprio app usa o QR de abertura.
  Future<Map<String, dynamic>> abrirGeladeiraPeloApp(Sessao sessao, String qr) async {
    final resposta = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/api/app/geladeiras/abrir',
        data: {'qr': qr},
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao)),
      ),
    );
    return resposta.data ?? {};
  }

  /// Muda a unidade do morador (a da geladeira lida), quando o contrato permite.
  Future<Map<String, dynamic>> trocarUnidade(Sessao sessao, int lojaId) async {
    final resposta = await _enviar(
      () => _dio.put<Map<String, dynamic>>(
        '/api/app/eu/unidade',
        data: {'lojaId': lojaId},
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao)),
      ),
    );
    return resposta.data ?? {};
  }

  /// Morador abre porta, catraca ou freezer pelo QR do equipamento. A pessoa é
  /// a da sessão; a API aplica as regras do condomínio e enfileira a ordem na placa.
  Future<Map<String, dynamic>> abrirPorQr(Sessao sessao, {required String qrCode, required String chave}) async {
    final resposta = await _enviar(
      () => _dio.post<Map<String, dynamic>>(
        '/api/app/smart-access/abrir',
        data: {'qrCode': qrCode, 'chaveIdempotencia': chave},
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao)),
      ),
    );
    return resposta.data ?? {};
  }

  /// Paleta de cores que a loja escolheu no painel.
  Future<Map<String, dynamic>> aparencia(Sessao sessao, int lojaId) async {
    final resposta = await _enviar(
      () => _dio.get<Map<String, dynamic>>(
        '/api/app/aparencia',
        queryParameters: {'lojaId': lojaId},
        options: Options(headers: EscopoRequisicao.cabecalhos(sessao)),
      ),
    );
    return resposta.data ?? {};
  }

  /// Canal SSE do contrato (`/api/tempo-real/eventos`). Devolve cada evento
  /// como `(nome, dados)`. A conexão fica aberta até o servidor ou o app fechar.
  Stream<({String evento, String dados})> eventosTempoReal(Sessao sessao) async* {
    final resposta = await _dio.get<ResponseBody>(
      '/api/tempo-real/eventos',
      options: Options(
        headers: {...EscopoRequisicao.cabecalhos(sessao), 'Accept': 'text/event-stream'},
        responseType: ResponseType.stream,
        receiveTimeout: Duration.zero,
      ),
    );
    final corpo = resposta.data;
    if (corpo == null) return;
    var evento = 'message';
    final dados = StringBuffer();
    final linhas = corpo.stream
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter());
    await for (final linha in linhas) {
      if (linha.isEmpty) {
        if (dados.isNotEmpty) yield (evento: evento, dados: dados.toString());
        evento = 'message';
        dados.clear();
      } else if (linha.startsWith('event:')) {
        evento = linha.substring(6).trim();
      } else if (linha.startsWith('data:')) {
        if (dados.isNotEmpty) dados.write('\n');
        dados.write(linha.substring(5).trimLeft());
      }
    }
  }

  Future<T> _enviar<T>(Future<T> Function() chamada) async {
    try {
      return await chamada();
    } catch (erro) {
      throw falhaDe(erro);
    }
  }
}
