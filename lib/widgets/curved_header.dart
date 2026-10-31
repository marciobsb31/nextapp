import 'package:flutter/material.dart';

/// Cabeçalho azul das telas de acesso: topo reto, colado na borda da tela.
///
/// Embaixo, por padrão, só os cantos arredondados. Com [curvaInvertida], a borda de baixo
/// vira um arco côncavo: as pontas descem e o meio sobe [profundidade] pixels.
class CurvedAuthHeader extends StatelessWidget {
  final Widget child;
  final double height;
  final double raio;
  final bool curvaInvertida;
  final double profundidade;

  const CurvedAuthHeader({
    super.key,
    required this.child,
    this.height = 230,
    this.raio = 32,
    this.curvaInvertida = false,
    this.profundidade = 44,
  });

  static const _gradiente = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF071426),
      Color(0xFF0C233F),
      Color(0xFF08182B),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (curvaInvertida) {
      return ClipPath(
        clipper: _ArcoConcavo(profundidade),
        child: Container(
          width: double.infinity,
          height: height,
          decoration: const BoxDecoration(gradient: _gradiente),
          padding: EdgeInsets.only(bottom: profundidade),
          child: child,
        ),
      );
    }
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(raio)),
        gradient: _gradiente,
      ),
      child: child,
    );
  }
}

class _ArcoConcavo extends CustomClipper<Path> {
  const _ArcoConcavo(this.profundidade);

  final double profundidade;

  @override
  Path getClip(Size size) {
    final h = size.height;
    final w = size.width;
    // A curva quadrática passa pelo meio na altura h - profundidade.
    return Path()
      ..lineTo(w, 0)
      ..lineTo(w, h)
      ..quadraticBezierTo(w / 2, h - profundidade * 2, 0, h)
      ..close();
  }

  @override
  bool shouldReclip(_ArcoConcavo antigo) => antigo.profundidade != profundidade;
}
