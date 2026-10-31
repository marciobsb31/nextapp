import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../controllers/auth_controller.dart';
import '../../core/rede/api.dart';
import '../../core/rede/falha_api.dart';
import '../../core/sessao/acesso_lembrado.dart';
import '../../core/sessao/sessao.dart';
import '../../core/util/link_entrada.dart';
import '../../theme/app_theme.dart';
import '../../theme/tema_loja.dart';
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
  bool _lembrar = true;
  bool _biometriaPronta = false;
  String? _errorMessage;

  /// Erros de preenchimento aparecem embaixo do próprio campo.
  String? _erroEmail;
  String? _erroSenha;

  /// Cadastro ainda não confirmado: oferece reenviar o link.
  bool _podeReenviar = false;
  bool _reenviando = false;

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

  Future<void> _concluirEntrada(Sessao sessao, {bool comSenha = false}) async {
    if (comSenha) {
      // Avisa o gerenciador de senhas do celular que o login deu certo (oferece salvar).
      TextInput.finishAutofillContext();
      await _oferecerBiometria();
    }
    await _acesso.aposEntrar(sessao, lembrar: _lembrar);
    widget.authController.entrarComSessao(sessao);
    if (mounted) widget.onLoginSuccess();
  }

  /// Depois do primeiro login com senha, pergunta uma vez se a pessoa quer usar a digital.
  Future<void> _oferecerBiometria() async {
    if (_biometriaPronta || !mounted) return;
    if (await _acesso.biometriaJaOferecida() || !await _acesso.biometriaDisponivel()) return;
    await _acesso.marcarBiometriaOferecida();
    if (!mounted) return;
    final usar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(LucideIcons.fingerprint, color: AppColors.primaryOrange, size: 36),
        title: const Text('Entrar com a digital?'),
        content: const Text('Na próxima vez, você entra só com a digital, sem digitar a senha.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Agora não')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Usar a digital')),
        ],
      ),
    );
    if (usar == true) _lembrar = true;
  }

  Future<void> _reenviarConfirmacao() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => _reenviando = true);
    try {
      final enviado = await ApiPdv.padrao().reenviarAviso(email);
      if (!mounted) return;
      if (!enviado) {
        // O servidor recebeu o pedido, mas o e-mail não saiu: avisa em vez de prometer que chega.
        setState(() => _errorMessage =
            'O e-mail de confirmação não saiu agora. Avise a administração do condomínio para conferir o envio de e-mails.');
        return;
      }
      setState(() {
        _podeReenviar = false;
        _errorMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Link de confirmação enviado para $email. Confira também a caixa de spam.'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (erro) {
      if (mounted) setState(() => _errorMessage = falhaDe(erro).mensagem);
    } finally {
      if (mounted) setState(() => _reenviando = false);
    }
  }

  String _mensagemDe(FalhaApi falha) {
    switch (falha.codigo) {
      case 'EMAIL_NAO_CONFIRMADO':
        return 'Seu cadastro ainda não foi confirmado. Abra o link que enviamos para o seu e-mail.';
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

  static final _formatoEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Só o preenchimento é conferido aqui; a regra da senha é do servidor.
    setState(() {
      _errorMessage = null;
      _podeReenviar = false;
      _erroEmail = email.isEmpty
          ? 'Informe seu e-mail.'
          : !_formatoEmail.hasMatch(email)
              ? 'Confira o e-mail (ex.: nome@email.com).'
              : null;
      _erroSenha = password.isEmpty ? 'Informe sua senha.' : null;
    });
    if (_erroEmail != null || _erroSenha != null) {
      HapticFeedback.mediumImpact();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final sessao = await ApiPdv.padrao().entrar(email, password);

      final isMenor =
          email.toLowerCase().contains('menor') ||
          email.toLowerCase().contains('jovem') ||
          email.toLowerCase().contains('teen');
      widget.authController.setMaior18(!isMenor);

      if (mounted) setState(() => _isLoading = false);
      await _concluirEntrada(sessao, comSenha: true);
    } catch (erro) {
      final falha = falhaDe(erro);
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _podeReenviar = falha.codigo == 'EMAIL_NAO_CONFIRMADO';
          if (falha.status == 401 && falha.codigo != 'EMAIL_NAO_CONFIRMADO') {
            _erroSenha = 'E-mail ou senha não conferem.';
          } else {
            _errorMessage = _mensagemDe(falha);
          }
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
                            'Recuperar senha',
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
                                color: const Color(0xFFFFF0E6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    LucideIcons.checkCircle2,
                                    color: Color(0xFFEA580C),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      msgRetorno!,
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFFC2410C),
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
                              labelText: 'E-mail cadastrado',
                              hintText: 'seu@email.com',
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
                                          'Enviar link',
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

  void _abrirCadastro() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterPage(
          authController: widget.authController,
          onRegisterSuccess: widget.onLoginSuccess,
        ),
      ),
    );
  }

  TextStyle _rotulo(bool isDark) => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white70 : AppColors.navyDark,
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Com o teclado aberto o cabeçalho encolhe e o botão Entrar continua à vista.
    final tecladoAberto = MediaQuery.viewInsetsOf(context).bottom > 0;
    final apoio = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SingleChildScrollView(
        child: Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: CurvedAuthHeader(
                height: tecladoAberto ? 120 : 230,
                child: SafeArea(
                  bottom: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: LogoAnimada(largura: tecladoAberto ? 110 : 170),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: ListenableBuilder(
                listenable: LinkEntrada.instancia,
                builder: (context, _) {
                  final veioDaGeladeira = LinkEntrada.instancia.geladeira != null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 14),
                      Text(
                        'Entrar',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.navyDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        veioDaGeladeira
                            ? 'Entre ou crie sua conta para comprar na geladeira.'
                            : 'Use sua conta Google ou seu e-mail e senha.',
                        style: GoogleFonts.poppins(fontSize: 13.5, color: apoio),
                      ),
                      if (veioDaGeladeira) ...[
                        const SizedBox(height: 14),
                        _avisoGeladeira(isDark),
                      ],
                      const SizedBox(height: 20),

                      if (_errorMessage != null) _avisoErro(),

                      _botaoGoogle(isDark),
                      const SizedBox(height: 18),
                      _divisor('ou com e-mail', isDark),
                      const SizedBox(height: 18),

                      AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('E-mail', style: _rotulo(isDark)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email, AutofillHints.username],
                              autocorrect: false,
                              enableSuggestions: false,
                              textCapitalization: TextCapitalization.none,
                              onChanged: (_) {
                                if (_erroEmail != null) setState(() => _erroEmail = null);
                              },
                              decoration: InputDecoration(
                                hintText: 'seu@email.com',
                                errorText: _erroEmail,
                                prefixIcon: const Icon(LucideIcons.mail, color: AppColors.textSecondary, size: 20),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text('Senha', style: _rotulo(isDark)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              autocorrect: false,
                              enableSuggestions: false,
                              onChanged: (_) {
                                if (_erroSenha != null) setState(() => _erroSenha = null);
                              },
                              onSubmitted: (_) {
                                if (!_isLoading) _handleLogin();
                              },
                              decoration: InputDecoration(
                                errorText: _erroSenha,
                                prefixIcon: const Icon(LucideIcons.lock, color: AppColors.textSecondary, size: 20),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword ? 'Mostrar senha' : 'Esconder senha',
                                  icon: Icon(
                                    _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),

                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => setState(() => _lembrar = !_lembrar),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
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
                                        'Manter conectado',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.white70 : AppColors.navyDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _handleEsqueceuSenha,
                            style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
                            child: Text(
                              'Esqueci a senha',
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryOrange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      GradientButton(
                        text: _isLoading ? 'Entrando...' : 'Entrar',
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _handleLogin,
                      ),

                      if (_biometriaPronta) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton.icon(
                            onPressed: _isLoading ? null : _handleBiometrics,
                            style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
                            icon: Icon(LucideIcons.fingerprint, size: 20, color: AppColors.primaryOrange),
                            label: Text(
                              'Entrar com a digital',
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : AppColors.navyDark,
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      _divisor('primeira vez aqui?', isDark),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _abrirCadastro,
                          icon: Icon(LucideIcons.userPlus, size: 18, color: AppColors.primaryOrange),
                          label: Text(
                            'Criar conta',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.navyDark,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.primaryOrange.withValues(alpha: 0.5), width: 1.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avisoGeladeira(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TemaLoja.instancia.paleta.suave,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.refrigerator, color: AppColors.primaryOrange, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Você leu o QR de uma geladeira. Assim que entrar, abrimos a compra dela para você.',
              style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.navyDark, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avisoErro() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.alertCircle, color: Color(0xFFC62828), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: GoogleFonts.poppins(color: const Color(0xFFB71C1C), fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (_podeReenviar)
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: TextButton.icon(
                onPressed: _reenviando ? null : _reenviarConfirmacao,
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(48, 40)),
                icon: _reenviando
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(LucideIcons.mailCheck, size: 16, color: Color(0xFFB71C1C)),
                label: Text(
                  'Reenviar link de confirmação',
                  style: GoogleFonts.poppins(color: const Color(0xFFB71C1C), fontSize: 12.5, fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _divisor(String texto, bool isDark) {
    final linha = Expanded(child: Divider(color: isDark ? AppColors.borderDark : Colors.grey.shade300, thickness: 1));
    return Row(
      children: [
        linha,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            texto,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
        ),
        linha,
      ],
    );
  }

  Widget _botaoGoogle(bool isDark) {
    return Semantics(
      button: true,
      label: 'Continuar com Google',
      child: InkWell(
        onTap: _isGoogleLoading ? null : _handleGoogleLogin,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardSurfaceDarkSecondary : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: isDark ? AppColors.borderDark : Colors.grey.shade300, width: 1.2),
            boxShadow: AppColors.cardShadow,
          ),
          child: _isGoogleLoading
              ? const Center(
                  child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF4285F4))),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildGoogleIcon(),
                    const SizedBox(width: 12),
                    Text(
                      'Continuar com Google',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.navyDark,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() => SvgPicture.string(_logoGoogle, width: 22, height: 22);
}

/// "G" oficial do Google (quatro cores), para o botão "Continuar com Google".
const _logoGoogle = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>''';
