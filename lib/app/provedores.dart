import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/rede/api.dart';
import '../core/rede/falha_api.dart';
import '../core/sessao/cofre_sessao.dart';
import '../core/sessao/sessao.dart';

final apiProvider = Provider<ApiPdv>((ref) => ApiPdv.padrao());

final sessaoProvider = AsyncNotifierProvider<SessaoController, Sessao?>(SessaoController.new);

class SessaoController extends AsyncNotifier<Sessao?> {
  @override
  Future<Sessao?> build() => ref.watch(cofreSessaoProvider).ler();

  Future<String?> entrar(String email, String senha) async {
    try {
      final sessao = await ref.read(apiProvider).entrar(email, senha);
      if (sessao.trocarSenha) {
        return 'O primeiro acesso pede uma senha nova. Use o link enviado ao e-mail.';
      }
      if (!sessao.autenticada) {
        return 'A API não devolveu uma sessão.';
      }
      await ref.read(cofreSessaoProvider).guardar(sessao);
      state = AsyncData(sessao);
      return null;
    } catch (erro) {
      return falhaDe(erro).mensagem;
    }
  }

  Future<void> sair() async {
    final atual = state.asData?.value;
    if (atual != null && atual.autenticada) {
      try {
        await ref.read(apiProvider).sair(atual);
      } catch (_) {
        // A sessão local sai mesmo se o servidor não responder.
      }
    }
    await ref.read(cofreSessaoProvider).limpar();
    state = const AsyncData(null);
  }
}
