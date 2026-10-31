import 'package:flutter/material.dart';

import '../../app/entrada.dart';
import '../../app/tema.dart';

/// Peças comuns das telas de gestão do app (mesmo visual do painel do lojista).

List<Map<String, dynamic>> mapas(Object? valor) {
  if (valor is! List) return const [];
  return [for (final item in valor) if (item is Map) Map<String, dynamic>.from(item)];
}

/// "2026-10-31T14:05:00" → "31/10 14:05"; "2026-10-31" → "31/10/2026".
String dataCurta(Object? valor) {
  final texto = valor?.toString() ?? '';
  final data = DateTime.tryParse(texto);
  if (data == null) return texto;
  String dois(int n) => n.toString().padLeft(2, '0');
  if (texto.length <= 10) return '${dois(data.day)}/${dois(data.month)}/${data.year}';
  return '${dois(data.day)}/${dois(data.month)} ${dois(data.hour)}:${dois(data.minute)}';
}

String dataIso(DateTime data) =>
    '${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';

class TelaGestao extends StatelessWidget {
  const TelaGestao({super.key, required this.titulo, required this.corpo, this.acoes, this.botao});

  final String titulo;
  final Widget corpo;
  final List<Widget>? acoes;
  final Widget? botao;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.fundo,
      appBar: AppBar(
        backgroundColor: Cores.fundo,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Cores.marinho,
        elevation: 0,
        titleSpacing: 4,
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: Cores.marinho)),
        actions: acoes,
      ),
      floatingActionButton: botao,
      body: SafeArea(child: corpo),
    );
  }
}

/// Ícone dentro do quadrado arredondado, como nos cartões do app do cliente.
class IconeGestao extends StatelessWidget {
  const IconeGestao(this.icone, {super.key, this.cor});

  final IconData icone;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final tom = cor ?? Cores.laranja;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: tom.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
      child: Icon(icone, color: tom, size: 22),
    );
  }
}

class CartaoGestao extends StatelessWidget {
  const CartaoGestao({
    super.key,
    required this.titulo,
    this.detalhe,
    this.valor,
    this.icone = Icons.receipt_long_outlined,
    this.corIcone,
    this.aoTocar,
    this.fim,
  });

  final String titulo;
  final String? detalhe;
  final String? valor;
  final IconData icone;
  final Color? corIcone;
  final VoidCallback? aoTocar;
  final Widget? fim;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: cartaoApp(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(Cores.raio),
          onTap: aoTocar,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                IconeGestao(icone, cor: corIcone),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Cores.marinho, fontSize: 15)),
                      if (detalhe != null && detalhe!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(detalhe!, style: const TextStyle(color: Cores.tinta, fontSize: 12, height: 1.3)),
                      ],
                    ],
                  ),
                ),
                if (fim != null || valor != null) const SizedBox(width: 8),
                fim ?? (valor == null ? const SizedBox.shrink() : Text(valor!, style: const TextStyle(fontWeight: FontWeight.w700, color: Cores.marinho))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Indicador extends StatelessWidget {
  const Indicador({super.key, required this.rotulo, required this.valor, this.cor = Cores.marinho});

  final String rotulo;
  final String valor;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: cartaoApp(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rotulo, style: const TextStyle(color: Cores.tinta, fontSize: 12)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(valor, style: TextStyle(fontWeight: FontWeight.w700, color: cor, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado comum: carregando, erro ou lista vazia.
class EstadoLista extends StatelessWidget {
  const EstadoLista({super.key, required this.carregando, this.erro, required this.vazia, required this.textoVazio});

  final bool carregando;
  final String? erro;
  final bool vazia;
  final String textoVazio;

  @override
  Widget build(BuildContext context) {
    if (carregando) return const Padding(padding: EdgeInsets.only(bottom: 12), child: LinearProgressIndicator());
    if (erro != null) return Padding(padding: const EdgeInsets.only(bottom: 12), child: AvisoAnimado(texto: erro!, erro: true));
    if (vazia) return Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(textoVazio, style: const TextStyle(color: Cores.tinta))));
    return const SizedBox.shrink();
  }
}

void avisar(BuildContext context, String mensagem, {bool erro = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: erro ? Cores.erro : Cores.sucesso));
}

class EscolhaPeriodo extends StatelessWidget {
  const EscolhaPeriodo({super.key, required this.dias, required this.aoEscolher});

  final int dias;
  final ValueChanged<int> aoEscolher;

  @override
  Widget build(BuildContext context) {
    return Pilulas<int>(
      valor: dias,
      opcoes: const [(1, 'Hoje'), (7, '7 dias'), (30, '30 dias')],
      aoEscolher: aoEscolher,
    );
  }
}

/// Seletor em pílulas do app: trilho branco com sombra e a opção ativa no gradiente da marca.
class Pilulas<T> extends StatelessWidget {
  const Pilulas({super.key, required this.valor, required this.opcoes, required this.aoEscolher});

  final T valor;
  final List<(T, String)> opcoes;
  final ValueChanged<T> aoEscolher;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Cores.cartao, borderRadius: BorderRadius.circular(30), boxShadow: Cores.sombra),
      child: Row(
        children: [
          for (final opcao in opcoes)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => aoEscolher(opcao.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: valor == opcao.$1 ? Cores.gradienteMarca : null,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: valor == opcao.$1 ? Cores.brilhoMarca : null,
                  ),
                  child: Text(
                    opcao.$2,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: valor == opcao.$1 ? Colors.white : Cores.tinta,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
