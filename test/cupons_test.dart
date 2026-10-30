import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdv_market/app/provedores.dart';
import 'package:pdv_market/core/rede/api.dart';
import 'package:pdv_market/core/sessao/sessao.dart';
import 'package:pdv_market/features/lojista/cupons_page.dart';

class _ApiCupom extends ApiPdv {
  _ApiCupom() : super(Dio());

  @override
  Future<List<Map<String, dynamic>>> cupons(Sessao sessao) async {
    return [
      {
        'codigo': 'VERAO',
        'descontoPercentual': 10,
        'compraMinima': 0,
        'dataInicio': '2026-10-01',
        'dataFim': '2026-10-31',
        'usoUnico': true,
        'usado': false,
      },
    ];
  }
}

class _SessaoPronta extends SessaoController {
  @override
  Future<Sessao?> build() async {
    return const Sessao(
      token: 't',
      tenantId: 'tenant_1',
      nome: 'Ana',
      email: 'ana@loja.com',
      perfil: 'TENANT_ADMIN',
    );
  }
}

void main() {
  test('o cupom exige código e período, como a API', () {
    expect(mensagemCupom(codigo: '  ', inicio: '2026-10-01', fim: '2026-10-31'), 'Informe o código do cupom.');
    expect(mensagemCupom(codigo: 'VERAO', inicio: '', fim: '2026-10-31'), 'Informe a data de início e a data de fim.');
    expect(
      mensagemCupom(codigo: 'VERAO', inicio: '2026-11-01', fim: '2026-10-01'),
      'A data de fim precisa ser igual ou posterior à data de início.',
    );
    expect(mensagemCupom(codigo: 'VERAO', inicio: '2026-10-01', fim: '2026-10-01'), isNull);
    expect(numeroCupom(''), 0);
    expect(numeroCupom('10,5'), 10.5);
    expect(numeroCupom('abc'), isNull);
    expect(isoDe([2026, 10, 24]), '2026-10-24');
    expect(dataBr('2026-10-24'), '24/10/2026');
    expect(idDe(''), isNull);
  });

  testWidgets('o lojista vê o cupom do contrato e o botão de criar', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(_ApiCupom()),
          sessaoProvider.overrideWith(_SessaoPronta.new),
        ],
        child: const MaterialApp(home: CuponsPage()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('VERAO'), findsOneWidget);
    expect(find.text('Novo'), findsOneWidget);
    expect(find.text('Uso único'), findsOneWidget);
  });
}
