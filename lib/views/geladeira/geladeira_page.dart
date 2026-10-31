import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../controllers/cart_controller.dart';
import '../../core/rede/api.dart';
import '../../core/rede/falha_api.dart';
import '../../core/sessao/sessao.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../payment/payment_flow.dart';

/// Geladeira autônoma lida pelo QR: mostra os produtos da unidade dela, cobra
/// pelo PagSeguro e, pago o pedido, gera o QR que abre a porta no leitor.
class GeladeiraPage extends StatefulWidget {
  const GeladeiraPage({super.key, required this.sessao, required this.geladeiraId, this.api});

  final Sessao sessao;
  final int geladeiraId;
  final ApiPdv? api;

  @override
  State<GeladeiraPage> createState() => _GeladeiraPageState();
}

class _GeladeiraPageState extends State<GeladeiraPage> {
  late final ApiPdv _api = widget.api ?? ApiPdv.padrao();
  final CartController _carrinho = CartController();
  Map<String, dynamic>? _geladeira;
  List<Product> _produtos = [];
  String? _erro;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carrinho.addListener(() => setState(() {}));
    _carregar();
  }

  @override
  void dispose() {
    _carrinho.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final g = await _api.geladeira(widget.sessao, widget.geladeiraId);
      if (g['mesmaUnidade'] != true && g['lojaId'] is num) {
        // A compra entra na unidade da geladeira.
        await _api.trocarUnidade(widget.sessao, (g['lojaId'] as num).toInt());
      }
      final pagina = await _api.produtos(widget.sessao, tamanho: 200);
      final itens = (pagina['itens'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => Product.fromJson(Map<String, dynamic>.from(m)))
          .where((p) => p.disponivel)
          .toList();
      if (!mounted) return;
      setState(() {
        _geladeira = g;
        _produtos = itens;
        _carregando = false;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _erro = falhaDe(erro).mensagem;
        _carregando = false;
      });
    }
  }

  int _quantidade(Product p) =>
      _carrinho.items.where((i) => i.product.id == p.id).fold(0, (s, i) => s + i.quantity);

  void _pagar() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentFlow(
          cartController: _carrinho,
          sessao: widget.sessao,
          api: widget.api,
          semMaquininha: true,
          onFinishFlow: () => Navigator.popUntil(context, (r) => r.isFirst),
          aoAprovar: (ctx, vendaId) => Navigator.pushReplacement(
            ctx,
            MaterialPageRoute(
              builder: (_) => AberturaGeladeiraPage(
                sessao: widget.sessao,
                geladeiraId: widget.geladeiraId,
                vendaId: vendaId,
                api: widget.api,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = _geladeira;
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          (g?['nome'] ?? 'Geladeira').toString(),
          style: GoogleFonts.poppins(color: AppColors.navyDark, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: AppColors.navyDark),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.alertCircle, size: 42, color: Color(0xFFC62828)),
                        const SizedBox(height: 12),
                        Text(_erro!, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 13.5)),
                        TextButton(onPressed: _carregar, child: const Text('Tentar de novo')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Row(
                        children: [
                          Icon(LucideIcons.refrigerator, color: AppColors.primaryOrange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${g?['lojaNome'] ?? ''}${g?['online'] == true ? ' · online' : ' · sem conexão no momento'}',
                              style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _produtos.isEmpty
                          ? Center(child: Text('Nenhum produto disponível nesta geladeira agora.', style: GoogleFonts.poppins()))
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _produtos.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final p = _produtos[i];
                                final qtd = _quantidade(p);
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppColors.cardShadow),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                            Text('R\$ ${p.price.toStringAsFixed(2).replaceAll('.', ',')}',
                                                style: GoogleFonts.poppins(color: AppColors.primaryOrange, fontWeight: FontWeight.w700)),
                                          ],
                                        ),
                                      ),
                                      if (qtd > 0) ...[
                                        IconButton(
                                          icon: const Icon(LucideIcons.minusCircle),
                                          onPressed: () => _carrinho.decrementQuantity(p.id),
                                        ),
                                        Text('$qtd', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                                      ],
                                      IconButton(
                                        icon: Icon(LucideIcons.plusCircle, color: AppColors.primaryOrange),
                                        onPressed: () => _carrinho.addProduct(p),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: GradientButton(
                          text: _carrinho.items.isEmpty
                              ? 'Escolha os produtos'
                              : 'Pagar • R\$ ${_carrinho.total.toStringAsFixed(2).replaceAll('.', ',')}',
                          icon: LucideIcons.creditCard,
                          onPressed: _carrinho.items.isEmpty ? null : _pagar,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

/// QR de abertura: o morador mostra no leitor da geladeira. Vale uma vez e por poucos minutos.
class AberturaGeladeiraPage extends StatefulWidget {
  const AberturaGeladeiraPage({super.key, required this.sessao, required this.geladeiraId, required this.vendaId, this.api});

  final Sessao sessao;
  final int geladeiraId;
  final int vendaId;
  final ApiPdv? api;

  @override
  State<AberturaGeladeiraPage> createState() => _AberturaGeladeiraPageState();
}

class _AberturaGeladeiraPageState extends State<AberturaGeladeiraPage> {
  late final ApiPdv _api = widget.api ?? ApiPdv.padrao();
  String? _qr;
  DateTime? _expira;
  String? _mensagem;
  bool _liberada = false;
  bool _ocupado = false;
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    _gerar();
    _relogio = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _relogio?.cancel();
    super.dispose();
  }

  Future<void> _gerar() async {
    setState(() {
      _ocupado = true;
      _mensagem = null;
    });
    try {
      final r = await _api.gerarAberturaGeladeira(widget.sessao, widget.geladeiraId, widget.vendaId);
      setState(() {
        _qr = r['qr']?.toString();
        _expira = DateTime.tryParse(r['expiraEm']?.toString() ?? '') ?? DateTime.now().add(const Duration(minutes: 10));
      });
    } catch (erro) {
      setState(() => _mensagem = falhaDe(erro).mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _abrirPeloCelular() async {
    final qr = _qr;
    if (qr == null) return;
    setState(() => _ocupado = true);
    try {
      final r = await _api.abrirGeladeiraPeloApp(widget.sessao, qr);
      setState(() {
        _liberada = r['liberado'] == true;
        _mensagem = r['mensagem']?.toString();
      });
    } catch (erro) {
      setState(() => _mensagem = falhaDe(erro).mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final restante = _expira == null ? Duration.zero : _expira!.difference(DateTime.now());
    final expirou = _qr != null && restante.isNegative;
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Abrir a geladeira', style: GoogleFonts.poppins(color: AppColors.navyDark, fontWeight: FontWeight.w700, fontSize: 18)),
        iconTheme: const IconThemeData(color: AppColors.navyDark),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              if (_liberada) ...[
                const Icon(LucideIcons.unlock, size: 64, color: AppColors.successGreen),
                const SizedBox(height: 12),
                Text(_mensagem ?? 'Geladeira liberada.', textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
              ] else if (_qr != null && !expirou) ...[
                Text('Mostre este QR no leitor da geladeira', textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navyDark)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AppColors.cardShadow),
                  child: QrImageView(data: _qr!, size: 240),
                ),
                const SizedBox(height: 12),
                Text('Vale por ${restante.inMinutes}:${(restante.inSeconds % 60).toString().padLeft(2, '0')} e abre uma vez.',
                    style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  icon: const Icon(LucideIcons.smartphone, size: 16),
                  label: const Text('A geladeira não tem leitor? Abrir pelo celular'),
                  onPressed: _ocupado ? null : _abrirPeloCelular,
                ),
              ] else ...[
                Text(expirou ? 'O QR expirou.' : 'Gerando o QR de abertura...', style: GoogleFonts.poppins(fontSize: 15)),
              ],
              if (_mensagem != null && !_liberada) ...[
                const SizedBox(height: 14),
                Text(_mensagem!, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: const Color(0xFFB71C1C), fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 20),
              if (!_liberada && (expirou || _mensagem != null))
                GradientButton(text: 'Gerar novo QR', icon: LucideIcons.refreshCw, onPressed: _ocupado ? null : _gerar),
              const SizedBox(height: 12),
              TextButton(onPressed: () => Navigator.popUntil(context, (r) => r.isFirst), child: const Text('Voltar ao início')),
            ],
          ),
        ),
      ),
    );
  }
}
