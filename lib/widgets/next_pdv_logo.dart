import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';

/// Emblema e Logo Oficial NextPDV
/// Inspirado na identidade visual com o totem/smartphone e as setas dinâmicas em 'X'
class NextPdvLogo extends StatelessWidget {
  final double iconSize;
  final double fontSize;
  final bool showBadge;
  final bool showSubtitle;
  final Color? textColor;
  final bool isDarkBackground;
  final bool useAssetImage;

  const NextPdvLogo({
    super.key,
    this.iconSize = 54,
    this.fontSize = 24,
    this.showBadge = true,
    this.showSubtitle = true,
    this.textColor,
    this.isDarkBackground = false,
    this.useAssetImage = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (useAssetImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/nextpdv_logo.jpg',
              height: iconSize * 1.5,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildVectorEmblem(),
            ),
          )
        else
          _buildVectorEmblem(),
        const SizedBox(height: 10),

        // Tipografia NEXTPDV Oficial
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'NEXT',
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: isDarkBackground ? Colors.white : (textColor ?? const Color(0xFF0A2342)),
              ),
            ),
            Text(
              'PDV',
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: AppColors.primaryOrange,
              ),
            ),
          ],
        ),

        if (showSubtitle) ...[
          const SizedBox(height: 4),
          Text(
            'Mercado Autônomo & Smart Access',
            style: GoogleFonts.poppins(
              fontSize: (fontSize * 0.44).clamp(11.0, 13.0),
              fontWeight: FontWeight.w600,
              color: isDarkBackground ? const Color(0xFF94A3B8) : AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVectorEmblem() {
    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base/Totem Smartphone Kiosk
          Container(
            width: iconSize * 0.55,
            height: iconSize * 0.85,
            decoration: BoxDecoration(
              border: Border.all(
                color: isDarkBackground ? Colors.white70 : const Color(0xFF0A2342),
                width: 2.8,
              ),
              borderRadius: BorderRadius.circular(iconSize * 0.14),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: iconSize * 0.22,
                height: 2.5,
                margin: const EdgeInsets.only(bottom: 3),
                decoration: BoxDecoration(
                  color: isDarkBackground ? Colors.white60 : const Color(0xFF0A2342),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Seta Inferior Esquerda (Azul Escuro / Ciano)
          Positioned(
            left: 2,
            bottom: iconSize * 0.16,
            child: Icon(
              LucideIcons.cornerDownLeft,
              size: iconSize * 0.52,
              color: isDarkBackground ? const Color(0xFF38BDF8) : const Color(0xFF0A2342),
            ),
          ),

          // Seta Superior Direita (Laranja Vibrante)
          Positioned(
            right: 0,
            top: 0,
            child: Transform.rotate(
              angle: 0.78,
              child: const Icon(
                LucideIcons.arrowUpRight,
                size: 28,
                color: AppColors.primaryOrange,
              ),
            ),
          ),

          // Centro dinâmico
          Container(
            width: iconSize * 0.28,
            height: iconSize * 0.28,
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class NextPdvInlineBrand extends StatelessWidget {
  final double height;
  final bool showLojaBadge;
  final String? lojaNome;

  const NextPdvInlineBrand({
    super.key,
    this.height = 32,
    this.showLojaBadge = false,
    this.lojaNome,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Emblema Compacto
        Container(
          width: height,
          height: height,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryOrange.withValues(alpha: 0.12),
          ),
          child: Center(
            child: Icon(
              LucideIcons.scanLine,
              color: AppColors.primaryOrange,
              size: height * 0.55,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'NEXT',
          style: GoogleFonts.poppins(
            fontSize: height * 0.56,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: isDark ? Colors.white : const Color(0xFF0A2342),
          ),
        ),
        Text(
          'PDV',
          style: GoogleFonts.poppins(
            fontSize: height * 0.56,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
            color: AppColors.primaryOrange,
          ),
        ),
        if (showLojaBadge &&
            lojaNome != null &&
            !RegExp(r'loja\s*#', caseSensitive: false).hasMatch(lojaNome!)) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.building2, size: 12, color: AppColors.primaryOrange),
                const SizedBox(width: 4),
                Text(
                  lojaNome!,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.navyDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
