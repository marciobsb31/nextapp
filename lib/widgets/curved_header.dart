import 'package:flutter/material.dart';

/// Cabeçalho azul das telas de acesso: topo reto, colado na borda da tela,
/// e só os cantos de baixo arredondados.
class CurvedAuthHeader extends StatelessWidget {
  final Widget child;
  final double height;
  final double raio;

  const CurvedAuthHeader({
    super.key,
    required this.child,
    this.height = 230,
    this.raio = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(raio)),
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
    );
  }
}
