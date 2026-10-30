import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EntradaSuave extends StatelessWidget {
  const EntradaSuave({super.key, required this.indice, required this.child});

  final int indice;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduzido = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduzido ? 1 : 0, end: 1),
      duration: Duration(milliseconds: reduzido ? 1 : 380 + indice * 55),
      curve: Curves.easeOutBack,
      builder: (context, valor, child) {
        final progresso = valor.clamp(0.0, 1.0);
        return Opacity(
          opacity: progresso,
          child: Transform.translate(
            offset: Offset(0, (1 - progresso) * 18),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class AvisoAnimado extends StatelessWidget {
  const AvisoAnimado({super.key, required this.texto, this.erro = false});

  final String texto;
  final bool erro;

  @override
  Widget build(BuildContext context) {
    final cor = erro ? const Color(0xFFB42318) : const Color(0xFF127A34);
    final fundo = erro ? const Color(0xFFFFF1F0) : const Color(0xFFE9F8EE);
    return EntradaSuave(
      indice: 0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: fundo,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cor.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(erro ? Icons.error_outline : Icons.check_circle_outline, color: cor),
            const SizedBox(width: 10),
            Expanded(child: Text(texto, style: TextStyle(color: cor, height: 1.35))),
          ],
        ),
      ),
    );
  }
}

Future<void> vibrarErro() async {
  await HapticFeedback.heavyImpact();
  await Future<void>.delayed(const Duration(milliseconds: 40));
  await HapticFeedback.heavyImpact();
}
