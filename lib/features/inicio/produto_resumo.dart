import '../../core/sessao/sessao.dart';

class ProdutoResumo {
  const ProdutoResumo({
    required this.id,
    required this.nome,
    required this.preco,
    required this.precoOriginal,
    required this.disponivel,
    required this.imagemUrl,
    required this.descricao,
    this.categoriaId,
    this.categoriaNome = '',
  });

  final int id;
  final String nome;
  final String preco;
  final String? precoOriginal;
  final bool disponivel;
  final String imagemUrl;
  final String descricao;
  final int? categoriaId;
  final String categoriaNome;

  bool get emOferta => precoOriginal != null;

  factory ProdutoResumo.deJson(Map<String, dynamic> json) {
    final original = json['precoOriginal'];
    final categoria = json['categoria'];
    final mapa = categoria is Map ? Map<String, dynamic>.from(categoria) : const <String, dynamic>{};
    return ProdutoResumo(
      id: json['id'] is num ? (json['id'] as num).toInt() : 0,
      nome: texto(json['nome']),
      preco: reais(json['preco']),
      precoOriginal: original == null ? null : reais(original),
      disponivel: json['disponivel'] == true,
      imagemUrl: texto(json['imagemUrl']),
      descricao: texto(json['descricao']),
      categoriaId: mapa['id'] is num ? (mapa['id'] as num).toInt() : null,
      categoriaNome: texto(mapa['nome']),
    );
  }
}

class CategoriaResumo {
  const CategoriaResumo({required this.id, required this.nome, required this.quantidade});

  final int id;
  final String nome;
  final int quantidade;

  factory CategoriaResumo.deJson(Map<String, dynamic> json) {
    return CategoriaResumo(
      id: json['id'] is num ? (json['id'] as num).toInt() : 0,
      nome: texto(json['nome']),
      quantidade: json['quantidade'] is num ? (json['quantidade'] as num).toInt() : 0,
    );
  }
}

/// A unidade da compra é a do vínculo devolvido por `GET /api/app/eu`.
/// Uma lista de outras lojas não escolhe o catálogo.
int? unidadeDaConta(Map<String, dynamic>? conta) {
  final id = conta?['lojaId'];
  if (id is num) return id.toInt();
  if (id is String) return int.tryParse(id.trim());
  return null;
}

List<ProdutoResumo> acrescentarPagina(List<ProdutoResumo> atual, List<ProdutoResumo> pagina) {
  final vistos = <int>{for (final item in atual) item.id};
  return [
    ...atual,
    for (final item in pagina)
      if (vistos.add(item.id)) item,
  ];
}

List<ProdutoResumo> filtrarVitrine({
  required List<ProdutoResumo> produtos,
  int? categoriaId,
  required bool soOferta,
  required String busca,
}) {
  final termo = busca.trim().toLowerCase();
  return [
    for (final produto in produtos)
      if ((categoriaId == null || produto.categoriaId == categoriaId) &&
          (!soOferta || produto.emOferta) &&
          (termo.isEmpty ||
              produto.nome.toLowerCase().contains(termo) ||
              produto.descricao.toLowerCase().contains(termo) ||
              produto.categoriaNome.toLowerCase().contains(termo)))
        produto,
  ];
}

String reais(Object? valor) {
  final textoValor = valor == null ? '0' : valor.toString().trim();
  final negativo = textoValor.startsWith('-');
  final absoluto = negativo ? textoValor.substring(1) : textoValor;
  final partes = absoluto.split('.');
  final inteiro = int.tryParse(partes.first) ?? 0;
  var fracao = partes.length > 1 ? partes[1] : '';
  if (fracao.length > 2) fracao = fracao.substring(0, 2);
  fracao = fracao.padRight(2, '0');
  final centavos = inteiro * 100 + (int.tryParse(fracao) ?? 0);
  final ajustado = negativo ? -centavos : centavos;
  final sinal = ajustado < 0 ? '-' : '';
  final abs = ajustado.abs();
  return '$sinal R\$ ${abs ~/ 100},${(abs % 100).toString().padLeft(2, '0')}';
}
