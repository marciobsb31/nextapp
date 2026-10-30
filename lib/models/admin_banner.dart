class AdminBanner {
  final String id;
  final String title;
  final String subtitle;
  final String tag;
  final String color1;
  final String color2;
  final int lojaId;
  final String? imageUrl;
  final String? videoUrl;
  final String? link;
  final List<int> produtoIds;
  final String? targetCategory;
  final bool ativo;

  const AdminBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.color1,
    required this.color2,
    required this.lojaId,
    this.imageUrl,
    this.videoUrl,
    this.link,
    this.produtoIds = const [],
    this.targetCategory,
    this.ativo = true,
  });

  factory AdminBanner.fromJson(Map<String, dynamic> json) {
    String corFundo = json['corFundo']?.toString().trim() ?? '';
    String c1 = json['color1']?.toString() ?? '0xFFFF8C00';
    String c2 = json['color2']?.toString() ?? '0xFFFF5500';
    if (corFundo.isNotEmpty) {
      if (corFundo.startsWith('#') && corFundo.length == 7) {
        final hex = corFundo.substring(1);
        c1 = '0xFF$hex';
        c2 = '0xFF$hex';
      } else if (corFundo.startsWith('0x') || corFundo.startsWith('0X')) {
        c1 = corFundo;
        c2 = corFundo;
      }
    }

    final pIds = <int>[];
    if (json['produtoIds'] is List) {
      for (final p in (json['produtoIds'] as List)) {
        if (p is num) pIds.add(p.toInt());
      }
    }

    final img = json['imagemUrl']?.toString() ?? json['imageUrl']?.toString();
    final finalImg = (img != null && img.trim().isNotEmpty) ? img.trim() : null;

    return AdminBanner(
      id: json['id']?.toString() ?? '',
      title: json['titulo']?.toString() ?? json['title']?.toString() ?? '',
      subtitle: json['subtitulo']?.toString() ?? json['subtitle']?.toString() ?? '',
      tag: json['selo']?.toString() ?? json['tag']?.toString() ?? 'DESTAQUE',
      color1: c1,
      color2: c2,
      lojaId: (json['lojaId'] as num?)?.toInt() ?? 1,
      imageUrl: finalImg,
      videoUrl: json['videoUrl']?.toString(),
      link: json['link']?.toString(),
      produtoIds: pIds,
      targetCategory: json['targetCategory']?.toString(),
      ativo: json['ativo'] == null ? true : json['ativo'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'tag': tag,
        'color1': color1,
        'color2': color2,
        'lojaId': lojaId,
        'imageUrl': imageUrl,
        'targetCategory': targetCategory,
        'ativo': ativo,
      };

  /// Mock de banners cadastrados e configuráveis no Painel Admin por Loja
  static List<AdminBanner> get defaultAdminBanners => const [
        // Banners Loja 1: Bella Vista
        AdminBanner(
          id: 'b1_bv',
          lojaId: 1,
          title: 'Compre sem Filas 24h',
          subtitle: 'Acesse o condomínio, pegue seus itens e pague no app',
          tag: 'AUTÔNOMO',
          color1: '0xFFFF8C00',
          color2: '0xFFFF5500',
          targetCategory: 'all',
          ativo: true,
        ),
        AdminBanner(
          id: 'b2_bv',
          lojaId: 1,
          title: 'Oferta Especial do Bloco',
          subtitle: 'Pizzas artesanais e cafés especiais com até 20% OFF',
          tag: 'ADMIN BELLA VISTA',
          color1: '0xFF0F172A',
          color2: '0xFF1E293B',
          targetCategory: 'frozen',
          ativo: true,
        ),
        AdminBanner(
          id: 'b3_bv',
          lojaId: 1,
          title: 'Geladeiras Reabastecidas',
          subtitle: 'Bebidas geladas e snacks premium para sua semana',
          tag: 'ESTOQUE NOVO',
          color1: '0xFF1E1B4B',
          color2: '0xFF3730A3',
          targetCategory: 'drinks',
          ativo: true,
        ),

        // Banners Loja 2: Parque dos Jardins
        AdminBanner(
          id: 'b1_pj',
          lojaId: 2,
          title: 'Novidades no Parque dos Jardins',
          subtitle: 'Energéticos Red Bull e lanches gourmet disponíveis',
          tag: 'EXCLUSIVO JARDINS',
          color1: '0xFF0F172A',
          color2: '0xFF0284C7',
          targetCategory: 'drinks',
          ativo: true,
        ),
        AdminBanner(
          id: 'b2_pj',
          lojaId: 2,
          title: 'Hora do Lanche Saudável',
          subtitle: 'Sucos integrais e castanhas selecionadas',
          tag: 'HEALTHY',
          color1: '0xFF059669',
          color2: '0xFF10B981',
          targetCategory: 'snacks',
          ativo: true,
        ),
      ];

  /// Obtém os banners ativos configurados pelo Admin para a loja indicada
  static List<AdminBanner> getBannersForLoja(int lojaId) {
    final banners = defaultAdminBanners
        .where((b) => b.lojaId == lojaId && b.ativo)
        .toList();
    if (banners.isEmpty) {
      // Fallback seguro com banner padrão
      return [
        AdminBanner(
          id: 'b_generic_$lojaId',
          lojaId: lojaId,
          title: 'NextPDV Mercado Autônomo',
          subtitle: 'Produtos selecionados 24 horas no seu condomínio',
          tag: 'NEXTPDV',
          color1: '0xFFFF8C00',
          color2: '0xFFFF5500',
          ativo: true,
        ),
      ];
    }
    return banners;
  }
}
