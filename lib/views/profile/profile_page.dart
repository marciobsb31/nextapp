import 'dart:convert';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../controllers/auth_controller.dart';
import '../../core/rede/falha_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_bell_notification.dart';
import '../../widgets/product_image.dart';
import '../support/help_support_page.dart';

class ProfilePage extends StatefulWidget {
  final AuthController authController;
  final VoidCallback onLogout;

  const ProfilePage({
    super.key,
    required this.authController,
    required this.onLogout,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Widget _buildAvatarImage(String url, {double size = 90}) {
    if (url.startsWith('data:image')) {
      try {
        final base64Data = url.split(',').last;
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      } catch (_) {}
    }
    return Image.network(
      ProductImage.formatProxyUrl(url),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: AppColors.navyDark,
        child: Icon(LucideIcons.user, color: Colors.white, size: size * 0.45),
      ),
    );
  }

  void _abrirModalTrocaFoto() {
    XFile? arquivoSelecionado;
    Uint8List? bytesSelecionados;
    String? mensagemErro;
    var enviando = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final imagemPreview = bytesSelecionados;
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 18,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
              ),
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
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Enviar nova foto',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.navyDark,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primaryOrange,
                            width: 3,
                          ),
                        ),
                        child: imagemPreview == null
                            ? _buildAvatarImage(
                                widget.authController.avatarUrl,
                                size: 80,
                              )
                            : Image.memory(
                                imagemPreview,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      arquivoSelecionado?.name ??
                          'JPG ou PNG · até 5 MB',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (mensagemErro != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        mensagemErro!,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFB42318),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: enviando
                            ? null
                            : () async {
                                final arquivo = await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 1200,
                                  imageQuality: 85,
                                );
                                if (arquivo == null || !ctx.mounted) return;
                                final extensao = arquivo.name
                                    .split('.')
                                    .last
                                    .toLowerCase();
                                if (!{'jpg', 'jpeg', 'png'}.contains(extensao)) {
                                  setModalState(() {
                                    mensagemErro =
                                        'Selecione uma imagem JPG ou PNG.';
                                  });
                                  return;
                                }
                                final bytes = await arquivo.readAsBytes();
                                if (!ctx.mounted) return;
                                if (bytes.length > 5 * 1024 * 1024) {
                                  setModalState(() {
                                    mensagemErro =
                                        'A foto pode ter até 5 MB.';
                                  });
                                  return;
                                }
                                setModalState(() {
                                  arquivoSelecionado = arquivo;
                                  bytesSelecionados = bytes;
                                  mensagemErro = null;
                                });
                              },
                        icon: const Icon(LucideIcons.image),
                        label: const Text('Escolher foto'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: enviando ||
                                arquivoSelecionado == null ||
                                bytesSelecionados == null
                            ? null
                            : () async {
                                final arquivo = arquivoSelecionado!;
                                final bytes = bytesSelecionados!;
                                setModalState(() {
                                  enviando = true;
                                  mensagemErro = null;
                                });
                                try {
                                  await widget.authController.enviarFotoPerfil(
                                    bytes: bytes,
                                    nomeArquivo: arquivo.name,
                                  );
                                  if (!ctx.mounted) return;
                                  Navigator.of(ctx).pop();
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Foto do perfil atualizada.',
                                      ),
                                      backgroundColor: Color(0xFF2E7D32),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } catch (erro) {
                                  if (!ctx.mounted) return;
                                  setModalState(() {
                                    mensagemErro = falhaDe(erro).mensagem;
                                  });
                                } finally {
                                  if (ctx.mounted) {
                                    setModalState(() => enviando = false);
                                  }
                                }
                              },
                        icon: enviando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(LucideIcons.upload),
                        label: Text(enviando ? 'Enviando...' : 'Salvar foto'),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Meu Perfil & Condomínio',
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : AppColors.navyDark,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // ==========================================
              // CARD DO MORADOR COM SININHO ANIMADO À ESQUERDA DA FOTO
              // ==========================================
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardSurfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppColors.cardShadow,
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : Colors.transparent,
                  ),
                ),
                child: Column(
                  children: [
                    // Linha da Foto com Sininho Animado à Esquerda da Foto
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Sininho animado quando houver notificações ao lado esquerdo da foto
                        AnimatedBellNotification(
                          unreadCount:
                              widget.authController.unreadNotifications,
                          onClearNotifications: () =>
                              widget.authController.clearNotifications(),
                        ),
                        const SizedBox(width: 8),

                        // Foto de Perfil com Botão de Câmera
                        GestureDetector(
                          onTap: _abrirModalTrocaFoto,
                          child: Stack(
                            children: [
                              Container(
                                width: 86,
                                height: 86,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primaryOrange,
                                    width: 3,
                                  ),
                                ),
                                child: _buildAvatarImage(
                                  widget.authController.avatarUrl,
                                  size: 86,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryOrange,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    LucideIcons.camera,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: _abrirModalTrocaFoto,
                      icon: const Icon(
                        LucideIcons.camera,
                        size: 14,
                        color: AppColors.primaryOrange,
                      ),
                      label: Text(
                        'Trocar Foto do App',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.authController.userName,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.navyDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.authController.userEmail,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.building2,
                                color: AppColors.primaryOrange,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${widget.authController.condoName} • ${widget.authController.unit}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.navyDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'CEP: ${widget.authController.cep} • Raio: ${widget.authController.unidadeAtual.distanciaFormatada} (Autorizado)',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ==========================================
              // MUDANÇA DE TEMA PARA ESCURO / CLARO
              // ==========================================
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardSurfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppColors.cardShadow,
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : Colors.transparent,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.authController.isDarkMode
                            ? LucideIcons.moon
                            : LucideIcons.sun,
                        color: AppColors.primaryOrange,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Tema do Aplicativo',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.navyDark,
                      ),
                    ),
                    subtitle: Text(
                      widget.authController.isDarkMode
                          ? 'Tema Escuro Ativado'
                          : 'Tema Claro Ativado',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: widget.authController.isDarkMode
                            ? AppColors.primaryOrange
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.authController.isDarkMode ? 'Escuro' : 'Claro',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: widget.authController.isDarkMode
                              ? Colors.white
                              : AppColors.navyDark,
                        ),
                      ),
                    ),
                    onTap: () {
                      widget.authController.toggleTheme();
                      setState(() {});
                    },
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ==========================================
              // ACORDEON DE CARTÕES & FORMAS DE PAGAMENTO
              // ==========================================
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardSurfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: AppColors.cardShadow,
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : Colors.transparent,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          LucideIcons.creditCard,
                          color: AppColors.primaryOrange,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Cartões & Formas de Pagamento',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.navyDark,
                        ),
                      ),
                      subtitle: Text(
                        'Veja como escolher e pagar seu pedido com segurança',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        Divider(
                          color: isDark
                              ? AppColors.borderDark
                              : Colors.grey.shade200,
                        ),
                        const SizedBox(height: 6),

                        // Informações de pagamento sem exibir dados fictícios de cartão ou saldo.
                        _buildPaymentCardItem(
                          title: 'Pix',
                          subtitle: 'Escolha Pix ao finalizar a compra. O QR Code ou código Copia e Cola é gerado para o pedido.',
                          badgeText: 'No checkout',
                          badgeColor: const Color(0xFF0D9488),
                          icon: LucideIcons.qrCode,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),
                        _buildPaymentCardItem(
                          title: 'Cartão',
                          subtitle: 'Os dados são informados na etapa de pagamento e processados pelo provedor. O app não mostra o número completo no perfil.',
                          badgeText: 'Seguro',
                          badgeColor: const Color(0xFF0284C7),
                          icon: LucideIcons.creditCard,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),

                        // Botão de Adicionar Nova Forma de Pagamento
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: AppColors.primaryOrange,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(
                              LucideIcons.plus,
                              size: 16,
                              color: AppColors.primaryOrange,
                            ),
                            label: Text(
                              'Ver opções de pagamento',
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryOrange,
                              ),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'As opções de pagamento aparecem ao finalizar uma compra.',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ==========================================
              // SMART ACCESS & SEGURANÇA (BOTÕES DE LIGA/DESLIGA TOTALMENTE OCULTOS!)
              // ==========================================
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardSurfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: AppColors.cardShadow,
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : Colors.transparent,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'Permissões & Credenciais de Acesso',
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppColors.navyDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Item 1: Smart Access Biométrico (Sem botão liga/desliga)
                      _buildStatusRow(
                        title: 'Smart Access Biométrico',
                        subtitle:
                            'Autenticação por FaceID e Biometria habilitada',
                        status: 'Ativo',
                        statusColor: AppColors.successGreen,
                        icon: LucideIcons.fingerprint,
                        isDark: isDark,
                      ),
                      Divider(
                        color: isDark
                            ? AppColors.borderDark
                            : Colors.grey.shade200,
                      ),

                      // Item 2: Verificação 18+ (Sem botão liga/desliga)
                      _buildStatusRow(
                        title: 'Maior de 18 Anos',
                        subtitle: widget.authController.isMaior18
                            ? 'Maioridade ativa: todas as categorias visíveis'
                            : 'Menor de 18 anos',
                        status: widget.authController.isMaior18
                            ? 'Verificado'
                            : 'Restrito',
                        statusColor: widget.authController.isMaior18
                            ? AppColors.successGreen
                            : Colors.grey,
                        icon: LucideIcons.wine,
                        isDark: isDark,
                      ),
                      Divider(
                        color: isDark
                            ? AppColors.borderDark
                            : Colors.grey.shade200,
                      ),

                      // Item 3: Permissão de Portas & Freezers (Sem botão liga/desliga)
                      _buildStatusRow(
                        title: 'Permissão Smart Access',
                        subtitle:
                            'Portas e freezers autorizados na unidade ativa',
                        status: 'Liberado',
                        statusColor: AppColors.successGreen,
                        icon: LucideIcons.qrCode,
                        isDark: isDark,
                      ),
                      Divider(
                        color: isDark
                            ? AppColors.borderDark
                            : Colors.grey.shade200,
                      ),

                      // Item 4: Notificações Push (Sem botão liga/desliga)
                      _buildStatusRow(
                        title: 'Notificações de Acesso & Compras',
                        subtitle:
                            'Alertas de compras e confirmação de destravamento',
                        status: 'Ativas',
                        statusColor: AppColors.successGreen,
                        icon: LucideIcons.bellRing,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ==========================================
              // OUTRAS OPÇÕES: AJUDA & SAIR
              // ==========================================
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardSurfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: AppColors.cardShadow,
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : Colors.transparent,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            LucideIcons.helpCircle,
                            color: AppColors.primaryOrange,
                          ),
                          title: Text(
                            'Ajuda & Perguntas Frequentes',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.navyDark,
                            ),
                          ),
                          trailing: const Icon(
                            LucideIcons.chevronRight,
                            size: 18,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HelpSupportPage(
                                  authController: widget.authController,
                                ),
                              ),
                            );
                          },
                        ),
                        Divider(
                          height: 1,
                          color: isDark
                              ? AppColors.borderDark
                              : Colors.grey.shade200,
                        ),
                        ListTile(
                          leading: const Icon(
                            LucideIcons.logOut,
                            color: Colors.redAccent,
                          ),
                          title: Text(
                            'Sair da Conta',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.redAccent,
                            ),
                          ),
                          onTap: widget.onLogout,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentCardItem({
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardSurfaceDarkSecondary
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryOrange, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.navyDark,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow({
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
    required IconData icon,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryOrange, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.navyDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.check, size: 12, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  status,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
