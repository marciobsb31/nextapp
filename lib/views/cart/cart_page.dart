import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../controllers/cart_controller.dart';
import '../../models/cart_item.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/product_image.dart';
import '../../widgets/swipe_to_pay.dart';
import '../payment/payment_flow.dart';

class CartPage extends StatelessWidget {
  final CartController cartController;
  final VoidCallback onBackToShop;

  const CartPage({
    super.key,
    required this.cartController,
    required this.onBackToShop,
  });

  void _proceedToCheckout(BuildContext context) {
    if (cartController.items.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentFlow(
          cartController: cartController,
          onFinishFlow: () {
            cartController.clearCart();
            Navigator.popUntil(context, (route) => route.isFirst);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: isDark ? Colors.white : AppColors.navyDark),
          onPressed: onBackToShop,
        ),
        title: Text(
          'Meu Carrinho',
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : AppColors.navyDark,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          AnimatedBuilder(
            animation: cartController,
            builder: (context, _) {
              if (cartController.items.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 20),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Text('Limpar Carrinho?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                      content: Text('Deseja remover todos os itens selecionados?', style: GoogleFonts.poppins(fontSize: 13)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cancelar', style: GoogleFonts.poppins(color: Colors.grey)),
                        ),
                        TextButton(
                          onPressed: () {
                            cartController.clearCart();
                            Navigator.pop(ctx);
                          },
                          child: Text('Limpar', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: cartController,
        builder: (context, _) {
          final items = cartController.items;

          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardSurfaceDark : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: const Icon(
                        LucideIcons.shoppingBag,
                        color: AppColors.primaryOrange,
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Seu carrinho está vazio',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.navyDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Acesse a gôndola inteligente ou geladeira e adicione seus produtos favoritos.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    GradientButton(
                      text: 'Explorar Produtos',
                      icon: LucideIcons.store,
                      onPressed: onBackToShop,
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              // Lista de Produtos
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _buildCartItemCard(context, item, isDark: isDark);
                  },
                ),
              ),

              // Resumo do Pedido e Botão Finalizar
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardSurfaceDark : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Subtotal
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Subtotal',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            'R\$ ${cartController.subtotal.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppColors.navyDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Taxa de Condomínio / Serviço
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Taxa Smart Market',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(LucideIcons.info, size: 14, color: Colors.grey),
                            ],
                          ),
                          Text(
                            'R\$ ${cartController.serviceFee.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppColors.navyDark,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24, thickness: 1),

                      // Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.navyDark,
                            ),
                          ),
                          Text(
                            'R\$ ${cartController.total.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryOrange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Swipe to Pay ou Botão CTA
                      SwipeToPay(
                        label: 'Deslize para Pagar',
                        onSwipeCompleted: () => _proceedToCheckout(context),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => _proceedToCheckout(context),
                        child: Text(
                          'Ou clique aqui para escolher forma de pagamento >>',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCartItemCard(BuildContext context, CartItem item, {required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          // Imagem
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ProductImage(
              imageUrl: item.product.imageUrl,
              width: 72,
              height: 72,
              iconSize: 24,
            ),
          ),
          const SizedBox(width: 14),

          // Nome e Preço
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.navyDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.product.unit,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'R\$ ${item.totalPrice.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ],
            ),
          ),

          // Controle numérico [ - count + ] com botões laranjas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardSurfaceDarkSecondary : AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => cartController.decrementQuantity(item.product.id),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.orangeGradient,
                    ),
                    child: const Icon(LucideIcons.minus, color: Colors.white, size: 14),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '${item.quantity}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.navyDark,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => cartController.incrementQuantity(item.product.id),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.orangeGradient,
                    ),
                    child: const Icon(LucideIcons.plus, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
