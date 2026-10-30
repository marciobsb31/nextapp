import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/config/ambiente.dart';
import '../models/admin_banner.dart';
import '../models/category_model.dart';
import '../models/product.dart';

class SmartAccessPermissions {
  final bool temAcessoSmartAccess;
  final bool somenteSmartAccess;
  final List<String> portasFreezerAutorizadas;

  const SmartAccessPermissions({
    required this.temAcessoSmartAccess,
    required this.somenteSmartAccess,
    this.portasFreezerAutorizadas = const ['Porta Principal', 'Freezer 01 - Bebidas', 'Freezer 02 - Congelados'],
  });
}

class StoreApiService {
  final Dio _dio;

  StoreApiService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: Ambiente.resolveBaseUrl().endsWith('/api')
                    ? Ambiente.resolveBaseUrl()
                    : '${Ambiente.resolveBaseUrl()}/api',
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 4),
              ),
            );

  List<String> get _candidateBases {
    final resolved = Ambiente.resolveBaseUrl();
    final apiBase = resolved.endsWith('/api') ? resolved : '$resolved/api';
    final setBases = <String>{
      apiBase,
      if (Ambiente.local) ...['http://localhost:80/api', 'http://localhost:9000/api'],
    };
    return setBases.toList();
  }

  /// Carrega produtos reais do banco de dados/backend respeitando o isolamento por Condomínio/Loja e Maioridade (+18)
  Future<List<Product>> carregarProdutos({
    required int lojaId,
    String? tenantId,
    required bool isMaior18,
  }) async {
    final effectiveTenant = (tenantId != null && tenantId.isNotEmpty) ? tenantId : 'tenant_1';

    for (final base in _candidateBases) {
      try {
        final client = Dio(
          BaseOptions(
            baseUrl: base,
            connectTimeout: const Duration(seconds: 2),
            receiveTimeout: const Duration(seconds: 4),
          ),
        );

        // Tenta endpoint padrão /produtos e /app/produtos
        for (final path in ['/produtos', '/app/produtos']) {
          try {
            final response = await client.get(
              path,
              queryParameters: {'lojaId': lojaId},
              options: Options(
                headers: {
                  'X-Loja-ID': lojaId.toString(),
                  'X-Tenant-ID': effectiveTenant,
                  'X-User-Is18': isMaior18 ? 'true' : 'false',
                },
              ),
            );

            List? rawList;
            if (response.statusCode == 200) {
              if (response.data is List) {
                rawList = response.data as List;
              } else if (response.data is Map) {
                // Suporte a diferentes envelopes: value (PowerShell/.NET), itens, content, data, items
                for (final key in ['value', 'itens', 'content', 'data', 'items']) {
                  if (response.data[key] is List) {
                    rawList = response.data[key] as List;
                    break;
                  }
                }
              }
            }

            if (rawList != null && rawList.isNotEmpty) {
              final list = rawList
                  .map((item) => Product.fromJson(
                        Map<String, dynamic>.from(item as Map),
                        tenantId: effectiveTenant,
                        lojaId: lojaId,
                      ))
                  .where((p) => p.disponivel && p.estoque > 0) // apenas produtos disponíveis e com estoque em tempo real
                  .where((p) => isMaior18 || !p.isAlcoholic)
                  .toList();

              if (list.isNotEmpty) return list;
            }
          } catch (_) {}
        }
      } catch (_) {}
    }

    // Fallback de catálogo local isolado caso o serviço não responda
    return Product.getProductsForLojaAndAge(
      lojaId: lojaId,
      tenantId: effectiveTenant,
      isMaior18: isMaior18,
    );
  }

  /// Carrega categorias do banco de dados/backend respeitando o isolamento por Condomínio/Loja e Maioridade (+18)
  Future<List<CategoryModel>> carregarCategorias({
    required int lojaId,
    String? tenantId,
    required bool isMaior18,
  }) async {
    // 1. Obtém os produtos reais carregados desta loja para construir as categorias exatas
    final produtos = await carregarProdutos(
      lojaId: lojaId,
      tenantId: tenantId,
      isMaior18: isMaior18,
    );

    if (produtos.isNotEmpty) {
      final Map<String, CategoryModel> mapCats = {
        'all': const CategoryModel(id: 'all', name: 'Todos', icon: LucideIcons.layoutGrid),
      };

      for (final p in produtos) {
        final catNome = p.category.trim();
        if (catNome.isEmpty) continue;
        final catId = catNome.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

        if (!mapCats.containsKey(catId)) {
          final isAlc = p.isAlcoholic ||
              catNome.toLowerCase().contains('alcoól') ||
              catNome.toLowerCase().contains('alcool') ||
              catNome.toLowerCase().contains('cerveja') ||
              catNome.toLowerCase().contains('vinho');

          if (!isMaior18 && isAlc) continue;

          IconData icone = LucideIcons.shoppingBag;
          final catLower = catNome.toLowerCase();
          if (isAlc) {
            icone = LucideIcons.wine;
          } else if (catLower.contains('sorvete') || catLower.contains('picolé')) {
            icone = LucideIcons.iceCream2;
          } else if (catLower.contains('bebida') || catLower.contains('suco') || catLower.contains('refrig')) {
            icone = LucideIcons.cupSoda;
          } else if (catLower.contains('biscoito') || catLower.contains('snack') || catLower.contains('doce') || catLower.contains('bomboniere')) {
            icone = LucideIcons.cookie;
          } else if (catLower.contains('churrasco') || catLower.contains('carne')) {
            icone = LucideIcons.flame;
          } else if (catLower.contains('higiene') || catLower.contains('beleza')) {
            icone = LucideIcons.sparkles;
          } else if (catLower.contains('congelad') || catLower.contains('prato')) {
            icone = LucideIcons.snowflake;
          }

          mapCats[catId] = CategoryModel(
            id: catId,
            name: catNome,
            icon: icone,
            isAlcoolica: isAlc,
            requires18Plus: isAlc,
            lojaId: lojaId,
            tenantId: tenantId ?? 'tenant_1',
          );
        }
      }

      if (mapCats.length > 1) {
        return mapCats.values.toList();
      }
    }

    return CategoryModel.getCategoriesForUser(
      isMaior18: isMaior18,
      lojaId: lojaId,
      tenantId: tenantId ?? 'tenant_1',
    );
  }

  /// Consulta permissões de Smart Access no sistemaweb/backend
  Future<SmartAccessPermissions> verificarPermissoesSmartAccess(String email) async {
    try {
      final response = await _dio.get(
        '/morador/smart-access-permissao',
        queryParameters: {'email': email},
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return SmartAccessPermissions(
          temAcessoSmartAccess: data['temAcesso'] == true,
          somenteSmartAccess: data['somenteSmartAccess'] == true,
        );
      }
    } catch (_) {
      // Fallback seguro baseado em regras de negócio
    }

    // Default: morador regular cadastrado tem acesso completo
    return const SmartAccessPermissions(
      temAcessoSmartAccess: true,
      somenteSmartAccess: false,
    );
  }

  /// Carrega banners cadastrados no Admin em Aplicativo / Anúncios respeitando o isolamento do tenant e loja
  Future<List<AdminBanner>> carregarBannersAdmin({
    required int lojaId,
    String? tenantId,
  }) async {
    final effectiveTenant = (tenantId != null && tenantId.isNotEmpty) ? tenantId : 'tenant_1';

    for (final base in _candidateBases) {
      try {
        final client = Dio(
          BaseOptions(
            baseUrl: base,
            connectTimeout: const Duration(seconds: 3),
            receiveTimeout: const Duration(seconds: 4),
          ),
        );

        for (final path in ['/app/banners/ativos', '/banners/ativos', '/api/app/banners/ativos']) {
          try {
            final response = await client.get(
              path,
              queryParameters: {'lojaId': lojaId},
              options: Options(
                headers: {
                  'X-Loja-ID': lojaId.toString(),
                  'X-Tenant-ID': effectiveTenant,
                },
              ),
            );

            List? rawList;
            if (response.statusCode == 200) {
              if (response.data is List) {
                rawList = response.data as List;
              } else if (response.data is Map) {
                final map = response.data as Map;
                if (map['value'] is List) {
                  rawList = map['value'] as List;
                } else if (map['itens'] is List) {
                  rawList = map['itens'] as List;
                } else if (map['content'] is List) {
                  rawList = map['content'] as List;
                }
              }
            }

            if (rawList != null && rawList.isNotEmpty) {
              final banners = rawList
                  .map((item) => AdminBanner.fromJson(Map<String, dynamic>.from(item as Map)))
                  .where((b) => b.ativo)
                  .toList();
              if (banners.isNotEmpty) {
                return banners;
              }
            }
          } catch (_) {}
        }
      } catch (_) {}
    }
    return AdminBanner.getBannersForLoja(lojaId);
  }

  /// Realiza o upload de nova foto para o perfil do usuário
  Future<String?> uploadFotoUsuario({
    required List<int> bytes,
    required String nomeArquivo,
    String? token,
    String? tenantId,
  }) async {
    for (final base in _candidateBases) {
      try {
        final client = Dio(
          BaseOptions(
            baseUrl: base,
            connectTimeout: const Duration(seconds: 6),
            receiveTimeout: const Duration(seconds: 8),
          ),
        );

        final formData = FormData.fromMap({
          'arquivo': MultipartFile.fromBytes(bytes, filename: nomeArquivo),
        });

        final headers = <String, dynamic>{};
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
        if (tenantId != null && tenantId.isNotEmpty) {
          headers['X-Tenant-ID'] = tenantId;
        }

        final response = await client.post(
          '/app/eu/foto',
          data: formData,
          options: Options(headers: headers),
        );

        if (response.statusCode == 200 && response.data is Map) {
          final url = response.data['fotoUrl']?.toString();
          if (url != null && url.isNotEmpty) {
            if (url.startsWith('/')) {
              final root = base.replaceAll(RegExp(r'/api/?$'), '');
              return '$root$url';
            }
            return url;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Atualiza a foto do usuário no backend se o serviço estiver ativo
  Future<bool> atualizarFotoUsuario({
    required String email,
    required String fotoUrl,
    String? tenantId,
    int? clienteId,
  }) async {
    for (final base in _candidateBases) {
      try {
        final client = Dio(
          BaseOptions(
            baseUrl: base,
            connectTimeout: const Duration(seconds: 2),
            receiveTimeout: const Duration(seconds: 3),
          ),
        );
        final response = await client.post(
          '/app/eu/foto-url',
          data: {
            'email': email,
            'fotoUrl': fotoUrl,
            'tenantId': tenantId,
            'clienteId': clienteId,
          },
        );
        if (response.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }
}
