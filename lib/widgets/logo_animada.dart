import 'package:flutter/material.dart';

/// Logo do NextPDV sem fundo, com entrada suave, flutuação leve e um brilho
/// que atravessa a marca de tempos em tempos.
///
/// `clara: true` usa a versão com o azul-marinho em branco, para fundos escuros.
class LogoAnimada extends StatefulWidget {
  const LogoAnimada({super.key, this.largura = 190, this.clara = true});

  final double largura;
  final bool clara;

  @override
  State<LogoAnimada> createState() => _LogoAnimadaState();
}

class _LogoAnimadaState extends State<LogoAnimada> with TickerProviderStateMixin {
  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _ciclo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  // Três ciclos de brilho e flutuação depois da entrada; parada, a logo não gasta bateria.
  static const _ciclos = 3;
  int _feitos = 0;

  @override
  void initState() {
    super.initState();
    _ciclo.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      _feitos++;
      if (_feitos < _ciclos) _ciclo.forward(from: 0);
    });
    _entrada.forward().whenComplete(() {
      if (mounted) _ciclo.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _entrada.dispose();
    _ciclo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduzido = MediaQuery.disableAnimationsOf(context);
    final imagem = Image.asset(
      widget.clara ? 'assets/images/nextpdv_logo_claro.png' : 'assets/images/nextpdv_logo_sem_fundo.png',
      width: widget.largura,
      fit: BoxFit.contain,
      semanticLabel: 'NextPDV',
    );
    if (reduzido) return imagem;

    return AnimatedBuilder(
      animation: Listenable.merge([_entrada, _ciclo]),
      builder: (context, child) {
        final entrada = Curves.easeOutBack.transform(_entrada.value);
        final t = _ciclo.isCompleted ? 0.0 : _ciclo.value;
        // Flutua 4 px para cima e para baixo durante o ciclo.
        final flutua = (1 - (2 * t - 1).abs()) * 2 - 1;
        // O brilho cruza a logo no primeiro terço do ciclo e some no resto.
        final brilho = (t * 3).clamp(0.0, 1.0);
        return Opacity(
          opacity: _entrada.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -4 * flutua),
            child: Transform.scale(
              scale: 0.7 + 0.3 * entrada,
              child: ShaderMask(
                blendMode: BlendMode.srcATop,
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: brilho < 1 ? 0.55 : 0),
                    Colors.white.withValues(alpha: 0),
                  ],
                  stops: [
                    (brilho - 0.25).clamp(0.0, 1.0),
                    brilho,
                    (brilho + 0.25).clamp(0.0, 1.0),
                  ],
                ).createShader(rect),
                child: child,
              ),
            ),
          ),
        );
      },
      child: imagem,
    );
  }
}
