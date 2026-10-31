import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/product.dart';
import '../theme/app_theme.dart';
import '../core/util/dinheiro.dart';
import 'product_image.dart';

Future<void> showProductDetailSheet(
  BuildContext context,
  Product product, {
  required VoidCallback onAdd,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? AppColors.cardSurfaceDark
        : Colors.white,
    builder: (sheetContext) => _DetalheProduto(product: product, onAdd: onAdd),
  );
}

/// Detalhe do produto com a quantidade escolhida antes de pôr no carrinho.
class _DetalheProduto extends StatefulWidget {
  const _DetalheProduto({required this.product, required this.onAdd});

  final Product product;
  final VoidCallback onAdd;

  @override
  State<_DetalheProduto> createState() => _DetalheProdutoState();
}

class _DetalheProdutoState extends State<_DetalheProduto> {
  var _quantidade = 1;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final limite = product.estoque > 0 ? product.estoque : 99;
    final unidade = product.unit.trim().toLowerCase() == 'un' ? '' : ' · ${product.unit}';
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ProductImage(imageUrl: product.imageUrl, width: double.infinity, height: 220, iconSize: 56),
            ),
            const SizedBox(height: 16),
            Text('${product.category}$unidade', style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13)),
            Text(
              product.name,
              style: GoogleFonts.poppins(color: AppColors.navyDark, fontSize: 22, fontWeight: FontWeight.w800),
            ),
            if (product.description.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(product.description, style: GoogleFonts.poppins(color: AppColors.textSecondary, height: 1.45)),
            ],
            const SizedBox(height: 10),
            if (product.disponivel)
              Row(children: [
                Icon(Icons.inventory_2_outlined, size: 16,
                    color: product.estoque > 0 && product.estoque <= 5 ? const Color(0xFFD97706) : AppColors.successGreen),
                const SizedBox(width: 6),
                Text(
                  product.estoque > 0 && product.estoque <= 5 ? 'Restam só ${product.estoque}' : 'Em estoque',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: product.estoque > 0 && product.estoque <= 5 ? const Color(0xFFD97706) : AppColors.successGreen,
                  ),
                ),
              ]),
            const SizedBox(height: 14),
            Row(
              children: [
                if (product.originalPrice != null) ...[
                  Text(reaisBr(product.originalPrice!),
                      style: GoogleFonts.poppins(color: AppColors.textSecondary, decoration: TextDecoration.lineThrough)),
                  const SizedBox(width: 10),
                ],
                Text(reaisBr(product.price),
                    style: GoogleFonts.poppins(color: AppColors.primaryOrange, fontSize: 22, fontWeight: FontWeight.w800)),
                if (_quantidade > 1) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text('Total ${reaisBr(product.price * _quantidade)}',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            Row(children: [
              if (product.disponivel) ...[_seletor(limite), const SizedBox(width: 12)],
              Expanded(
                child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: product.disponivel
                    ? () {
                        for (var i = 0; i < _quantidade; i++) {
                          widget.onAdd();
                        }
                        Navigator.of(context).pop();
                      }
                    : null,
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(
                  product.disponivel
                      ? 'Adicionar'
                      : 'Produto indisponível',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _seletor(int limite) {
    Widget botao(IconData icone, VoidCallback? aoTocar, String dica) => IconButton(
          tooltip: dica,
          onPressed: aoTocar,
          icon: Icon(icone, size: 18),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.12),
            foregroundColor: AppColors.primaryOrange,
            minimumSize: const Size(40, 40),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        botao(Icons.remove, _quantidade > 1 ? () => setState(() => _quantidade--) : null, 'Menos um'),
        SizedBox(
          width: 36,
          child: Text('$_quantidade', textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.navyDark)),
        ),
        botao(Icons.add, _quantidade < limite ? () => setState(() => _quantidade++) : null, 'Mais um'),
      ],
    );
  }
}
