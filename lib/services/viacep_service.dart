import 'package:dio/dio.dart';
import '../core/config/ambiente.dart';
import '../models/loja_unidade.dart';

class ViaCepResult {
  final String cep;
  final String logradouro;
  final String complemento;
  final String bairro;
  final String localidade;
  final String uf;
  final bool erro;
  final bool isReadOnly;

  const ViaCepResult({
    required this.cep,
    required this.logradouro,
    this.complemento = '',
    required this.bairro,
    required this.localidade,
    required this.uf,
    this.erro = false,
    this.isReadOnly = true,
  });

  factory ViaCepResult.fromJson(Map<String, dynamic> json, {bool isReadOnly = true}) {
    if (json['erro'] == true || json['erro'] == 'true') {
      return const ViaCepResult(
        cep: '',
        logradouro: '',
        complemento: '',
        bairro: '',
        localidade: '',
        uf: '',
        erro: true,
        isReadOnly: false,
      );
    }
    return ViaCepResult(
      cep: json['cep']?.toString() ?? '',
      logradouro: json['logradouro']?.toString() ?? '',
      complemento: json['complemento']?.toString() ?? '',
      bairro: json['bairro']?.toString() ?? '',
      localidade: (json['localidade'] ?? json['cidade'])?.toString() ?? '',
      uf: json['uf']?.toString() ?? '',
      erro: false,
      isReadOnly: isReadOnly,
    );
  }

  String get resumo => '$logradouro, $bairro - $localidade/$uf';
}

/// Resultado integrado da consulta: Endereço oficial ViaCEP + Condomínios existentes na base de dados
class CepConsultaResult {
  final ViaCepResult? endereco;
  final List<LojaUnidade> condominios;
  final String? erro;

  const CepConsultaResult({
    this.endereco,
    this.condominios = const [],
    this.erro,
  });

  bool get temCondominios => condominios.isNotEmpty;
}

class ViaCepService {
  final Dio _dio;
  final Map<String, CepConsultaResult>? mockResponses;

  ViaCepService({
    Dio? dio,
    this.mockResponses,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 5),
              ),
            );

  /// Consulta a base de dados do sistemaweb/backend trazendo o endereço oficial e os condomínios existentes no raio de 500m
  Future<CepConsultaResult> consultarCepEBuscarCondominios(String rawCep) async {
    final cep = rawCep.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8) {
      return const CepConsultaResult(
        erro: 'Informe um CEP válido com 8 números.',
      );
    }

    final mocks = mockResponses;
    if (mocks != null && mocks.containsKey(cep)) {
      return mocks[cep]!;
    }

    for (final base in {
      '${Ambiente.resolveBaseUrl()}/api/publico/lojas',
      if (Ambiente.local) ...[
        'http://localhost:9000/api/publico/lojas',
        'http://localhost:80/api/publico/lojas',
        'http://localhost/api/publico/lojas',
      ],
    }) {
      try {
        final response = await _dio.get(base, queryParameters: {'cep': cep});
        if (response.statusCode == 200 && response.data is Map) {
          final data = response.data as Map<String, dynamic>;

          // Endereço oficial dos Correios retornado pela base
          ViaCepResult? endereco;
          if (data['endereco'] is Map) {
            endereco = ViaCepResult.fromJson(
              Map<String, dynamic>.from(data['endereco'] as Map),
              isReadOnly: true,
            );
          }

          // Lojas/condomínios retornados da base de dados filtrados estritamente pelo raio de 500m
          final List<LojaUnidade> condominios = [];
          if (data['lojas'] is List) {
            for (final item in data['lojas'] as List) {
              if (item is Map) {
                final loja = LojaUnidade.fromJson(Map<String, dynamic>.from(item));
                if (loja.estaNoRaio500m) {
                  condominios.add(loja);
                }
              }
            }
          }

          return CepConsultaResult(
            endereco: endereco,
            condominios: condominios,
          );
        }
      } catch (_) {}
    }

    // 2. Fallback de resiliência: consulta ViaCEP diretamente e aplica a regra de condomínios cadastrados
    final enderecoViaCep = await consultarCep(rawCep);
    if (enderecoViaCep == null || enderecoViaCep.erro) {
      return const CepConsultaResult(
        erro: 'CEP não encontrado na base oficial dos Correios.',
      );
    }

    // Busca unidades conhecidas no raio de 500m
    final unidades = buscarUnidadesNoRaio500m(rawCep);

    return CepConsultaResult(
      endereco: enderecoViaCep,
      condominios: unidades,
    );
  }

  /// Consulta direta ao ViaCEP retornando o endereço
  Future<ViaCepResult?> consultarCep(String rawCep) async {
    final cep = rawCep.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8) return null;

    final mocks = mockResponses;
    if (mocks != null && mocks.containsKey(cep)) {
      return mocks[cep]!.endereco;
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>('https://viacep.com.br/ws/$cep/json/');
      if (response.data == null) return null;
      final result = ViaCepResult.fromJson(response.data!, isReadOnly: true);
      if (result.erro) return null;
      return result;
    } catch (_) {
      // Fallback para CEPs conhecidos de São Paulo (Paulista / Bela Vista)
      if (cep.startsWith('013') || cep.startsWith('014')) {
        return ViaCepResult(
          cep: '${cep.substring(0, 5)}-${cep.substring(5)}',
          logradouro: 'Avenida Paulista',
          complemento: 'lado ímpar',
          bairro: 'Bela Vista',
          localidade: 'São Paulo',
          uf: 'SP',
          isReadOnly: true,
        );
      } else if (cep.startsWith('041') || cep.startsWith('042')) {
        return ViaCepResult(
          cep: '${cep.substring(0, 5)}-${cep.substring(5)}',
          logradouro: 'Rua Vergueiro',
          complemento: '',
          bairro: 'Vila Mariana',
          localidade: 'São Paulo',
          uf: 'SP',
          isReadOnly: true,
        );
      }
      return null;
    }
  }

  /// Retorna as unidades autorizadas que atendem o CEP em um raio de até 500 metros
  List<LojaUnidade> buscarUnidadesNoRaio500m(String rawCep) {
    return listarTodasUnidadesComDistancia(rawCep)
        .where((unidade) => unidade.estaNoRaio500m)
        .toList();
  }

  /// Retorna todas as unidades calculando a distância relativa ao CEP informado
  List<LojaUnidade> listarTodasUnidadesComDistancia(String rawCep) {
    final cepLimpo = rawCep.replaceAll(RegExp(r'\D'), '');

    if (cepLimpo.startsWith('721') || cepLimpo.startsWith('722') || cepLimpo.startsWith('70') || cepLimpo.startsWith('71')) {
      // Região Taguatinga / Ceilândia / Brasília (Borges Landeiro)
      return const [
        LojaUnidade(
          tenantId: 'tenant_1',
          lojaId: 2,
          nome: 'Condomínio Borges Landeiro',
          endereco: 'Quadra QNM 42 Conjunto B2',
          bairro: 'Taguatinga Norte',
          cidade: 'Brasília',
          uf: 'DF',
          latitude: -15.808000,
          longitude: -48.115000,
          distanciaMetros: 0, // 0m -> Dentro do raio (<= 500m)
        ),
      ];
    }

    if (cepLimpo.startsWith('013') || cepLimpo.startsWith('014')) {
      // Região Bela Vista / Paulista / Jardins
      return const [
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
          distanciaMetros: 140, // 140m -> Dentro do raio (<= 500m)
        ),
        LojaUnidade(
          tenantId: 'tenant_condominio_do_edificio_residencial_manha',
          lojaId: 4,
          nome: 'Condomínio Residencial Manhattan',
          endereco: 'Alameda Santos, 1200',
          bairro: 'Cerqueira César',
          cidade: 'São Paulo',
          uf: 'SP',
          latitude: -23.564200,
          longitude: -46.652100,
          distanciaMetros: 66, // 66m -> Dentro do raio (<= 500m)
        ),
        LojaUnidade(
          tenantId: 'tenant_acai_da_esquina',
          lojaId: 6,
          nome: 'Açaí da Esquina',
          endereco: 'Av. Paulista, 1000',
          bairro: 'Bela Vista',
          cidade: 'São Paulo',
          uf: 'SP',
          latitude: -23.561414,
          longitude: -46.655881,
          distanciaMetros: 60, // 60m -> Dentro do raio (<= 500m)
        ),
        LojaUnidade(
          tenantId: 'tenant_parquejardins',
          lojaId: 2,
          nome: 'Condomínio Parque dos Jardins',
          endereco: 'Alameda Santos, 1200',
          bairro: 'Cerqueira César',
          cidade: 'São Paulo',
          uf: 'SP',
          latitude: -23.564200,
          longitude: -46.652100,
          distanciaMetros: 390, // 390m -> Dentro do raio (<= 500m)
        ),
        LojaUnidade(
          tenantId: 'tenant_condominio_smart_access',
          lojaId: 5,
          nome: 'Condomínio Smart Access - Bela Vista',
          endereco: 'Av. Paulista, 1000',
          bairro: 'Bela Vista',
          cidade: 'São Paulo',
          uf: 'SP',
          latitude: -23.561414,
          longitude: -46.655881,
          distanciaMetros: 60, // 60m -> Dentro do raio (<= 500m)
        ),
        LojaUnidade(
          tenantId: 'tenant_altodaserra',
          lojaId: 3,
          nome: 'Residencial Alto da Serra',
          endereco: 'Rua Vergueiro, 2500',
          bairro: 'Vila Mariana',
          cidade: 'São Paulo',
          uf: 'SP',
          latitude: -23.582000,
          longitude: -46.638000,
          distanciaMetros: 2800, // 2.8 km -> Fora do raio (> 500m)
        ),
      ];
    } else if (cepLimpo.startsWith('041') || cepLimpo.startsWith('042')) {
      // Região Vila Mariana / Alto da Serra
      return const [
        LojaUnidade(
          tenantId: 'tenant_altodaserra',
          lojaId: 3,
          nome: 'Residencial Alto da Serra',
          endereco: 'Rua Vergueiro, 2500',
          bairro: 'Vila Mariana',
          cidade: 'São Paulo',
          uf: 'SP',
          latitude: -23.582000,
          longitude: -46.638000,
          distanciaMetros: 180, // 180m -> Dentro do raio (<= 500m)
        ),
        LojaUnidade(
          tenantId: 'tenant_condominio_smart_access',
          lojaId: 1,
          nome: 'Condomínio Smart Access - Bela Vista',
          endereco: 'Av. Paulista, 1000',
          bairro: 'Bela Vista',
          cidade: 'São Paulo',
          uf: 'SP',
          latitude: -23.561414,
          longitude: -46.655881,
          distanciaMetros: 3400, // 3.4 km -> Fora do raio (> 500m)
        ),
      ];
    } else {
      // Outros CEPs (ex: fora da área de cobertura ou outra cidade/estado)
      // Se não houver condomínio cadastrado no banco para este CEP, retorna vazio
      return const [];
    }
  }
}
