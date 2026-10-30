class Product {
  final String id;
  final String name;
  final String category;
  final double price;
  final double? originalPrice;
  final String imageUrl;
  final String unit;
  final String description;
  final bool isPromo;
  final int lojaId;
  final String tenantId;
  final bool isAlcoholic;
  final bool disponivel;
  final int estoque;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.originalPrice,
    required this.imageUrl,
    this.unit = 'un',
    this.description = '',
    this.isPromo = false,
    this.lojaId = 1,
    this.tenantId = 'tenant_1',
    this.isAlcoholic = false,
    this.disponivel = true,
    this.estoque = 1,
  });

  factory Product.fromJson(Map<String, dynamic> json, {String? tenantId, int? lojaId}) {
    final preco = (json['preco'] as num?)?.toDouble() ??
        (json['price'] as num?)?.toDouble() ??
        0.0;
    final precoPromo = (json['precoPromocional'] as num?)?.toDouble() ??
        (json['originalPrice'] as num?)?.toDouble();
    final nome = json['nome']?.toString() ?? json['name']?.toString() ?? '';

    String catNome = 'Geral';
    if (json['categoria'] is Map) {
      catNome = (json['categoria'] as Map)['nome']?.toString() ?? 'Geral';
    } else if (json['categoriaNome'] != null) {
      catNome = json['categoriaNome'].toString();
    } else if (json['categoria'] != null) {
      catNome = json['categoria'].toString();
    } else if (json['category'] != null) {
      catNome = json['category'].toString();
    }

    final isAlcool = json['isAlcoholic'] == true ||
        catNome.toLowerCase().contains('alcoól') ||
        catNome.toLowerCase().contains('alcool') ||
        catNome.toLowerCase().contains('cerveja') ||
        catNome.toLowerCase().contains('vinho') ||
        nome.toLowerCase().contains('cerveja') ||
        nome.toLowerCase().contains('vinho') ||
        nome.toLowerCase().contains('heineken') ||
        nome.toLowerCase().contains('amstel') ||
        nome.toLowerCase().contains('stella') ||
        nome.toLowerCase().contains('budweiser');

    final img = json['imagemUrl']?.toString() ?? json['imageUrl']?.toString();
    final finalImg = (img != null && img.trim().isNotEmpty) ? img.trim() : '';

    int qtdEstoque = 1;
    if (json['estoque'] is Map) {
      final q = (json['estoque'] as Map)['quantidade'];
      if (q is num) qtdEstoque = q.toInt();
    } else if (json['estoque'] is num) {
      qtdEstoque = (json['estoque'] as num).toInt();
    } else if (json['quantidade'] is num) {
      qtdEstoque = (json['quantidade'] as num).toInt();
    }

    final bool isDisp = (json['disponivel'] != false) && (qtdEstoque > 0);

    return Product(
      id: json['id']?.toString() ?? 'prod_${DateTime.now().millisecondsSinceEpoch}',
      name: nome,
      category: catNome,
      price: precoPromo != null && precoPromo > 0 && precoPromo < preco ? precoPromo : preco,
      originalPrice: precoPromo != null && precoPromo > 0 && precoPromo < preco ? preco : null,
      imageUrl: finalImg,
      unit: json['unidadeMedida']?.toString() ?? json['unit']?.toString() ?? 'un',
      description: json['descricao']?.toString() ?? json['description']?.toString() ?? '',
      isPromo: precoPromo != null && precoPromo > 0,
      lojaId: (json['lojaId'] as num?)?.toInt() ?? lojaId ?? 1,
      tenantId: json['tenantId']?.toString() ?? tenantId ?? 'tenant_1',
      isAlcoholic: isAlcool,
      disponivel: isDisp,
      estoque: qtdEstoque,
    );
  }

  /// Retorna os produtos isolados estritamente para o condomínio/unidade selecionada
  static List<Product> getProductsForLoja(int lojaId, {String? tenantId}) {
    return mockProducts.where((p) {
      if (tenantId != null && tenantId.isNotEmpty) {
        if (tenantId == 'tenant_1' && (p.lojaId == 1 || p.tenantId == 'tenant_bellavista')) {
          return true;
        }
        return p.tenantId == tenantId;
      }
      return p.lojaId == lojaId;
    }).toList();
  }

  /// Retorna os produtos respeitando o isolamento do condomínio E a verificação de maioridade (18+)
  static List<Product> getProductsForLojaAndAge({
    required int lojaId,
    String? tenantId,
    required bool isMaior18,
  }) {
    return mockProducts.where((p) {
      if (tenantId != null && tenantId.isNotEmpty) {
        if (tenantId == 'tenant_1' && (p.lojaId == 1 || p.tenantId == 'tenant_bellavista')) {
          // match
        } else if (p.tenantId != tenantId) {
          return false;
        }
      } else {
        if (p.lojaId != lojaId) return false;
      }
      // Regra 18+: Se o usuário for menor de idade, remove qualquer produto alcoólico
      if (!isMaior18 && p.isAlcoholic) return false;
      return true;
    }).toList();
  }

  /// Retorna lista de produtos com base em conjunto de IDs
  static List<Product> getProductsByIds(Iterable<String> ids) {
    return mockProducts.where((p) => ids.contains(p.id)).toList();
  }

  /// Recomendação por Inteligência Artificial (NextAI):
  /// Cruza produtos comprados recentemente e favoritos com a base real do condomínio.
  /// Só exibe se houver histórico real e produtos com estoque > 0 na base.
  static List<Product> getAiRecommendations({
    required int lojaId,
    String? tenantId,
    required bool isMaior18,
    Set<String>? favIds,
    List<String>? recentIds,
    List<Product>? baseProdutos,
  }) {
    final Set<String> prioridades = {...?recentIds, ...?favIds};
    // Regra de negócio: Recomendações só devem aparecer se o usuário já tiver feito compra ou favoritado
    if (prioridades.isEmpty) {
      return const [];
    }

    final List<Product> base = baseProdutos ??
        getProductsForLojaAndAge(
          lojaId: lojaId,
          tenantId: tenantId,
          isMaior18: isMaior18,
        );

    // Filtra estritamente produtos da base real que estejam disponíveis e em estoque
    return base
        .where((p) => prioridades.contains(p.id) && p.disponivel && p.estoque > 0)
        .toList();
  }

  static List<Product> get mockProducts => [
        // ==========================================
        // PRODUTOS ISOLADOS - UNIDADE 1: RESIDENCIAL BELLA VISTA
        // ==========================================
        const Product(
          id: 'p1_bv',
          lojaId: 1,
          tenantId: 'tenant_bellavista',
          name: 'Coca-Cola Zero 350ml',
          category: 'Bebidas',
          price: 5.50,
          originalPrice: 6.90,
          imageUrl: 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=500&auto=format&fit=crop&q=60',
          unit: 'lata 350ml',
          description: 'Refrigerante Coca-Cola sem açúcar geladinho no Bella Vista.',
          isPromo: true,
          isAlcoholic: false,
        ),
        const Product(
          id: 'p2_bv',
          lojaId: 1,
          tenantId: 'tenant_bellavista',
          name: 'Cerveja Heineken Puro Malte 330ml',
          category: 'Bebidas Alcoólicas',
          price: 7.90,
          imageUrl: 'https://images.unsplash.com/photo-1608270546103-97992982d56a?w=500&auto=format&fit=crop&q=60',
          unit: 'long neck 330ml',
          description: 'Cerveja Premium puro malte gelada. Proibida para menores de 18 anos.',
          isPromo: false,
          isAlcoholic: true, // Álcool -> Restrito a +18
        ),
        const Product(
          id: 'p3_bv',
          lojaId: 1,
          tenantId: 'tenant_bellavista',
          name: 'Batata Pringles Original 114g',
          category: 'Lanches',
          price: 14.90,
          originalPrice: 17.50,
          imageUrl: 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=500&auto=format&fit=crop&q=60',
          unit: 'tubo 114g',
          description: 'Batata crocante e salgada sabor original clássico.',
          isPromo: true,
          isAlcoholic: false,
        ),
        const Product(
          id: 'p4_bv',
          lojaId: 1,
          tenantId: 'tenant_bellavista',
          name: 'Chocolate Lindt Excellence 70%',
          category: 'Lanches',
          price: 24.90,
          imageUrl: 'https://images.unsplash.com/photo-1549007994-cb92caebd54b?w=500&auto=format&fit=crop&q=60',
          unit: 'barra 100g',
          description: 'Chocolate suíço amargo 70% cacau refinado.',
          isPromo: false,
          isAlcoholic: false,
        ),
        const Product(
          id: 'p5_bv',
          lojaId: 1,
          tenantId: 'tenant_bellavista',
          name: 'Pizza Artesanal Quatro Queijos',
          category: 'Congelados',
          price: 32.90,
          originalPrice: 38.00,
          imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500&auto=format&fit=crop&q=60',
          unit: '450g congelada',
          description: 'Massa de fermentação natural com queijos nobres selecionados.',
          isPromo: true,
          isAlcoholic: false,
        ),
        const Product(
          id: 'p6_bv',
          lojaId: 1,
          tenantId: 'tenant_bellavista',
          name: 'Café Especial Moído Torrado 250g',
          category: 'Mercearia',
          price: 19.80,
          imageUrl: 'https://images.unsplash.com/photo-1559056199-641a0ac8b55e?w=500&auto=format&fit=crop&q=60',
          unit: 'pacote 250g',
          description: 'Grãos 100% arábica do Sul de Minas com notas de caramelo.',
          isPromo: false,
          isAlcoholic: false,
        ),
        const Product(
          id: 'p7_bv',
          lojaId: 1,
          tenantId: 'tenant_bellavista',
          name: 'Sorvete Häagen-Dazs Dulce de Leche',
          category: 'Congelados',
          price: 39.90,
          imageUrl: 'https://images.unsplash.com/photo-1570197788417-0e82375c9371?w=500&auto=format&fit=crop&q=60',
          unit: 'pote 473ml',
          description: 'Sorvete super premium com pedaços crocantes e calda de doce de leite.',
          isPromo: false,
          isAlcoholic: false,
        ),
        const Product(
          id: 'p8_bv',
          lojaId: 1,
          tenantId: 'tenant_bellavista',
          name: 'Pão de Queijo Mineiro Congelado 400g',
          category: 'Congelados',
          price: 16.50,
          imageUrl: 'https://images.unsplash.com/photo-1563729784474-d77dbb933a9e?w=500&auto=format&fit=crop&q=60',
          unit: 'pacote 400g',
          description: 'Receita tradicional da canastra com queijo curado.',
          isPromo: false,
          isAlcoholic: false,
        ),

        // ==========================================
        // PRODUTOS ISOLADOS - UNIDADE 2: PARQUE DOS JARDINS
        // ==========================================
        const Product(
          id: 'p1_pj',
          lojaId: 2,
          tenantId: 'tenant_parquejardins',
          name: 'Energético Red Bull Energy 250ml',
          category: 'Bebidas',
          price: 9.90,
          originalPrice: 11.50,
          imageUrl: 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=500&auto=format&fit=crop&q=60',
          unit: 'lata 250ml',
          description: 'Vitaliza mente e corpo geladinho na gôndola do Parque dos Jardins.',
          isPromo: true,
          isAlcoholic: false,
        ),
        const Product(
          id: 'p2_pj',
          lojaId: 2,
          tenantId: 'tenant_parquejardins',
          name: 'Cerveja Stella Artois Pure Gold 330ml',
          category: 'Bebidas Alcoólicas',
          price: 8.50,
          imageUrl: 'https://images.unsplash.com/photo-1584225064785-c62a8b43d148?w=500&auto=format&fit=crop&q=60',
          unit: 'long neck 330ml',
          description: 'Sem glúten com todo o sabor da tradicional Stella. Venda restrita a maiores de 18 anos.',
          isPromo: false,
          isAlcoholic: true, // Álcool -> Restrito a +18
        ),
        const Product(
          id: 'p3_pj',
          lojaId: 2,
          tenantId: 'tenant_parquejardins',
          name: 'Castanha de Caju Torrada Salgada 150g',
          category: 'Lanches',
          price: 18.90,
          imageUrl: 'https://images.unsplash.com/photo-1536591375315-1b836814d455?w=500&auto=format&fit=crop&q=60',
          unit: 'pote 150g',
          description: 'Castanhas inteiras selecionadas com sal marinho.',
          isPromo: false,
          isAlcoholic: false,
        ),
        const Product(
          id: 'p4_pj',
          lojaId: 2,
          tenantId: 'tenant_parquejardins',
          name: 'Lasanha Bolonhesa Gourmet 600g',
          category: 'Congelados',
          price: 29.90,
          originalPrice: 34.00,
          imageUrl: 'https://images.unsplash.com/photo-1574894709920-11b28e7367e3?w=500&auto=format&fit=crop&q=60',
          unit: 'porção 600g',
          description: 'Molho bolonhesa artesanal com queijo gratinado.',
          isPromo: true,
          isAlcoholic: false,
        ),
        const Product(
          id: 'p5_pj',
          lojaId: 2,
          tenantId: 'tenant_parquejardins',
          name: 'Suco de Laranja Integral 1L',
          category: 'Bebidas',
          price: 11.90,
          imageUrl: 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=500&auto=format&fit=crop&q=60',
          unit: 'garrafa 1L',
          description: '100% natural sem adição de açúcar ou conservantes.',
          isPromo: false,
          isAlcoholic: false,
        ),
        const Product(
          id: 'p6_pj',
          lojaId: 2,
          tenantId: 'tenant_parquejardins',
          name: 'Biscoito Waffle Holandês Stroopwafel',
          category: 'Mercearia',
          price: 15.40,
          imageUrl: 'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=500&auto=format&fit=crop&q=60',
          unit: 'pacote 200g',
          description: 'Waffle recheado com caramelo e especiarias.',
          isPromo: false,
          isAlcoholic: false,
        ),

        // ==========================================
        // PRODUTOS ISOLADOS - UNIDADE 3: ALTO DA SERRA (ISOLADA)
        // ==========================================
        const Product(
          id: 'p1_as',
          lojaId: 3,
          tenantId: 'tenant_altodaserra',
          name: 'Água Mineral San Pellegrino 505ml',
          category: 'Bebidas',
          price: 12.50,
          imageUrl: 'https://images.unsplash.com/photo-1548839140-29a749e1bc4e?w=500&auto=format&fit=crop&q=60',
          unit: 'garrafa 505ml',
          description: 'Água mineral natural gaseificada italiana.',
          isPromo: false,
          isAlcoholic: false,
        ),
        const Product(
          id: 'p2_as',
          lojaId: 3,
          tenantId: 'tenant_altodaserra',
          name: 'Cerveja Corona Extra 330ml',
          category: 'Bebidas Alcoólicas',
          price: 8.90,
          imageUrl: 'https://images.unsplash.com/photo-1584225064785-c62a8b43d148?w=500&auto=format&fit=crop&q=60',
          unit: 'long neck 330ml',
          description: 'Cerveja leve com fatia de limão. Proibida a menores de 18 anos.',
          isPromo: true,
          isAlcoholic: true, // Álcool -> Restrito a +18
        ),
        const Product(
          id: 'p3_as',
          lojaId: 3,
          tenantId: 'tenant_altodaserra',
          name: 'Croissant Manteiga Congelado 4 un',
          category: 'Congelados',
          price: 22.90,
          imageUrl: 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=500&auto=format&fit=crop&q=60',
          unit: 'pacote 4 un',
          description: 'Massa folhada francesa pronta para assar em casa.',
          isPromo: false,
          isAlcoholic: false,
        ),

        // ==========================================
        // PRODUTOS ISOLADOS - CONDOMÍNIO RESIDENCIAL MANHATTAN
        // ==========================================
        const Product(
          id: 'p1_manh',
          lojaId: 4,
          tenantId: 'tenant_condominio_do_edificio_residencial_manha',
          name: 'Água de Coco Integral 1L Manhattan',
          category: 'Bebidas',
          price: 9.90,
          originalPrice: 11.50,
          imageUrl: 'https://images.unsplash.com/photo-1550258987-190a2d41a8ba?w=500&auto=format&fit=crop&q=60',
          unit: 'garrafa 1L',
          description: 'Água de coco 100% natural pasteurizada no Condomínio Manhattan.',
          isPromo: true,
          isAlcoholic: false,
        ),
        const Product(
          id: 'p2_manh',
          lojaId: 4,
          tenantId: 'tenant_condominio_do_edificio_residencial_manha',
          name: 'Cerveja IPA Colorado Ribeirão 600ml',
          category: 'Bebidas Alcoólicas',
          price: 15.90,
          imageUrl: 'https://images.unsplash.com/photo-1608270546103-97992982d56a?w=500&auto=format&fit=crop&q=60',
          unit: 'garrafa 600ml',
          description: 'Cerveja artesanal com rapadura. Proibida para menores de 18 anos.',
          isPromo: false,
          isAlcoholic: true,
        ),
        const Product(
          id: 'p3_manh',
          lojaId: 4,
          tenantId: 'tenant_condominio_do_edificio_residencial_manha',
          name: 'Vinho Chileno Cabernet Sauvignon 750ml',
          category: 'Bebidas Alcoólicas',
          price: 44.90,
          originalPrice: 49.90,
          imageUrl: 'https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?w=500&auto=format&fit=crop&q=60',
          unit: 'garrafa 750ml',
          description: 'Vinho tinto seco encorpado. Proibida para menores de 18 anos.',
          isPromo: true,
          isAlcoholic: true,
        ),
        const Product(
          id: 'p4_manh',
          lojaId: 4,
          tenantId: 'tenant_condominio_do_edificio_residencial_manha',
          name: 'Batata Ruffles Costelinha 96g',
          category: 'Lanches & Snacks',
          price: 10.90,
          imageUrl: 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=500&auto=format&fit=crop&q=60',
          unit: 'pacote 96g',
          description: 'Batata frita crocante sabor costelinha com limão.',
          isPromo: false,
          isAlcoholic: false,
        ),
        const Product(
          id: 'p5_manh',
          lojaId: 4,
          tenantId: 'tenant_condominio_do_edificio_residencial_manha',
          name: 'Lasanha Quatro Queijos Sadia 600g',
          category: 'Congelados & Pratos',
          price: 16.50,
          originalPrice: 18.90,
          imageUrl: 'https://images.unsplash.com/photo-1574894709920-11b28e7367e3?w=500&auto=format&fit=crop&q=60',
          unit: '600g congelada',
          description: 'Lasanha com queijo muçarela, provolone, parmesão e gorgonzola.',
          isPromo: true,
          isAlcoholic: false,
        ),
        const Product(
          id: 'p6_manh',
          lojaId: 4,
          tenantId: 'tenant_condominio_do_edificio_residencial_manha',
          name: 'Café Gourmet em Grãos Torrado 500g',
          category: 'Mercearia Nobre',
          price: 34.90,
          imageUrl: 'https://images.unsplash.com/photo-1559056199-641a0ac8b55e?w=500&auto=format&fit=crop&q=60',
          unit: 'pacote 500g',
          description: 'Café especial com notas florais e caramelo.',
          isPromo: false,
          isAlcoholic: false,
        ),

        // ==========================================
        // PRODUTOS ISOLADOS - CONDOMÍNIO SMART ACCESS
        // ==========================================
        const Product(
          id: 'p1_sa',
          lojaId: 5,
          tenantId: 'tenant_condominio_smart_access',
          name: 'Red Bull Energy Drink 250ml Smart',
          category: 'Freezer - Bebidas Express',
          price: 8.90,
          originalPrice: 10.50,
          imageUrl: 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=500&auto=format&fit=crop&q=60',
          unit: 'lata 250ml',
          description: 'Energético geladinho no freezer smart access.',
          isPromo: true,
          isAlcoholic: false,
        ),
        const Product(
          id: 'p2_sa',
          lojaId: 5,
          tenantId: 'tenant_condominio_smart_access',
          name: 'Cerveja Budweiser Long Neck 330ml',
          category: 'Freezer - Alcoólicos (+18)',
          price: 7.90,
          imageUrl: 'https://images.unsplash.com/photo-1584225064785-c62a8b43d148?w=500&auto=format&fit=crop&q=60',
          unit: 'long neck 330ml',
          description: 'Cerveja gelada no freezer de bebidas. Proibida para menores de 18 anos.',
          isPromo: false,
          isAlcoholic: true,
        ),
        const Product(
          id: 'p3_sa',
          lojaId: 5,
          tenantId: 'tenant_condominio_smart_access',
          name: 'Sanduíche Natural de Frango 180g',
          category: 'Geladeira - Sanduíches & Saladas',
          price: 14.50,
          imageUrl: 'https://images.unsplash.com/photo-1509722747041-616f39b57569?w=500&auto=format&fit=crop&q=60',
          unit: 'unidade 180g',
          description: 'Pão integral com pasta de frango e cenoura.',
          isPromo: false,
          isAlcoholic: false,
        ),
        const Product(
          id: 'p4_sa',
          lojaId: 5,
          tenantId: 'tenant_condominio_smart_access',
          name: 'Chocolate KitKat 4 Fingers 41.5g',
          category: 'Lanches & Doces',
          price: 3.90,
          originalPrice: 4.90,
          imageUrl: 'https://images.unsplash.com/photo-1549007994-cb92caebd54b?w=500&auto=format&fit=crop&q=60',
          unit: 'unidade 41.5g',
          description: 'Wafer crocante coberto com chocolate ao leite.',
          isPromo: true,
          isAlcoholic: false,
        ),

        // ==========================================
        // PRODUTOS ISOLADOS - AÇAÍ DA ESQUINA
        // ==========================================
        const Product(
          id: 'p1_acai',
          lojaId: 6,
          tenantId: 'tenant_acai_da_esquina',
          name: 'Açaí Tradicional 500ml',
          category: 'Tigelas de Açaí',
          price: 16.00,
          imageUrl: 'https://images.unsplash.com/photo-1590080875515-8a3a8dc5735e?w=500&auto=format&fit=crop&q=60',
          unit: 'tigela 500ml',
          description: 'Açaí puro com granola e banana.',
          isPromo: false,
          isAlcoholic: false,
        ),
        const Product(
          id: 'p2_acai',
          lojaId: 6,
          tenantId: 'tenant_acai_da_esquina',
          name: 'Açaí com Cupuaçu 500ml',
          category: 'Tigelas de Açaí',
          price: 18.00,
          imageUrl: 'https://images.unsplash.com/photo-1590080875515-8a3a8dc5735e?w=500&auto=format&fit=crop&q=60',
          unit: 'tigela 500ml',
          description: 'Combinação perfeita de açaí cremoso e creme de cupuaçu.',
          isPromo: false,
          isAlcoholic: false,
        ),
        const Product(
          id: 'p3_acai',
          lojaId: 6,
          tenantId: 'tenant_acai_da_esquina',
          name: 'Tigela de Morango Especial',
          category: 'Tigelas de Açaí',
          price: 22.00,
          imageUrl: 'https://images.unsplash.com/photo-1590080875515-8a3a8dc5735e?w=500&auto=format&fit=crop&q=60',
          unit: 'tigela 600ml',
          description: 'Açaí com morangos frescos, leite condensado e leite em pó.',
          isPromo: false,
          isAlcoholic: false,
        ),
        const Product(
          id: 'p4_acai',
          lojaId: 6,
          tenantId: 'tenant_acai_da_esquina',
          name: 'Copo de Açaí com Banana 400ml',
          category: 'Copos de Açaí',
          price: 12.00,
          imageUrl: 'https://images.unsplash.com/photo-1590080875515-8a3a8dc5735e?w=500&auto=format&fit=crop&q=60',
          unit: 'copo 400ml',
          description: 'Copo prático para viagem com camadas de açaí e banana.',
          isPromo: false,
          isAlcoholic: false,
        ),
        const Product(
          id: 'p5_acai',
          lojaId: 6,
          tenantId: 'tenant_acai_da_esquina',
          name: 'Vitamina de Açaí Turbinada',
          category: 'Copos de Açaí',
          price: 14.00,
          imageUrl: 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?w=500&auto=format&fit=crop&q=60',
          unit: 'copo 500ml',
          description: 'Açaí batido com leite, guaraná em pó e banana.',
          isPromo: false,
          isAlcoholic: false,
        ),
        const Product(
          id: 'p6_acai',
          lojaId: 6,
          tenantId: 'tenant_acai_da_esquina',
          name: 'Água de Coco Verde 300ml',
          category: 'Bebidas Naturais',
          price: 6.00,
          imageUrl: 'https://images.unsplash.com/photo-1550258987-190a2d41a8ba?w=500&auto=format&fit=crop&q=60',
          unit: 'copo 300ml',
          description: 'Água de coco tirada na hora bem geladinha.',
          isPromo: false,
          isAlcoholic: false,
        ),
        const Product(
          id: 'p7_acai',
          lojaId: 6,
          tenantId: 'tenant_acai_da_esquina',
          name: 'Barra de Cereal com Avelã',
          category: 'Bebidas Naturais',
          price: 5.00,
          imageUrl: 'https://images.unsplash.com/photo-1549007994-cb92caebd54b?w=500&auto=format&fit=crop&q=60',
          unit: 'unidade 30g',
          description: 'Barra de cereais com castanhas e avelã.',
          isPromo: false,
          isAlcoholic: false,
        ),
      ];
}
