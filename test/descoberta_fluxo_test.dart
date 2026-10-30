import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdv_market/app/provedores.dart';
import 'package:pdv_market/app/tema.dart';
import 'package:pdv_market/core/rede/api.dart';
import 'package:pdv_market/features/descoberta/descoberta_page.dart';

class _ApiCep extends ApiPdv {
  _ApiCep() : super(Dio());

  @override
  Future<Map<String, dynamic>> lojasPorCep(String cep) async {
    return {
      'raioKm': 5,
      'endereco': {
        'cep': '01310100',
        'logradouro': 'Avenida Paulista',
        'complemento': 'lado par',
        'bairro': 'Bela Vista',
        'cidade': 'São Paulo',
        'uf': 'SP',
      },
      'lojas': [
        {
          'tenantId': 'tenant_acai_da_esquina',
          'lojaId': 1,
          'nome': 'Açaí da Esquina',
          'logradouro': 'Avenida Paulista',
          'numero': '1000',
          'bairro': 'Bela Vista',
          'cidade': 'São Paulo',
          'distanciaMetros': 320,
        },
        {
          'tenantId': 'tenant_longe',
          'lojaId': 9,
          'nome': 'Mercado Longe',
          'cidade': 'São Paulo',
          'distanciaKm': 2.7,
        },
      ],
    };
  }
}

void main() {
  testWidgets('o CEP preenche o endereço e o CPF inválido é recusado', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(_ApiCep())],
        child: MaterialApp(theme: temaPdv(), home: const DescobertaPage()),
      ),
    );

    await tester.enterText(find.byType(TextField), '01310100');
    await tester.pump();
    await tester.ensureVisible(find.text('Buscar pelo CEP'));
    await tester.tap(find.text('Buscar pelo CEP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Avenida Paulista'), findsWidgets);
    expect(find.text('Açaí da Esquina'), findsOneWidget);
    expect(find.text('Mercado Longe'), findsNothing);
    expect(find.textContaining('500 metros'), findsOneWidget);

    await tester.tap(find.text('Açaí da Esquina'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Avenida Paulista'), findsWidgets);
    expect(find.text('Bela Vista'), findsWidgets);
    expect(find.text('São Paulo'), findsWidgets);

    Future<void> preencher(String rotulo, String valor) async {
      final campo = find.widgetWithText(TextField, rotulo);
      await tester.ensureVisible(campo);
      await tester.enterText(campo, valor);
      await tester.pump();
    }

    await preencher('Número', '100');
    await preencher('Nome', 'Ana Souza');
    await preencher('E-mail', 'ana@loja.test');
    await preencher('Senha', 'segredo');
    await preencher('Telefone com DDD', '11987654321');
    await preencher('CPF', '11111111111');
    await tester.tap(find.text('Aceito os termos de uso e a política de privacidade'));
    await tester.pump();
    await tester.tap(find.text('Criar conta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('Esse CPF não confere'), findsOneWidget);
  });
}
