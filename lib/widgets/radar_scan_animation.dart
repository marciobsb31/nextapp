import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';

class RadarScanAnimation extends StatefulWidget {
  final String statusText;
  final String subText;

  const RadarScanAnimation({
    super.key,
    this.statusText = 'Validando Acesso Smart...',
    this.subText = 'Criptografia ponta a ponta e token do condomínio',
  });

  @override
  State<RadarScanAnimation> createState() => _RadarScanAnimationState();
}

class _RadarScanAnimationState extends State<RadarScanAnimation>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ondas concêntricas de radar
              AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(240, 240),
                    painter: _RadarWavePainter(
                      progress: _waveController.value,
                      sweepAngle: _sweepController.value * 2 * math.pi,
                    ),
                  );
                },
              ),

              // Núcleo central pulsante de segurança
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.orangeGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withOpacity(0.55),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.shieldCheck,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          widget.statusText,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.navyDark,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            widget.subText,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _RadarWavePainter extends CustomPainter {
  final double progress;
  final double sweepAngle;

  _RadarWavePainter({required this.progress, required this.sweepAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Círculos concêntricos fixos
    final linePaint = Paint()
      ..color = AppColors.primaryOrange.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, (maxRadius / 3) * i, linePaint);
    }

    // Ondas expansivas em pulso
    for (int i = 0; i < 2; i++) {
      final currentProgress = (progress + (i * 0.5)) % 1.0;
      final currentRadius = currentProgress * maxRadius;
      final opacity = (1.0 - currentProgress) * 0.45;

      final wavePaint = Paint()
        ..color = AppColors.primaryOrange.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, currentRadius, wavePaint);
    }

    // Varredura de radar (Sweep)
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: FractionalOffset.center,
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          AppColors.primaryOrange.withOpacity(0.0),
          AppColors.primaryOrange.withOpacity(0.25),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(sweepAngle);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: maxRadius),
      0,
      math.pi / 2,
      true,
      sweepPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RadarWavePainter oldDelegate) => true;
}
