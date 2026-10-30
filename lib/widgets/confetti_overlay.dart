import 'dart:math' as math;
import 'package:flutter/material.dart';

class ConfettiOverlay extends StatefulWidget {
  final Widget child;

  const ConfettiOverlay({super.key, required this.child});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ConfettiParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..forward();

    // Gerar 60 partículas coloridas
    final colors = [
      const Color(0xFFFF6B00),
      const Color(0xFFFF8C00),
      const Color(0xFF10B981),
      const Color(0xFF3B82F6),
      const Color(0xFFFFD700),
      const Color(0xFF8B5CF6),
    ];

    for (int i = 0; i < 70; i++) {
      _particles.add(
        _ConfettiParticle(
          x: _random.nextDouble(),
          y: -_random.nextDouble() * 0.4,
          speed: 0.25 + _random.nextDouble() * 0.5,
          angle: _random.nextDouble() * math.pi * 2,
          rotationSpeed: (_random.nextDouble() - 0.5) * 8,
          size: 6 + _random.nextDouble() * 6,
          color: colors[_random.nextInt(colors.length)],
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _ConfettiPainter(
                  progress: _controller.value,
                  particles: _particles,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ConfettiParticle {
  double x;
  double y;
  double speed;
  double angle;
  double rotationSpeed;
  double size;
  Color color;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.angle,
    required this.rotationSpeed,
    required this.size,
    required this.color,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiParticle> particles;

  _ConfettiPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final currentY = (p.y + progress * p.speed * 1.5) * size.height;
      if (currentY > size.height) continue;

      final currentX = (p.x * size.width) + math.sin(progress * 4 + p.angle) * 35;
      final currentAngle = p.angle + progress * p.rotationSpeed;

      final paint = Paint()
        ..color = p.color.withOpacity((1.0 - (progress * 0.8)).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(currentAngle);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
