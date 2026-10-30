import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/entrada.dart';
import '../../app/provedores.dart';
import '../../app/tema.dart';
import '../../core/documento/documentos.dart';
import '../../core/rede/falha_api.dart';
import '../../core/sessao/sessao.dart';

const _ufs = {
  'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG',
  'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO',
};

class FornecedoresPage extends ConsumerStatefulWidget {
  const FornecedoresPage({super.key});

  @override
  ConsumerState<FornecedoresPage> createState() => _FornecedoresPageState();
}

class _FornecedoresPageState extends ConsumerState<FornecedoresPage> {
  final _busca = TextEditingController();
  List<Map<String, dynamic>> _itens = const [];
  var _carregando = true;
  String? _aviso;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_carregar);
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null) return;
    setState(() {
      _carregando = true;
      _aviso = null;
    });
    try {
      final itens = await ref.read(apiProvider).fornecedores(sessao);
      if (!mounted) return;
      setState(() => _itens = itens);
    } catch (erro) {
      if (!mounted) return;
      setState(() => _aviso = falhaDe(erro).mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _abrir([Map<String, dynamic>? atual]) async {
    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => FornecedorFormPage(atual: atual)),
    );
    if (salvou == true) _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessaoProvider).asData?.value;
    final termo = _busca.text.trim().toLowerCase();
    final lista = [
      for (final item in _itens)
        if (termo.isEmpty ||
            texto(item['nomeMarca']).toLowerCase().contains(termo) ||
            texto(item['razaoSocial']).toLowerCase().contains(termo) ||
            somenteDigitos(texto(item['cnpj'])).contains(somenteDigitos(termo)))
          item,
    ];
    return Scaffold(
      backgroundColor: Cores.fundo,
      appBar: AppBar(title: const Text('Fornecedores')),
      floatingActionButton: sessao?.admin == true
          ? FloatingActionButton.extended(
              backgroundColor: Cores.laranja,
              foregroundColor: Colors.white,
              onPressed: () => _abrir(),
              icon: const Icon(Icons.add),
              label: const Text('Novo'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
          children: [
            const Text('Marcas que abastecem este contrato.', style: TextStyle(color: Cores.tinta)),
            const SizedBox(height: 12),
            TextField(
              controller: _busca,
              decoration: InputDecoration(
                hintText: 'Buscar marca ou CNPJ',
                prefixIcon: const Icon(Icons.search, color: Cores.tinta),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (_carregando) const LinearProgressIndicator(),
            if (_aviso != null) AvisoAnimado(texto: _aviso!, erro: true),
            if (!_carregando && _aviso == null && lista.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Column(
                  children: [
                    Icon(Icons.local_shipping_outlined, size: 48, color: Cores.laranja),
                    SizedBox(height: 12),
                    Text('Nenhum fornecedor neste contrato.', style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            for (final item in lista)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Text(texto(item['nomeMarca']), style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                      [
                        if (texto(item['razaoSocial']).isNotEmpty) texto(item['razaoSocial']),
                        if (texto(item['cnpj']).isNotEmpty) formatarCnpj(texto(item['cnpj'])),
                        [texto(item['cidade']), texto(item['estado'])].where((parte) => parte.isNotEmpty).join('-'),
                      ].where((parte) => parte.isNotEmpty).join('\n'),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Cores.laranja),
                    onTap: () => _abrir(item),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class FornecedorFormPage extends ConsumerStatefulWidget {
  const FornecedorFormPage({this.atual, super.key});

  final Map<String, dynamic>? atual;

  @override
  ConsumerState<FornecedorFormPage> createState() => _FornecedorFormPageState();
}

class _FornecedorFormPageState extends ConsumerState<FornecedorFormPage> {
  late final TextEditingController _cnpj;
  late final TextEditingController _marca;
  late final TextEditingController _razao;
  late final TextEditingController _cep;
  late final TextEditingController _logradouro;
  late final TextEditingController _numero;
  late final TextEditingController _bairro;
  late final TextEditingController _cidade;
  late final TextEditingController _estado;
  late final TextEditingController _complemento;
  final Set<String> _travados = {};
  var _ocupado = false;
  String? _aviso;

  @override
  void initState() {
    super.initState();
    final atual = widget.atual;
    _cnpj = TextEditingController(text: formatarCnpj(texto(atual?['cnpj'])));
    _marca = TextEditingController(text: texto(atual?['nomeMarca']));
    _razao = TextEditingController(text: texto(atual?['razaoSocial']));
    _cep = TextEditingController(text: formatarCep(texto(atual?['cep'])));
    _logradouro = TextEditingController(text: texto(atual?['logradouro']));
    _numero = TextEditingController(text: texto(atual?['numero']));
    _bairro = TextEditingController(text: texto(atual?['bairro']));
    _cidade = TextEditingController(text: texto(atual?['cidade']));
    _estado = TextEditingController(text: texto(atual?['estado']));
    _complemento = TextEditingController(text: texto(atual?['complemento']));
  }

  @override
  void dispose() {
    for (final campo in [_cnpj, _marca, _razao, _cep, _logradouro, _numero, _bairro, _cidade, _estado, _complemento]) {
      campo.dispose();
    }
    super.dispose();
  }

  TextEditingController _campo(String chave) {
    return switch (chave) {
      'cnpj' => _cnpj,
      'nomeMarca' => _marca,
      'razaoSocial' => _razao,
      'cep' => _cep,
      'logradouro' => _logradouro,
      'numero' => _numero,
      'bairro' => _bairro,
      'cidade' => _cidade,
      'estado' => _estado,
      'complemento' => _complemento,
      _ => _marca,
    };
  }

  void _aplicar(Map<String, dynamic> corpo) {
    final travados = corpo['travados'];
    setState(() {
      _travados
        ..clear()
        ..addAll([
          if (travados is List)
            for (final item in travados) item.toString(),
        ]);
      for (final chave in ['nomeMarca', 'razaoSocial', 'cep', 'logradouro', 'numero', 'bairro', 'cidade', 'estado', 'complemento']) {
        final valor = texto(corpo[chave]);
        if (valor.isEmpty) continue;
        final campo = _campo(chave);
        campo.text = chave == 'cep' ? formatarCep(valor) : valor;
      }
    });
  }

  Future<void> _buscarCnpj() async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    final digitos = somenteDigitos(_cnpj.text);
    if (sessao == null || !cnpjValido(digitos)) return;
    setState(() => _ocupado = true);
    try {
      final corpo = await ref.read(apiProvider).consultarCnpjFornecedor(sessao, digitos);
      if (!mounted) return;
      _aplicar(corpo);
      unawaited(HapticFeedback.selectionClick());
    } catch (erro) {
      if (!mounted) return;
      setState(() => _aviso = falhaDe(erro).mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _buscarCep() async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    final digitos = somenteDigitos(_cep.text);
    if (sessao == null || digitos.length != 8) return;
    setState(() => _ocupado = true);
    try {
      final corpo = await ref.read(apiProvider).consultarCepFornecedor(sessao, digitos);
      if (!mounted) return;
      _aplicar(corpo);
      unawaited(HapticFeedback.selectionClick());
    } catch (erro) {
      if (!mounted) return;
      setState(() => _aviso = falhaDe(erro).mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _salvar() async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null || !sessao.admin) return;
    final marca = _marca.text.trim();
    final cnpj = somenteDigitos(_cnpj.text);
    final cep = somenteDigitos(_cep.text);
    final uf = _estado.text.trim().toUpperCase();
    String? aviso;
    if (marca.isEmpty) aviso = 'Informe o nome da marca.';
    aviso ??= mensagemCnpj(_cnpj.text);
    if (cep.isNotEmpty && cep.length != 8) aviso ??= 'Informe o CEP com 8 dígitos.';
    if (uf.isNotEmpty && !_ufs.contains(uf)) aviso ??= 'Informe a UF.';
    if (aviso != null) {
      setState(() => _aviso = aviso);
      unawaited(vibrarErro());
      return;
    }
    setState(() {
      _ocupado = true;
      _aviso = null;
    });
    try {
      final id = widget.atual?['id'];
      await ref.read(apiProvider).salvarFornecedor(
        sessao,
        {
          'cnpj': cnpj,
          'nomeMarca': marca,
          'razaoSocial': _razao.text.trim(),
          'cep': cep,
          'logradouro': _logradouro.text.trim(),
          'numero': _numero.text.trim(),
          'bairro': _bairro.text.trim(),
          'cidade': _cidade.text.trim(),
          'estado': uf,
          'complemento': _complemento.text.trim(),
        },
        id: id is num ? id.toInt() : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (erro) {
      if (!mounted) return;
      setState(() => _aviso = falhaDe(erro).mensagem);
      unawaited(vibrarErro());
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final podeGravar = ref.watch(sessaoProvider).asData?.value?.admin == true;
    return Scaffold(
      backgroundColor: Cores.fundo,
      appBar: AppBar(title: Text(widget.atual == null ? 'Novo fornecedor' : 'Fornecedor')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          const Text('O CNPJ consulta a Receita e trava o que ela devolver. A marca é obrigatória.', style: TextStyle(color: Cores.tinta)),
          const SizedBox(height: 16),
          _entrada('CNPJ', _cnpj, teclado: TextInputType.number, aoMudar: (valor) {
            final formatado = formatarCnpj(valor);
            if (formatado != valor) {
              _cnpj.value = TextEditingValue(text: formatado, selection: TextSelection.collapsed(offset: formatado.length));
            }
            if (cnpjValido(formatado)) _buscarCnpj();
          }),
          _entrada('Nome da marca', _marca, chave: 'nomeMarca'),
          _entrada('Razão social', _razao, chave: 'razaoSocial'),
          _entrada('CEP', _cep, teclado: TextInputType.number, chave: 'cep', aoMudar: (valor) {
            final formatado = formatarCep(valor);
            if (formatado != valor) {
              _cep.value = TextEditingValue(text: formatado, selection: TextSelection.collapsed(offset: formatado.length));
            }
            if (somenteDigitos(formatado).length == 8) _buscarCep();
          }),
          _entrada('Logradouro', _logradouro, chave: 'logradouro'),
          _entrada('Número', _numero, chave: 'numero'),
          _entrada('Bairro', _bairro, chave: 'bairro'),
          _entrada('Cidade', _cidade, chave: 'cidade'),
          _entrada('UF', _estado, chave: 'estado'),
          _entrada('Complemento', _complemento, chave: 'complemento'),
          if (_aviso != null) ...[
            const SizedBox(height: 8),
            AvisoAnimado(texto: _aviso!, erro: true),
          ],
          const SizedBox(height: 16),
          if (podeGravar)
            FilledButton(
              onPressed: _ocupado ? null : _salvar,
              child: Text(_ocupado ? 'Consultando...' : 'Salvar fornecedor'),
            ),
        ],
      ),
    );
  }

  Widget _entrada(String rotulo, TextEditingController campo, {String? chave, TextInputType? teclado, ValueChanged<String>? aoMudar}) {
    final travado = chave != null && _travados.contains(chave);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: campo,
        readOnly: travado,
        keyboardType: teclado,
        textCapitalization: chave == 'estado' ? TextCapitalization.characters : TextCapitalization.none,
        decoration: InputDecoration(labelText: rotulo, filled: true, fillColor: travado ? const Color(0xFFFFF1E8) : Colors.white),
        onChanged: travado ? null : aoMudar,
      ),
    );
  }
}
