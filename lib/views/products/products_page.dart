import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/cart_controller.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';
import '../../widgets/next_pdv_logo.dart';
import '../../widgets/product_image.dart';
import '../../widgets/product_detail_sheet.dart';

class ProductsPage extends StatefulWidget {
  final AuthController authController;
  final CartController cartController;
  final VoidCallback? onNavigateToCart;

  const ProductsPage({
    super.key,
    required this.authController,
    required this.cartController,
    this.onNavigateToCart,
  });

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  String _selectedCategory = 'all';
  String _searchQuery = '';

  void _adicionarComAnimacao(Product product) {
    widget.cartController.addProduct(product);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 2200),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navyDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ProductImage(
                imageUrl: product.imageUrl,
                width: 32,
                height: 32,
                iconSize: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${product.name} adicionado!',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'R\$ ${product.price.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      color: AppColors.primaryOrange,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: widget.onNavigateToCart == null
            ? null
            : SnackBarAction(
                label: 'VER SACOLA',
                textColor: AppColors.primaryOrangeLight,
                onPressed: widget.onNavigateToCart!,
              ),
      ),
    );
  }

  void _abrirDetalheProduto(Product product) {
    showProductDetailSheet(
      context,
      product,
      onAdd: () => _adicionarComAnimacao(product),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.authController,
        widget.cartController,
      ]),
      builder: (context, _) {
        final lojaAtual = widget.authController.unidadeAtual;
        final isMaior18 = widget.authController.isMaior18;
        final cartCount = widget.cartController.totalItemCount;
        final cartTotal = widget.cartController.total;

        // Categorias do condomínio ativo respeitando idade (+18) e isolamento
        final categoriasDisponiveis =
            widget.authController.categoriasCondominioAtual;

        // Se a categoria selecionada foi ocultada, reseta para 'all'
        final categoriaExiste = categoriasDisponiveis.any(
          (c) => c.id == _selectedCategory,
        );
        final categoriaAtiva = categoriaExiste ? _selectedCategory : 'all';

        // Carregamento de produtos com isolamento estrito por condomínio e verificação 18+
        final produtosLoja = widget.authController.produtosCondominioAtual;

        final filtered = produtosLoja.where((p) {
          final matchesSearch = p.name.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
          if (!matchesSearch) return false;

          if (categoriaAtiva == 'all') return true;
          if (categoriaAtiva == 'drinks')
            return p.category.toLowerCase().contains('bebida');
          if (categoriaAtiva == 'alcohol')
            return p.category.toLowerCase().contains('alcoól') || p.isAlcoholic;
          if (categoriaAtiva == 'snacks')
            return p.category.toLowerCase().contains('lanche') ||
                p.category.toLowerCase().contains('snack') ||
                p.category.toLowerCase().contains('doce');
          if (categoriaAtiva == 'frozen')
            return p.category.toLowerCase().contains('congelado') ||
                p.category.toLowerCase().contains('geladeira') ||
                p.category.toLowerCase().contains('freezer');
          if (categoriaAtiva == 'grocery')
            return p.category.toLowerCase().contains('mercearia');
          if (categoriaAtiva == 'bowls')
            return p.category.toLowerCase().contains('tigela');
          if (categoriaAtiva == 'cups')
            return p.category.toLowerCase().contains('copo');
          if (categoriaAtiva == 'sandwiches')
            return p.category.toLowerCase().contains('sanduíche');
          return p.category.toLowerCase().contains(
                categoriaAtiva.toLowerCase(),
              ) ||
              p.category == categoriaAtiva;
        }).toList();

        return Scaffold(
          backgroundColor: isDark
              ? AppColors.backgroundDark
              : AppColors.backgroundLight,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Column(
                children: [
                  const NextPdvInlineBrand(height: 26),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: Text(
                          '${lojaAtual.nome} • Unidade Vinculada',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        LucideIcons.shieldCheck,
                        size: 11,
                        color: AppColors.primaryOrange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              GestureDetector(
                onTap: widget.onNavigateToCart,
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.cardSurfaceDarkSecondary
                        : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        LucideIcons.shoppingBag,
                        color: isDark ? Colors.white : AppColors.navyDark,
                        size: 20,
                      ),
                      if (cartCount > 0)
                        Positioned(
                          top: -6,
                          right: -8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$cartCount',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            centerTitle: true,
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    // Campo de busca moderno
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: isMaior18
                              ? 'Buscar cerveja, café, pizza...'
                              : 'Buscar sucos, lanches, pizza...',
                          prefixIcon: const Icon(
                            LucideIcons.search,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(LucideIcons.x, size: 18),
                                  onPressed: () =>
                                      setState(() => _searchQuery = ''),
                                )
                              : null,
                        ),
                      ),
                    ),

                    // Chips horizontais de categorias (respeitando idade e isolamento)
                    SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        itemCount: categoriasDisponiveis.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, idx) {
                          final cat = categoriasDisponiveis[idx];
                          final isSelected = categoriaAtiva == cat.id;

                          return ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  cat.icon,
                                  size: 14,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                            ? Colors.white70
                                            : AppColors.navyDark),
                                ),
                                const SizedBox(width: 6),
                                Text(cat.name),
                              ],
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.primaryOrange,
                            backgroundColor: isDark
                                ? AppColors.cardSurfaceDarkSecondary
                                : Colors.white,
                            labelStyle: GoogleFonts.poppins(
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondary),
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primaryOrange
                                    : (isDark
                                          ? AppColors.borderDark
                                          : Colors.grey.shade200),
                              ),
                            ),
                            onSelected: (_) =>
                                setState(() => _selectedCategory = cat.id),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Grid de Produtos
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    LucideIcons.searchX,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Nenhum produto encontrado',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white70
                                          : AppColors.navyDark,
                                    ),
                                  ),
                                  Text(
                                    'Tente outra busca ou categoria.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              padding: EdgeInsets.fromLTRB(
                                20,
                                8,
                                20,
                                cartCount > 0 ? 100 : 90,
                              ),
                              physics: const BouncingScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 0.48,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final product = filtered[index];
                                return _buildProductCard(
                                  product,
                                  isDark: isDark,
                                );
                              },
                            ),
                    ),
                  ],
                ),

                // ==========================================
                // BARRA FLUTUANTE DE VER SACOLA (QUANDO HOUVER ITENS)
                // ==========================================
                if (cartCount > 0)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 16,
                    child: GestureDetector(
                      onTap: widget.onNavigateToCart,
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.primaryOrange,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.shoppingBag,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$cartCount ${cartCount == 1 ? 'item adicionado' : 'itens no carrinho'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Total: R\$ ${cartTotal.toStringAsFixed(2)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      color: AppColors.primaryOrangeLight,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                gradient: AppColors.orangeGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Ver Sacola',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    LucideIcons.arrowRight,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductCard(Product product, {required bool isDark}) {
    final isFav = widget.authController.isFavorito(product.id);

    return Container(
      key: ValueKey('product-card-${product.id}'),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
        border: Border.all(
          color: isDark ? AppColors.borderDark : Colors.transparent,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _abrirDetalheProduto(product),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: ProductImage(
                      imageUrl: product.imageUrl,
                      height: 96,
                      width: double.infinity,
                      iconSize: 36,
                    ),
                  ),
                  if (product.isPromo)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.orangeGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'OFERTA',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () =>
                          widget.authController.toggleFavorito(product.id),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.cardSurfaceDarkSecondary
                              : Colors.white.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Icon(
                          isFav ? Icons.favorite : LucideIcons.heart,
                          color: isFav
                              ? Colors.redAccent
                              : Colors.grey.shade600,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.navyDark,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.unit,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'R\$ ${product.price.toStringAsFixed(2)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryOrange,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _adicionarComAnimacao(product),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: AppColors.orangeGradient,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.plus,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
