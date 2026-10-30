import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/entrada.dart';
import '../../app/provedores.dart';
import '../../core/documento/documentos.dart';
import '../../core/rede/falha_api.dart';
import '../../core/sessao/escopo.dart';
import 'descoberta_page.dart';

class CadastroPage extends ConsumerStatefulWidget {
  const CadastroPage({
    super.key,
    required this.cep,
    required this.loja,
    required this.oferecidas,
    required this.endereco,
  });

  final String cep;
  final LojaEncontrada loja;
  final List<LojaEncontrada> oferecidas;
  final EnderecoViaCep endereco;

  @override
  ConsumerState<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends ConsumerState<CadastroPage> {
  late final TextEditingController _cep;
  late final TextEditingController _logradouro;
  late final TextEditingController _bairro;
  late final TextEditingController _cidade;
  late final TextEditingController _uf;
  late final TextEditingController _complemento;
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _telefone = TextEditingController();
  final _numero = TextEditingController();
  final _cpf = TextEditingController();
  final _numeroFoco = FocusNode();
  var _aceite = false;
  var _avisos = true;
  var _ocupado = false;
  String? _erro;
  String? _pronto;

  @override
  void initState() {
    super.initState();
    final endereco = widget.endereco;
    _cep = TextEditingController(text: formatarCep(widget.cep));
    _logradouro = TextEditingController(text: endereco.logradouro);
    _bairro = TextEditingController(text: endereco.bairro);
    _cidade = TextEditingController(text: endereco.cidade);
    _uf = TextEditingController(text: endereco.uf);
    _complemento = TextEditingController(text: endereco.complemento);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _numeroFoco.requestFocus();
    });
  }

  @override
  void dispose() {
    _cep.dispose();
    _logradouro.dispose();
    _bairro.dispose();
    _cidade.dispose();
    _uf.dispose();
    _complemento.dispose();
    _nome.dispose();
    _email.dispose();
    _senha.dispose();
    _telefone.dispose();
    _numero.dispose();
    _cpf.dispose();
    _numeroFoco.dispose();
    super.dispose();
  }

  String? _validar() {
    if (_nome.text.trim().length < 2) return 'Informe o nome completo.';
    final email = mensagemEmail(_email.text);
    if (email != null) return email;
    if (_senha.text.length < 6) return 'A senha precisa ter pelo menos 6 caracteres.';
    final telefone = mensagemTelefone(_telefone.text);
    if (telefone != null) return telefone;
    final cpf = mensagemCpf(_cpf.text);
    if (cpf != null) return cpf;
    if (_numero.text.trim().isEmpty) return 'Informe o número da casa ou do apartamento.';
    if (_logradouro.text.trim().isEmpty || _bairro.text.trim().isEmpty || _cidade.text.trim().isEmpty || _uf.text.trim().length != 2) {
      return 'O CEP não trouxe a rua completa. Preencha logradouro, bairro, cidade e UF.';
    }
    if (!_aceite) return 'Aceite os termos e a política de privacidade para criar a conta.';
    return null;
  }

  Future<void> _criar() async {
    final oferecidas = [for (final loja in widget.oferecidas) loja.oferecida];
    if (!EscopoRequisicao.podeConfirmarLoja(
      tenantId: widget.loja.tenantId,
      lojaId: widget.loja.lojaId,
      oferecidas: oferecidas,
    )) {
      setState(() => _erro = 'Esta unidade não está na lista do CEP. Volte e escolha outra.');
      unawaited(vibrarErro());
      return;
    }
    final validacao = _validar();
    if (validacao != null) {
      setState(() => _erro = validacao);
      unawaited(vibrarErro());
      return;
    }
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      final resposta = await ref.read(apiProvider).cadastrarConta({
        'nome': _nome.text.trim(),
        'email': _email.text.trim().toLowerCase(),
        'senha': _senha.text,
        'telefone': somenteDigitos(_telefone.text),
        'cep': somenteDigitos(widget.cep),
        'numeroEndereco': _numero.text.trim(),
        'complemento': _complemento.text.trim(),
        'logradouro': _logradouro.text.trim(),
        'bairro': _bairro.text.trim(),
        'cidade': _cidade.text.trim(),
        'uf': _uf.text.trim().toUpperCase(),
        'cpf': somenteDigitos(_cpf.text),
        'tenantId': widget.loja.tenantId,
        'lojaId': widget.loja.lojaId,
        'aceitaNotificacao': _avisos,
      });
      if (!mounted) return;
      final enviado = resposta['emailEnviado'] == true;
      setState(() {
        _pronto = enviado
            ? 'Conta criada em ${widget.loja.nome}. Abra o e-mail e confirme antes de entrar.'
            : 'Conta criada em ${widget.loja.nome}. O e-mail de confirmação não saiu agora. Peça um novo aviso no servidor.';
      });
      unawaited(HapticFeedback.mediumImpact());
    } catch (erro) {
      if (!mounted) return;
      setState(() => _erro = falhaDe(erro).mensagem);
      unawaited(vibrarErro());
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final endereco = widget.endereco;
    final cpfOk = mensagemCpf(_cpf.text) == null && somenteDigitos(_cpf.text).length == 11;
    return Scaffold(
      appBar: AppBar(title: Text(widget.loja.nome)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          EntradaSuave(
            indice: 0,
            child: AvisoAnimado(
              texto: endereco.completo
                  ? 'O ViaCEP preencheu ${endereco.resumo}. Falta o número e os seus dados.'
                  : 'O ViaCEP não trouxe a rua inteira. Complete o que ficou em branco.',
            ),
          ),
          const SizedBox(height: 16),
          EntradaSuave(indice: 1, child: _campo('CEP', _cep, travado: true)),
          const SizedBox(height: 12),
          EntradaSuave(indice: 2, child: _campo('Logradouro', _logradouro, travado: endereco.temRua)),
          const SizedBox(height: 12),
          EntradaSuave(
            indice: 3,
            child: TextField(
              controller: _numero,
              focusNode: _numeroFoco,
              keyboardType: TextInputType.streetAddress,
              decoration: const InputDecoration(labelText: 'Número'),
            ),
          ),
          const SizedBox(height: 12),
          _campo('Complemento', _complemento, travado: false),
          const SizedBox(height: 12),
          _campo('Bairro', _bairro, travado: endereco.bairro.isNotEmpty),
          const SizedBox(height: 12),
          _campo('Cidade', _cidade, travado: endereco.cidade.isNotEmpty),
          const SizedBox(height: 12),
          _campo('UF', _uf, travado: endereco.uf.length == 2),
          const SizedBox(height: 20),
          _campo('Nome', _nome, teclado: TextInputType.name),
          const SizedBox(height: 12),
          _campo('E-mail', _email, teclado: TextInputType.emailAddress),
          const SizedBox(height: 12),
          TextField(controller: _senha, obscureText: true, decoration: const InputDecoration(labelText: 'Senha')),
          const SizedBox(height: 12),
          TextField(
            controller: _telefone,
            keyboardType: TextInputType.phone,
            inputFormatters: [_MascaraCadastro(formatarTelefone)],
            decoration: const InputDecoration(labelText: 'Telefone com DDD'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cpf,
            keyboardType: TextInputType.number,
            inputFormatters: [_MascaraCadastro(formatarCpf)],
            decoration: InputDecoration(
              labelText: 'CPF',
              helperText: cpfOk ? 'CPF conferido.' : 'Usamos os dígitos verificadores do CPF.',
              suffixIcon: cpfOk ? const Icon(Icons.verified_outlined, color: Color(0xFF127A34)) : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _avisos,
            onChanged: (valor) => setState(() => _avisos = valor),
            title: const Text('Receber avisos desta unidade'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _aceite,
            onChanged: (valor) => setState(() => _aceite = valor ?? false),
            title: const Text('Aceito os termos de uso e a política de privacidade'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (_erro != null) AvisoAnimado(texto: _erro!, erro: true),
          if (_pronto != null) AvisoAnimado(texto: _pronto!),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _ocupado || _pronto != null ? null : _criar,
            child: Text(_ocupado ? 'Criando a conta...' : 'Criar conta'),
          ),
        ],
      ),
    );
  }

  Widget _campo(String rotulo, TextEditingController controle, {bool travado = false, TextInputType? teclado}) {
    return TextField(
      controller: controle,
      readOnly: travado,
      keyboardType: teclado,
      decoration: InputDecoration(
        labelText: rotulo,
        filled: true,
        fillColor: travado ? const Color(0xFFF6F4F2) : Colors.white,
      ),
    );
  }
}

class _MascaraCadastro extends TextInputFormatter {
  _MascaraCadastro(this.formatar);

  final String Function(String valor) formatar;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue antigo, TextEditingValue novo) {
    final texto = formatar(novo.text);
    return TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: texto.length));
  }
}
