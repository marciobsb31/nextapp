import 'package:flutter/material.dart';

class CurvedBottomClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 36);

    // Curva suave côncava/convexa conforme inspiração
    final firstControlPoint = Offset(size.width / 2, size.height + 14);
    final firstEndPoint = Offset(size.width, size.height - 36);

    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class CurvedAuthHeader extends StatelessWidget {
  final Widget child;
  final double height;
  final Color backgroundColor;

  const CurvedAuthHeader({
    super.key,
    required this.child,
    this.height = 230,
    this.backgroundColor = const Color(0xFF091A2F),
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: CurvedBottomClipper(),
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: backgroundColor,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF071426),
              Color(0xFF0C233F),
              Color(0xFF08182B),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}
