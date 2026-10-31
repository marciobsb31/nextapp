import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../controllers/auth_controller.dart';
import '../../core/rede/api.dart';
import '../../core/rede/falha_api.dart';
import '../../core/sessao/acesso_lembrado.dart';
import '../../core/sessao/sessao.dart';
import '../../theme/app_theme.dart';
import '../../widgets/curved_header.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/logo_animada.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  final AuthController authController;
  final VoidCallback onLoginSuccess;
  final AcessoLembrado? acesso;

  const LoginPage({
    super.key,
    required this.authController,
    required this.onLoginSuccess,
    this.acesso,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AcessoLembrado _acesso = widget.acesso ?? AcessoLembrado();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _lembrar = false;
  bool _biometriaPronta = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _carregarLembrado();
  }

  Future<void> _carregarLembrado() async {
    final lembrar = await _acesso.lembrarMarcado();
    final email = await _acesso.emailLembrado();
    final guardada = await _acesso.sessaoGuardada();
    final biometria = guardada != null && await _acesso.biometriaDisponivel();
    if (!mounted) return;
    setState(() {
      _lembrar = lembrar;
      if (email.isNotEmpty && _emailController.text.isEmpty) _emailController.text = email;
      _biometriaPronta = biometria;
    });
  }

  Future<void> _concluirEntrada(Sessao sessao) async {
    await _acesso.aposEntrar(sessao, lembrar: _lembrar);
    widget.authController.entrarComSessao(sessao);
    if (mounted) widget.onLoginSuccess();
  }

  String _mensagemDe(FalhaApi falha) {
    switch (falha.codigo) {
      case 'EMAIL_NAO_CONFIRMADO':
        return 'Confirme o cadastro pelo link enviado ao seu e-mail antes de entrar.';
      case 'ACESSO_INATIVO':
        return 'Este acesso está inativo. Solicite a reativação à administração.';
      case 'CONTRATO_SUSPENSO':
        return 'O contrato deste condomínio está suspenso.';
      default:
        return falha.mensagem;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    setState(() => _errorMessage = null);

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // 1. Validação estrita de campos de entrada
    if (email.isEmpty) {
      setState(
        () => _errorMessage = 'Por favor, informe seu e-mail ou condomínio.',
      );
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      setState(
        () => _errorMessage =
            'Informe um e-mail válido (ex: morador@condominio.com.br).',
      );
      return;
    }

    if (password.isEmpty) {
      setState(() => _errorMessage = 'Por favor, digite sua senha de acesso.');
      return;
    }

    if (password.length < 6) {
      setState(
        () => _errorMessage =
            'A senha de acesso deve ter no mínimo 6 caracteres.',
      );
      return;
    }

    setState(() => _isLoading = true);

    // 2. Validação e tentativa de login na API
    try {
      final api = ApiPdv.padrao();
      final sessao = await api.entrar(email, password);

      final isMenor =
          email.toLowerCase().contains('menor') ||
          email.toLowerCase().contains('jovem') ||
          email.toLowerCase().contains('teen');
      widget.authController.setMaior18(!isMenor);

      if (mounted) setState(() => _isLoading = false);
      await _concluirEntrada(sessao);
      return;
    } catch (erro) {
      final falha = falhaDe(erro);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _mensagemDe(falha);
        });
      }
    }
  }

  void _handleEsqueceuSenha() {
    final emailRecupController = TextEditingController(
      text: _emailController.text.trim(),
    );
    bool enviando = false;
    String? msgRetorno;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardSurfaceDark : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Curvado Escuro com Ícone de Cadeado (Inspiração Tela 04)
                    CurvedAuthHeader(
                      height: 140,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primaryOrange.withValues(
                                  alpha: 0.15,
                                ),
                                border: Border.all(
                                  color: AppColors.primaryOrange.withValues(
                                    alpha: 0.4,
                                  ),
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                LucideIcons.lockKeyhole,
                                color: AppColors.primaryOrange,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'NEXTPDV',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white70,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        left: 24,
                        right: 24,
                        top: 8,
                        bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Recuperação de Senha',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.navyDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Informe seu e-mail cadastrado para receber as instruções de redefinição de senha.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (msgRetorno != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    LucideIcons.checkCircle2,
                                    color: Color(0xFF2E7D32),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      msgRetorno!,
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF1B5E20),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          TextField(
                            controller: emailRecupController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'E-mail Cadastrado',
                              hintText: 'seu.email@exemplo.com',
                              prefixIcon: Icon(
                                LucideIcons.mail,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryOrange,
                                foregroundColor: Colors.white,
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: enviando
                                  ? null
                                  : () async {
                                      final em = emailRecupController.text
                                          .trim();
                                      if (em.isEmpty || !em.contains('@')) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Informe um e-mail válido',
                                                ),
                                              ),
                                            );
                                        return;
                                      }
                                      setSheetState(() => enviando = true);
                                      try {
                                        final msg = await ApiPdv.padrao()
                                            .esqueci(em);
                                        setSheetState(() {
                                          enviando = false;
                                          msgRetorno = msg;
                                        });
                                      } catch (_) {
                                        setSheetState(() {
                                          enviando = false;
                                          msgRetorno = 'Se este e-mail estiver cadastrado, o link chega em instantes.';
                                        });
                                      }
                                    },
                              child: enviando
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          LucideIcons.send,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Enviar Link de Recuperação',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              '← Voltar ao Login',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _handleGoogleLogin() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    // A API decide: conta existente entra; conta nova vai para o cadastro do endereço.
    final Sessao? sessao;
    try {
      sessao = await widget.authController.entrarComGoogle();
    } catch (erro) {
      final falha = falhaDe(erro);
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
          if (falha.codigo != 'CANCELADO') _errorMessage = _mensagemDe(falha);
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);

    if (sessao != null) {
      await _concluirEntrada(sessao);
    } else {
      // Usuário não existe no sistema: feedback claro e redirecionamento para o cadastro
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(LucideIcons.userPlus, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Conta Google selecionada. Complete seu endereço para escolher a unidade...',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.navyDark,
          duration: const Duration(milliseconds: 2200),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RegisterPage(
            authController: widget.authController,
            googleProfile: widget.authController.pendingGoogleProfile,
            onRegisterSuccess: widget.onLoginSuccess,
          ),
        ),
      );
    }
  }

  /// A biometria só destrava a sessão lembrada, e a API confirma o token antes de entrar.
  void _handleBiometrics() async {
    setState(() => _errorMessage = null);
    final sessao = await _acesso.sessaoGuardada();
    if (sessao == null) {
      setState(() {
        _biometriaPronta = false;
        _errorMessage = 'Entre com e-mail e senha e marque "Lembrar de mim" para usar a biometria.';
      });
      return;
    }
    if (!await _acesso.confirmarBiometria()) return;
    setState(() => _isLoading = true);
    try {
      await ApiPdv.padrao().eu(sessao);
      if (mounted) setState(() => _isLoading = false);
      await _concluirEntrada(sessao);
    } catch (erro) {
      final falha = falhaDe(erro);
      final expirou = falha.status == 401 || falha.status == 403;
      if (expirou) await _acesso.esquecerSessao();
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (expirou) _biometriaPronta = false;
          _errorMessage = expirou ? 'Sua sessão expirou. Entre com e-mail e senha.' : _mensagemDe(falha);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ==========================================
            // HEADER CURVADO SUPERIOR COM A LOGO (Inspiração Tela 02)
            // ==========================================
            CurvedAuthHeader(
              height: 220,
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: LogoAnimada(largura: 190),
                  ),
                ),
              ),
            ),

            // ==========================================
            // CORPO DO FORMULÁRIO (Inspiração Tela 02)
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acessar Conta',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.navyDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Insira suas credenciais para continuar',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 22),

                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFFCDD2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.alertCircle,
                            color: Color(0xFFC62828),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFB71C1C),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Campo E-mail com Ícone de Envelope
                  Text(
                    'E-mail',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.navyDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'cliente@nextpdv.com.br',
                      prefixIcon: Icon(
                        LucideIcons.mail,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Campo Senha com Ícone de Cadeado e Eye Toggle
                  Text(
                    'Senha',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.navyDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: '••••••••••••',
                      prefixIcon: const Icon(
                        LucideIcons.lock,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? LucideIcons.eyeOff
                              : LucideIcons.eye,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Lembrar de mim à esquerda, Esqueceu a senha? à direita
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() => _lembrar = !_lembrar),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: Checkbox(
                                  value: _lembrar,
                                  activeColor: AppColors.primaryOrange,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                  onChanged: (valor) => setState(() => _lembrar = valor ?? false),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Lembrar de mim',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : AppColors.navyDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      TextButton(
                      onPressed: _handleEsqueceuSenha,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                      ),
                      child: Text(
                        'Esqueceu a senha?',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                    ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Botão Primário Laranja "Entrar"
                  GradientButton(
                    text: 'Entrar',
                    isLoading: _isLoading,
                    onPressed: _handleLogin,
                  ),
                  const SizedBox(height: 18),

                  // Divisor OU (Conforme Inspiração)
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: isDark
                              ? AppColors.borderDark
                              : Colors.grey.shade300,
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'OU',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: isDark
                              ? AppColors.borderDark
                              : Colors.grey.shade300,
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ==========================================
                  // BOTÃO DO GOOGLE (DESCIDO CONFORME INSPIRAÇÃO!)
                  // ==========================================
                  InkWell(
                    onTap: _isGoogleLoading ? null : _handleGoogleLogin,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.cardSurfaceDarkSecondary
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : Colors.grey.shade300,
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: _isGoogleLoading
                          ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Color(0xFF4285F4),
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildGoogleIcon(),
                                const SizedBox(width: 12),
                                Text(
                                  'Entrar com Google',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.navyDark,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Biometria: aparece só com sessão lembrada neste aparelho
                  if (_biometriaPronta) Center(
                    child: InkWell(
                      onTap: _handleBiometrics,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.fingerprint,
                              size: 20,
                              color: AppColors.primaryOrange,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Entrar com Biometria',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.navyDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Link de Rodapé: "Novo por aqui? Cadastre-se"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Novo por aqui? ',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RegisterPage(
                                authController: widget.authController,
                                onRegisterSuccess: widget.onLoginSuccess,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Cadastre-se',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.19;
    final arcBounds = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    void drawSegment(Color color, double startAngle, double sweepAngle) {
      canvas.drawArc(
        arcBounds,
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt,
      );
    }

    drawSegment(const Color(0xFFEA4335), -1.50, 1.42);
    drawSegment(const Color(0xFFFBBC05), -0.01, 1.49);
    drawSegment(const Color(0xFF34A853), 1.56, 1.43);
    drawSegment(const Color(0xFF4285F4), 3.06, 1.58);

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(size.width - strokeWidth / 2, center.dy),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
