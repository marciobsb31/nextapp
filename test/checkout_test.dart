import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdv_market/controllers/checkout_controller.dart';
import 'package:pdv_market/core/pagamento/cartao_pagbank.dart';
import 'package:pdv_market/core/pagamento/fila_pedidos.dart';
import 'package:pdv_market/core/rede/api.dart';
import 'package:pdv_market/core/rede/falha_api.dart';
import 'package:pdv_market/core/sessao/sessao.dart';
import 'package:pdv_market/models/cart_item.dart';
import 'package:pdv_market/models/product.dart';
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sessao = Sessao(token: 'jwt', tenantId: 'tenant_1', nome: 'M', email: 'morador@cond.com.br', perfil: 'CLIENTE');

/// API falsa: registra o que o app mandou e responde como o servidor.
class _ApiFalsa extends ApiPdv {
  _ApiFalsa({this.semInternet = false, this.chavePublica = ''}) : super(Dio());

  bool semInternet;
  final String chavePublica;
  final pedidos = <Map<String, Object?>>[];

  @override
  Future<Map<String, dynamic>> simularCarrinho(Sessao sessao, List<Map<String, Object>> itens, {int? unidadeId}) async =>
      {'total': 21.0};

  @override
  Future<Map<String, dynamic>> configCartao(Sessao sessao) async => {'chavePublica': chavePublica, 'parcelasMax': 3};

  @override
  Future<Map<String, dynamic>> criarPedido(Sessao sessao, Map<String, Object?> corpo) async {
    if (semInternet) throw const FalhaApi('sem rede', codigo: 'SEM_CONEXAO');
    pedidos.add(corpo);
    final meio = corpo['metodoPagamento'];
    return {
      'vendaId': 77,
      'numero': '#77',
      'total': 21.0,
      'metodoPagamento': meio,
      'statusPagamento': meio == 'NA_LOJA' ? 'PENDENTE' : (meio == 'PIX' ? 'AGUARDANDO' : 'PAGO'),
      'pix': meio == 'PIX' ? {'copiaECola': '000201PIX'} : null,
    };
  }
}

List<CartItem> _carrinho({bool alcool = false}) => [
      CartItem(product: Product(id: '10', name: 'Água', category: 'Bebidas', price: 3.5, imageUrl: '', isAlcoholic: alcool), quantity: 6),
    ];

/// Par RSA de teste e a chave pública no formato que o PagBank devolve (SPKI em Base64).
(String, RSAPrivateKey) _parDeChaves() {
  final sorte = FortunaRandom()..seed(KeyParameter(Uint8List.fromList(List.generate(32, (i) => i))));
  final gerador = RSAKeyGenerator()
    ..init(ParametersWithRandom(RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64), sorte));
  final par = gerador.generateKeyPair();
  final publica = par.publicKey;
  final algoritmo = ASN1Sequence(elements: [ASN1ObjectIdentifier.fromName('rsaEncryption'), ASN1Null()]);
  final rsa = ASN1Sequence(elements: [ASN1Integer(publica.modulus), ASN1Integer(publica.exponent)])..encode();
  final spki = ASN1Sequence(elements: [algoritmo, ASN1BitString(stringValues: rsa.encodedBytes)])..encode();
  return (base64Encode(spki.encodedBytes!), par.privateKey);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Cartão PagBank', () {
    test('Criptografa no formato do SDK oficial', () {
      final (chave, privada) = _parDeChaves();
      final cartao = CartaoDigitado(numero: '4111 1111 1111 1111', titular: 'MARIA SILVA', validade: '12/30', cvv: '123');
      final cifrado = cartao.criptografar(chave, agora: DateTime.fromMillisecondsSinceEpoch(1700000000000));

      final motor = PKCS1Encoding(RSAEngine())..init(false, PrivateKeyParameter<RSAPrivateKey>(privada));
      final claro = utf8.decode(motor.process(base64Decode(cifrado)));
      expect(claro, '4111111111111111;123;12;2030;MARIA SILVA;1700000000000');
    });

    test('Bandeira, Luhn e validação', () {
      expect(bandeiraDe('4111111111111111'), 'VISA');
      expect(bandeiraDe('5555555555554444'), 'MASTERCARD');
      expect(bandeiraDe('378282246310005'), 'AMEX');
      expect(bandeiraDe('6362970000457013'), 'ELO');
      expect(luhn('4111111111111111'), isTrue);
      expect(luhn('4111111111111112'), isFalse);
      expect(CartaoDigitado(numero: '4111111111111112', titular: 'A B', validade: '12/30', cvv: '123').problema(), 'Confira o número do cartão.');
      expect(CartaoDigitado(numero: '4111111111111111', titular: 'A B', validade: '01/20', cvv: '123').problema(), 'Este cartão está vencido.');
      expect(CartaoDigitado(numero: '378282246310005', titular: 'A B', validade: '12/30', cvv: '123').problema(), 'Confira o código de segurança.');
      expect(CartaoDigitado(numero: '4111111111111111', titular: 'A B', validade: '12/30', cvv: '123').problema(), isNull);
    });
  });

  group('Compra', () {
    test('Maquininha online vira pedido para pagar na loja', () async {
      final api = _ApiFalsa();
      final compra = CheckoutController(sessao: _sessao, itens: _carrinho(), api: api)..escolher(MeioPagamento.maquininha);
      await compra.finalizar();
      expect(compra.etapa, EtapaCompra.pagarNaLoja);
      expect(api.pedidos.single['metodoPagamento'], 'NA_LOJA');
      expect(api.pedidos.single['itens'], [{'produtoId': 10, 'quantidade': 6}]);
    });

    test('Maquininha sem internet fica na fila e é enviada depois, sem duplicar', () async {
      final api = _ApiFalsa(semInternet: true);
      final fila = FilaPedidos();
      final compra = CheckoutController(sessao: _sessao, itens: _carrinho(), api: api, fila: fila)..escolher(MeioPagamento.maquininha);
      await compra.finalizar();
      expect(compra.etapa, EtapaCompra.naFila);
      final guardados = await fila.listar(email: _sessao.email);
      expect(guardados, hasLength(1));

      // Ainda sem internet: nada sai da fila.
      expect((await fila.enviar(api, _sessao)).semConexao, isTrue);
      expect(await fila.listar(), hasLength(1));

      api.semInternet = false;
      final resultado = await fila.enviar(api, _sessao);
      expect(resultado.enviados, 1);
      expect(await fila.listar(), isEmpty);
      expect(api.pedidos.single['idempotencia'], guardados.single.chave);
    });

    test('Fila de outro usuário não é enviada com esta sessão', () async {
      final fila = FilaPedidos();
      await fila.guardar(PedidoPendente(
        chave: 'abcdefgh-1234-4123-8123-123456789abc',
        email: 'vizinho@cond.com.br',
        itens: const [{'produtoId': 10, 'quantidade': 1}],
        totalEstimado: 3.5,
        criadoEm: DateTime.now(),
      ));
      final api = _ApiFalsa();
      expect((await fila.enviar(api, _sessao)).enviados, 0);
      expect(api.pedidos, isEmpty);
    });

    test('PIX sem internet não entra na fila e explica o motivo', () async {
      final compra = CheckoutController(sessao: _sessao, itens: _carrinho(), api: _ApiFalsa(semInternet: true))
        ..escolher(MeioPagamento.pix);
      await compra.finalizar();
      expect(compra.etapa, EtapaCompra.escolhendo);
      expect(compra.mensagem, contains('Maquininha'));
      expect(await FilaPedidos().listar(), isEmpty);
    });

    test('PIX mostra o código e cartão aprovado conclui', () async {
      final pix = CheckoutController(sessao: _sessao, itens: _carrinho(), api: _ApiFalsa())..escolher(MeioPagamento.pix);
      await pix.finalizar();
      expect(pix.etapa, EtapaCompra.aguardandoPix);
      expect(pix.pixCopiaECola, '000201PIX');
      pix.dispose();

      final (chave, _) = _parDeChaves();
      final api = _ApiFalsa(chavePublica: chave);
      final credito = CheckoutController(sessao: _sessao, itens: _carrinho(), api: api)..escolher(MeioPagamento.credito);
      await credito.finalizar(
        cartao: CartaoDigitado(numero: '4111111111111111', titular: 'MARIA SILVA', validade: '12/30', cvv: '123'),
        cpfTitular: '529.982.247-25',
      );
      expect(credito.etapa, EtapaCompra.aprovado);
      final cartao = api.pedidos.single['cartao'] as Map;
      expect(cartao['bandeira'], 'VISA');
      expect(cartao['final'], '1111');
      expect(cartao['titularCpf'], '52998224725');
      expect(jsonEncode(api.pedidos.single), isNot(contains('4111111111111111')));
    });

    test('Bebida alcoólica exige confirmar maioridade', () async {
      final api = _ApiFalsa();
      final compra = CheckoutController(sessao: _sessao, itens: _carrinho(alcool: true), api: api)..escolher(MeioPagamento.maquininha);
      await compra.finalizar();
      expect(compra.mensagem, contains('18 anos'));
      expect(api.pedidos, isEmpty);
      compra.marcarMaioridade(true);
      await compra.finalizar();
      expect(api.pedidos.single['confirmaMaioridade'], isTrue);
    });
  });
}
