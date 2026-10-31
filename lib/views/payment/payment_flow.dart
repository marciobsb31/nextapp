import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../controllers/cart_controller.dart';
import '../../controllers/checkout_controller.dart';
import '../../core/pagamento/cartao_pagbank.dart';
import '../../core/rede/api.dart';
import '../../core/sessao/sessao.dart';
import '../../theme/app_theme.dart';
import '../../widgets/confetti_overlay.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/radar_scan_animation.dart';

/// Pagamento do pedido pelo PagBank da loja: PIX, crédito, débito ou na
/// maquininha (Moderninha) ao retirar. Sem internet, só a maquininha segue:
/// o pedido fica no aparelho e é enviado quando a conexão voltar.
class PaymentFlow extends StatefulWidget {
  final CartController cartController;
  final VoidCallback onFinishFlow;
  final Sessao? sessao;
  final ApiPdv? api;

  /// Geladeira autônoma: depois do pagamento aprovado, abre a tela do QR de abertura.
  final void Function(BuildContext context, int vendaId)? aoAprovar;

  /// Sem "Maquininha": a geladeira só abre com pagamento confirmado.
  final bool semMaquininha;

  const PaymentFlow({
    super.key,
    required this.cartController,
    required this.onFinishFlow,
    this.sessao,
    this.api,
    this.aoAprovar,
    this.semMaquininha = false,
  });

  @override
  State<PaymentFlow> createState() => _PaymentFlowState();
}

class _PaymentFlowState extends State<PaymentFlow> {
  late final CheckoutController _compra = CheckoutController(
    sessao: widget.sessao,
    itens: widget.cartController.items,
    api: widget.api,
  );

  final _numeroCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  final _validadeCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _compra.preparar();
    _numeroCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _compra.dispose();
    _numeroCtrl.dispose();
    _nomeCtrl.dispose();
    _validadeCtrl.dispose();
    _cvvCtrl.dispose();
    _cpfCtrl.dispose();
    super.dispose();
  }

  bool get _cartao => _compra.meio == MeioPagamento.credito || _compra.meio == MeioPagamento.debito;

  void _confirmar() {
    FocusScope.of(context).unfocus();
    _compra.finalizar(
      cartao: _cartao
          ? CartaoDigitado(
              numero: _numeroCtrl.text,
              titular: _nomeCtrl.text,
              validade: _validadeCtrl.text,
              cvv: _cvvCtrl.text.trim(),
            )
          : null,
      cpfTitular: _cpfCtrl.text,
    );
  }

  String _reais(double valor) => 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _compra,
      builder: (context, _) {
        switch (_compra.etapa) {
          case EtapaCompra.enviando:
            return _telaProcessando();
          case EtapaCompra.aguardandoPix:
            return _telaAguardando();
          case EtapaCompra.aprovado:
            return _telaFinal(
              icone: LucideIcons.checkCheck,
              cor: AppColors.successGreen,
              titulo: 'PAGAMENTO APROVADO!',
              texto: widget.aoAprovar == null
                  ? 'Pedido ${_compra.numeroPedido} pago. A loja já recebeu e vai separar seus produtos.'
                  : 'Pedido ${_compra.numeroPedido} pago. Gere o QR e mostre no leitor da geladeira para abrir.',
              confete: true,
              acao: widget.aoAprovar == null || _compra.vendaId == null
                  ? null
                  : GradientButton(
                      text: 'Abrir a geladeira',
                      icon: LucideIcons.unlock,
                      onPressed: () => widget.aoAprovar!(context, _compra.vendaId!),
                    ),
            );
          case EtapaCompra.pagarNaLoja:
            return _telaFinal(
              icone: LucideIcons.store,
              cor: AppColors.primaryOrange,
              titulo: 'PEDIDO ${_compra.numeroPedido} FEITO',
              texto: 'Pague na maquininha da loja (Moderninha) ao retirar. O caixa confirma o pagamento no sistema.',
            );
          case EtapaCompra.naFila:
            return _telaFinal(
              icone: LucideIcons.wifiOff,
              cor: AppColors.navyDark,
              titulo: 'PEDIDO GUARDADO',
              texto: 'Você está sem internet. O pedido ficou salvo neste aparelho e será enviado sozinho quando a conexão voltar. Pague na maquininha da loja ao retirar.',
            );
          case EtapaCompra.recusado:
          case EtapaCompra.escolhendo:
            return _telaEscolha();
        }
      },
    );
  }

  Widget _telaEscolha() {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.navyDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Pagamento',
          style: GoogleFonts.poppins(color: AppColors.navyDark, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cabecalhoTotal(),
              const SizedBox(height: 20),
              _abas(),
              const SizedBox(height: 20),
              if (_compra.mensagem != null) _aviso(_compra.mensagem!),
              switch (_compra.meio) {
                MeioPagamento.pix => _explicacao(
                    LucideIcons.qrCode,
                    'PIX pelo PagSeguro',
                    'Ao confirmar, o código PIX é gerado na conta da loja. O pedido é liberado assim que o banco confirmar.',
                  ),
                MeioPagamento.maquininha => _explicacao(
                    LucideIcons.creditCard,
                    'Maquininha na loja',
                    'Pague no débito, crédito ou PIX na Moderninha da loja ao retirar. Funciona mesmo sem internet: o pedido fica guardado e é enviado quando a conexão voltar.',
                  ),
                _ => _formularioCartao(),
              },
              if (_compra.temAlcool) ...[
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _compra.confirmaMaioridade,
                  onChanged: (v) => _compra.marcarMaioridade(v ?? false),
                  activeColor: AppColors.primaryOrange,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    'Tenho 18 anos ou mais (o carrinho tem bebida alcoólica).',
                    style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.navyDark),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              GradientButton(
                text: switch (_compra.meio) {
                  MeioPagamento.pix => 'Gerar PIX • ${_reais(_compra.totalExibido)}',
                  MeioPagamento.maquininha => 'Fazer pedido • ${_reais(_compra.totalExibido)}',
                  _ => 'Pagar • ${_reais(_compra.totalExibido)}',
                },
                icon: LucideIcons.checkCircle,
                onPressed: _confirmar,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cabecalhoTotal() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AppColors.cardShadow),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Valor a pagar', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(
                _reais(_compra.totalExibido),
                style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.navyDark),
              ),
              if (_compra.totalServidor == null)
                Text('Total final confirmado pela loja', style: GoogleFonts.poppins(fontSize: 10.5, color: AppColors.textSecondary)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppColors.primaryOrange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(LucideIcons.shieldCheck, color: AppColors.primaryOrange, size: 16),
                const SizedBox(width: 6),
                Text(
                  'PagSeguro',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryOrange),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _abas() {
    final opcoes = [
      (MeioPagamento.pix, 'PIX', LucideIcons.qrCode),
      (MeioPagamento.credito, 'Crédito', LucideIcons.creditCard),
      (MeioPagamento.debito, 'Débito', LucideIcons.wallet),
      if (!widget.semMaquininha) (MeioPagamento.maquininha, 'Maquininha', LucideIcons.store),
    ];
    return Row(
      children: [
        for (final (meio, rotulo, icone) in opcoes)
          Expanded(
            child: GestureDetector(
              onTap: () => _compra.escolher(meio),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _compra.meio == meio ? AppColors.navyDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  children: [
                    Icon(icone, size: 20, color: _compra.meio == meio ? AppColors.primaryOrange : AppColors.navyDark),
                    const SizedBox(height: 5),
                    Text(
                      rotulo,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: _compra.meio == meio ? FontWeight.w700 : FontWeight.w500,
                        color: _compra.meio == meio ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _aviso(String texto) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertCircle, color: Color(0xFFC62828), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto, style: GoogleFonts.poppins(color: const Color(0xFFB71C1C), fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _explicacao(IconData icone, String titulo, String texto) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AppColors.cardShadow),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: AppColors.primaryOrange, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.navyDark)),
                const SizedBox(height: 4),
                Text(texto, style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formularioCartao() {
    final bandeira = bandeiraDe(_numeroCtrl.text);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AppColors.cardShadow),
      child: Column(
        children: [
          _campo(
            _numeroCtrl,
            'Número do cartão',
            LucideIcons.creditCard,
            teclado: TextInputType.number,
            sufixo: bandeira.isEmpty ? null : bandeira,
            formatos: [FilteringTextInputFormatter.allow(RegExp(r'[\d ]')), LengthLimitingTextInputFormatter(23)],
          ),
          _campo(_nomeCtrl, 'Nome impresso no cartão', LucideIcons.user, maiusculas: true),
          Row(
            children: [
              Expanded(
                child: _campo(
                  _validadeCtrl,
                  'Validade (MM/AA)',
                  LucideIcons.calendar,
                  teclado: TextInputType.datetime,
                  formatos: [FilteringTextInputFormatter.allow(RegExp(r'[\d/]')), LengthLimitingTextInputFormatter(7)],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _campo(
                  _cvvCtrl,
                  'CVV',
                  LucideIcons.lock,
                  teclado: TextInputType.number,
                  oculto: true,
                  formatos: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                ),
              ),
            ],
          ),
          _campo(
            _cpfCtrl,
            'CPF do titular',
            LucideIcons.idCard,
            teclado: TextInputType.number,
            formatos: [FilteringTextInputFormatter.allow(RegExp(r'[\d.\-]')), LengthLimitingTextInputFormatter(14)],
          ),
          if (_compra.meio == MeioPagamento.credito && _compra.parcelasMax > 1)
            DropdownButtonFormField<int>(
              initialValue: _compra.parcelas,
              decoration: const InputDecoration(labelText: 'Parcelas'),
              items: [
                for (var p = 1; p <= _compra.parcelasMax; p++)
                  DropdownMenuItem(value: p, child: Text(p == 1 ? 'À vista' : '${p}x')),
              ],
              onChanged: (v) => _compra.escolherParcelas(v ?? 1),
            ),
          const SizedBox(height: 6),
          Text(
            'Os dados do cartão são criptografados neste aparelho e vão direto para o PagSeguro. Nada fica salvo.',
            style: GoogleFonts.poppins(fontSize: 10.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _campo(
    TextEditingController controle,
    String rotulo,
    IconData icone, {
    TextInputType? teclado,
    bool oculto = false,
    bool maiusculas = false,
    String? sufixo,
    List<TextInputFormatter>? formatos,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controle,
        keyboardType: teclado,
        obscureText: oculto,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: maiusculas ? TextCapitalization.characters : TextCapitalization.none,
        inputFormatters: formatos,
        decoration: InputDecoration(
          labelText: rotulo,
          prefixIcon: Icon(icone, size: 18, color: AppColors.textSecondary),
          suffixText: sufixo,
        ),
      ),
    );
  }

  Widget _telaProcessando() {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: const SafeArea(
        child: Center(
          child: RadarScanAnimation(
            statusText: 'Enviando ao PagSeguro...',
            subText: 'Registrando o pedido na loja e solicitando o pagamento',
          ),
        ),
      ),
    );
  }

  Widget _telaAguardando() {
    final codigo = _compra.pixCopiaECola ?? '';
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          codigo.isEmpty ? 'Analisando pagamento' : 'Pague com PIX',
          style: GoogleFonts.poppins(color: AppColors.navyDark, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(_reais(_compra.totalExibido), style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.navyDark)),
              Text('Pedido ${_compra.numeroPedido}', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              if (codigo.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AppColors.cardShadow),
                  child: QrImageView(data: codigo, size: 220),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(LucideIcons.copy, size: 16),
                  label: const Text('Copiar código PIX'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: codigo));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código PIX copiado.')));
                  },
                ),
              ],
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                codigo.isEmpty ? 'O PagSeguro está analisando o cartão...' : 'Aguardando a confirmação do banco...',
                style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              TextButton(onPressed: _compra.conferirPagamento, child: const Text('Já paguei, conferir agora')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _telaFinal({required IconData icone, required Color cor, required String titulo, required String texto, bool confete = false, Widget? acao}) {
    final conteudo = SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: AppColors.cardShadow),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(color: cor.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: Icon(icone, color: cor, size: 42),
                    ),
                    const SizedBox(height: 20),
                    Text(titulo, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.navyDark)),
                    const SizedBox(height: 8),
                    Text(texto, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
                    const SizedBox(height: 18),
                    Text(_reais(_compra.totalExibido), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryOrange)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (acao != null) ...[acao, const SizedBox(height: 12)],
              GradientButton(text: 'Voltar ao início', icon: LucideIcons.home, onPressed: widget.onFinishFlow),
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: confete ? ConfettiOverlay(child: conteudo) : conteudo,
    );
  }
}
