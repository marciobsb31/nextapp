import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';

class Card3DMockup extends StatefulWidget {
  final String cardNumber;
  final String cardHolderName;
  final String expiryDate;
  final String cvv;
  final String brand;
  final LinearGradient? gradient;

  const Card3DMockup({
    super.key,
    required this.cardNumber,
    required this.cardHolderName,
    required this.expiryDate,
    required this.cvv,
    this.brand = 'mastercard',
    this.gradient,
  });

  @override
  State<Card3DMockup> createState() => _Card3DMockupState();
}

class _Card3DMockupState extends State<Card3DMockup> {
  double _rotateX = 0.05;
  double _rotateY = -0.05;

  String _formatCardNumber(String raw) {
    final clean = raw.replaceAll(' ', '');
    final padded = clean.padRight(16, '•');
    return '${padded.substring(0, 4)}  ${padded.substring(4, 8)}  ${padded.substring(8, 12)}  ${padded.substring(12, 16)}';
  }

  Widget _buildBrandLogo(String brand) {
    switch (brand.toLowerCase()) {
      case 'visa':
        return Text(
          'VISA',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 22,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        );
      case 'elo':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
            ),
            Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.amber),
            ),
            Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.blue),
            ),
          ],
        );
      case 'mastercard':
      default:
        return Stack(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withOpacity(0.9),
              ),
            ),
            Positioned(
              left: 14,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withOpacity(0.85),
                ),
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardGradient = widget.gradient ?? AppColors.cardNavyGradient;

    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _rotateY += details.delta.dx * 0.003;
          _rotateX -= details.delta.dy * 0.003;
          _rotateX = _rotateX.clamp(-0.15, 0.15);
          _rotateY = _rotateY.clamp(-0.15, 0.15);
        });
      },
      onPanEnd: (_) {
        setState(() {
          _rotateX = 0.04;
          _rotateY = -0.04;
        });
      },
      child: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0015) // Efeito de perspectiva 3D
          ..rotateX(_rotateX)
          ..rotateY(_rotateY),
        alignment: FractionalOffset.center,
        child: Container(
          width: double.infinity,
          height: 210,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            gradient: cardGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.navyDark.withOpacity(0.35),
                blurRadius: 28,
                spreadRadius: 2,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Shimmer / Gloss reflexo translúcido no canto superior direito
              Positioned(
                top: -60,
                right: -40,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.18),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Conteúdo do Cartão
              Padding(
                padding: const EdgeInsets.all(22.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top row: Chip EMV + NFC + Marca
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            // Chip metálico dourado
                            Container(
                              width: 44,
                              height: 32,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Container(
                                      width: 20,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.black26),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              LucideIcons.wifi,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ],
                        ),
                        _buildBrandLogo(widget.brand),
                      ],
                    ),

                    // Número do Cartão
                    Text(
                      _formatCardNumber(widget.cardNumber),
                      style: GoogleFonts.robotoMono(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),

                    // Informações inferiores: Nome, Validade, CVV
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TITULAR',
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.cardHolderName.isEmpty
                                    ? 'NOME DO TITULAR'
                                    : widget.cardHolderName.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'VALIDADE',
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.expiryDate.isEmpty ? 'MM/AA' : widget.expiryDate,
                              style: GoogleFonts.robotoMono(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
