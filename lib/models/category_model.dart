import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CategoryModel {
  final String id;
  final String name;
  final IconData icon;
  final bool isAlcoolica;
  final bool requires18Plus;
  final int lojaId;
  final String tenantId;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    this.isAlcoolica = false,
    this.requires18Plus = false,
    this.lojaId = 1,
    this.tenantId = 'tenant_1',
  });

  factory CategoryModel.fromJson(
    Map<String, dynamic> json, {
    String? tenantId,
    int? lojaId,
  }) {
    final nome = json['nome']?.toString() ?? json['name']?.toString() ?? 'Geral';
    final idStr = json['id']?.toString() ?? nome.toLowerCase();

    final isAlcool = json['isAlcoolica'] == true ||
        json['requires18Plus'] == true ||
        nome.toLowerCase().contains('alcoól') ||
        nome.toLowerCase().contains('alcool') ||
        nome.toLowerCase().contains('cerveja') ||
        nome.toLowerCase().contains('vinho');

    return CategoryModel(
      id: idStr,
      name: nome,
      icon: _resolveIcon(nome),
      isAlcoolica: isAlcool,
      requires18Plus: isAlcool,
      lojaId: (json['lojaId'] as num?)?.toInt() ?? lojaId ?? 1,
      tenantId: json['tenantId']?.toString() ?? tenantId ?? 'tenant_1',
    );
  }

  static IconData _resolveIcon(String categoryName) {
    final nameLower = categoryName.toLowerCase();
    if (nameLower.contains('bebida') || nameLower.contains('drink')) {
      return LucideIcons.cupSoda;
    }
    if (nameLower.contains('alcoól') || nameLower.contains('alcool') || nameLower.contains('cerveja')) {
      return LucideIcons.beer;
    }
    if (nameLower.contains('lanche') || nameLower.contains('snack') || nameLower.contains('doce') || nameLower.contains('bomboniere')) {
      return LucideIcons.cookie;
    }
    if (nameLower.contains('congelado') || nameLower.contains('geladeira') || nameLower.contains('freezer')) {
      return LucideIcons.snowflake;
    }
    if (nameLower.contains('festa')) {
      return LucideIcons.partyPopper;
    }
    if (nameLower.contains('mercearia')) {
      return LucideIcons.shoppingBag;
    }
    if (nameLower.contains('açaí') || nameLower.contains('acai') || nameLower.contains('tigela')) {
      return LucideIcons.utensils;
    }
    return LucideIcons.layoutGrid;
  }

  static List<CategoryModel> getCategoriesForUser({
    bool isMaior18 = true,
    int lojaId = 1,
    String tenantId = 'tenant_1',
  }) {
    return getCategoriesForCondominio(
      lojaId: lojaId,
      tenantId: tenantId,
      isMaior18: isMaior18,
    );
  }

  static List<CategoryModel> getCategoriesForCondominio({
    required int lojaId,
    String? tenantId,
    bool isMaior18 = true,
  }) {
    final effectiveTenant = (tenantId != null && tenantId.isNotEmpty) ? tenantId : 'tenant_1';

    List<CategoryModel> lista;

    if (lojaId == 4 || effectiveTenant == 'tenant_condominio_do_edificio_residencial_manha') {
      lista = [
        const CategoryModel(id: 'all', name: 'Todos', icon: LucideIcons.layoutGrid, lojaId: 4, tenantId: 'tenant_condominio_do_edificio_residencial_manha'),
        const CategoryModel(id: 'mercearia_nobre', name: 'Mercearia Nobre', icon: LucideIcons.shoppingBag, lojaId: 4, tenantId: 'tenant_condominio_do_edificio_residencial_manha'),
        const CategoryModel(id: 'congelados_pratos', name: 'Congelados & Pratos', icon: LucideIcons.snowflake, lojaId: 4, tenantId: 'tenant_condominio_do_edificio_residencial_manha'),
        const CategoryModel(id: 'drinks', name: 'Bebidas Selecionadas', icon: LucideIcons.cupSoda, lojaId: 4, tenantId: 'tenant_condominio_do_edificio_residencial_manha'),
        const CategoryModel(id: 'alcohol', name: 'Bebidas Nobres +18', icon: LucideIcons.beer, isAlcoolica: true, requires18Plus: true, lojaId: 4, tenantId: 'tenant_condominio_do_edificio_residencial_manha'),
      ];
    } else if (lojaId == 5 || effectiveTenant == 'tenant_condominio_smart_access') {
      lista = [
        const CategoryModel(id: 'all', name: 'Todos', icon: LucideIcons.layoutGrid, lojaId: 5, tenantId: 'tenant_condominio_smart_access'),
        const CategoryModel(id: 'freezer_bebidas', name: 'Freezer - Bebidas Express', icon: LucideIcons.snowflake, lojaId: 5, tenantId: 'tenant_condominio_smart_access'),
        const CategoryModel(id: 'geladeira_sanduiches', name: 'Geladeira - Sanduíches', icon: LucideIcons.sandwich, lojaId: 5, tenantId: 'tenant_condominio_smart_access'),
        const CategoryModel(id: 'alcohol', name: 'Cervejas Smart +18', icon: LucideIcons.beer, isAlcoolica: true, requires18Plus: true, lojaId: 5, tenantId: 'tenant_condominio_smart_access'),
      ];
    } else if (lojaId == 6 || effectiveTenant == 'tenant_acai_da_esquina') {
      lista = [
        const CategoryModel(id: 'all', name: 'Todos', icon: LucideIcons.layoutGrid, lojaId: 6, tenantId: 'tenant_acai_da_esquina'),
        const CategoryModel(id: 'tigelas_acai', name: 'Tigelas de Açaí', icon: LucideIcons.utensils, lojaId: 6, tenantId: 'tenant_acai_da_esquina'),
        const CategoryModel(id: 'copos_acai', name: 'Copos de Açaí', icon: LucideIcons.cupSoda, lojaId: 6, tenantId: 'tenant_acai_da_esquina'),
        const CategoryModel(id: 'adicionais', name: 'Adicionais & Frutas', icon: LucideIcons.sparkles, lojaId: 6, tenantId: 'tenant_acai_da_esquina'),
      ];
    } else {
      lista = [
        const CategoryModel(id: 'all', name: 'Todos', icon: LucideIcons.layoutGrid, lojaId: 1, tenantId: 'tenant_1'),
        const CategoryModel(id: 'drinks', name: 'Bebidas', icon: LucideIcons.cupSoda, lojaId: 1, tenantId: 'tenant_1'),
        const CategoryModel(id: 'alcohol', name: 'Bebidas +18', icon: LucideIcons.beer, isAlcoolica: true, requires18Plus: true, lojaId: 1, tenantId: 'tenant_1'),
        const CategoryModel(id: 'snacks', name: 'Snacks & Doces', icon: LucideIcons.cookie, lojaId: 1, tenantId: 'tenant_1'),
        const CategoryModel(id: 'frozen', name: 'Congelados', icon: LucideIcons.snowflake, lojaId: 1, tenantId: 'tenant_1'),
        const CategoryModel(id: 'grocery', name: 'Mercearia', icon: LucideIcons.shoppingBag, lojaId: 1, tenantId: 'tenant_1'),
      ];
    }

    return lista.where((c) {
      if (!isMaior18 && (c.isAlcoolica || c.requires18Plus)) {
        return false;
      }
      return true;
    }).toList();
  }

  static List<CategoryModel> get mockCategories => const [
        CategoryModel(
          id: 'all',
          name: 'Todos',
          icon: LucideIcons.layoutGrid,
          isAlcoolica: false,
          requires18Plus: false,
        ),
        CategoryModel(
          id: 'drinks',
          name: 'Bebidas',
          icon: LucideIcons.cupSoda,
          isAlcoolica: false,
          requires18Plus: false,
        ),
        CategoryModel(
          id: 'alcohol',
          name: 'Bebidas +18',
          icon: LucideIcons.beer,
          isAlcoolica: true,
          requires18Plus: true,
        ),
        CategoryModel(
          id: 'snacks',
          name: 'Snacks & Doces',
          icon: LucideIcons.cookie,
          isAlcoolica: false,
          requires18Plus: false,
        ),
        CategoryModel(
          id: 'frozen',
          name: 'Congelados',
          icon: LucideIcons.snowflake,
          isAlcoolica: false,
          requires18Plus: false,
        ),
        CategoryModel(
          id: 'grocery',
          name: 'Mercearia',
          icon: LucideIcons.shoppingBag,
          isAlcoolica: false,
          requires18Plus: false,
        ),
      ];
}
