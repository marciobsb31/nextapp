import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/product.dart';
import '../theme/app_theme.dart';
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
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ProductImage(
                imageUrl: product.imageUrl,
                width: double.infinity,
                height: 220,
                iconSize: 56,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${product.category} · ${product.unit}',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            Text(
              product.name,
              style: GoogleFonts.poppins(
                color: AppColors.navyDark,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              product.description.isEmpty
                  ? 'Consulte a loja para mais informações sobre este produto.'
                  : product.description,
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (product.originalPrice != null) ...[
                  Text(
                    'R\$ ${product.originalPrice!.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  'R\$ ${product.price.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    color: AppColors.primaryOrange,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: product.disponivel
                    ? () {
                        onAdd();
                        Navigator.of(sheetContext).pop();
                      }
                    : null,
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(
                  product.disponivel
                      ? 'Adicionar ao carrinho'
                      : 'Produto indisponível',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
