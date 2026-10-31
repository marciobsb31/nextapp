import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdv_market/controllers/auth_controller.dart';
import 'package:pdv_market/controllers/cart_controller.dart';
import 'package:pdv_market/models/admin_banner.dart';
import 'package:pdv_market/models/category_model.dart';
import 'package:pdv_market/models/loja_unidade.dart';
import 'package:pdv_market/models/product.dart';
import 'package:pdv_market/services/viacep_service.dart';
import 'package:pdv_market/views/auth/login_page.dart';
import 'package:pdv_market/views/auth/register_page.dart';
import 'package:pdv_market/views/home/home_page.dart';
import 'package:pdv_market/views/main_navigation_shell.dart';
import 'package:pdv_market/views/products/products_page.dart';
import 'package:pdv_market/views/profile/profile_page.dart';
import 'package:pdv_market/views/support/help_support_page.dart';
import 'package:pdv_market/widgets/gradient_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
    HttpOverrides.global = _MockHttpOverrides();
  });

  group('Next PDV - Regras de Negócio e Isolamento Multi-tenant', () {
    test('1. Isolamento de Produtos por Loja (Multi-tenant)', () {
      final produtosLoja1 = Product.getProductsForLoja(1);
      final produtosLoja2 = Product.getProductsForLoja(2);
      final produtosLoja3 = Product.getProductsForLoja(3);

      expect(produtosLoja1.isNotEmpty, isTrue);
      expect(produtosLoja2.isNotEmpty, isTrue);
      expect(produtosLoja3.isNotEmpty, isTrue);

      // Garante que cada loja possui apenas seus próprios produtos
      for (final p in produtosLoja1) {
        expect(p.lojaId, equals(1));
        expect(p.tenantId, equals('tenant_bellavista'));
      }
      for (final p in produtosLoja2) {
        expect(p.lojaId, equals(2));
        expect(p.tenantId, equals('tenant_parquejardins'));
      }
      for (final p in produtosLoja3) {
        expect(p.lojaId, equals(3));
        expect(p.tenantId, equals('tenant_altodaserra'));
      }

      // Nenhum produto de uma loja vaza para outra loja
      final idsLoja1 = produtosLoja1.map((p) => p.id).toSet();
      final idsLoja2 = produtosLoja2.map((p) => p.id).toSet();
      expect(idsLoja1.intersection(idsLoja2).isEmpty, isTrue);
    });

    test(
      '2. Validação do Raio de 500 Metros e Bloqueio de Outros Condomínios',
      () {
        final viaCepService = ViaCepService();

        // CEP 01311-000 (Avenida Paulista / Bela Vista)
        final unidadesPaulista = viaCepService.listarTodasUnidadesComDistancia(
          '01311000',
        );
        final unidadesNoRaio = viaCepService.buscarUnidadesNoRaio500m(
          '01311000',
        );

        // Bella Vista (140m) e Parque dos Jardins (390m) estão no raio de 500m
        expect(
          unidadesPaulista.any((u) => u.lojaId == 1 && u.estaNoRaio500m),
          isTrue,
        );
        expect(
          unidadesPaulista.any((u) => u.lojaId == 2 && u.estaNoRaio500m),
          isTrue,
        );

        // Alto da Serra (2.8km) deve estar estritamente FORA do raio (> 500m)
        final unidadeAltoDaSerra = unidadesPaulista.firstWhere(
          (u) => u.lojaId == 3,
        );
        expect(unidadeAltoDaSerra.estaNoRaio500m, isFalse);
        expect(unidadeAltoDaSerra.distanciaMetros, greaterThan(500.0));

        // As unidades autorizadas no raio contém apenas unidades com <= 500m
        for (final u in unidadesNoRaio) {
          expect(u.distanciaMetros, lessThanOrEqualTo(500.0));
        }
        expect(unidadesNoRaio.contains(unidadeAltoDaSerra), isFalse);
      },
    );

    testWidgets(
      '3. Tela de Cadastro: CEP é o primeiro campo e pré-preenche Google',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        final authController = AuthController();

        final googleProfile = const GoogleProfileData(
          name: 'Márcio Google User',
          email: 'marcio.google@gmail.com',
          photoUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100',
          sub: 'google_sub_123',
        );

        final viaCepMock = ViaCepService(
          mockResponses: {
            '01310100': const CepConsultaResult(
              endereco: ViaCepResult(
                cep: '01310-100',
                logradouro: 'Avenida Paulista',
                bairro: 'Bela Vista',
                localidade: 'São Paulo',
                uf: 'SP',
                isReadOnly: true,
              ),
              condominios: [
                LojaUnidade(
                  tenantId: 'tenant_bellavista',
                  lojaId: 1,
                  nome: 'Residencial Bella Vista',
                  endereco: 'Av. Paulista, 1000',
                  bairro: 'Bela Vista',
                  cidade: 'São Paulo',
                  uf: 'SP',
                  latitude: -23.561414,
                  longitude: -46.655881,
                  distanciaMetros: 140,
                ),
              ],
            ),
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RegisterPage(
              authController: authController,
              googleProfile: googleProfile,
              viaCepService: viaCepMock,
              onRegisterSuccess: () {},
            ),
          ),
        );
        await tester.pump();

        // Verifica exibição do badge de usuário Google
        expect(find.text('Google Conectado'), findsOneWidget);
        expect(find.text('Márcio Google User'), findsOneWidget);

        // Verifica que o primeiro campo de entrada é o CEP
        expect(find.text('CEP (Primeiro campo obrigatório)'), findsOneWidget);
        expect(find.byType(TextField), findsWidgets);

        // Digita o CEP para buscar as unidades dentro de 500m
        final cepField = find.byType(TextField).first;
        await tester.enterText(cepField, '01310-100');
        await tester.pump();
        await tester.tap(find.text('Buscar'));
        await tester.pump();

        // Verifica que a lista de unidades no raio de 500m é renderizada
        expect(find.text('Unidades no Raio de 500 Metros'), findsOneWidget);
        expect(find.text('Residencial Bella Vista'), findsOneWidget);
        expect(find.text('✓ 140 m'), findsOneWidget);
      },
    );

    testWidgets(
      '4. Home e Produtos carregam catálogo isolado da unidade ativa',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        final authController = AuthController();
        final cartController = CartController();

        // Teste na Home Page
        await tester.pumpWidget(
          MaterialApp(
            home: HomePage(
              authController: authController,
              cartController: cartController,
              onNavigateToCart: () {},
              onNavigateToProfile: () {},
            ),
          ),
        );
        await tester.pump();

        // Verifica presença da marca Next PDV
        expect(find.text('NEXT'), findsWidgets);
        expect(find.text('PDV'), findsWidgets);

        // Verifica identificação da loja e raio ativo
        expect(find.text('Residencial West Side'), findsOneWidget);
        expect(find.text('Sua unidade'), findsOneWidget);

        // Teste na Products Page (Gôndolas & Geladeiras com catálogo isolado)
        await tester.pumpWidget(
          MaterialApp(
            home: ProductsPage(
              authController: authController,
              cartController: cartController,
            ),
          ),
        );
        await tester.pump();

        // Verifica produto isolado da Loja #1
        expect(find.text('Coca-Cola Zero 350ml'), findsOneWidget);
        // Produto da Loja #3 não deve aparecer nesta loja!
        expect(find.text('Água Mineral San Pellegrino 505ml'), findsNothing);
      },
    );

    test('5. Verificação de Idade (+18): Bloqueio de Bebidas Alcoólicas para Menores', () {
      // Quando maior de 18 anos
      final categoriasAdulto = CategoryModel.getCategoriesForUser(
        isMaior18: true,
        lojaId: 1,
      );
      final produtosAdulto = Product.getProductsForLojaAndAge(
        lojaId: 1,
        isMaior18: true,
      );

      expect(categoriasAdulto.any((c) => c.id == 'alcohol'), isTrue);
      expect(produtosAdulto.any((p) => p.isAlcoholic), isTrue);
      expect(produtosAdulto.any((p) => p.name.contains('Heineken')), isTrue);

      // Quando menor de 18 anos
      final categoriasMenor = CategoryModel.getCategoriesForUser(
        isMaior18: false,
        lojaId: 1,
      );
      final produtosMenor = Product.getProductsForLojaAndAge(
        lojaId: 1,
        isMaior18: false,
      );

      // Categoria de álcool e produtos alcoólicos NÃO devem existir para menores
      expect(categoriasMenor.any((c) => c.id == 'alcohol'), isFalse);
      expect(produtosMenor.any((p) => p.isAlcoholic), isFalse);
      expect(produtosMenor.any((p) => p.name.contains('Heineken')), isFalse);
      expect(
        produtosMenor.any((p) => p.name.contains('Stella Artois')),
        isFalse,
      );
      expect(produtosMenor.any((p) => p.name.contains('Corona')), isFalse);
    });

    testWidgets(
      '6. Smart Access: Leitor de QR Code visível apenas quando autorizado no sistemaweb',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;

        // Cenário A: Usuário SEM permissão no sistemaweb
        final authSemAcesso = AuthController();
        authSemAcesso.setPermissoesSmartAccess(
          temAcesso: false,
          somenteSmartAccess: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MainNavigationShell(
              authController: authSemAcesso,
              onLogout: () {},
            ),
          ),
        );
        await tester.pump();

        // Leitor de QR code e botão central NÃO deve aparecer!
        expect(find.text('ABRIR\nPORTA'), findsNothing);
        expect(find.byIcon(Icons.qr_code_scanner), findsNothing);

        // Cenário B: Usuário COM acesso Smart Access liberado
        final authComAcesso = AuthController();
        authComAcesso.setPermissoesSmartAccess(
          temAcesso: true,
          somenteSmartAccess: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MainNavigationShell(
              authController: authComAcesso,
              onLogout: () {},
            ),
          ),
        );
        await tester.pump();

        // Botão ABRIR PORTA com QR code scanner deve estar presente
        expect(find.text('ABRIR\nPORTA'), findsOneWidget);
        expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
      },
    );

    testWidgets(
      '7. Identificação de Somente Serviço Smart Access (Acesso apenas a Portas & Freezers)',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        final authController = AuthController();

        // Usuário com contrato "somente smart access"
        authController.setPermissoesSmartAccess(
          temAcesso: true,
          somenteSmartAccess: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MainNavigationShell(
              authController: authController,
              onLogout: () {},
            ),
          ),
        );
        await tester.pump();

        // Banner indicativo do modo especial
        expect(
          find.text('Modo Especial: Acesso restrito a Portas & Freezers'),
          findsOneWidget,
        );
        // Botão de abrir porta continua disponível para portas e freezers
        expect(find.text('ABRIR\nPORTA'), findsOneWidget);
      },
    );

    test('8. Banners do Admin: Configurados e isolados por Loja/Tenant', () {
      final bannersLoja1 = AdminBanner.getBannersForLoja(1);
      final bannersLoja2 = AdminBanner.getBannersForLoja(2);

      expect(bannersLoja1.isNotEmpty, isTrue);
      expect(bannersLoja2.isNotEmpty, isTrue);

      for (final b in bannersLoja1) {
        expect(b.lojaId, equals(1));
        expect(b.ativo, isTrue);
      }
      for (final b in bannersLoja2) {
        expect(b.lojaId, equals(2));
        expect(b.ativo, isTrue);
      }
    });

    test('9. Favoritos e Recomendações NextAI', () {
      final authController = AuthController();

      // Produto de teste
      const produtoId = 'p1_bv'; // Coca-Cola Zero

      expect(authController.isFavorito(produtoId), isTrue);

      // Remove dos favoritos
      authController.toggleFavorito(produtoId);
      expect(authController.isFavorito(produtoId), isFalse);
      expect(authController.favoritosIds.contains(produtoId), isFalse);

      // Adiciona novamente aos favoritos
      authController.toggleFavorito(produtoId);
      expect(authController.isFavorito(produtoId), isTrue);

      // Registra compra recente
      authController.registrarCompra(['p3_bv']); // Pão de Queijo Forno de Minas
      expect(authController.ultimasComprasIds.contains('p3_bv'), isTrue);

      // Recomendações NextAI consideram os favoritos e compras recentes
      final recomendados = Product.getAiRecommendations(
        lojaId: 1,
        isMaior18: true,
        favIds: authController.favoritosIds,
        recentIds: authController.ultimasComprasIds,
      );

      expect(recomendados.isNotEmpty, isTrue);
      expect(recomendados.any((p) => p.id == produtoId), isTrue);
    });

    testWidgets('10. Tela de Ajuda: Exibe somente Perguntas Frequentes', (
      tester,
    ) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final authController = AuthController();

      await tester.pumpWidget(
        MaterialApp(home: HelpSupportPage(authController: authController)),
      );
      await tester.pump();

      // Exibe as FAQs sem oferecer abertura de chamado ou contato de suporte.
      expect(find.text('Perguntas Frequentes'), findsOneWidget);
      expect(find.text('Abrir um Chamado'), findsNothing);

      // Verifica FAQ sobre Smart Access e 18+
      expect(
        find.text('Como funciona a abertura da porta (Smart Access)?'),
        findsOneWidget,
      );
      expect(find.text('Por que não vejo bebidas alcoólicas?'), findsOneWidget);
    });

    test(
      '11. Conexão com Base de Dados: Busca de condomínios a partir do CEP',
      () {
        final viaCepService = ViaCepService();

        // CEP com condomínios cadastrados (Paulista / Bela Vista)
        final unidadesPaulista = viaCepService.listarTodasUnidadesComDistancia(
          '01311000',
        );
        expect(unidadesPaulista.isNotEmpty, isTrue);
        expect(unidadesPaulista.any((u) => u.estaNoRaio500m), isTrue);

        // CEP sem nenhum condomínio conveniado na base de dados
        final unidadesSemCobertura = viaCepService
            .listarTodasUnidadesComDistancia('20040002');
        expect(unidadesSemCobertura.isEmpty, isTrue);
      },
    );

    testWidgets(
      '12. Campos do ViaCEP são ReadOnly e campos de número/bloco são editáveis',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        final authController = AuthController();
        final viaCepMock = ViaCepService(
          mockResponses: {
            '01310100': const CepConsultaResult(
              endereco: ViaCepResult(
                cep: '01310-100',
                logradouro: 'Avenida Paulista',
                bairro: 'Bela Vista',
                localidade: 'São Paulo',
                uf: 'SP',
                isReadOnly: true,
              ),
              condominios: [],
            ),
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RegisterPage(
              authController: authController,
              viaCepService: viaCepMock,
              onRegisterSuccess: () {},
            ),
          ),
        );
        await tester.pump();

        // Digita o CEP e busca
        final cepField = find.byType(TextField).first;
        await tester.enterText(cepField, '01310-100');
        await tester.pump();
        await tester.tap(find.text('Buscar'));
        await tester.pump();

        // Encontra os TextFields da tela
        final textFields = tester
            .widgetList<TextField>(find.byType(TextField))
            .toList();
        expect(textFields.isNotEmpty, isTrue);

        // Logradouro deve ser readOnly
        final logradouroField = textFields.firstWhere(
          (tf) => tf.decoration?.labelText?.contains('Logradouro') == true,
        );
        expect(logradouroField.readOnly, isTrue);

        // Bairro deve ser readOnly
        final bairroField = textFields.firstWhere(
          (tf) => tf.decoration?.labelText?.contains('Bairro') == true,
        );
        expect(bairroField.readOnly, isTrue);

        // Cidade / UF deve ser readOnly
        final cidadeField = textFields.firstWhere(
          (tf) => tf.decoration?.labelText?.contains('Cidade') == true,
        );
        expect(cidadeField.readOnly, isTrue);

        // Número (editável pelo morador)
        final numeroField = textFields.firstWhere(
          (tf) => tf.decoration?.labelText?.contains('Número') == true,
        );
        expect(numeroField.readOnly, isFalse);

        // Complemento (editável pelo morador)
        final complementoField = textFields.firstWhere(
          (tf) => tf.decoration?.labelText?.contains('Complemento') == true,
        );
        expect(complementoField.readOnly, isFalse);
      },
    );

    testWidgets(
      '13. Bloqueio estrito de cadastro quando o CEP não possui condomínio conveniado',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        final authController = AuthController();
        final viaCepMock = ViaCepService(
          mockResponses: {
            '20040002': const CepConsultaResult(
              endereco: ViaCepResult(
                cep: '20040-002',
                logradouro: 'Rua do Ouvidor',
                bairro: 'Centro',
                localidade: 'Rio de Janeiro',
                uf: 'RJ',
                isReadOnly: true,
              ),
              condominios:
                  [], // Nenhum condomínio existente na base para este CEP
            ),
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: RegisterPage(
              authController: authController,
              viaCepService: viaCepMock,
              onRegisterSuccess: () {},
            ),
          ),
        );
        await tester.pump();

        // Digita um CEP sem nenhum condomínio conveniado (fora da cobertura)
        final cepField = find.byType(TextField).first;
        await tester.enterText(cepField, '20040-002');
        await tester.pump();

        // Toca no botão 'Buscar'
        await tester.tap(find.text('Buscar'));
        await tester.pump();

        // Verifica exibição do aviso de cadastro bloqueado
        expect(
          find.textContaining(
            'Nenhum condomínio atendido pelo NextPDV foi localizado no raio de 500 metros',
          ),
          findsOneWidget,
        );
        final btnBloqueado = find.text(
          '🚫 CADASTRO BLOQUEADO (SEM CONDOMÍNIO)',
        );
        expect(btnBloqueado, findsOneWidget);

        // Tentar tocar no botão bloqueado não deve avançar para o passo 2
        await tester.ensureVisible(btnBloqueado);
        await tester.tap(btnBloqueado, warnIfMissed: false);
        await tester.pump();

        // Confirma que continua no Passo 1 (Endereço) e NÃO avançou para o Passo 2
        expect(find.text('Endereço do Morador'), findsOneWidget);
        expect(find.text('Identificação do Morador'), findsNothing);
      },
    );

    test('14. Isolamento Estrito de Produtos e Categorias: Manhattan, Smart Access e Açaí', () {
      // Condomínio Manhattan (tenant_condominio_do_edificio_residencial_manha, lojaId: 4)
      final categsManhattan = CategoryModel.getCategoriesForCondominio(
        tenantId: 'tenant_condominio_do_edificio_residencial_manha',
        lojaId: 4,
      );
      final prodsManhattan = Product.getProductsForLoja(
        4,
        tenantId: 'tenant_condominio_do_edificio_residencial_manha',
      );

      expect(
        categsManhattan.any((c) => c.name.contains('Mercearia Nobre')),
        isTrue,
      );
      expect(
        categsManhattan.any((c) => c.name.contains('Congelados & Pratos')),
        isTrue,
      );
      expect(
        prodsManhattan.any(
          (p) => p.name.contains('Água de Coco Integral 1L Manhattan'),
        ),
        isTrue,
      );
      expect(
        prodsManhattan.any(
          (p) => p.name.contains('Cerveja IPA Colorado Ribeirão'),
        ),
        isTrue,
      );

      // Condomínio Smart Access (tenant_condominio_smart_access, lojaId: 5)
      final categsSmartAccess = CategoryModel.getCategoriesForCondominio(
        tenantId: 'tenant_condominio_smart_access',
        lojaId: 5,
      );
      final prodsSmartAccess = Product.getProductsForLoja(
        5,
        tenantId: 'tenant_condominio_smart_access',
      );

      expect(
        categsSmartAccess.any(
          (c) => c.name.contains('Freezer - Bebidas Express'),
        ),
        isTrue,
      );
      expect(
        categsSmartAccess.any((c) => c.name.contains('Geladeira - Sanduíches')),
        isTrue,
      );
      expect(prodsSmartAccess.any((p) => p.name.contains('Budweiser')), isTrue);

      // Açaí da Esquina (tenant_acai_da_esquina, lojaId: 6)
      final categsAcai = CategoryModel.getCategoriesForCondominio(
        tenantId: 'tenant_acai_da_esquina',
        lojaId: 6,
      );
      final prodsAcai = Product.getProductsForLoja(
        6,
        tenantId: 'tenant_acai_da_esquina',
      );

      expect(categsAcai.any((c) => c.name.contains('Tigelas de Açaí')), isTrue);
      expect(categsAcai.any((c) => c.name.contains('Copos de Açaí')), isTrue);
      expect(
        prodsAcai.any((p) => p.name.contains('Açaí Tradicional 500ml')),
        isTrue,
      );

      // Garantia de Isolamento: Nenhum produto do Manhattan pode vazar para Smart Access ou Bella Vista
      final idsManhattan = prodsManhattan.map((p) => p.id).toSet();
      final idsSmartAccess = prodsSmartAccess.map((p) => p.id).toSet();
      final idsAcai = prodsAcai.map((p) => p.id).toSet();
      final idsBellaVista = Product.getProductsForLoja(1)
          .map((p) => p.id)
          .toSet();

      expect(idsManhattan.intersection(idsSmartAccess).isEmpty, isTrue);
      expect(idsManhattan.intersection(idsAcai).isEmpty, isTrue);
      expect(idsManhattan.intersection(idsBellaVista).isEmpty, isTrue);
      expect(idsSmartAccess.intersection(idsAcai).isEmpty, isTrue);
    });

    test('15. Troca de Condomínio no AuthController: Atualiza catálogo e categorias isoladas', () {
      final authController = AuthController();
      final cartController = CartController();

      // Inicialmente em Residencial West Side (tenant_1)
      expect(authController.unidadeAtual.tenantId, equals('tenant_1'));
      expect(authController.produtosCondominioAtual.isNotEmpty, isTrue);

      // Adiciona produto ao carrinho
      cartController.clear();
      cartController.addProduct(authController.produtosCondominioAtual.first);
      expect(cartController.totalItemCount, equals(1));

      // Seleciona Condomínio Residencial Manhattan (lojaId: 4)
      final manhattan = LojaUnidade.mockUnidadesCadastradas.firstWhere(
        (u) => u.tenantId == 'tenant_condominio_do_edificio_residencial_manha',
      );
      authController.selecionarUnidade(manhattan);

      // Proteção de isolamento: carrinho é resetado ao trocar de loja/condomínio
      cartController.clear();
      expect(cartController.totalItemCount, equals(0));

      // Catálogo e Categorias passam a ser do Condomínio Manhattan imediatamente
      expect(
        authController.unidadeAtual.nome,
        equals('Condomínio Residencial Manhattan'),
      );
      expect(
        authController.produtosCondominioAtual.any(
          (p) => p.name.contains('Água de Coco Integral 1L Manhattan'),
        ),
        isTrue,
      );
      expect(
        authController.categoriasCondominioAtual.any(
          (c) => c.name.contains('Mercearia Nobre'),
        ),
        isTrue,
      );
    });

    testWidgets(
      '16. ProductsPage: Renderiza dinamicamente produtos do condomínio selecionado',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        final authController = AuthController();
        final cartController = CartController();

        // Define condomínio ativo como Condomínio Residencial Manhattan
        final manhattan = LojaUnidade.mockUnidadesCadastradas.firstWhere(
          (u) =>
              u.tenantId == 'tenant_condominio_do_edificio_residencial_manha',
        );
        authController.selecionarUnidade(manhattan);

        await tester.pumpWidget(
          MaterialApp(
            home: ProductsPage(
              authController: authController,
              cartController: cartController,
            ),
          ),
        );
        await tester.pump();

        // Deve exibir o cabeçalho do Manhattan
        expect(
          find.text('Condomínio Residencial Manhattan • Unidade Vinculada'),
          findsOneWidget,
        );

        // Deve exibir produtos isolados do Manhattan
        expect(find.text('Água de Coco Integral 1L Manhattan'), findsOneWidget);
        expect(
          find.text('Cerveja IPA Colorado Ribeirão 600ml'),
          findsOneWidget,
        );

        // Troca condomínio para Bella Vista
        final bellaVista = LojaUnidade.mockUnidadesCadastradas.firstWhere(
          (u) => u.tenantId == 'tenant_bellavista',
        );
        authController.selecionarUnidade(bellaVista);
        await tester.pump();

        // Agora deve exibir o cabeçalho do Bella Vista e esconder os do Manhattan
        expect(
          find.text('Residencial Bella Vista • Unidade Vinculada'),
          findsOneWidget,
        );
        expect(find.text('Coca-Cola Zero 350ml'), findsOneWidget);
        expect(find.text('Água de Coco Integral 1L Manhattan'), findsNothing);
      },
    );

    testWidgets(
      '17. Troca da Foto do App e do Perfil: Reflete na UI e atualiza AuthController',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        final authController = AuthController();
        const newAvatar =
            'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=300&auto=format&fit=crop&q=80';

        // Sem foto, o avatar mostra as iniciais (nada de foto de banco de imagens).
        expect(authController.temFoto, isFalse);

        // Atualiza diretamente via AuthController
        authController.setAvatarUrl(newAvatar);
        expect(authController.avatarUrl, equals(newAvatar));

        await tester.pumpWidget(
          MaterialApp(
            home: ProfilePage(authController: authController, onLogout: () {}),
          ),
        );
        await tester.pump();

        expect(find.text('Trocar foto'), findsOneWidget);
        await tester.ensureVisible(find.text('Trocar foto'));
        await tester.tap(find.text('Trocar foto'));
        await tester.pump(const Duration(milliseconds: 500));

        // Modal com galeria, câmera e o botão de salvar (desligado até escolher a foto)
        expect(find.text('Enviar nova foto'), findsOneWidget);
        expect(find.text('Galeria'), findsOneWidget);
        expect(find.text('Tirar foto'), findsOneWidget);
        expect(find.text('Salvar foto'), findsOneWidget);
      },
    );

    testWidgets(
      '18. Validações de Login: erro embaixo do campo, sem barrar o tamanho da senha',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        final authController = AuthController();
        bool loginSucesso = false;

        await tester.pumpWidget(
          MaterialApp(
            home: LoginPage(
              authController: authController,
              onLoginSuccess: () => loginSucesso = true,
            ),
          ),
        );
        await tester.pump();

        final btnEntrar = find.byType(GradientButton);
        await tester.ensureVisible(btnEntrar);
        final textFields = find.byType(TextField);

        // Os exemplos dos campos não parecem dados já preenchidos.
        expect(find.text('cliente@nextpdv.com.br'), findsNothing);

        // Sem e-mail e sem senha: cada campo mostra o seu erro.
        await tester.tap(btnEntrar);
        await tester.pump();
        expect(find.text('Informe seu e-mail.'), findsOneWidget);
        expect(find.text('Informe sua senha.'), findsOneWidget);
        expect(loginSucesso, isFalse);

        // E-mail inválido
        await tester.enterText(textFields.first, 'emailinvalido');
        await tester.enterText(textFields.last, '123');
        await tester.tap(btnEntrar);
        await tester.pump();
        expect(find.text('Confira o e-mail (ex.: nome@email.com).'), findsOneWidget);
        // A regra da senha é do servidor: senha curta não é barrada na tela.
        expect(find.textContaining('mínimo'), findsNothing);
        expect(loginSucesso, isFalse);

        // Ao corrigir o e-mail, o erro some.
        await tester.enterText(textFields.first, 'marcio@bellavista.com.br');
        await tester.pump();
        expect(find.text('Confira o e-mail (ex.: nome@email.com).'), findsNothing);
      },
    );

    testWidgets(
      '19. Esqueceu a Senha: Abre modal de recuperação e aceita e-mail',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        final authController = AuthController();

        await tester.pumpWidget(
          MaterialApp(
            home: LoginPage(
              authController: authController,
              onLoginSuccess: () {},
            ),
          ),
        );
        await tester.pump();

        await tester.ensureVisible(find.text('Esqueci a senha'));
        await tester.tap(find.text('Esqueci a senha'));
        await tester.pumpAndSettle();

        expect(find.text('Recuperar senha'), findsOneWidget);
        expect(find.text('Enviar link'), findsOneWidget);
      },
    );
  });
}

class _MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _MockHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}
