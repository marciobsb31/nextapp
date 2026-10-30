import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class SmartAccessButton extends StatefulWidget {
  final VoidCallback onTap;
  final double size;
  final bool showBadgeNotice;

  const SmartAccessButton({
    super.key,
    required this.onTap,
    this.size = 86,
    this.showBadgeNotice = false,
  });

  @override
  State<SmartAccessButton> createState() => _SmartAccessButtonState();
}

class _SmartAccessButtonState extends State<SmartAccessButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    // Efeito de escaneamento com linha descendo e subindo induzindo ao escaneamento
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double iconBoxSize = widget.size * 0.42;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.orangeGradient,
            border: Border.all(color: Colors.white, width: 3.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryOrange.withOpacity(0.45),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              splashColor: Colors.white.withOpacity(0.3),
              onTap: widget.onTap,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Área de escaneamento a laser
                    SizedBox(
                      width: iconBoxSize,
                      height: iconBoxSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner_rounded,
                            color: Colors.white,
                            size: widget.size * 0.38,
                          ),
                          AnimatedBuilder(
                            animation: _scanAnimation,
                            builder: (context, _) {
                              final topPos = 4.0 + (_scanAnimation.value * (iconBoxSize - 12.0));
                              return Positioned(
                                top: topPos,
                                left: 2,
                                right: 2,
                                child: Container(
                                  height: 2.2,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Color(0xFF00FFCC), // Ciano neon / laser de escaneamento
                                        Colors.white,
                                        Color(0xFF00FFCC),
                                        Colors.transparent,
                                      ],
                                      stops: [0.0, 0.15, 0.5, 0.85, 1.0],
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0xFF00FFCC),
                                        blurRadius: 5,
                                        spreadRadius: 1,
                                      ),
                                      BoxShadow(
                                        color: Colors.white,
                                        blurRadius: 2,
                                        spreadRadius: 0.5,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ABRIR\nPORTA',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: widget.size * 0.12,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.showBadgeNotice) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.navyDark.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Smart Access • Apenas para cadastrados',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.primaryOrange,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
