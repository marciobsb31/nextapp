import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/pagamento/cartao_pagbank.dart';
import '../core/pagamento/fila_pedidos.dart';
import '../core/rede/api.dart';
import '../core/rede/falha_api.dart';
import '../core/sessao/sessao.dart';
import '../core/util/chave_unica.dart';
import '../models/cart_item.dart';

/// Formas de pagamento do app. "Maquininha" é pagar na Moderninha da loja
/// (`NA_LOJA` na API) e é a única que funciona sem internet.
enum MeioPagamento { pix, credito, debito, maquininha }

enum EtapaCompra { escolhendo, enviando, aguardandoPix, aprovado, pagarNaLoja, naFila, recusado }

extension on MeioPagamento {
  String get daApi => switch (this) {
        MeioPagamento.pix => 'PIX',
        MeioPagamento.credito => 'CREDITO',
        MeioPagamento.debito => 'DEBITO',
        MeioPagamento.maquininha => 'NA_LOJA',
      };
}

/// Compra de verdade na API do PDV, cobrando pelo PagBank da loja.
class CheckoutController extends ChangeNotifier {
  CheckoutController({required this.sessao, required List<CartItem> itens, ApiPdv? api, FilaPedidos? fila})
      : _itens = itens,
        _api = api ?? ApiPdv.padrao(),
        _fila = fila ?? FilaPedidos();

  final Sessao? sessao;
  final List<CartItem> _itens;
  final ApiPdv _api;
  final FilaPedidos _fila;

  MeioPagamento meio = MeioPagamento.pix;
  EtapaCompra etapa = EtapaCompra.escolhendo;
  double? totalServidor;
  int parcelasMax = 1;
  int parcelas = 1;
  bool confirmaMaioridade = false;
  String? mensagem;
  String? pixCopiaECola;
  int? vendaId;
  String numeroPedido = '';
  Timer? _consultaPix;

  /// Chave da compra atual; muda só quando o pedido muda (outro meio, outros itens).
  String _chave = chaveUnica();

  bool get temAlcool => _itens.any((i) => i.product.isAlcoholic);

  double get totalLocal => _itens.fold(0.0, (s, i) => s + i.totalPrice);

  double get totalExibido => totalServidor ?? totalLocal;

  List<Map<String, Object>>? get _itensDaApi {
    final lista = <Map<String, Object>>[];
    for (final item in _itens) {
      final id = int.tryParse(item.product.id);
      if (id == null) return null;
      lista.add({'produtoId': id, 'quantidade': item.quantity});
    }
    return lista;
  }

  void escolher(MeioPagamento novo) {
    if (meio == novo) return;
    meio = novo;
    mensagem = null;
    _chave = chaveUnica();
    notifyListeners();
  }

  void marcarMaioridade(bool valor) {
    confirmaMaioridade = valor;
    notifyListeners();
  }

  void escolherParcelas(int valor) {
    parcelas = valor.clamp(1, parcelasMax);
    notifyListeners();
  }

  /// Total e parcelas vêm do servidor; sem internet fica o total do carrinho.
  Future<void> preparar() async {
    final s = sessao;
    final itens = _itensDaApi;
    if (s == null || !s.autenticada || itens == null || itens.isEmpty) return;
    try {
      final simulado = await _api.simularCarrinho(s, itens);
      final total = simulado['total'];
      if (total is num) totalServidor = total.toDouble();
    } catch (_) {}
    try {
      final config = await _api.configCartao(s);
      final max = config['parcelasMax'];
      if (max is num && max >= 1) parcelasMax = max.toInt();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> finalizar({CartaoDigitado? cartao, String cpfTitular = ''}) async {
    final s = sessao;
    if (s == null || !s.autenticada) return _recusar('Entre na sua conta para comprar.');
    final itens = _itensDaApi;
    if (itens == null) return _recusar('Há produto de demonstração no carrinho. Atualize a vitrine e monte o carrinho de novo.');
    if (itens.isEmpty) return _recusar('O carrinho está vazio.');
    if (temAlcool && !confirmaMaioridade) return _recusar('Confirme que você tem 18 anos ou mais para levar bebida alcoólica.');

    final corpo = <String, Object?>{
      'itens': itens,
      'metodoPagamento': meio.daApi,
      'idempotencia': _chave,
      if (temAlcool) 'confirmaMaioridade': true,
    };

    etapa = EtapaCompra.enviando;
    mensagem = null;
    notifyListeners();

    try {
      if (meio == MeioPagamento.credito || meio == MeioPagamento.debito) {
        if (cartao == null) return _recusar('Informe os dados do cartão.');
        final problema = cartao.problema();
        if (problema != null) return _recusar(problema);
        final config = await _api.configCartao(s);
        final chave = (config['chavePublica'] ?? '').toString();
        if (chave.isEmpty) return _recusar('A loja ainda não ativou o pagamento com cartão.');
        corpo['cartao'] = {
          'encrypted': cartao.criptografar(chave),
          'bandeira': cartao.bandeira,
          'final': cartao.finalCartao,
          'titularCpf': cpfTitular.replaceAll(RegExp(r'\D'), ''),
          'parcelas': meio == MeioPagamento.debito ? 1 : parcelas,
        };
      }
      _aplicar(await _api.criarPedido(s, corpo));
    } on FalhaApi catch (falha) {
      if (falha.semConexao && meio == MeioPagamento.maquininha) {
        await _fila.guardar(PedidoPendente(
          chave: _chave,
          email: s.email,
          itens: itens,
          totalEstimado: totalExibido,
          criadoEm: DateTime.now(),
          confirmaMaioridade: temAlcool && confirmaMaioridade,
        ));
        etapa = EtapaCompra.naFila;
        notifyListeners();
        return;
      }
      if (falha.semConexao) {
        return _recusar('Sem internet agora. PIX e cartão precisam de conexão; escolha "Maquininha" para pagar na loja.');
      }
      _recusar(falha.mensagem);
    } catch (_) {
      _recusar('Não foi possível preparar o pagamento. Confira os dados e tente de novo.');
    }
  }

  void _aplicar(Map<String, dynamic> pedido) {
    vendaId = (pedido['vendaId'] as num?)?.toInt();
    numeroPedido = (pedido['numero'] ?? '').toString();
    final total = pedido['total'];
    if (total is num) totalServidor = total.toDouble();
    final status = (pedido['statusPagamento'] ?? '').toString();
    final pix = pedido['pix'];
    if (status == 'PAGO') {
      etapa = EtapaCompra.aprovado;
    } else if (status == 'NEGADO') {
      _chave = chaveUnica();
      etapa = EtapaCompra.recusado;
      mensagem = (pedido['mensagemPagamento'] ?? 'Pagamento não aprovado pelo PagBank.').toString();
    } else if (meio == MeioPagamento.maquininha) {
      etapa = EtapaCompra.pagarNaLoja;
    } else if (meio == MeioPagamento.pix && pix is Map) {
      pixCopiaECola = (pix['copiaECola'] ?? '').toString();
      etapa = EtapaCompra.aguardandoPix;
      _acompanharPix();
    } else {
      // Cartão em análise no PagBank: acompanha até sair o resultado.
      etapa = EtapaCompra.aguardandoPix;
      _acompanharPix();
    }
    notifyListeners();
  }

  void _acompanharPix() {
    _consultaPix?.cancel();
    _consultaPix = Timer.periodic(const Duration(seconds: 5), (_) => conferirPagamento());
  }

  Future<void> conferirPagamento() async {
    final s = sessao;
    final id = vendaId;
    if (s == null || id == null) return;
    try {
      final situacao = await _api.pagamentoDoPedido(s, id);
      final status = (situacao['statusPagamento'] ?? '').toString();
      if (status == 'PAGO') {
        _consultaPix?.cancel();
        etapa = EtapaCompra.aprovado;
        notifyListeners();
      } else if (status == 'NEGADO' || status == 'EXPIRADO' || status == 'CANCELADO') {
        _consultaPix?.cancel();
        _chave = chaveUnica();
        etapa = EtapaCompra.recusado;
        mensagem = (situacao['mensagemPagamento'] ?? 'O pagamento não foi concluído.').toString();
        notifyListeners();
      }
    } catch (_) {
      // Sem resposta agora; tenta de novo na próxima volta.
    }
  }

  void voltarParaEscolha() {
    _consultaPix?.cancel();
    etapa = EtapaCompra.escolhendo;
    notifyListeners();
  }

  void _recusar(String texto) {
    etapa = EtapaCompra.escolhendo;
    mensagem = texto;
    notifyListeners();
  }

  @override
  void dispose() {
    _consultaPix?.cancel();
    super.dispose();
  }
}
