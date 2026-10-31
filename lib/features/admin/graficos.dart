import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/tema.dart';
import '../../core/util/dinheiro.dart';

/// Gráficos leves da gestão, desenhados no próprio app (sem biblioteca externa).

/// Barras verticais (faturamento por dia ou por hora). Toque numa barra para ver o valor.
class GraficoBarras extends StatefulWidget {
  const GraficoBarras({super.key, required this.valores, required this.rotulos, this.altura = 170});

  final List<double> valores;
  final List<String> rotulos;
  final double altura;

  @override
  State<GraficoBarras> createState() => _GraficoBarrasState();
}

class _GraficoBarrasState extends State<GraficoBarras> {
  int? _tocada;

  @override
  Widget build(BuildContext context) {
    final valores = widget.valores;
    final maximo = valores.isEmpty ? 0.0 : valores.reduce(math.max);
    final selecionada = _tocada != null && _tocada! < valores.length ? _tocada : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 20,
          child: Text(
            selecionada == null
                ? (maximo > 0 ? 'Maior: ${reaisBr(maximo)}' : 'Sem vendas no período')
                : '${widget.rotulos[selecionada]} · ${reaisBr(valores[selecionada])}',
            style: const TextStyle(fontSize: 12, color: Cores.tinta, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: widget.altura,
          child: LayoutBuilder(
            builder: (context, caixa) {
              final n = math.max(valores.length, 1);
              final passo = caixa.maxWidth / n;
              return GestureDetector(
                onTapDown: (d) => setState(() => _tocada = (d.localPosition.dx / passo).floor().clamp(0, n - 1)),
                onHorizontalDragUpdate: (d) => setState(() => _tocada = (d.localPosition.dx / passo).floor().clamp(0, n - 1)),
                child: CustomPaint(
                  size: Size(caixa.maxWidth, widget.altura),
                  painter: _PintorBarras(valores, maximo, selecionada, Cores.laranja, Cores.suave),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        _eixo(),
      ],
    );
  }

  /// Só alguns rótulos no eixo para não embolar.
  Widget _eixo() {
    final n = widget.rotulos.length;
    if (n == 0) return const SizedBox.shrink();
    final indices = n <= 7 ? List.generate(n, (i) => i) : [0, n ~/ 4, n ~/ 2, (n * 3) ~/ 4, n - 1];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final i in indices.toSet())
          Text(widget.rotulos[i], style: const TextStyle(fontSize: 10, color: Cores.tinta)),
      ],
    );
  }
}

class _PintorBarras extends CustomPainter {
  _PintorBarras(this.valores, this.maximo, this.selecionada, this.cor, this.fundo);

  final List<double> valores;
  final double maximo;
  final int? selecionada;
  final Color cor;
  final Color fundo;

  @override
  void paint(Canvas canvas, Size size) {
    final guia = Paint()
      ..color = Cores.linha
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guia);
    }
    if (valores.isEmpty) return;
    final passo = size.width / valores.length;
    final largura = math.max(2.0, passo * 0.62);
    for (var i = 0; i < valores.length; i++) {
      final altura = maximo <= 0 ? 0.0 : (valores[i] / maximo) * (size.height - 4);
      final x = i * passo + (passo - largura) / 2;
      final barra = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, size.height - math.max(altura, 2), largura, math.max(altura, 2)),
        topLeft: Radius.circular(largura / 3),
        topRight: Radius.circular(largura / 3),
      );
      final destaque = selecionada == null || selecionada == i;
      canvas.drawRRect(barra, Paint()..color = altura <= 0 ? fundo : (destaque ? cor : cor.withValues(alpha: 0.35)));
    }
  }

  @override
  bool shouldRepaint(_PintorBarras antigo) =>
      antigo.valores != valores || antigo.selecionada != selecionada || antigo.maximo != maximo || antigo.cor != cor;
}

/// Rosca com a participação de cada parte (formas de pagamento) e a legenda ao lado.
class GraficoRosca extends StatelessWidget {
  const GraficoRosca({super.key, required this.fatias});

  final List<({String rotulo, double valor, Color cor})> fatias;

  @override
  Widget build(BuildContext context) {
    final total = fatias.fold<double>(0, (s, f) => s + f.valor);
    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _PintorRosca(fatias, total),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Total', style: TextStyle(fontSize: 11, color: Cores.tinta)),
                FittedBox(child: Text(reaisBr(total), style: const TextStyle(fontWeight: FontWeight.w700, color: Cores.marinho))),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final f in fatias)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: f.cor, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f.rotulo, style: const TextStyle(fontSize: 13, color: Cores.marinho))),
                    Text(total <= 0 ? '0%' : '${(f.valor * 100 / total).round()}%',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Cores.marinho)),
                  ]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PintorRosca extends CustomPainter {
  _PintorRosca(this.fatias, this.total);

  final List<({String rotulo, double valor, Color cor})> fatias;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    final espessura = size.width * 0.16;
    final area = Rect.fromLTWH(espessura / 2, espessura / 2, size.width - espessura, size.height - espessura);
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = espessura;
    if (total <= 0) {
      canvas.drawArc(area, 0, math.pi * 2, false, pincel..color = Cores.linha);
      return;
    }
    var inicio = -math.pi / 2;
    for (final f in fatias) {
      final arco = math.pi * 2 * f.valor / total;
      canvas.drawArc(area, inicio, math.max(arco - 0.03, 0.01), false, pincel..color = f.cor);
      inicio += arco;
    }
  }

  @override
  bool shouldRepaint(_PintorRosca antigo) => antigo.fatias != fatias || antigo.total != total;
}

/// Barras horizontais (ranking dos mais vendidos).
class BarrasHorizontais extends StatelessWidget {
  const BarrasHorizontais({super.key, required this.itens});

  final List<({String rotulo, double valor, String detalhe})> itens;

  @override
  Widget build(BuildContext context) {
    final maximo = itens.isEmpty ? 0.0 : itens.map((i) => i.valor).reduce(math.max);
    return Column(
      children: [
        for (final item in itens)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(item.rotulo, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Cores.marinho)),
                  ),
                  Text(item.detalhe, style: const TextStyle(fontSize: 12, color: Cores.tinta)),
                ]),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: maximo <= 0 ? 0 : item.valor / maximo,
                    minHeight: 8,
                    backgroundColor: Cores.suave,
                    color: Cores.laranja,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Cores das fatias: tons do laranja da casa e o azul do app.
List<Color> coresDosGraficos() => [
      Cores.laranja,
      Cores.marinho,
      const Color(0xFFFDBA74),
      const Color(0xFF64748B),
      const Color(0xFFC2410C),
      const Color(0xFFCBD5E1),
    ];
