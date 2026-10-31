import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/entrada.dart';
import '../../app/provedores.dart';
import '../../app/tema.dart';
import '../../core/rede/falha_api.dart';
import '../../core/sessao/sessao.dart';

/// Mensagens iguais às de `CupomController` e do painel.
String? mensagemCupom({required String codigo, required String inicio, required String fim}) {
  if (codigo.trim().isEmpty) return 'Informe o código do cupom.';
  if (inicio.isEmpty || fim.isEmpty) return 'Informe a data de início e a data de fim.';
  if (fim.compareTo(inicio) < 0) return 'A data de fim precisa ser igual ou posterior à data de início.';
  return null;
}

double? numeroCupom(String valor) {
  final limpo = valor.trim().replaceAll(',', '.');
  if (limpo.isEmpty) return 0;
  return double.tryParse(limpo);
}

String dataIso(DateTime data) {
  final mes = data.month.toString().padLeft(2, '0');
  final dia = data.day.toString().padLeft(2, '0');
  return '${data.year}-$mes-$dia';
}

String dataBr(String iso) {
  if (iso.length < 10) return iso;
  final partes = iso.substring(0, 10).split('-');
  if (partes.length != 3) return iso;
  return '${partes[2]}/${partes[1]}/${partes[0]}';
}

String isoDe(Object? valor) {
  if (valor is String && valor.length >= 10 && valor[4] == '-') return valor.substring(0, 10);
  if (valor is List && valor.length >= 3) {
    final ano = valor[0];
    final mes = valor[1];
    final dia = valor[2];
    if (ano is num && mes is num && dia is num) {
      return '${ano.toInt()}-${mes.toInt().toString().padLeft(2, '0')}-${dia.toInt().toString().padLeft(2, '0')}';
    }
  }
  return '';
}

int? idDe(Object? valor) {
  if (valor is num) return valor.toInt();
  if (valor == null || texto(valor).isEmpty) return null;
  return int.tryParse(texto(valor));
}

class CuponsPage extends ConsumerStatefulWidget {
  const CuponsPage({super.key});

  @override
  ConsumerState<CuponsPage> createState() => _CuponsPageState();
}

class _CuponsPageState extends ConsumerState<CuponsPage> {
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
      final itens = await ref.read(apiProvider).cupons(sessao);
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
      MaterialPageRoute<bool>(builder: (_) => CupomFormPage(atual: atual)),
    );
    if (salvou == true) _carregar();
  }


  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Sessao?>>(sessaoProvider, (anterior, proximo) {
      if (proximo.asData?.value != null && mounted) {
        _carregar();
      }
    });
    final sessao = ref.watch(sessaoProvider).asData?.value;
    final termo = _busca.text.trim().toLowerCase();
    final lista = [
      for (final item in _itens)
        if (termo.isEmpty || texto(item['codigo']).toLowerCase().contains(termo)) item,
    ];
    return Scaffold(
      backgroundColor: Cores.fundo,
      appBar: AppBar(title: const Text('Cupons')),
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
            const Text('O desconto vale no período e na unidade gravados aqui.', style: TextStyle(color: Cores.tinta)),
            const SizedBox(height: 12),
            TextField(
              controller: _busca,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Buscar código',
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
              Padding(
                padding: EdgeInsets.only(top: 48),
                child: Column(
                  children: [
                    Icon(Icons.confirmation_number_outlined, size: 48, color: Cores.laranja),
                    SizedBox(height: 12),
                    Text('Nenhum cupom neste contrato.', style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            for (final item in lista)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Cores.raio),
                  elevation: 2,
                  shadowColor: Colors.black.withValues(alpha: 0.25),
                  child: ListTile(
                    title: Text(texto(item['codigo']), style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${item['descontoPercentual'] ?? 0}% · mínimo R\$ ${item['compraMinima'] ?? 0}'),
                        Text('${dataBr(isoDe(item['dataInicio']))} a ${dataBr(isoDe(item['dataFim']))}'),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Cores.laranja.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item['usoUnico'] == true ? (item['usado'] == true ? 'Já usado' : 'Uso único') : 'Várias vezes',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Cores.laranja),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: Icon(Icons.chevron_right, color: Cores.laranja),
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

class _Opcao {
  const _Opcao(this.id, this.nome);
  final int id;
  final String nome;
}

class CupomFormPage extends ConsumerStatefulWidget {
  const CupomFormPage({this.atual, super.key});

  final Map<String, dynamic>? atual;

  @override
  ConsumerState<CupomFormPage> createState() => _CupomFormPageState();
}

class _CupomFormPageState extends ConsumerState<CupomFormPage> {
  late final TextEditingController _codigo;
  late final TextEditingController _desconto;
  late final TextEditingController _minimo;
  late final TextEditingController _buscaProduto;
  late final TextEditingController _buscaCliente;
  late String _inicio;
  late String _fim;
  late bool _usoUnico;
  String _categoria = '';
  int? _lojaId;
  int? _produtoId;
  String _produtoNome = '';
  int? _clienteId;
  String _clienteNome = '';
  List<String> _categorias = const [];
  List<_Opcao> _lojas = const [];
  List<_Opcao> _clientes = const [];
  List<Map<String, dynamic>> _achados = const [];
  var _ocupado = false;
  var _buscando = false;
  String? _aviso;

  @override
  void initState() {
    super.initState();
    final atual = widget.atual;
    _codigo = TextEditingController(text: texto(atual?['codigo']));
    _desconto = TextEditingController(text: texto(atual?['descontoPercentual']).isEmpty ? '10' : texto(atual?['descontoPercentual']));
    _minimo = TextEditingController(text: texto(atual?['compraMinima']).isEmpty ? '0' : texto(atual?['compraMinima']));
    _buscaProduto = TextEditingController();
    _buscaCliente = TextEditingController();
    final hoje = dataIso(DateTime.now());
    final daqui = dataIso(DateTime.now().add(const Duration(days: 30)));
    _inicio = isoDe(atual?['dataInicio']).isEmpty ? hoje : isoDe(atual?['dataInicio']);
    _fim = isoDe(atual?['dataFim']).isEmpty ? daqui : isoDe(atual?['dataFim']);
    _usoUnico = atual?['usoUnico'] == true;
    _categoria = texto(atual?['categoriaNome']);
    _lojaId = idDe(atual?['lojaId']);
    _produtoId = idDe(atual?['produtoId']);
    _produtoNome = texto(atual?['produtoNome']);
    _clienteId = idDe(atual?['clienteId']);
    _clienteNome = texto(atual?['clienteNome']);
    Future<void>.microtask(_apoio);
  }

  @override
  void dispose() {
    _codigo.dispose();
    _desconto.dispose();
    _minimo.dispose();
    _buscaProduto.dispose();
    _buscaCliente.dispose();
    super.dispose();
  }

  Future<void> _apoio() async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null) return;
    try {
      final conta = await ref.read(apiProvider).eu(sessao);
      final nomes = await ref.read(apiProvider).categoriasContrato(sessao);
      final clientes = await ref.read(apiProvider).clientesCupom(sessao);
      if (!mounted) return;
      final lojas = <_Opcao>[
        for (final item in conta['lojasPermitidas'] is List ? conta['lojasPermitidas'] as List : const [])
          if (item is Map && item['id'] is num)
            _Opcao((item['id'] as num).toInt(), texto(item['nome']).isEmpty ? 'Unidade ${item['id']}' : texto(item['nome'])),
      ];
      setState(() {
        _lojas = lojas;
        _categorias = nomes;
        _clientes = [
          for (final item in clientes)
            if (item['id'] is int) _Opcao(item['id'] as int, texto(item['nome'])),
        ];
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() => _aviso = falhaDe(erro).mensagem);
    }
  }

  Future<void> _data(bool inicio) async {
    final atual = DateTime.tryParse(inicio ? _inicio : _fim) ?? DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (escolhida == null || !mounted) return;
    setState(() {
      if (inicio) {
        _inicio = dataIso(escolhida);
      } else {
        _fim = dataIso(escolhida);
      }
    });
  }

  Future<void> _buscarProduto() async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    final termo = _buscaProduto.text.trim();
    if (sessao == null || termo.length < 2) return;
    final unidade = _lojaId;
    if (unidade == null) {
      setState(() => _aviso = 'Escolha a unidade para procurar um produto.');
      return;
    }
    setState(() {
      _buscando = true;
      _aviso = null;
    });
    try {
      final corpo = await ref.read(apiProvider).produtos(sessao, busca: termo, unidadeId: unidade);
      final itens = corpo['itens'];
      if (!mounted) return;
      setState(() {
        _achados = [
          for (final item in itens is List ? itens : const [])
            if (item is Map) Map<String, dynamic>.from(item),
        ];
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() => _aviso = falhaDe(erro).mensagem);
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _salvar() async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null || !sessao.admin) return;
    final desconto = numeroCupom(_desconto.text);
    final minimo = numeroCupom(_minimo.text);
    final aviso = mensagemCupom(codigo: _codigo.text, inicio: _inicio, fim: _fim) ??
        (desconto == null || minimo == null ? 'Informe o desconto e a compra mínima com números.' : null);
    if (aviso != null) {
      setState(() => _aviso = aviso);
      return;
    }
    setState(() {
      _ocupado = true;
      _aviso = null;
    });
    try {
      await ref.read(apiProvider).salvarCupom(
        sessao,
        {
          'codigo': _codigo.text.trim().toUpperCase(),
          'descontoPercentual': desconto,
          'compraMinima': minimo,
          'categoriaNome': _categoria.trim().isEmpty ? null : _categoria.trim(),
          'produtoId': _produtoId,
          'lojaId': _lojaId,
          'clienteId': _clienteId,
          'dataInicio': _inicio,
          'dataFim': _fim,
          'usoUnico': _usoUnico,
        },
        id: idDe(widget.atual?['id']),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (erro) {
      if (!mounted) return;
      setState(() => _aviso = falhaDe(erro).mensagem);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(sessaoProvider).asData?.value?.admin == true;
    final categorias = {..._categorias, if (_categoria.isNotEmpty) _categoria}.toList()..sort();
    final clientes = _buscaCliente.text.trim().length < 2
        ? const <_Opcao>[]
        : [
            for (final item in _clientes)
              if (item.nome.toLowerCase().contains(_buscaCliente.text.trim().toLowerCase())) item,
          ].take(8);
    return Scaffold(
      backgroundColor: Cores.fundo,
      appBar: AppBar(title: Text(widget.atual == null ? 'Novo cupom' : 'Editar cupom')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          TextField(
            controller: _codigo,
            readOnly: !admin,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [LengthLimitingTextInputFormatter(80)],
            decoration: const InputDecoration(labelText: 'Código'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desconto,
            readOnly: !admin,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Desconto (%)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _minimo,
            readOnly: !admin,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Compra mínima (R\$)'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: admin ? () => _data(true) : null, child: Text('Início ${dataBr(_inicio)}'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: admin ? () => _data(false) : null, child: Text('Fim ${dataBr(_fim)}'))),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _categoria,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: [
              const DropdownMenuItem(value: '', child: Text('Todas as categorias')),
              for (final nome in categorias) DropdownMenuItem(value: nome, child: Text(nome)),
            ],
            onChanged: admin ? (valor) => setState(() => _categoria = valor ?? '') : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: _lojaId,
            decoration: const InputDecoration(labelText: 'Unidade'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Todas as unidades')),
              if (_lojaId != null && !_lojas.any((loja) => loja.id == _lojaId))
                DropdownMenuItem<int?>(value: _lojaId, child: Text('Unidade $_lojaId')),
              for (final loja in _lojas) DropdownMenuItem<int?>(value: loja.id, child: Text(loja.nome)),
            ],
            onChanged: admin ? (valor) => setState(() => _lojaId = valor) : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Uso único'),
            subtitle: Text(_usoUnico ? 'O código vale uma vez.' : 'O código pode ser usado várias vezes.'),
            value: _usoUnico,
            activeThumbColor: Cores.laranja,
            onChanged: admin ? (valor) => setState(() => _usoUnico = valor) : null,
          ),
          if (_produtoId != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_produtoNome.isEmpty ? 'Produto $_produtoId' : _produtoNome),
              subtitle: const Text('O desconto incide só neste produto.'),
              trailing: admin ? IconButton(onPressed: () => setState(() { _produtoId = null; _produtoNome = ''; }), icon: const Icon(Icons.close)) : null,
            ),
          if (_clienteId != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_clienteNome.isEmpty ? 'Cliente $_clienteId' : _clienteNome),
              subtitle: const Text('Só este cliente usa o código.'),
              trailing: admin
                  ? IconButton(
                      onPressed: () => setState(() {
                        _clienteId = null;
                        _clienteNome = '';
                      }),
                      icon: const Icon(Icons.close),
                    )
                  : null,
            ),
          if (admin) ...[
            TextField(
              controller: _buscaProduto,
              decoration: InputDecoration(
                labelText: 'Produto específico',
                hintText: 'Nome do produto',
                suffixIcon: IconButton(onPressed: _buscando ? null : _buscarProduto, icon: const Icon(Icons.search)),
              ),
              onSubmitted: (_) => _buscarProduto(),
            ),
            if (_buscando) const LinearProgressIndicator(),
            for (final item in _achados)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(texto(item['nome'])),
                onTap: () => setState(() {
                  _produtoId = idDe(item['id']);
                  _produtoNome = texto(item['nome']);
                  _achados = const [];
                  _buscaProduto.clear();
                }),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _buscaCliente,
              decoration: const InputDecoration(labelText: 'Cliente específico', hintText: 'Nome do cliente'),
              onChanged: (_) => setState(() {}),
            ),
            for (final cliente in clientes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(cliente.nome.isEmpty ? 'Cliente ${cliente.id}' : cliente.nome),
                onTap: () => setState(() {
                  _clienteId = cliente.id;
                  _clienteNome = cliente.nome;
                  _buscaCliente.clear();
                }),
              ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Com um produto, o desconto incide só nele. Com uma unidade, o cupom só vale nela.',
            style: TextStyle(color: Cores.tinta),
          ),
          if (_aviso != null) ...[
            const SizedBox(height: 12),
            AvisoAnimado(texto: _aviso!, erro: true),
          ],
          if (admin) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: _ocupado ? null : _salvar, child: Text(_ocupado ? 'Salvando...' : 'Salvar')),
          ],
        ],
      ),
    );
  }
}
