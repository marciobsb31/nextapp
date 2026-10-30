class LojaUnidade {
  final String tenantId;
  final int lojaId;
  final String nome;
  final String endereco;
  final String bairro;
  final String cidade;
  final String uf;
  final double latitude;
  final double longitude;
  final double distanciaMetros;

  const LojaUnidade({
    required this.tenantId,
    required this.lojaId,
    required this.nome,
    required this.endereco,
    required this.bairro,
    required this.cidade,
    required this.uf,
    required this.latitude,
    required this.longitude,
    required this.distanciaMetros,
  });

  bool get estaNoRaio500m => distanciaMetros <= 500.0;

  String get distanciaFormatada {
    if (distanciaMetros < 1000) {
      return '${distanciaMetros.round()} m';
    }
    return '${(distanciaMetros / 1000).toStringAsFixed(1)} km';
  }

  factory LojaUnidade.fromJson(Map<String, dynamic> json) {
    final distMetros = (json['distanciaMetros'] as num?)?.toDouble() ??
        (((json['distanciaKm'] as num?)?.toDouble() ?? 0.0) * 1000.0);

    final logr = json['logradouro']?.toString() ?? '';
    final numStr = json['numero']?.toString() ?? '';
    final enderCompleto = logr.isNotEmpty && numStr.isNotEmpty
        ? '$logr, $numStr'
        : (logr.isNotEmpty ? logr : (json['endereco']?.toString() ?? ''));

    return LojaUnidade(
      tenantId: json['tenantId']?.toString() ?? 'tenant_condominio',
      lojaId: (json['lojaId'] as num?)?.toInt() ?? 1,
      nome: json['nome']?.toString() ?? 'Condomínio Conveniado',
      endereco: enderCompleto,
      bairro: json['bairro']?.toString() ?? '',
      cidade: json['cidade']?.toString() ?? '',
      uf: json['uf']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      distanciaMetros: distMetros,
    );
  }

  static List<LojaUnidade> get mockUnidadesCadastradas => const [
        LojaUnidade(
          tenantId: 'tenant_1',
          lojaId: 1,
          nome: 'Residencial West Side',
          endereco: 'Quadra QNM 42 Conjunto B1',
          bairro: 'Taguatinga Norte',
          cidade: 'Brasília',
          uf: 'DF',
          latitude: -15.808000,
          longitude: -48.115000,
          distanciaMetros: 0, // Dentro do raio de 500m!
        ),
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
          distanciaMetros: 140, // 140m -> Dentro do raio de 500m!
        ),
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
          distanciaMetros: 0, // Dentro do raio de 500m!
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
          distanciaMetros: 66, // 66m -> Dentro do raio de 500m!
        ),
        LojaUnidade(
          tenantId: 'tenant_condominio_smart_access',
          lojaId: 5,
          nome: 'Condomínio Smart Access',
          endereco: 'Av. Paulista, 1000',
          bairro: 'Bela Vista',
          cidade: 'São Paulo',
          uf: 'SP',
          latitude: -23.561414,
          longitude: -46.655881,
          distanciaMetros: 60, // 60m -> Dentro do raio de 500m!
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
          distanciaMetros: 60, // 60m -> Dentro do raio de 500m!
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
          distanciaMetros: 390, // 390m -> Dentro do raio de 500m!
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
          distanciaMetros: 2800, // 2.8 km -> Fora do raio de 500m!
        ),
      ];
}
