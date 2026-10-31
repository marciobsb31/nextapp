import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdv_market/core/sessao/sessao.dart';
import 'package:pdv_market/features/admin/gestao_comum.dart';
import 'package:pdv_market/features/admin/painel_admin.dart';

void main() {
  const admin = Sessao(token: 't', tenantId: 'tenant_1', nome: 'Ana Admin', email: 'ana@loja.local', perfil: 'TENANT_ADMIN');
  const operador = Sessao(token: 't', tenantId: 'tenant_1', nome: 'Otto', email: 'otto@loja.local', perfil: 'OPERADOR');

  Future<void> abrirGestao(WidgetTester tester, Sessao sessao) async {
    // Tela alta: o menu inteiro cabe sem rolar.
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: PainelAdmin(sessao: sessao, aoSair: () {}, aoUsarComoCliente: () {})),
    ));
    await tester.pump();
    await tester.tap(find.text('Gestão'));
    await tester.pump();
  }

  // As chamadas à API ficam sem resposta no teste; deixa o prazo delas e do sino vencer.
  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  }

  testWidgets('Administrador vê o menu completo da gestão', (tester) async {
    await abrirGestao(tester, admin);
    for (final item in ['Vendas', 'Notificações', 'Clientes e avisos', 'Cupons', 'Lista de compras', 'Nota por foto']) {
      expect(find.text(item), findsWidgets, reason: item);
    }
    await tester.scrollUntilVisible(find.text('Smart Access'), 200);
    expect(find.text('Financeiro'), findsOneWidget);
    expect(find.text('Usuários'), findsOneWidget);
    expect(find.text('Smart Access'), findsWidgets);
    await fechar(tester);
  });

  testWidgets('Operador não vê financeiro, usuários nem Smart Access', (tester) async {
    await abrirGestao(tester, operador);
    expect(find.text('Vendas'), findsWidgets);
    expect(find.text('Lista de compras'), findsOneWidget);
    expect(find.text('Financeiro'), findsNothing);
    expect(find.text('Usuários'), findsNothing);
    expect(find.text('Nota por foto'), findsNothing);
    await fechar(tester);
  });

  test('Datas curtas da gestão', () {
    expect(dataCurta('2026-10-31'), '31/10/2026');
    expect(dataCurta('2026-10-31T14:05:00'), '31/10 14:05');
    expect(dataIso(DateTime(2026, 1, 5)), '2026-01-05');
    expect(mapas([{'a': 1}, 'x']).length, 1);
  });
}
