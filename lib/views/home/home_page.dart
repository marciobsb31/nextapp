import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/cart_controller.dart';
import '../../models/admin_banner.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_bell_notification.dart';
import '../../widgets/next_pdv_logo.dart';
import '../../widgets/product_image.dart';
import '../../widgets/product_detail_sheet.dart';

class HomePage extends StatefulWidget {
  final AuthController authController;
  final CartController cartController;
  final VoidCallback onNavigateToCart;
  final VoidCallback onNavigateToProfile;
  final VoidCallback? onNavigateToSearch;

  const HomePage({
    super.key,
    required this.authController,
    required this.cartController,
    required this.onNavigateToCart,
    required this.onNavigateToProfile,
    this.onNavigateToSearch,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedCategory = 'all';
  int _bannerIndex = 0;

  void _adicionarComAnimacao(Product product) {
    widget.cartController.addProduct(product);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1400),
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
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  Text(
                    'Sacola atualizada • R\$ ${product.price.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(color: AppColors.primaryOrange, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'VER SACOLA',
          textColor: AppColors.primaryOrangeLight,
          onPressed: widget.onNavigateToCart,
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
    return AnimatedBuilder(
      animation: widget.authController,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final lojaAtual = widget.authController.unidadeAtual;
        final isMaior18 = widget.authController.isMaior18;
        final enderecoUnidade = [
          lojaAtual.endereco,
          [lojaAtual.bairro, lojaAtual.cidade, lojaAtual.uf]
              .where((parte) => parte.trim().isNotEmpty)
              .join(' · '),
        ].where((parte) => parte.trim().isNotEmpty).join(' · ');

        // 1. Categorias do condomínio respeitando idade (+18) e isolamento
        final categoriasDisponiveis = widget.authController.categoriasCondominioAtual;

        // Se a categoria selecionada foi ocultada (ex: álcool para menor de 18), volta para 'all'
        final categoriaExiste = categoriasDisponiveis.any((c) => c.id == _selectedCategory);
        final categoriaAtiva = categoriaExiste ? _selectedCategory : 'all';

        // 2. Banners sincronizados do painel Admin (Aplicativo/Anúncios) para esta unidade
        final bannersAdmin = widget.authController.bannersCondominioAtual;

        // 3. Produtos isolados estritamente para este condomínio e respeitando +18
        final todosProdutosLoja = widget.authController.produtosCondominioAtual;

        // 4. Produtos por IA (NextAI): Comprados recentemente e recomendações da base real
        final produtosIa = Product.getAiRecommendations(
          lojaId: lojaAtual.lojaId,
          tenantId: lojaAtual.tenantId,
          isMaior18: isMaior18,
          favIds: widget.authController.favoritosIds,
          recentIds: widget.authController.ultimasComprasIds,
          baseProdutos: todosProdutosLoja,
        );

        // 5. Produtos Favoritos do usuário
        final produtosFavoritos = todosProdutosLoja
            .where((p) => widget.authController.isFavorito(p.id))
            .toList();

        // 6. Produtos filtrados na categoria ativa (suporta qualquer categoria do condomínio)
        final products = todosProdutosLoja.where((p) {
          if (categoriaAtiva == 'all') return true;
          if (categoriaAtiva == 'drinks') return p.category.toLowerCase().contains('bebida');
          if (categoriaAtiva == 'alcohol') return p.category.toLowerCase().contains('alcoól') || p.isAlcoholic;
          if (categoriaAtiva == 'snacks') return p.category.toLowerCase().contains('lanche') || p.category.toLowerCase().contains('snack') || p.category.toLowerCase().contains('doce');
          if (categoriaAtiva == 'frozen') return p.category.toLowerCase().contains('congelado') || p.category.toLowerCase().contains('geladeira') || p.category.toLowerCase().contains('freezer');
          if (categoriaAtiva == 'grocery') return p.category.toLowerCase().contains('mercearia');
          if (categoriaAtiva == 'bowls') return p.category.toLowerCase().contains('tigela');
          if (categoriaAtiva == 'cups') return p.category.toLowerCase().contains('copo');
          if (categoriaAtiva == 'sandwiches') return p.category.toLowerCase().contains('sanduíche');
          return p.category.toLowerCase().contains(categoriaAtiva.toLowerCase()) || p.category == categoriaAtiva;
        }).toList();

        return Scaffold(
          backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
          body: SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Top Bar com Logo Oficial NextPDV e Identificação da Unidade
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                    child: Column(
                      children: [
                        // Linha Superior: Logo NextPDV + Ações (Perfil e Carrinho)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const NextPdvInlineBrand(
                              height: 32,
                              showLojaBadge: false,
                            ),
                            Row(
                              children: [
                              // Foto de perfil
                              GestureDetector(
                                  onTap: widget.onNavigateToProfile,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.primaryOrange, width: 2),
                                      boxShadow: AppColors.cardShadow,
                                    ),
                                    child: Image.network(
                                      ProductImage.formatProxyUrl(widget.authController.avatarUrl),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: AppColors.navyDark,
                                        child: const Icon(LucideIcons.user, color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Sininho ao lado do carrinho
                                AnimatedBellNotification(
                                  unreadCount: widget.authController.unreadNotifications,
                                  onClearNotifications: () => widget.authController.clearNotifications(),
                                ),

                                // Ícone do Carrinho com Contador Badge
                                GestureDetector(
                                  onTap: widget.onNavigateToCart,
                                  child: Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                        color: isDark ? AppColors.cardSurfaceDarkSecondary : Colors.white,
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
                                        AnimatedBuilder(
                                          animation: widget.cartController,
                                          builder: (context, _) {
                                            final count = widget.cartController.totalItemCount;
                                            if (count == 0) return const SizedBox.shrink();
                                            return Positioned(
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
                                                  '$count',
                                                  textAlign: TextAlign.center,
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Card de Localização e Conformidade 500m (Exibição da Unidade do Morador - Fixa)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.navyDark,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryOrange.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(LucideIcons.mapPin, color: AppColors.primaryOrange, size: 16),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            lojaAtual.nome,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                LucideIcons.lock,
                                                size: 10,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                'Sua Unidade',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                      Text(
                                        widget.authController.unit,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      if (enderecoUnidade.isNotEmpty)
                                        Text(
                                          enderecoUnidade,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            color: Colors.white70,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0x332D83E6),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0x664A9EFF), width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(LucideIcons.checkCheck, size: 12, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Raio 500 m · ${lojaAtual.distanciaFormatada}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Banners Rotativos (Configurados a partir do Painel do Admin)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 8),
                    child: Column(
                      children: [
                        CarouselSlider(
                          options: CarouselOptions(
                            height: 138,
                            viewportFraction: 0.90,
                            enlargeCenterPage: true,
                            autoPlay: true,
                            autoPlayInterval: const Duration(seconds: 4),
                            onPageChanged: (index, reason) {
                              setState(() => _bannerIndex = index);
                            },
                          ),
                          items: bannersAdmin.map((AdminBanner banner) {
                            Color parseColor(String col, Color fallback) {
                              try {
                                final c = col.trim();
                                if (c.startsWith('#') && c.length == 7) {
                                  return Color(int.parse('0xFF${c.substring(1)}'));
                                }
                                if (c.startsWith('0x') || c.startsWith('0X')) {
                                  return Color(int.parse(c));
                                }
                                return Color(int.parse(c));
                              } catch (_) {
                                return fallback;
                              }
                            }

                            final c1 = parseColor(banner.color1, AppColors.primaryOrange);
                            final c2 = parseColor(banner.color2, const Color(0xFFFF5500));
                            final hasImage = banner.imageUrl != null && banner.imageUrl!.trim().isNotEmpty;

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  colors: [c1, c2],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: c1.withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Stack(
                                  children: [
                                    if (hasImage)
                                      Positioned.fill(
                                        child: Image.network(
                                          ProductImage.formatProxyUrl(banner.imageUrl!),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                        ),
                                      ),
                                    if (hasImage)
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                              colors: [
                                                c1.withValues(alpha: 0.92),
                                                c2.withValues(alpha: 0.45),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.all(18),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withValues(alpha: 0.22),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    banner.tag,
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.white,
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  banner.title,
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                    height: 1.2,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  banner.subtitle,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white.withValues(alpha: 0.9),
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            LucideIcons.sparkles,
                                            color: Colors.white70,
                                            size: 38,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        // Indicador de Banners
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: bannersAdmin.asMap().entries.map((entry) {
                            return Container(
                              width: _bannerIndex == entry.key ? 16 : 6,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: _bannerIndex == entry.key
                                    ? AppColors.primaryOrange
                                    : Colors.grey.shade300,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),

                        // ==========================================
                        // BOTÃO DE BUSCAR PRODUTO (ABAIXO DO BANNER)
                        // ==========================================
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: InkWell(
                            onTap: widget.onNavigateToSearch,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 50,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.cardSurfaceDark : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: AppColors.cardShadow,
                                border: Border.all(
                                  color: AppColors.primaryOrange.withValues(alpha: 0.35),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(LucideIcons.search, color: AppColors.primaryOrange, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Buscar produto no minimarket...',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: AppColors.orangeGradient,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryOrange.withOpacity(0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Buscar',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
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
                ),

                // ==========================================
                // SEÇÃO INTELIGÊNCIA ARTIFICIAL: COMPRADOS RECENTEMENTE & RECOMENDAÇÕES (NextAI)
                // Regra: só deve aparecer se já tiver sido feito alguma compra ou salvo algum favorito
                // ==========================================
                if ((widget.authController.favoritosIds.isNotEmpty || widget.authController.ultimasComprasIds.isNotEmpty) && produtosIa.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Sugestões para você',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppColors.navyDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Baseado no seu histórico de compras no condomínio',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 195,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: produtosIa.take(5).length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final p = produtosIa[index];
                              return _buildHorizontalProductCard(p);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ==========================================
                // SEÇÃO SEUS FAVORITOS (COM CORAÇÃOZINHO)
                // ==========================================
                if (produtosFavoritos.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.favorite, color: Colors.redAccent, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Seus Favoritos',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : AppColors.navyDark,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '(${produtosFavoritos.length})',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 195,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: produtosFavoritos.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final p = produtosFavoritos[index];
                                return _buildHorizontalProductCard(p);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Categorias Rápidas (Chips com verificação de maioridade +18)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: SizedBox(
                      height: 50,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: categoriasDisponiveis.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final category = categoriasDisponiveis[index];
                          final isSelected = categoriaAtiva == category.id;

                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedCategory = category.id);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryOrange
                                    : (isDark ? AppColors.cardSurfaceDark : Colors.white),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? AppColors.primaryOrange : Colors.grey.shade200,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primaryOrange.withValues(alpha: 0.35),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : AppColors.cardShadow,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    category.icon,
                                    size: 16,
                                    color: isSelected ? Colors.white : (isDark ? Colors.white : AppColors.navyDark),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    category.name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? Colors.white : (isDark ? Colors.white : AppColors.navyDark),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // Cabeçalho de Produtos Disponíveis
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Gôndolas & Geladeiras',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.navyDark,
                          ),
                        ),
                        Text(
                          '${products.length} itens disponíveis',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Grid de Produtos com Botão de Favorito e Adicionar à Sacola
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.48,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = products[index];
                        return _buildProductCard(product);
                      },
                      childCount: products.length,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 110)),
              ],
            ),
          ),
        );
      },
    );
  }

  // Card Horizontal para as seções NextAI e Favoritos
  Widget _buildHorizontalProductCard(Product product) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFav = widget.authController.isFavorito(product.id);

    return Container(
      key: ValueKey('home-product-${product.id}'),
      width: 140,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _abrirDetalheProduto(product),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: ProductImage(
                  imageUrl: product.imageUrl,
                  height: 95,
                  width: double.infinity,
                  iconSize: 32,
                ),
              ),
              // Coração de Favoritos
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => widget.authController.toggleFavorito(product.id),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Icon(
                      isFav ? Icons.favorite : LucideIcons.heart,
                      color: isFav ? Colors.redAccent : Colors.grey.shade600,
                      size: 14,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.navyDark,
                  ),
                ),
                Text(
                  product.unit,
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'R\$ ${product.price.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryOrange),
                    ),
                    GestureDetector(
                      onTap: () => _adicionarComAnimacao(product),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: AppColors.orangeGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.plus, color: Colors.white, size: 14),
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

  // Card do Grid Principal com Coraçãozinho e Botão Adicionar
  Widget _buildProductCard(Product product) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFav = widget.authController.isFavorito(product.id);

    return Container(
      key: ValueKey('home-product-${product.id}'),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardSurfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
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
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                      onTap: () => widget.authController.toggleFavorito(product.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.cardSurfaceDarkSecondary : Colors.white)
                              .withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(
                          isFav ? Icons.favorite : LucideIcons.heart,
                          color: isFav ? Colors.redAccent : Colors.grey.shade600,
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
                    const SizedBox(height: 4),
                    Text(
                      product.unit,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (product.originalPrice != null)
                              Text(
                                'R\$ ${product.originalPrice!.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            Text(
                              'R\$ ${product.price.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryOrange,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => _adicionarComAnimacao(product),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: AppColors.orangeGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryOrange.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              LucideIcons.plus,
                              color: Colors.white,
                              size: 16,
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
