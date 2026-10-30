import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../controllers/cart_controller.dart';
import '../../controllers/payment_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/card_3d_mockup.dart';
import '../../widgets/confetti_overlay.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/radar_scan_animation.dart';

class PaymentFlow extends StatefulWidget {
  final CartController cartController;
  final VoidCallback onFinishFlow;

  const PaymentFlow({
    super.key,
    required this.cartController,
    required this.onFinishFlow,
  });

  @override
  State<PaymentFlow> createState() => _PaymentFlowState();
}

class _PaymentFlowState extends State<PaymentFlow> {
  final PaymentController _paymentController = PaymentController();
  bool _isAddingNewCard = false;

  final _numberCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();

  @override
  void dispose() {
    _paymentController.dispose();
    _numberCtrl.dispose();
    _nameCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  void _onConfirmPayment() async {
    await _paymentController.processPayment();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _paymentController,
      builder: (context, _) {
        if (_paymentController.status == PaymentStatus.processing) {
          return _buildProcessingScreen();
        }

        if (_paymentController.status == PaymentStatus.approved) {
          return _buildSuccessScreen();
        }

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft, color: AppColors.navyDark),
              onPressed: () {
                if (_isAddingNewCard) {
                  setState(() => _isAddingNewCard = false);
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            title: Text(
              _isAddingNewCard ? 'Adicionar Novo Cartão' : 'Pagamento Smart',
              style: GoogleFonts.poppins(
                color: AppColors.navyDark,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Resumo do valor a pagar no topo
                  _buildTotalHeader(),
                  const SizedBox(height: 20),

                  if (_isAddingNewCard)
                    _buildNewCardSection()
                  else ...[
                    // Seletor de Métodos
                    _buildPaymentMethodTabs(),
                    const SizedBox(height: 24),

                    if (_paymentController.selectedMethod == PaymentMethodType.creditCard)
                      _buildCreditCardSection()
                    else if (_paymentController.selectedMethod == PaymentMethodType.pix)
                      _buildPixSection()
                    else
                      _buildMealVoucherSection(),
                  ],

                  const SizedBox(height: 32),

                  // Botão de Confirmação
                  if (!_isAddingNewCard)
                    GradientButton(
                      text: _paymentController.selectedMethod == PaymentMethodType.pix
                          ? 'Já Realizei a Transferência PIX'
                          : 'Finalizar Compra • R\$ ${widget.cartController.total.toStringAsFixed(2)}',
                      icon: LucideIcons.checkCircle,
                      onPressed: _onConfirmPayment,
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTotalHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Valor a Pagar',
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                'R\$ ${widget.cartController.total.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navyDark,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.shieldCheck, color: AppColors.primaryOrange, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Seguro & Criptografado',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodTabs() {
    final methods = [
      {'type': PaymentMethodType.creditCard, 'label': 'Cartão', 'icon': LucideIcons.creditCard},
      {'type': PaymentMethodType.pix, 'label': 'PIX 24h', 'icon': LucideIcons.qrCode},
      {'type': PaymentMethodType.mealVoucher, 'label': 'Alimentação', 'icon': LucideIcons.utensils},
    ];

    return Row(
      children: methods.map((m) {
        final isSelected = _paymentController.selectedMethod == m['type'];
        return Expanded(
          child: GestureDetector(
            onTap: () => _paymentController.selectMethod(m['type'] as PaymentMethodType),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.navyDark : Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.navyDark.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : AppColors.cardShadow,
              ),
              child: Column(
                children: [
                  Icon(
                    m['icon'] as IconData,
                    color: isSelected ? AppColors.primaryOrange : AppColors.navyDark,
                    size: 22,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    m['label'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCreditCardSection() {
    final cards = _paymentController.savedCards;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Cartões Salvos',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.navyDark,
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _isAddingNewCard = true),
              icon: const Icon(LucideIcons.plusCircle, size: 16, color: AppColors.primaryOrange),
              label: Text(
                'Novo Cartão',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryOrange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Carrossel 3D de cartões salvos
        CarouselSlider.builder(
          itemCount: cards.length,
          options: CarouselOptions(
            height: 220,
            viewportFraction: 0.90,
            enlargeCenterPage: true,
            enlargeFactor: 0.25,
            onPageChanged: (index, reason) {
              _paymentController.selectCard(index);
            },
          ),
          itemBuilder: (context, index, realIndex) {
            final card = cards[index];
            return Card3DMockup(
              cardNumber: card.cardNumber,
              cardHolderName: card.cardHolderName,
              expiryDate: card.expiryDate,
              cvv: card.cvv,
              brand: card.brand,
              gradient: card.gradient,
            );
          },
        ),

        const SizedBox(height: 14),
        Center(
          child: Text(
            'Arraste para o lado para alternar entre cartões',
            style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildNewCardSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mockup 3D interativo no topo que atualiza em tempo real
        Card3DMockup(
          cardNumber: _paymentController.cardNumber,
          cardHolderName: _paymentController.cardHolderName,
          expiryDate: _paymentController.expiryDate,
          cvv: _paymentController.cvv,
          brand: _paymentController.brand,
        ),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dados do Cartão',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navyDark,
                ),
              ),
              const SizedBox(height: 16),

              // Número
              TextField(
                controller: _numberCtrl,
                keyboardType: TextInputType.number,
                maxLength: 19,
                decoration: const InputDecoration(
                  labelText: 'Número do Cartão',
                  counterText: '',
                  prefixIcon: Icon(LucideIcons.creditCard, size: 20),
                ),
                onChanged: _paymentController.updateCardNumber,
              ),
              const SizedBox(height: 14),

              // Titular
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Nome Impresso no Cartão',
                  prefixIcon: Icon(LucideIcons.user, size: 20),
                ),
                onChanged: _paymentController.updateCardHolder,
              ),
              const SizedBox(height: 14),

              // Validade e CVV
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _expiryCtrl,
                      keyboardType: TextInputType.datetime,
                      maxLength: 5,
                      decoration: const InputDecoration(
                        labelText: 'Validade (MM/AA)',
                        counterText: '',
                        prefixIcon: Icon(LucideIcons.calendar, size: 20),
                      ),
                      onChanged: _paymentController.updateExpiryDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _cvvCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'CVV',
                        counterText: '',
                        prefixIcon: Icon(LucideIcons.lock, size: 20),
                      ),
                      onChanged: _paymentController.updateCvv,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Botão Salvar Cartão
              GradientButton(
                text: 'Salvar Cartão',
                icon: LucideIcons.save,
                onPressed: () {
                  _paymentController.saveNewCard();
                  setState(() => _isAddingNewCard = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Cartão salvo com sucesso!',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: AppColors.navyDark,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPixSection() {
    const String pixCopyPaste =
        '00020126580014br.gov.bcb.pix0136nextpdv-bellavista@banco.com.br5204000053039865802BR5925NEXT PDV MERCADO AUTONOMO6009SAO PAULO62070503***6304A1B2';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF32BCAD).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.zap, color: Color(0xFF32BCAD), size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                'Pagamento Instantâneo via PIX',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navyDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // QR Code Real do PIX gerado com qr_flutter
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200, width: 2),
            ),
            child: QrImageView(
              data: pixCopyPaste,
              version: QrVersions.auto,
              size: 200.0,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppColors.navyDark,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
                color: AppColors.navyDark,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Escaneie o QR Code no app do seu banco ou copie o código abaixo:',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),

          // Botão Copia e Cola
          InkWell(
            onTap: () {
              Clipboard.setData(const ClipboardData(text: pixCopyPaste));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Código PIX Copia e Cola copiado com sucesso!',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: AppColors.navyDark,
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryOrange.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.copy, color: AppColors.primaryOrange, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'COPIAR CÓDIGO PIX',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealVoucherSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.utensils, color: AppColors.primaryOrange, size: 48),
          const SizedBox(height: 14),
          Text(
            'Vale Alimentação / Refeição',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navyDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Aceitamos Alelo, Sodexo, Ticket, VR Benefícios e Flash cadastrados.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.creditCard, color: AppColors.navyDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alelo Alimentação •••• 9921',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text('Saldo estimado: R\$ 420,00', style: GoogleFonts.poppins(fontSize: 11, color: Colors.green)),
                    ],
                  ),
                ),
                const Icon(LucideIcons.check, color: AppColors.primaryOrange),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tela de Processamento com Radar de Cibersegurança
  Widget _buildProcessingScreen() {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: const SafeArea(
        child: Center(
          child: RadarScanAnimation(
            statusText: 'Autorizando Smart Access...',
            subText: 'Verificando saldo e autenticando token seguro do condomínio',
          ),
        ),
      ),
    );
  }

  // Tela de Sucesso com Confetes e Resumo
  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: ConfettiOverlay(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Card Pagamento Aprovado
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.successGreen.withOpacity(0.18),
                          blurRadius: 30,
                          spreadRadius: 4,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Ícone de Sucesso
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.successGreen.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.checkCheck,
                            color: AppColors.successGreen,
                            size: 46,
                          ),
                        ),
                        const SizedBox(height: 20),

                        Text(
                          'PAGAMENTO APROVADO!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.navyDark,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sua compra foi processada e registrada na portaria do condomínio.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(thickness: 1),
                        const SizedBox(height: 16),

                        // Resumo dos Valores
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Pago',
                              style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary),
                            ),
                            Text(
                              'R\$ ${widget.cartController.total.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryOrange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Data & Hora',
                              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                            ),
                            Text(
                              'Hoje, 14:35',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.navyDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Porta Destravada',
                              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                            ),
                            Row(
                              children: [
                                const Icon(LucideIcons.unlock, color: AppColors.successGreen, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Acesso Livre',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.successGreen,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Botão Voltar ao Início
                  GradientButton(
                    text: 'Voltar ao Início',
                    icon: LucideIcons.home,
                    onPressed: widget.onFinishFlow,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
