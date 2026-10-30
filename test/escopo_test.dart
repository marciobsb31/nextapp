import 'package:flutter_test/flutter_test.dart';
import 'package:pdv_market/core/sessao/escopo.dart';
import 'package:pdv_market/core/sessao/sessao.dart';

void main() {
  const sessao = Sessao(
    token: 'jwt-da-api',
    tenantId: 'tenant_a',
    nome: 'Ana',
    email: 'ana@loja.test',
    perfil: 'CLIENTE',
  );

  test('o cabeçalho leva só o token da sessão', () {
    expect(EscopoRequisicao.cabecalhos(sessao), {'Authorization': 'Bearer jwt-da-api'});
    expect(EscopoRequisicao.cabecalhos(sessao, unidadeId: 4).containsKey('X-Loja-ID'), isFalse);
    expect(EscopoRequisicao.cabecalhos(sessao).containsKey('X-Tenant-ID'), isFalse);
  });

  test('a operação informa a unidade escolhida sem trocar o contrato', () {
    const admin = Sessao(
      token: 'jwt-da-api',
      tenantId: 'tenant_a',
      nome: 'Admin',
      email: 'admin@loja.test',
      perfil: 'TENANT_ADMIN',
    );
    final cabecalhos = EscopoRequisicao.cabecalhos(admin, unidadeId: 2);
    expect(cabecalhos['X-Loja-ID'], '2');
    expect(cabecalhos.containsKey('X-Tenant-ID'), isFalse);
  });

  test('uma sessão sem token não autoriza chamada', () {
    const vazia = Sessao(token: '', tenantId: 'tenant_a', nome: '', email: '', perfil: 'CLIENTE');
    expect(() => EscopoRequisicao.cabecalhos(vazia), throwsStateError);
  });

  test('loja de outro contrato não é confirmável', () {
    const oferecidas = [
      LojaOferecida(tenantId: 'tenant_a', lojaId: 1, nome: 'Mercado A'),
    ];
    expect(
      EscopoRequisicao.podeConfirmarLoja(tenantId: 'tenant_b', lojaId: 1, oferecidas: oferecidas),
      isFalse,
    );
    expect(
      EscopoRequisicao.podeConfirmarLoja(tenantId: 'tenant_a', lojaId: 9, oferecidas: oferecidas),
      isFalse,
    );
    expect(
      EscopoRequisicao.podeConfirmarLoja(tenantId: 'tenant_a', lojaId: 1, oferecidas: oferecidas),
      isTrue,
    );
  });

  test('admin de loja não é cliente', () {
    const lojista = Sessao(
      token: 'jwt-da-api',
      tenantId: 'tenant_a',
      nome: 'Loja',
      email: 'admin@loja.test',
      perfil: 'TENANT_ADMIN',
    );
    expect(lojista.admin, isTrue);
    expect(lojista.cliente, isFalse);
    expect(sessao.admin, isFalse);
  });

  test('login de troca de senha não vira sessão autenticada', () {
    final sessao = Sessao.deLogin({
      'trocarSenha': true,
      'trocaToken': 'abc',
      'email': 'ana@loja.test',
    });
    expect(sessao.autenticada, isFalse);
    expect(sessao.trocaToken, 'abc');
  });
}
