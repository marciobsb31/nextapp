import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../rede/api.dart';
import '../rede/falha_api.dart';
import '../sessao/sessao.dart';

/// Pedido feito sem internet, para pagar na maquininha da loja.
///
/// Fica guardado no aparelho (no navegador, no armazenamento do site) com a
/// chave de idempotência já gerada. Quando a conexão volta, o app envia o
/// mesmo pedido com a mesma chave: se a primeira tentativa tiver chegado ao
/// servidor, ele devolve o pedido existente em vez de criar outro.
///
/// Só "na maquininha" entra na fila: PIX e cartão online dependem do PagBank
/// no momento da compra.
class PedidoPendente {
  PedidoPendente({
    required this.chave,
    required this.email,
    required this.itens,
    required this.totalEstimado,
    required this.criadoEm,
    this.confirmaMaioridade = false,
    this.erro,
  });

  final String chave;
  final String email;
  final List<Map<String, Object>> itens;
  final double totalEstimado;
  final DateTime criadoEm;
  final bool confirmaMaioridade;
  final String? erro;

  Map<String, Object?> corpoDaApi() => {
        'itens': itens,
        'metodoPagamento': 'NA_LOJA',
        'idempotencia': chave,
        if (confirmaMaioridade) 'confirmaMaioridade': true,
      };

  PedidoPendente comErro(String mensagem) => PedidoPendente(
        chave: chave,
        email: email,
        itens: itens,
        totalEstimado: totalEstimado,
        criadoEm: criadoEm,
        confirmaMaioridade: confirmaMaioridade,
        erro: mensagem,
      );

  Map<String, Object?> paraJson() => {
        'chave': chave,
        'email': email,
        'itens': itens,
        'totalEstimado': totalEstimado,
        'criadoEm': criadoEm.toIso8601String(),
        'confirmaMaioridade': confirmaMaioridade,
        'erro': erro,
      };

  factory PedidoPendente.deJson(Map<String, dynamic> json) => PedidoPendente(
        chave: json['chave'] as String,
        email: json['email'] as String? ?? '',
        itens: [
          for (final item in (json['itens'] as List? ?? const []))
            {'produtoId': (item as Map)['produtoId'] as int, 'quantidade': item['quantidade'] as int},
        ],
        totalEstimado: (json['totalEstimado'] as num?)?.toDouble() ?? 0,
        criadoEm: DateTime.tryParse(json['criadoEm'] as String? ?? '') ?? DateTime.now(),
        confirmaMaioridade: json['confirmaMaioridade'] == true,
        erro: json['erro'] as String?,
      );
}

class ResultadoEnvio {
  const ResultadoEnvio({required this.enviados, required this.recusados, required this.semConexao});

  final int enviados;
  final int recusados;
  final bool semConexao;
}

class FilaPedidos {
  static const _chave = 'pdv_market_fila_pedidos';

  Future<List<PedidoPendente>> listar({String? email}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bruto = prefs.getString(_chave);
      if (bruto == null || bruto.isEmpty) return [];
      final lista = (jsonDecode(bruto) as List).map((e) => PedidoPendente.deJson(Map<String, dynamic>.from(e as Map))).toList();
      return email == null ? lista : lista.where((p) => p.email == email).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> guardar(PedidoPendente pedido) async {
    final todos = await listar();
    todos.removeWhere((p) => p.chave == pedido.chave);
    todos.add(pedido);
    await _salvar(todos);
  }

  Future<void> remover(String chave) async {
    final todos = await listar();
    todos.removeWhere((p) => p.chave == chave);
    await _salvar(todos);
  }

  Future<void> _salvar(List<PedidoPendente> todos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chave, jsonEncode([for (final p in todos) p.paraJson()]));
    } catch (_) {}
  }

  /// Envia os pedidos guardados deste usuário. Para no primeiro erro de
  /// conexão; pedido recusado pela API (produto esgotado, unidade fechada...)
  /// fica marcado com o motivo para o morador ver e descartar.
  Future<ResultadoEnvio> enviar(ApiPdv api, Sessao sessao) async {
    var enviados = 0;
    var recusados = 0;
    for (final pedido in await listar(email: sessao.email)) {
      if (pedido.erro != null) continue;
      try {
        await api.criarPedido(sessao, pedido.corpoDaApi());
        await remover(pedido.chave);
        enviados++;
      } on FalhaApi catch (falha) {
        if (falha.semConexao) return ResultadoEnvio(enviados: enviados, recusados: recusados, semConexao: true);
        await guardar(pedido.comErro(falha.mensagem));
        recusados++;
      }
    }
    return ResultadoEnvio(enviados: enviados, recusados: recusados, semConexao: false);
  }
}
