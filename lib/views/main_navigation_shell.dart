import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../controllers/auth_controller.dart';
import '../controllers/cart_controller.dart';
import '../theme/app_theme.dart';
import 'cart/cart_page.dart';
import 'home/home_page.dart';
import 'orders/orders_page.dart';
import 'products/products_page.dart';
import 'profile/profile_page.dart';
import 'scanner/smart_access_modal.dart';

class MainNavigationShell extends StatefulWidget {
  final AuthController authController;
  final VoidCallback onLogout;

  const MainNavigationShell({
    super.key,
    required this.authController,
    required this.onLogout,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final CartController _cartController = CartController();

  late final AnimationController _scanController;
  late final Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    // Animação de escaneamento a laser contínuo (linha subindo e descendo)
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );
  }

  void _openSmartAccessScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SmartAccessModal()),
    );
  }

  void _navigateToCart() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartPage(
          cartController: _cartController,
          onBackToShop: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    _cartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authController,
      builder: (context, _) {
        final temSmartAccess = widget.authController.temAcessoSmartAccess;
        final somenteSmartAccess = widget.authController.somenteSmartAccess;

        final List<Widget> pages = [
          HomePage(
            authController: widget.authController,
            cartController: _cartController,
            onNavigateToCart: _navigateToCart,
            onNavigateToProfile: () => setState(() => _currentIndex = 4),
            onNavigateToSearch: () => setState(() => _currentIndex = 1),
          ),
          ProductsPage(
            authController: widget.authController,
            cartController: _cartController,
            onNavigateToCart: _navigateToCart,
          ),
          const SizedBox.shrink(), // Placeholder para o botão central Smart Access
          const OrdersPage(),
          ProfilePage(
            authController: widget.authController,
            onLogout: widget.onLogout,
          ),
        ];

        return Scaffold(
          body: Column(
            children: [
              // Banner de Notificação: Somente Smart Access (Apenas portas dos freezers)
              if (somenteSmartAccess)
                SafeArea(
                  bottom: false,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.doorClosed, color: AppColors.primaryOrange, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Modo Especial: Acesso restrito a Portas & Freezers',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex == 2 ? 0 : _currentIndex,
                  children: pages,
                ),
              ),
            ],
          ),
          extendBody: true,

          // Botão Flutuante Central Smart Access (com animação pulsante)
          // Se o usuário não tiver acesso ao smart access verificado no sistemaweb, NÃO exibe o botão
          floatingActionButtonLocation: temSmartAccess
              ? FloatingActionButtonLocation.centerDocked
              : null,
          floatingActionButton: temSmartAccess ? _buildAnimatedSmartAccessButton() : null,

          // Bottom Navigation Bar adaptativa
          bottomNavigationBar: _buildBottomBar(temSmartAccess),
        );
      },
    );
  }

  Widget _buildAnimatedSmartAccessButton() {
    const double buttonSize = 82;
    const double iconBoxSize = 34;

    return Container(
      margin: const EdgeInsets.only(top: 18),
      child: GestureDetector(
        onTap: _openSmartAccessScanner,
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8C00), Color(0xFFFF5500), Color(0xFFE65100)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white, width: 3.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryOrange.withValues(alpha: 0.45),
                blurRadius: 14,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Área do ícone com linha laser de escaneamento animada (descendo e subindo)
                SizedBox(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                        size: 32,
                      ),
                      AnimatedBuilder(
                        animation: _scanAnimation,
                        builder: (context, _) {
                          // Linha percorre verticalmente induzindo ao escaneamento contínuo
                          final topPos = 4.0 + (_scanAnimation.value * (iconBoxSize - 12.0));
                          return Positioned(
                            top: topPos,
                            left: 3,
                            right: 3,
                            child: Container(
                              height: 2.2,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                gradient: const LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Color(0xFF00FFCC), // Ciano neon elétrico / laser
                                    Colors.white,
                                    Color(0xFF00FFCC),
                                    Colors.transparent,
                                  ],
                                  stops: [0.0, 0.15, 0.5, 0.85, 1.0],
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0xFF00FFCC),
                                    blurRadius: 5,
                                    spreadRadius: 1,
                                  ),
                                  BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 2,
                                    spreadRadius: 0.5,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ABRIR\nPORTA',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool temSmartAccess) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomAppBar(
        shape: temSmartAccess ? const CircularNotchedRectangle() : null,
        notchMargin: 8,
        color: AppColors.navyDark,
        elevation: 0,
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // 1. Início
            _buildNavItem(0, LucideIcons.home, 'Início'),
            // 2. Produtos
            _buildNavItem(1, LucideIcons.layoutGrid, 'Produtos'),

            // Espaço para o botão central pulsante apenas se Smart Access estiver ativo
            if (temSmartAccess) const SizedBox(width: 80),

            // 4. Pedidos
            _buildNavItem(3, LucideIcons.receipt, 'Pedidos'),
            // 5. Perfil
            _buildNavItem(4, LucideIcons.user, 'Perfil'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? AppColors.primaryOrange
                  : Colors.white70,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primaryOrange
                    : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
