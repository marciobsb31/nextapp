import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdv_market/app/provedores.dart';
import 'package:pdv_market/core/rede/api.dart';
import 'package:pdv_market/core/sessao/sessao.dart';
import 'package:pdv_market/features/inicio/inicio_page.dart';
import 'package:pdv_market/features/inicio/produto_resumo.dart';

class _ApiUnidade extends ApiPdv {
  _ApiUnidade() : super(Dio());

  @override
  Future<Map<String, dynamic>> eu(Sessao sessao) async {
    return {
      'nome': 'Ana Souza',
      'email': 'ana@loja.com',
      'lojaId': 2,
      'lojaNome': 'Residencial Alameda',
      'endereco': {
        'logradouro': 'Rua das Flores',
        'numero': '120',
        'bairro': 'Centro',
        'cidade': 'Campinas',
        'uf': 'SP',
      },
      'lojasPermitidas': [
        {'id': 1, 'nome': 'Outra unidade'},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> produtos(
    Sessao sessao, {
    String busca = '',
    int? categoriaId,
    bool soDesconto = false,
    int? unidadeId,
    int pagina = 0,
    int tamanho = 24,
  }) async {
    return {
      'itens': [
        {
          'id': 9,
          'nome': 'Arroz da unidade',
          'preco': 8.5,
          'disponivel': true,
          'imagemUrl': '',
          'descricao': 'Pacote de arroz integral',
        },
        {
          'id': 10,
          'nome': 'Leite',
          'preco': 5.2,
          'disponivel': true,
          'imagemUrl': '',
          'descricao': 'Leite integral',
        },
        {
          'id': 11,
          'nome': 'Café',
          'preco': 12.0,
          'disponivel': true,
          'imagemUrl': '',
          'descricao': 'Café torrado e moído',
        },
      ],
      'total': 3,
      'pagina': 0,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> categorias(
    Sessao sessao, {
    int? unidadeId,
  }) async => const [];

  @override
  Future<List<Map<String, dynamic>>> banners(Sessao sessao, int lojaId) async =>
      const [];
}

class _SessaoCliente extends SessaoController {
  @override
  Future<Sessao?> build() async {
    return const Sessao(
      token: 't',
      tenantId: 'tenant_1',
      nome: 'Ana Souza',
      email: 'ana@loja.com',
      perfil: 'CLIENTE',
    );
  }
}

void main() {
  const acai = ProdutoResumo(
    id: 1,
    nome: 'Açaí 500 ml',
    preco: 'R\$ 16,00',
    precoOriginal: 'R\$ 18,00',
    disponivel: true,
    imagemUrl: '',
    descricao: 'Com granola',
    categoriaId: 2,
    categoriaNome: 'Lanches',
  );
  const agua = ProdutoResumo(
    id: 2,
    nome: 'Água',
    preco: 'R\$ 3,00',
    precoOriginal: null,
    disponivel: true,
    imagemUrl: '',
    descricao: '',
    categoriaId: 4,
    categoriaNome: 'Bebidas',
  );

  test('a vitrine separa oferta e categoria sem misturar outro grupo', () {
    final ofertas = filtrarVitrine(
      produtos: [acai, agua],
      categoriaId: null,
      soOferta: true,
      busca: '',
    );
    expect(ofertas.map((item) => item.id), [1]);

    final bebidas = filtrarVitrine(
      produtos: [acai, agua],
      categoriaId: 4,
      soOferta: false,
      busca: '',
    );
    expect(bebidas.single.nome, 'Água');

    final busca = filtrarVitrine(
      produtos: [acai, agua],
      categoriaId: null,
      soOferta: false,
      busca: 'granola',
    );
    expect(busca.single.id, 1);
  });

  test('o catálogo do cliente fica na unidade do vínculo', () {
    expect(
      unidadeDaConta({
        'lojaId': 2,
        'lojasPermitidas': [
          {'id': 1},
        ],
      }),
      2,
    );
    expect(unidadeDaConta({'lojaId': '2'}), 2);
    expect(
      unidadeDaConta({
        'lojaId': null,
        'lojasPermitidas': [
          {'id': 1},
        ],
      }),
      isNull,
    );
    final pagina = acrescentarPagina([acai], [acai, agua]);
    expect(pagina.map((item) => item.id), [1, 2]);
  });

  testWidgets('a tela do cliente mostra o produto da unidade do vínculo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(_ApiUnidade()),
          sessaoProvider.overrideWith(_SessaoCliente.new),
        ],
        child: const MaterialApp(home: InicioPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Arroz da unidade'), findsWidgets);
    expect(find.text('Qual unidade?'), findsNothing);
    expect(find.text('Outra unidade'), findsNothing);
    expect(find.text('Residencial Alameda'), findsOneWidget);
    expect(find.textContaining('Rua das Flores, 120'), findsOneWidget);
    for (final id in [9, 10, 11]) {
      expect(find.byKey(ValueKey('produto-card-$id')), findsOneWidget);
    }

    final topoArroz = tester
        .getTopLeft(find.byKey(const ValueKey('produto-card-9')))
        .dy;
    final topoLeite = tester
        .getTopLeft(find.byKey(const ValueKey('produto-card-10')))
        .dy;
    final topoCafe = tester
        .getTopLeft(find.byKey(const ValueKey('produto-card-11')))
        .dy;
    expect(topoArroz, topoLeite);
    expect(topoLeite, topoCafe);

    await tester.tap(find.byKey(const ValueKey('produto-card-9')));
    await tester.pumpAndSettle();
    expect(find.text('Pacote de arroz integral'), findsNWidgets(2));
    expect(find.text('Adicionar ao carrinho'), findsOneWidget);

    await tester.tap(find.text('Adicionar ao carrinho'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('produto-card-9')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });
}
