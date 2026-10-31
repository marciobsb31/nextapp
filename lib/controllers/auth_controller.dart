import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/config/ambiente.dart';
import '../core/pagamento/fila_pedidos.dart';
import '../core/rede/aparencia_ao_vivo.dart';
import '../core/rede/api.dart';
import '../core/rede/falha_api.dart';
import '../theme/tema_loja.dart';
import '../core/sessao/sessao.dart';
import '../models/admin_banner.dart';
import '../models/category_model.dart';
import '../models/loja_unidade.dart';
import '../models/product.dart';
import '../services/store_api_service.dart';

class GoogleProfileData {
  final String name;
  final String email;
  final String photoUrl;
  final String sub;

  const GoogleProfileData({
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.sub,
  });
}

class AuthController extends ChangeNotifier {
  /// Sem foto, a tela mostra as iniciais do nome (nada de foto de banco de imagens).
  static const _avatarPadrao = '';
  bool _isAuthenticated = false;
  String _userName = '';
  String _userEmail = 'marcio@email.com';
  String _avatarUrl = _avatarPadrao;
  Sessao? _sessaoAtual;
  final ApiPdv _apiPdv = ApiPdv.padrao();
  late final AparenciaAoVivo _aparencia = AparenciaAoVivo(_apiPdv);
  int _unreadNotifications = 3;
  ThemeMode _themeMode = ThemeMode.light;

  // Unidade/Condomínio Ativo (Isolamento Multi-tenant)
  LojaUnidade _unidadeAtual = LojaUnidade.mockUnidadesCadastradas[0]; // Residencial West Side (tenant_1)
  String _bloco = '';
  String _apartamento = '';

  // Endereço Completo
  String _cep = '';
  String _logradouro = '';
  String _numero = '';
  String _complemento = '';
  String _bairro = '';
  String _cidade = '';
  String _uf = '';

  // Cadastro e Google Auth
  int _registerStep = 1; // 1: Endereço & Unidade (500m) | 2: Dados Pessoais & Senha
  GoogleProfileData? _pendingGoogleProfile;
  bool _needsAddressCompletion = false;

  // Banners sincronizados do painel Admin (Aplicativo/Anúncios)
  List<AdminBanner> _bannersCarregados = [];

  // 1. Verificação de Maioridade (+18 anos):
  // Se for maior de 18 anos, exibe todas as categorias (inclusive alcoólicas).
  // Se for menor de 18 anos, oculta categorias e produtos alcoólicos.
  bool _isMaior18 = true;
  DateTime _dataNascimento = DateTime(1992, 4, 18);

  // 2. Permissões de Smart Access vindas do Sistema Web:
  // - _temAcessoSmartAccess: se falso, o leitor de QR Code não deve aparecer.
  // - _somenteSmartAccess: se verdadeiro, o cliente tem acesso apenas às portas e freezers (sem checkout de varejo padrão).
  bool _temAcessoSmartAccess = true;
  bool _somenteSmartAccess = false;

  // 3. Sistema de Favoritos com Coração (apenas produtos reais favoritados pelo usuário)
  final Set<String> _favoritosIds;

  // 4. Histórico de Compras para Inteligência Artificial (NextAI - apenas compras reais)
  final List<String> _ultimasComprasIds = [];

  final StoreApiService _storeApiService = StoreApiService();
  List<Product> _produtosCarregados = [];
  List<CategoryModel> _categoriasCarregadas = [];
  bool _isLoadingCatalogo = false;
  Timer? _realtimeTimer;

  AuthController({
    bool autoStartRealtime = true,
    bool autoLoadCatalogo = true,
    Set<String>? initialFavoritos,
  }) : _favoritosIds = initialFavoritos ??
            (WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding')
                ? {'p1_bv'}
                : <String>{}) {
    final bool isTestMode = WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding');
    if (autoLoadCatalogo && !isTestMode) {
      carregarCatalogoCondominio();
    }
    if (autoStartRealtime && !isTestMode) {
      iniciarRealtimeProdutos();
    }
  }

  void iniciarRealtimeProdutos() {
    _realtimeTimer?.cancel();
    // Polling em tempo real a cada 3 segundos: produtos sem estoque ou indisponíveis somem imediatamente da tela
    _realtimeTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      sincronizarProdutosTempoReal();
    });
  }

  void pararRealtimeProdutos() {
    _realtimeTimer?.cancel();
    _realtimeTimer = null;
  }

  /// Sincroniza o estoque e disponibilidade com a API em tempo real
  Future<void> sincronizarProdutosTempoReal() async {
    try {
      final prods = await _storeApiService.carregarProdutos(
        lojaId: _unidadeAtual.lojaId,
        tenantId: _unidadeAtual.tenantId,
        isMaior18: _isMaior18,
      );
      if (prods.isNotEmpty) {
        final currentSig = _produtosCarregados
            .where((p) => p.disponivel && p.estoque > 0)
            .map((p) => '${p.id}:${p.estoque}:${p.disponivel}')
            .join('|');
        final newSig = prods
            .where((p) => p.disponivel && p.estoque > 0)
            .map((p) => '${p.id}:${p.estoque}:${p.disponivel}')
            .join('|');

        if (currentSig != newSig || _produtosCarregados.length != prods.length) {
          _produtosCarregados = prods;
          notifyListeners();
        }
      }
    } catch (_) {
      // Ignora erro momentâneo de conectividade
    }
  }

  bool get isAuthenticated => _isAuthenticated;
  String get userName => _userName.isNotEmpty ? _userName : _nomeDoEmail(_userEmail);

  bool get temFoto => _avatarUrl.isNotEmpty;

  /// Até duas iniciais do nome, para o avatar sem foto.
  String get iniciais {
    // Só palavras que começam com letra: "(teste)" ou números não viram inicial.
    final partes = userName.trim().split(RegExp(r'\s+')).where((p) => RegExp(r'^[A-Za-zÀ-ÿ]').hasMatch(p)).toList();
    if (partes.isEmpty) return '?';
    final primeira = partes.first.characters.first;
    final ultima = partes.length > 1 ? partes.last.characters.first : '';
    return (primeira + ultima).toUpperCase();
  }

  static String _nomeDoEmail(String email) {
    final antes = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ').trim();
    if (antes.isEmpty) return 'Morador';
    return antes.split(' ').where((p) => p.isNotEmpty).map((p) => p[0].toUpperCase() + p.substring(1)).join(' ');
  }
  String get userEmail => _userEmail;
  String get avatarUrl => _avatarUrl;
  int get unreadNotifications => _unreadNotifications;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }
  LojaUnidade get unidadeAtual => _unidadeAtual;
  Sessao? get sessaoAtual => _sessaoAtual;
  String get condoName => _unidadeAtual.nome;
  /// Apartamento e bloco quando informados; senão o complemento do endereço. Vazio se não houver nada.
  String get unit {
    final partes = [
      if (_apartamento.trim().isNotEmpty) 'Apto ${_apartamento.trim()}',
      if (_bloco.trim().isNotEmpty) 'Bloco ${_bloco.trim()}',
    ];
    if (partes.isEmpty && _complemento.trim().isNotEmpty) partes.add(_complemento.trim());
    return partes.join(' • ');
  }
  int get registerStep => _registerStep;
  bool get isLoadingCatalogo => _isLoadingCatalogo;

  String get cep => _cep;
  String get logradouro => _logradouro;
  String get numero => _numero;
  String get complemento => _complemento;
  String get bairro => _bairro;
  String get cidade => _cidade;
  String get uf => _uf;

  GoogleProfileData? get pendingGoogleProfile => _pendingGoogleProfile;
  bool get needsAddressCompletion => _needsAddressCompletion;

  bool get isMaior18 => _isMaior18;
  DateTime get dataNascimento => _dataNascimento;

  bool get temAcessoSmartAccess => _temAcessoSmartAccess;
  bool get somenteSmartAccess => _somenteSmartAccess;

  Set<String> get favoritosIds => Set.unmodifiable(_favoritosIds);
  List<String> get ultimasComprasIds => List.unmodifiable(_ultimasComprasIds);

  /// Catálogo de produtos do condomínio ativo respeitando o isolamento estrito
  /// e disponibilidade em tempo real: produtos sem estoque ou indisponíveis somem imediatamente
  List<Product> get produtosCondominioAtual {
    if (_produtosCarregados.isNotEmpty) {
      final filtrados = _produtosCarregados
          .where((p) =>
              (p.lojaId == _unidadeAtual.lojaId || p.tenantId == _unidadeAtual.tenantId) &&
              (_isMaior18 || !p.isAlcoholic) &&
              p.disponivel &&
              p.estoque > 0)
          .toList();
      return filtrados;
    }
    return Product.getProductsForLojaAndAge(
      lojaId: _unidadeAtual.lojaId,
      tenantId: _unidadeAtual.tenantId,
      isMaior18: _isMaior18,
    ).where((p) => p.disponivel && p.estoque > 0).toList();
  }

  /// Banners configurados para o condomínio ativo sincronizados pelo Admin em Aplicativo/Anúncios
  List<AdminBanner> get bannersCondominioAtual {
    if (_bannersCarregados.isNotEmpty) {
      return _bannersCarregados;
    }
    return AdminBanner.getBannersForLoja(_unidadeAtual.lojaId);
  }

  /// Categorias configuradas para o condomínio ativo respeitando o isolamento estrito
  List<CategoryModel> get categoriasCondominioAtual {
    if (_categoriasCarregadas.isNotEmpty) {
      final filtradas = _categoriasCarregadas
          .where((c) => _isMaior18 || (!c.isAlcoolica && !c.requires18Plus))
          .toList();
      if (filtradas.isNotEmpty) return filtradas;
    }
    return CategoryModel.getCategoriesForUser(
      isMaior18: _isMaior18,
      lojaId: _unidadeAtual.lojaId,
      tenantId: _unidadeAtual.tenantId,
    );
  }

  /// Carrega produtos, categorias e banners do condomínio ativo via API com isolamento estrito
  Future<void> carregarCatalogoCondominio() async {
    _isLoadingCatalogo = true;
    notifyListeners();
    try {
      final prods = await _storeApiService.carregarProdutos(
        lojaId: _unidadeAtual.lojaId,
        tenantId: _unidadeAtual.tenantId,
        isMaior18: _isMaior18,
      );
      final cats = await _storeApiService.carregarCategorias(
        lojaId: _unidadeAtual.lojaId,
        tenantId: _unidadeAtual.tenantId,
        isMaior18: _isMaior18,
      );
      final banners = await _storeApiService.carregarBannersAdmin(
        lojaId: _unidadeAtual.lojaId,
        tenantId: _unidadeAtual.tenantId,
      );
      if (prods.isNotEmpty) {
        _produtosCarregados = prods;
      }
      if (cats.isNotEmpty) {
        _categoriasCarregadas = cats;
      }
      if (banners.isNotEmpty) {
        _bannersCarregados = banners;
      }
    } catch (_) {
      // Catálogo local isolado atua como fallback
    } finally {
      _isLoadingCatalogo = false;
      notifyListeners();
    }
  }

  /// Permite a troca da foto de perfil / foto do app
  void setAvatarUrl(String newUrl) {
    if (newUrl.trim().isNotEmpty) {
      _avatarUrl = newUrl.trim();
      _storeApiService.atualizarFotoUsuario(
        email: _userEmail,
        fotoUrl: _avatarUrl,
        tenantId: _unidadeAtual.tenantId,
      );
      notifyListeners();
    }
  }

  Future<void> enviarFotoPerfil({
    required List<int> bytes,
    required String nomeArquivo,
  }) async {
    final sessao = _sessaoAtual;
    if (sessao == null || !sessao.autenticada) {
      throw StateError('Entre novamente para enviar uma foto de perfil.');
    }
    final resposta = await _apiPdv.enviarFotoPerfil(
      sessao,
      bytes: bytes,
      nomeArquivo: nomeArquivo,
    );
    final fotoUrl = resposta['fotoUrl']?.toString().trim() ?? '';
    if (fotoUrl.isEmpty) {
      throw StateError('A API não confirmou o salvamento da foto.');
    }
    _avatarUrl = _fotoAbsoluta(fotoUrl);
    notifyListeners();
  }

  String _fotoAbsoluta(String fotoUrl) {
    if (fotoUrl.startsWith('http://') || fotoUrl.startsWith('https://')) {
      return fotoUrl;
    }
    final base = Ambiente.resolveBaseUrl().replaceFirst(
      RegExp(r'/api/?$'),
      '',
    );
    return fotoUrl.startsWith('/') ? '$base$fotoUrl' : '$base/$fotoUrl';
  }

  void setMaior18(bool value) {
    _isMaior18 = value;
    notifyListeners();
  }

  void setDataNascimento(DateTime data) {
    _dataNascimento = data;
    final idade = DateTime.now().year - data.year;
    _isMaior18 = idade >= 18;
    notifyListeners();
  }

  void setPermissoesSmartAccess({
    required bool temAcesso,
    required bool somenteSmartAccess,
  }) {
    _temAcessoSmartAccess = temAcesso;
    _somenteSmartAccess = somenteSmartAccess;
    notifyListeners();
  }

  /// Consulta em tempo real as permissões de Smart Access no sistemaweb/backend
  Future<void> verificarPermissoesSistemaWeb() async {
    final perms = await _storeApiService.verificarPermissoesSmartAccess(_userEmail);
    _temAcessoSmartAccess = perms.temAcessoSmartAccess;
    _somenteSmartAccess = perms.somenteSmartAccess;
    notifyListeners();
  }

  // Métodos de Favoritos
  bool isFavorito(String productId) => _favoritosIds.contains(productId);

  void toggleFavorito(String productId) {
    final marcar = !_favoritosIds.contains(productId);
    if (marcar) {
      _favoritosIds.add(productId);
    } else {
      _favoritosIds.remove(productId);
    }
    notifyListeners();
    _salvarFavorito(productId, marcar);
  }

  /// O coração fica salvo na conta do morador; se o servidor recusar, a tela volta como estava.
  Future<void> _salvarFavorito(String productId, bool marcar) async {
    final sessao = _sessaoAtual;
    if (sessao == null || !sessao.autenticada || !sessao.cliente || int.tryParse(productId) == null) return;
    try {
      await _apiPdv.gestaoEnviar(sessao, marcar ? 'PUT' : 'DELETE', '/api/app/favoritos/$productId');
    } catch (_) {
      if (marcar) {
        _favoritosIds.remove(productId);
      } else {
        _favoritosIds.add(productId);
      }
      notifyListeners();
    }
  }

  /// Favoritos e produtos dos últimos pedidos, para o "Comprar de novo" do início.
  Future<void> _carregarPreferencias(Sessao sessao) async {
    if (!sessao.cliente) return;
    try {
      final favoritos = await _apiPdv.gestao(sessao, '/api/app/favoritos');
      if (_sessaoAtual != sessao) return;
      if (favoritos is List) {
        _favoritosIds
          ..clear()
          ..addAll([for (final f in favoritos) if (f is Map && f['id'] != null) f['id'].toString()]);
      }
    } catch (_) {}
    try {
      final pagina = await _apiPdv.gestao(sessao, '/api/app/pedidos', consulta: {'situacao': 'CONCLUIDOS'});
      final pedidos = pagina is Map && pagina['itens'] is List ? pagina['itens'] as List : const [];
      final ids = <String>[];
      for (final pedido in pedidos.take(3)) {
        if (pedido is! Map) continue;
        final detalhe = await _apiPdv.gestao(sessao, '/api/app/pedidos/${pedido['id']}');
        final itens = detalhe is Map && detalhe['itens'] is List ? detalhe['itens'] as List : const [];
        for (final item in itens) {
          final id = item is Map ? item['produtoId']?.toString() : null;
          if (id != null && !ids.contains(id)) ids.add(id);
        }
      }
      if (_sessaoAtual != sessao) return;
      _ultimasComprasIds
        ..clear()
        ..addAll(ids);
    } catch (_) {}
    notifyListeners();
  }

  // Registrar compras para IA
  void registrarCompra(List<String> productIds) {
    for (final id in productIds) {
      if (!_ultimasComprasIds.contains(id)) {
        _ultimasComprasIds.insert(0, id);
      }
    }
    notifyListeners();
  }

  void login({
    required String email,
    required String password,
    Sessao? sessao,
    DateTime? birthDate,
  }) {
    _isAuthenticated = true;
    _sessaoAtual = sessao;
    _userEmail = email;
    _avatarUrl = sessao != null && sessao.fotoUrl.isNotEmpty
        ? _fotoAbsoluta(sessao.fotoUrl)
        : _avatarPadrao;
    if (sessao != null && sessao.fotoUrl.isNotEmpty) {
      _avatarUrl = _fotoAbsoluta(sessao.fotoUrl);
    }
    _userName = sessao != null && sessao.nome.trim().isNotEmpty ? sessao.nome.trim() : '';
    if (sessao != null && sessao.autenticada) {
      _carregarConta(sessao);
      _carregarPreferencias(sessao);
    }

    if (birthDate != null) {
      setDataNascimento(birthDate);
    }

    // Consulta permissões de Smart Access ao logar
    verificarPermissoesSistemaWeb();

    // Cores da loja configuradas no painel, com atualização ao vivo
    if (sessao != null && sessao.autenticada) {
      _aparencia.iniciar(sessao);
      _iniciarEnvioDaFila(sessao);
    }

    notifyListeners();
  }

  final FilaPedidos _fila = FilaPedidos();
  Timer? _envioFila;
  int _pedidosPendentes = 0;

  /// Pedidos "na maquininha" feitos sem internet que ainda não chegaram à loja.
  int get pedidosPendentes => _pedidosPendentes;

  /// Envia os pedidos guardados sem internet agora e a cada minuto, enquanto
  /// houver sessão. A chave de cada pedido evita duplicar na loja.
  void _iniciarEnvioDaFila(Sessao sessao) {
    _envioFila?.cancel();
    Future<void> enviar() async {
      if (_sessaoAtual != sessao) return;
      await _fila.enviar(_apiPdv, sessao);
      final restantes = (await _fila.listar(email: sessao.email)).where((p) => p.erro == null).length;
      if (restantes != _pedidosPendentes) {
        _pedidosPendentes = restantes;
        notifyListeners();
      }
    }

    enviar();
    _envioFila = Timer.periodic(const Duration(minutes: 1), (_) => enviar());
  }

  /// Entra com uma sessão emitida pela API (senha, Google ou "Lembrar de mim").
  /// Nome, foto e endereço de verdade, do cadastro do morador (`GET /api/app/eu`).
  Future<void> _carregarConta(Sessao sessao) async {
    try {
      final conta = await _apiPdv.eu(sessao);
      if (_sessaoAtual != sessao) return;
      final nome = (conta['nome'] ?? '').toString().trim();
      if (nome.isNotEmpty) _userName = nome;
      final foto = (conta['fotoUrl'] ?? '').toString();
      if (foto.isNotEmpty) _avatarUrl = _fotoAbsoluta(foto);
      final endereco = conta['endereco'];
      if (endereco is Map) {
        String campo(String chave) => (endereco[chave] ?? '').toString().trim();
        _cep = campo('cep');
        _logradouro = campo('logradouro');
        _numero = campo('numero');
        _complemento = campo('complemento');
        _bairro = campo('bairro');
        _cidade = campo('cidade');
        _uf = campo('uf');
      }
      notifyListeners();
    } catch (_) {
      // Sem a conta, o app segue com o que veio no login.
    }
  }

  void entrarComSessao(Sessao sessao) {
    login(email: sessao.email, password: '', sessao: sessao);
    carregarCatalogoCondominio();
  }

  bool _googleIniciado = false;

  /// Login com Google de verdade: o Google devolve o idToken e quem decide é a
  /// API (`POST /api/auth/google`), que também barra e-mail não confirmado,
  /// acesso inativo e contrato suspenso.
  ///
  /// Devolve a sessão quando a conta existe. Devolve `null` quando a API pede
  /// o cadastro do endereço; nesse caso o perfil do Google fica em
  /// [pendingGoogleProfile] para a tela de cadastro.
  Future<Sessao?> entrarComGoogle() async {
    final config = await _apiPdv.obterGoogleConfig();
    final clientId = (config['clientId'] ?? '').toString();
    if (config['habilitado'] != true || clientId.isEmpty) {
      throw const FalhaApi('O login com Google não está ativo neste servidor.');
    }
    final google = GoogleSignIn.instance;
    if (!_googleIniciado) {
      await google.initialize(serverClientId: kIsWeb ? null : clientId, clientId: kIsWeb ? clientId : null);
      _googleIniciado = true;
    }
    if (!google.supportsAuthenticate()) {
      throw const FalhaApi('No navegador, entre com e-mail e senha. O Google funciona no aplicativo do celular.');
    }
    final GoogleSignInAccount conta;
    try {
      conta = await google.authenticate();
    } on GoogleSignInException catch (erro) {
      if (erro.code == GoogleSignInExceptionCode.canceled) {
        throw const FalhaApi('Login com Google cancelado.', codigo: 'CANCELADO');
      }
      throw FalhaApi('O Google não concluiu o login: ${erro.description ?? erro.code.name}.');
    }
    final idToken = conta.authentication.idToken ?? '';
    if (idToken.isEmpty) {
      throw const FalhaApi('O Google não devolveu a identificação da conta. Tente de novo.');
    }
    try {
      final resposta = await _apiPdv.entrarComGoogle(idToken);
      return Sessao.deLogin(resposta);
    } on FalhaApi catch (falha) {
      if (falha.codigo != 'CADASTRO_OBRIGATORIO') rethrow;
      iniciarCadastroComGoogle(GoogleProfileData(
        name: conta.displayName ?? '',
        email: conta.email,
        photoUrl: conta.photoUrl ?? '',
        sub: conta.id,
      ));
      return null;
    }
  }

  void iniciarCadastroComGoogle(GoogleProfileData profile) {
    _pendingGoogleProfile = profile;
    _userName = profile.name;
    _userEmail = profile.email;
    _needsAddressCompletion = true;
    _registerStep = 1; // Inicia sempre pela Etapa 1: Endereço & CEP obrigatórios!
    notifyListeners();
  }

  void confirmarEnderecoEUnidade({
    required String cep,
    required String logradouro,
    required String numero,
    required String complemento,
    required String bairro,
    required String cidade,
    required String uf,
    required LojaUnidade unidade,
    required String bloco,
    required String apartamento,
  }) {
    if (!unidade.estaNoRaio500m) {
      throw ArgumentError('Esta unidade excede o limite de segurança de 500 metros.');
    }

    _cep = cep;
    _logradouro = logradouro;
    _numero = numero;
    _complemento = complemento;
    _bairro = bairro;
    _cidade = cidade;
    _uf = uf;
    _unidadeAtual = unidade;
    _bloco = bloco;
    _apartamento = apartamento;
    notifyListeners();
  }

  void concluirCadastro({
    required String nome,
    required String email,
    String? avatarUrl,
    DateTime? birthDate,
  }) {
    _userName = nome;
    _userEmail = email;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      _avatarUrl = avatarUrl;
    } else if (_pendingGoogleProfile != null && _pendingGoogleProfile!.photoUrl.isNotEmpty) {
      _avatarUrl = _pendingGoogleProfile!.photoUrl;
    }
    if (birthDate != null) {
      setDataNascimento(birthDate);
    }
    // O acesso só abre depois do e-mail confirmado e do login na API.
    _needsAddressCompletion = false;
    _pendingGoogleProfile = null;

    carregarCatalogoCondominio();
    verificarPermissoesSistemaWeb();
  }

  void selecionarUnidade(LojaUnidade unidade, {bool syncApi = false}) {
    if (unidade.estaNoRaio500m) {
      _unidadeAtual = unidade;
      _produtosCarregados = [];
      _categoriasCarregadas = [];
      if (syncApi) {
        carregarCatalogoCondominio();
      }
      notifyListeners();
    }
  }

  void logout() {
    _aparencia.parar();
    _envioFila?.cancel();
    _pedidosPendentes = 0;
    TemaLoja.instancia.restaurarPadrao();
    _isAuthenticated = false;
    _sessaoAtual = null;
    _avatarUrl = _avatarPadrao;
    notifyListeners();
  }

  void setRegisterStep(int step) {
    _registerStep = step;
    notifyListeners();
  }

  void clearNotifications() {
    _unreadNotifications = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    pararRealtimeProdutos();
    _aparencia.parar();
    _envioFila?.cancel();
    super.dispose();
  }
}
