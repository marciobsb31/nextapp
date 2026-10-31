import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdv_market/core/sessao/acesso_lembrado.dart';
import 'package:pdv_market/core/sessao/sessao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sessao = Sessao(
    token: 'jwt-da-api',
    tenantId: 'tenant_1',
    nome: 'Morador',
    email: 'morador@condominio.com.br',
    perfil: 'CLIENTE',
  );

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('Lembrar de mim guarda a sessão e o e-mail', () async {
    final acesso = AcessoLembrado();
    await acesso.aposEntrar(sessao, lembrar: true);

    expect(await acesso.lembrarMarcado(), isTrue);
    expect(await acesso.emailLembrado(), 'morador@condominio.com.br');
    final guardada = await acesso.sessaoGuardada();
    expect(guardada?.token, 'jwt-da-api');
    expect(guardada?.tenantId, 'tenant_1');
  });

  test('Sem Lembrar de mim nada fica no aparelho', () async {
    final acesso = AcessoLembrado();
    await acesso.aposEntrar(sessao, lembrar: true);
    await acesso.aposEntrar(sessao, lembrar: false);

    expect(await acesso.lembrarMarcado(), isFalse);
    expect(await acesso.emailLembrado(), isEmpty);
    expect(await acesso.sessaoGuardada(), isNull);
  });

  test('Sair apaga o token e mantém o e-mail preenchido', () async {
    final acesso = AcessoLembrado();
    await acesso.aposEntrar(sessao, lembrar: true);
    await acesso.esquecerSessao();

    expect(await acesso.sessaoGuardada(), isNull);
    expect(await acesso.emailLembrado(), 'morador@condominio.com.br');
  });

  test('Sessão de troca de senha nunca é restaurada', () async {
    final acesso = AcessoLembrado();
    await acesso.aposEntrar(
      const Sessao(token: '', tenantId: '', nome: '', email: 'a@b.com', perfil: '', trocarSenha: true),
      lembrar: true,
    );
    expect(await acesso.sessaoGuardada(), isNull);
  });
}
