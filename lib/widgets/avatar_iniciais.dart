import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Avatar de quem ainda não pôs foto: as iniciais do nome sobre o azul do app.
class AvatarIniciais extends StatelessWidget {
  const AvatarIniciais({super.key, required this.iniciais, this.tamanho = 40});

  final String iniciais;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanho,
      height: tamanho,
      alignment: Alignment.center,
      decoration: const BoxDecoration(gradient: AppColors.cardNavyGradient),
      child: Text(
        iniciais,
        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: tamanho * 0.36),
      ),
    );
  }
}
