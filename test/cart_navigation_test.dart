import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdv_market/controllers/auth_controller.dart';
import 'package:pdv_market/controllers/cart_controller.dart';
import 'package:pdv_market/models/product.dart';
import 'package:pdv_market/views/products/products_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a barra Ver carrinho é o único atalho e abre o carrinho', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authController = AuthController(
      autoLoadCatalogo: false,
      autoStartRealtime: false,
    );
    final cartController = CartController();
    addTearDown(authController.dispose);
    addTearDown(cartController.dispose);

    var abriuSacola = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ProductsPage(
          authController: authController,
          cartController: cartController,
          onNavigateToCart: () => abriuSacola = true,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(LucideIcons.plus).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Sem aviso com ação: só a barra "Ver carrinho".
    expect(find.byType(SnackBarAction), findsNothing);
    expect(find.text('Ver carrinho'), findsOneWidget);
    await tester.tap(find.text('Ver carrinho'));
    await tester.pump();

    expect(abriuSacola, isTrue);
    expect(cartController.totalItemCount, 1);
  });

  testWidgets('a vitrine tem duas colunas e abre o detalhe do produto', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authController = AuthController(
      autoLoadCatalogo: false,
      autoStartRealtime: false,
    );
    final cartController = CartController();
    addTearDown(authController.dispose);
    addTearDown(cartController.dispose);

    final produtos = authController.produtosCondominioAtual.take(3).toList();
    expect(produtos.length, 3);

    await tester.pumpWidget(
      MaterialApp(
        home: ProductsPage(
          authController: authController,
          cartController: cartController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cards = [
      for (final produto in produtos)
        find.byKey(ValueKey('product-card-${produto.id}')),
    ];
    final posicoes = [for (final card in cards) tester.getTopLeft(card).dy];
    // Duas colunas: os dois primeiros lado a lado, o terceiro na linha de baixo.
    expect(posicoes[0], posicoes[1]);
    expect(posicoes[2], greaterThan(posicoes[1]));

    await tester.tap(cards.first);
    await tester.pumpAndSettle();
    expect(find.text('Adicionar'), findsOneWidget);

    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();
    expect(cartController.totalItemCount, 1);
  });
}
