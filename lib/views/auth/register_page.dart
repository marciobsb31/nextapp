import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../controllers/auth_controller.dart';
import '../../core/documento/documentos.dart';
import '../../core/rede/api.dart';
import '../../core/rede/falha_api.dart';
import '../../models/loja_unidade.dart';
import '../../services/viacep_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/next_pdv_logo.dart';

class RegisterPage extends StatefulWidget {
  final AuthController authController;
  final VoidCallback onRegisterSuccess;
  final GoogleProfileData? googleProfile;
  final ViaCepService? viaCepService;

  const RegisterPage({
    super.key,
    required this.authController,
    required this.onRegisterSuccess,
    this.googleProfile,
    this.viaCepService,
  });

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Passo 1: Endereço & Unidade no Raio de 500m (Obrigatório primeiro)
  // Passo 2: Dados Pessoais & Senha
  int _currentStep = 1;

  // Controllers - Endereço (CEP primeiro - todos limpos para preenchimento via CEP)
  final _cepController = TextEditingController();
  final _logradouroController = TextEditingController();
  final _numeroController = TextEditingController();
  final _complementoController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _ufController = TextEditingController();
  final _blocoController = TextEditingController();
  final _aptController = TextEditingController();

  // Controllers - Dados Pessoais
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final _phoneController = TextEditingController();
  final _cpfController = TextEditingController();
  final _passwordController = TextEditingController();

  late final ViaCepService _viaCepService;
  bool _isSearchingCep = false;
  String? _cepErrorMessage;

  // Unidades disponíveis calculadas para o CEP (estritamente dentro do raio de 500m)
  List<LojaUnidade> _unidadesDisponiveis = [];
  LojaUnidade? _unidadeSelecionada;

  // Controle de campos que vieram do ViaCEP (devem vir ReadOnly quando preenchidos)
  bool _isLogradouroReadOnly = false;
  bool _isBairroReadOnly = false;
  bool _isCidadeReadOnly = false;
  bool _isUfReadOnly = false;

  bool _isLoading = false;
  bool _isMaior18 = true;

  @override
  void initState() {
    super.initState();
    _viaCepService = widget.viaCepService ?? ViaCepService();

    final profile = widget.googleProfile;
    // Traz nome e email do Google se disponível, caso contrário campos limpos
    _nameController = TextEditingController(text: profile?.name ?? '');
    _emailController = TextEditingController(text: profile?.email ?? '');

    // Sem CEP preenchido inicialmente, sem unidades carregadas
    _unidadesDisponiveis = [];
    _unidadeSelecionada = null;
  }

  @override
  void dispose() {
    _cepController.dispose();
    _logradouroController.dispose();
    _numeroController.dispose();
    _complementoController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    _ufController.dispose();
    _blocoController.dispose();
    _aptController.dispose();

    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cpfController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _buscarCep() async {
    final rawCep = _cepController.text.trim();
    if (rawCep.replaceAll(RegExp(r'\D'), '').length != 8) {
      setState(() {
        _cepErrorMessage = 'Informe um CEP válido com 8 dígitos';
      });
      return;
    }

    setState(() {
      _isSearchingCep = true;
      _cepErrorMessage = null;
    });

    try {
      // Conecta à base de dados do sistemaweb trazendo o endereço oficial e os condomínios
      final res = await _viaCepService.consultarCepEBuscarCondominios(rawCep);
      if (!mounted) return;

      if (res.erro != null) {
        setState(() {
          _cepErrorMessage = res.erro;
          _isSearchingCep = false;
          _unidadesDisponiveis = [];
          _unidadeSelecionada = null;
        });
        return;
      }

      setState(() {
        if (res.endereco != null) {
          _logradouroController.text = res.endereco!.logradouro;
          _bairroController.text = res.endereco!.bairro;
          _cidadeController.text = res.endereco!.localidade;
          _ufController.text = res.endereco!.uf;

          // Os dados vindos do ViaCEP devem vir readonly (apenas leitura)
          _isLogradouroReadOnly = res.endereco!.logradouro.isNotEmpty;
          _isBairroReadOnly = res.endereco!.bairro.isNotEmpty;
          _isCidadeReadOnly = res.endereco!.localidade.isNotEmpty;
          _isUfReadOnly = res.endereco!.uf.isNotEmpty;
        }

        // Traz SOMENTE as unidades no raio de 500 metros do CEP digitado
        _unidadesDisponiveis = res.condominios.where((u) => u.estaNoRaio500m).toList();
        _unidadeSelecionada = _unidadesDisponiveis.isNotEmpty ? _unidadesDisponiveis.first : null;
        _isSearchingCep = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSearchingCep = false;
          _cepErrorMessage = 'Erro ao consultar o CEP na base de dados.';
        });
      }
    }
  }

  void _avancarParaPasso2() {
    final cepLimpo = _cepController.text.trim().replaceAll(RegExp(r'\D'), '');
    if (cepLimpo.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sem o CEP não tem como fazer o cadastro. Informe um CEP válido com 8 dígitos.',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_logradouroController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Clique no botão da lupa para consultar o CEP e carregar os dados.',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_numeroController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Por favor, preencha o Número do imóvel.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Regra estrita: Somente unidades no raio de 500m
    if (_unidadesDisponiveis.isEmpty || _unidadeSelecionada == null || !_unidadeSelecionada!.estaNoRaio500m) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cadastro bloqueado: Nenhuma unidade disponível no raio de 500 metros deste CEP.',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    setState(() => _currentStep = 2);
  }

  Future<void> _finalizarCadastro() async {
    if (_unidadeSelecionada == null || !_unidadeSelecionada!.estaNoRaio500m) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cadastro bloqueado: Todo usuário do NextPDV deve ter um condomínio conveniado atrelado.',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final nome = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final senha = _passwordController.text;
    if (nome.isEmpty || email.isEmpty || !email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Informe seu nome e um e-mail válido.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // CPF obrigatório no cadastro rápido (também identifica o comprador nas geladeiras e na nota).
    if (!cpfValido(_cpfController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Informe um CPF válido.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (senha.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A senha precisa ter pelo menos 6 caracteres.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    late final Map<String, dynamic> resposta;
    try {
      resposta = await ApiPdv.padrao().cadastrarConta({
        'nome': nome,
        'email': email,
        'senha': senha,
        'cep': _cepController.text.trim(),
        'tenantId': _unidadeSelecionada!.tenantId,
        'lojaId': _unidadeSelecionada!.lojaId,
        'numeroEndereco': _numeroController.text.trim(),
        'complemento': _complementoController.text.trim(),
        'telefone': _phoneController.text.trim(),
        'cpf': _cpfController.text.replaceAll(RegExp(r'\D'), ''),
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(falhaDe(erro).mensagem, style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;

    // Confirma endereço e unidade no controller com isolamento de raio 500m
    widget.authController.confirmarEnderecoEUnidade(
      cep: _cepController.text,
      logradouro: _logradouroController.text,
      numero: _numeroController.text,
      complemento: _complementoController.text,
      bairro: _bairroController.text,
      cidade: _cidadeController.text,
      uf: _ufController.text,
      unidade: _unidadeSelecionada!,
      bloco: _blocoController.text,
      apartamento: _aptController.text,
    );
    widget.authController.setMaior18(_isMaior18);

    setState(() => _isLoading = false);
    _mostrarDialogoAtivacao(email, emailEnviado: resposta['emailEnviado'] == true);
  }

  void _mostrarDialogoAtivacao(String email, {required bool emailEnviado}) {
    var enviado = emailEnviado;
    var enviando = false;
    String? erroReenvio;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  enviado ? LucideIcons.mailCheck : LucideIcons.mail,
                  color: AppColors.primaryOrange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  enviado ? 'Ativação de Conta' : 'Cadastro criado',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                enviado
                    ? 'Enviamos o link de ativação para:'
                    : 'Não foi possível enviar o e-mail de ativação. Confira a configuração de SMTP e tente novamente.',
                style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  email,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navyDark),
                ),
              ),
              if (enviado) ...[
                const SizedBox(height: 12),
                Text(
                  'Abra o e-mail e confirme o cadastro para liberar o acesso. Depois, entre com sua senha.',
                  style: GoogleFonts.poppins(fontSize: 12, height: 1.4),
                ),
              ],
              if (erroReenvio != null) ...[
                const SizedBox(height: 10),
                Text(erroReenvio!, style: GoogleFonts.poppins(fontSize: 12, color: Colors.redAccent)),
              ],
            ],
          ),
          actions: [
            if (!enviado)
              TextButton(
                onPressed: enviando
                    ? null
                    : () async {
                        setDialogState(() {
                          enviando = true;
                          erroReenvio = null;
                        });
                        try {
                          final ok = await ApiPdv.padrao().reenviarAviso(email);
                          if (!ctx.mounted) return;
                          setDialogState(() {
                            enviando = false;
                            enviado = ok;
                            if (!ok) {
                              erroReenvio = 'O servidor não confirmou o envio. Tente novamente em instantes.';
                            }
                          });
                        } catch (erro) {
                          if (!ctx.mounted) return;
                          setDialogState(() {
                            enviando = false;
                            erroReenvio = falhaDe(erro).mensagem;
                          });
                        }
                      },
                child: Text(enviando ? 'Enviando...' : 'Reenviar e-mail'),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: enviando
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      widget.onRegisterSuccess();
                      Navigator.pop(context);
                    },
              child: Text('Voltar para entrar', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGoogleUser = widget.googleProfile != null;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.navyDark),
          onPressed: () {
            if (_currentStep == 2) {
              setState(() => _currentStep = 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const NextPdvInlineBrand(height: 28),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Oficial Inspirado na Tela 03
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'Criar Conta',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navyDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Preencha seus dados para começar a comprar',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Badge de Integração com Google se o morador veio da tela de login
              if (isGoogleUser) _buildGoogleUserBanner(),

              // Indicador de Etapas
              _buildStepIndicator(),

              const SizedBox(height: 20),

              // Formulário da Etapa Atual
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppColors.cardShadow,
                ),
                child: _currentStep == 1 ? _buildStep1Endereco() : _buildStep2DadosPessoais(),
              ),

              const SizedBox(height: 24),

              // Botões de Ação
              if (_currentStep == 1)
                GradientButton(
                  text: (_unidadesDisponiveis.any((u) => u.estaNoRaio500m) && _unidadeSelecionada != null)
                      ? 'Continuar para Dados Pessoais >>'
                      : '🚫 Cadastro Bloqueado (Sem Condomínio)',
                  onPressed: (_unidadesDisponiveis.any((u) => u.estaNoRaio500m) && _unidadeSelecionada != null)
                      ? _avancarParaPasso2
                      : null,
                )
              else ...[
                GradientButton(
                  text: 'Cadastrar',
                  isLoading: _isLoading,
                  onPressed: _finalizarCadastro,
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final sessao = await widget.authController.entrarComGoogle();
                      if (sessao != null) {
                        widget.authController.entrarComSessao(sessao);
                        widget.onRegisterSuccess();
                        if (context.mounted) Navigator.pop(context);
                      } else if (mounted) {
                        setState(() {});
                      }
                    } catch (erro) {
                      final falha = falhaDe(erro);
                      if (falha.codigo != 'CANCELADO') {
                        messenger.showSnackBar(SnackBar(content: Text(falha.mensagem)));
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.globe, size: 20, color: Color(0xFF4285F4)),
                        const SizedBox(width: 10),
                        Text(
                          'Cadastrar com Google',
                          style: GoogleFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navyDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Link de Rodapé: "Já tem uma conta? Entrar"
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Já tem uma conta? ',
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      'Entrar',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleUserBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF5FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4285F4).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4285F4).withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(LucideIcons.userCheck, color: Color(0xFF4285F4), size: 22),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.checkCircle2, size: 14, color: Color(0xFF4285F4)),
                    const SizedBox(width: 4),
                    Text(
                      'Google Conectado',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E3A8A),
                      ),
                    ),
                  ],
                ),
                Text(
                  widget.googleProfile!.name,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navyDark,
                  ),
                ),
                Text(
                  widget.googleProfile!.email,
                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Etapa $_currentStep de 2',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryOrange,
                ),
              ),
              Text(
                _currentStep == 1
                    ? '1. Endereço & Unidade (500m)'
                    : '2. Dados Pessoais & Acesso',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentStep == 2 ? AppColors.primaryOrange : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PASSO 1: ENDEREÇO COM CEP NO PRIMEIRO CAMPO E RAIO DE 500M
  // ==========================================
  Widget _buildStep1Endereco() {
    final unidadesNoRaio = _unidadesDisponiveis.where((u) => u.estaNoRaio500m).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.mapPin, color: AppColors.primaryOrange, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Endereço do Morador',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyDark,
                    ),
                  ),
                  Text(
                    'Obrigatório para liberação e isolamento do condomínio.',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // PRIMEIRO CAMPO: CEP com botão de busca automática ViaCEP
        Text(
          'CEP (Primeiro campo obrigatório)',
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.navyDark),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _cepController,
                keyboardType: TextInputType.number,
                maxLength: 9,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '00000-000',
                  prefixIcon: const Icon(LucideIcons.search, color: AppColors.textSecondary, size: 20),
                  suffixIcon: _isSearchingCep
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onChanged: (val) {
                  final limpo = val.replaceAll(RegExp(r'\D'), '');
                  if (limpo.length == 8) {
                    _buscarCep();
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: _isSearchingCep ? null : _buscarCep,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: AppColors.orangeGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.locateFixed, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Buscar',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        if (_cepErrorMessage != null) ...[
          const SizedBox(height: 6),
          Text(
            _cepErrorMessage!,
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.w600),
          ),
        ],

        const SizedBox(height: 14),

        // Logradouro (Rua/Avenida) - Bloqueado para edição se vier do ViaCEP
        TextField(
          controller: _logradouroController,
          readOnly: _isLogradouroReadOnly,
          decoration: InputDecoration(
            labelText: 'Logradouro / Rua / Avenida *',
            prefixIcon: const Icon(LucideIcons.home, color: AppColors.textSecondary, size: 20),
            filled: _isLogradouroReadOnly,
            fillColor: _isLogradouroReadOnly ? const Color(0xFFF1F5F9) : Colors.white,
            suffixIcon: _isLogradouroReadOnly
                ? Tooltip(
                    message: 'Preenchido automaticamente pelo ViaCEP (Somente leitura)',
                    child: Icon(LucideIcons.lock, color: AppColors.primaryOrange, size: 16),
                  )
                : null,
          ),
        ),

        const SizedBox(height: 12),

        // Número e Complemento (Campos abertos para edição)
        Row(
          children: [
            Expanded(
              flex: 4,
              child: TextField(
                controller: _numeroController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Número *',
                  prefixIcon: Icon(LucideIcons.hash, color: AppColors.textSecondary, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 6,
              child: TextField(
                controller: _complementoController,
                decoration: const InputDecoration(
                  labelText: 'Complemento',
                  hintText: 'Apto, Casa...',
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Bairro, Cidade e UF - Bloqueados para edição se vierem do ViaCEP
        Row(
          children: [
            Expanded(
              flex: 5,
              child: TextField(
                controller: _bairroController,
                readOnly: _isBairroReadOnly,
                decoration: InputDecoration(
                  labelText: 'Bairro',
                  filled: _isBairroReadOnly,
                  fillColor: _isBairroReadOnly ? const Color(0xFFF1F5F9) : Colors.white,
                  suffixIcon: _isBairroReadOnly
                      ? Tooltip(
                          message: 'Preenchido automaticamente pelo ViaCEP (Somente leitura)',
                          child: Icon(LucideIcons.lock, color: AppColors.primaryOrange, size: 16),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: TextField(
                controller: _cidadeController,
                readOnly: _isCidadeReadOnly,
                decoration: InputDecoration(
                  labelText: 'Cidade',
                  filled: _isCidadeReadOnly,
                  fillColor: _isCidadeReadOnly ? const Color(0xFFF1F5F9) : Colors.white,
                  suffixIcon: _isCidadeReadOnly
                      ? Tooltip(
                          message: 'Preenchido automaticamente pelo ViaCEP (Somente leitura)',
                          child: Icon(LucideIcons.lock, color: AppColors.primaryOrange, size: 16),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _ufController,
                readOnly: _isUfReadOnly,
                decoration: InputDecoration(
                  labelText: 'UF',
                  filled: _isUfReadOnly,
                  fillColor: _isUfReadOnly ? const Color(0xFFF1F5F9) : Colors.white,
                  suffixIcon: _isUfReadOnly
                      ? Tooltip(
                          message: 'Preenchido automaticamente pelo ViaCEP (Somente leitura)',
                          child: Icon(LucideIcons.lock, color: AppColors.primaryOrange, size: 16),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Bloco/Torre e Apartamento
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _blocoController,
                decoration: const InputDecoration(
                  labelText: 'Bloco / Torre *',
                  prefixIcon: Icon(LucideIcons.layout, color: AppColors.textSecondary, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _aptController,
                decoration: const InputDecoration(
                  labelText: 'Apto / Unidade *',
                  prefixIcon: Icon(LucideIcons.doorClosed, color: AppColors.textSecondary, size: 20),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        // ==========================================
        // SELEÇÃO DE UNIDADES NO RAIO DE 500 METROS
        // ==========================================
        Row(
          children: [
            Icon(LucideIcons.radar, color: AppColors.primaryOrange, size: 18),
            const SizedBox(width: 6),
            Text(
              'Unidades no Raio de 500 Metros',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.navyDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Para garantir o isolamento e segurança, selecione apenas a unidade do seu condomínio no raio de até 500m.',
          style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
        ),

        const SizedBox(height: 12),

        if (_cepController.text.trim().isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade300, width: 1.2),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.info, color: AppColors.navyDark, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Digite seu CEP no campo acima e clique na lupa para buscar o endereço oficial e as unidades atendidas no raio de 500 metros.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navyDark,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (unidadesNoRaio.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.shieldAlert, color: Color(0xFFDC2626), size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cadastro Bloqueado: Nenhuma unidade conveniada',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF991B1B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Nenhum condomínio atendido pelo NextPDV foi localizado no raio de 500 metros para o CEP informado. O cadastro é restrito a moradores dentro do raio de atendimento.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF7F1D1D),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: unidadesNoRaio.map((unidade) {
              final isSelected = _unidadeSelecionada?.lojaId == unidade.lojaId;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryOrange.withOpacity(0.06)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryOrange
                        : Colors.grey.shade300,
                    width: isSelected ? 2.0 : 1.0,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryOrange : AppColors.navyDark,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.building2,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            unidade.nome,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navyDark,
                            ),
                          ),
                        ),
                        // Badge de Distância e Raio
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0E6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFF97316),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            '✓ ${unidade.distanciaFormatada}',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFEA580C),
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '${unidade.endereco} - ${unidade.bairro}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: Radio<int>(
                      value: unidade.lojaId,
                      groupValue: _unidadeSelecionada?.lojaId,
                      activeColor: AppColors.primaryOrange,
                      onChanged: (_) {
                        setState(() => _unidadeSelecionada = unidade);
                      },
                    ),
                    onTap: () {
                      setState(() => _unidadeSelecionada = unidade);
                    },
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // ==========================================
  // PASSO 2: DADOS PESSOAIS & CONFIRMAÇÃO
  // ==========================================
  Widget _buildStep2DadosPessoais() {
    final isGoogleUser = widget.googleProfile != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.userCheck, color: AppColors.primaryOrange, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Identificação do Morador',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyDark,
                    ),
                  ),
                  Text(
                    isGoogleUser
                        ? 'Dados importados da sua Conta Google.'
                        : 'Informe seus dados para habilitar o Smart Access.',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        if (isGoogleUser && widget.googleProfile!.photoUrl.isNotEmpty) ...[
          Center(
            child: Column(
              children: [
                ClipOval(
                  child: Image.network(
                    widget.googleProfile!.photoUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const CircleAvatar(
                      radius: 32,
                      child: Icon(LucideIcons.user, size: 28),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Foto importada da Conta Google',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Unidade Confirmada Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.navyDark.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.navyDark.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.shieldCheck, color: AppColors.primaryOrange, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unidade Vinculada (Isolamento Ativo):',
                      style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textSecondary),
                    ),
                    Text(
                      '${_unidadeSelecionada?.nome}',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navyDark),
                    ),
                    Text(
                      'Apto ${_aptController.text} • ${_blocoController.text} (Distância: ${_unidadeSelecionada?.distanciaFormatada})',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppColors.primaryOrange, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Nome Completo
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Nome Completo *',
            prefixIcon: const Icon(LucideIcons.user, color: AppColors.textSecondary, size: 20),
            suffixIcon: isGoogleUser
                ? const Icon(LucideIcons.checkCheck, color: Color(0xFF4285F4), size: 18)
                : null,
          ),
        ),

        const SizedBox(height: 14),

        // E-mail
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'E-mail Principal *',
            prefixIcon: const Icon(LucideIcons.mail, color: AppColors.textSecondary, size: 20),
            suffixIcon: isGoogleUser
                ? const Icon(LucideIcons.checkCheck, color: Color(0xFF4285F4), size: 18)
                : null,
          ),
        ),

        const SizedBox(height: 14),

        // Telefone Celular
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Telefone Celular / WhatsApp *',
            prefixIcon: Icon(LucideIcons.phone, color: AppColors.textSecondary, size: 20),
          ),
        ),

        const SizedBox(height: 14),

        // CPF (obrigatório)
        TextField(
          controller: _cpfController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.\-]')), LengthLimitingTextInputFormatter(14)],
          decoration: const InputDecoration(
            labelText: 'CPF *',
            prefixIcon: Icon(LucideIcons.idCard, color: AppColors.textSecondary, size: 20),
          ),
        ),

        const SizedBox(height: 14),

        // Senha de Acesso
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Senha de Acesso ao App *',
            prefixIcon: Icon(LucideIcons.lock, color: AppColors.textSecondary, size: 20),
          ),
        ),

        const SizedBox(height: 14),

        // Verificação de Maioridade (+18)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isMaior18 ? AppColors.primaryOrange.withValues(alpha: 0.4) : Colors.grey.shade300,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                LucideIcons.wine,
                color: _isMaior18 ? AppColors.primaryOrange : Colors.grey,
              ),
              title: Text(
                'Maior de 18 Anos (+18)',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navyDark,
                ),
              ),
              subtitle: Text(
                _isMaior18
                    ? 'Autoriza a compra de bebidas alcoólicas'
                    : 'Bebidas alcoólicas serão bloqueadas no app',
                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
              ),
              value: _isMaior18,
              activeThumbColor: AppColors.primaryOrange,
              onChanged: (val) => setState(() => _isMaior18 = val),
            ),
          ),
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryOrange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primaryOrange.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.keyRound, color: AppColors.primaryOrange, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sua unidade Next PDV liberará a porta física automaticamente via QR Code e Biometria.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.navyDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
