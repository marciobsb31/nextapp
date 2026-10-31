import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/provedores.dart';
import '../../app/tema.dart';
import '../../core/rede/falha_api.dart';
import '../../core/sessao/sessao.dart';
import '../inicio/produto_resumo.dart';
import 'gestao_comum.dart';

const _categorias = {
  'FORNECEDOR': 'Fornecedor',
  'ALUGUEL': 'Aluguel',
  'ENERGIA': 'Energia',
  'AGUA': 'Água',
  'INTERNET': 'Internet',
  'SERVICO': 'Serviço',
  'IMPOSTO': 'Imposto',
  'MENSALIDADE': 'Mensalidade',
  'OUTRA': 'Outra',
};

/// Contas a pagar e a receber: o mesmo cadastro do Financeiro do painel web.
class FinanceiroPage extends ConsumerStatefulWidget {
  const FinanceiroPage({super.key});

  @override
  ConsumerState<FinanceiroPage> createState() => _FinanceiroPageState();
}

class _FinanceiroPageState extends ConsumerState<FinanceiroPage> with SingleTickerProviderStateMixin {
  late final _abas = TabController(length: 2, vsync: this)..addListener(() => setState(() {}));
  var _situacao = '';
  var _carregando = true;
  String? _erro;
  Map<String, dynamic> _resumo = const {};
  List<Map<String, dynamic>> _pagar = const [];
  List<Map<String, dynamic>> _receber = const [];

  String get _tipo => _abas.index == 0 ? 'PAGAR' : 'RECEBER';

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_carregar);
  }

  @override
  void dispose() {
    _abas.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    final api = ref.read(apiProvider);
    try {
      final hoje = DateTime.now();
      final resumo = await api.gestao(sessao, '/api/financeiro/resumo',
          consulta: {'de': dataIso(DateTime(hoje.year, hoje.month)), 'ate': dataIso(hoje)});
      final consulta = {'situacao': _situacao, 'ordem': 'vencimento', 'direcao': 'asc'};
      final pagar = mapas(await api.gestao(sessao, '/api/financeiro/contas', consulta: {...consulta, 'tipo': 'PAGAR'}));
      final receber = mapas(await api.gestao(sessao, '/api/financeiro/contas', consulta: {...consulta, 'tipo': 'RECEBER'}));
      if (!mounted) return;
      setState(() {
        _resumo = resumo is Map ? Map<String, dynamic>.from(resumo) : const {};
        _pagar = pagar;
        _receber = receber;
      });
    } catch (erro) {
      if (mounted) setState(() => _erro = falhaDe(erro).mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TelaGestao(
      titulo: 'Financeiro',
      acoes: [IconButton(onPressed: _carregar, icon: const Icon(Icons.refresh))],
      botao: FloatingActionButton.extended(
        backgroundColor: Cores.laranja,
        foregroundColor: Colors.white,
        onPressed: () => _editar(null),
        icon: const Icon(Icons.add),
        label: Text(_tipo == 'PAGAR' ? 'Conta a pagar' : 'Conta a receber'),
      ),
      corpo: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(children: [
              Indicador(rotulo: 'A pagar', valor: reais(_resumo['valorPendente']), cor: Cores.erro),
              const SizedBox(width: 8),
              Indicador(rotulo: 'A receber', valor: reais(_resumo['valorAReceber']), cor: Cores.sucesso),
              const SizedBox(width: 8),
              Indicador(rotulo: 'Vencidas', valor: '${(_resumo['vencidas'] as num? ?? 0) + (_resumo['receberVencidas'] as num? ?? 0)}'),
            ]),
          ),
          TabBar(
            controller: _abas,
            labelColor: Cores.laranja,
            indicatorColor: Cores.laranja,
            unselectedLabelColor: Cores.tinta,
            tabs: const [Tab(text: 'A pagar'), Tab(text: 'A receber')],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Wrap(
              spacing: 8,
              children: [
                for (final opcao in const [('', 'Todas'), ('PENDENTE', 'Em aberto'), ('VENCIDA', 'Vencidas'), ('PAGA', 'Quitadas')])
                  ChoiceChip(
                    label: Text(opcao.$2),
                    selected: _situacao == opcao.$1,
                    onSelected: (_) {
                      setState(() => _situacao = opcao.$1);
                      _carregar();
                    },
                  ),
              ],
            ),
          ),
          Expanded(child: TabBarView(controller: _abas, children: [_lista(_pagar, 'PAGAR'), _lista(_receber, 'RECEBER')])),
        ],
      ),
    );
  }

  Widget _lista(List<Map<String, dynamic>> contas, String tipo) {
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          EstadoLista(
            carregando: _carregando,
            erro: _erro,
            vazia: !_carregando && contas.isEmpty,
            textoVazio: tipo == 'PAGAR' ? 'Nenhuma conta a pagar.' : 'Nenhuma conta a receber.',
          ),
          for (final c in contas)
            CartaoGestao(
              titulo: texto(c['descricao']),
              detalhe: '${_rotuloSituacao(c, tipo)} · vence ${dataCurta(c['vencimento'])}'
                  '${texto(c['beneficiario']).isEmpty ? '' : ' · ${c['beneficiario']}'}',
              valor: reais(c['valor']),
              icone: tipo == 'PAGAR' ? Icons.call_made : Icons.call_received,
              corIcone: c['status'] == 'PAGA'
                  ? Cores.sucesso
                  : c['situacao'] == 'VENCIDA' ? Cores.erro : Cores.laranja,
              aoTocar: () => _acoes(c, tipo),
            ),
        ],
      ),
    );
  }

  String _rotuloSituacao(Map<String, dynamic> c, String tipo) {
    if (c['status'] == 'PAGA') return tipo == 'PAGAR' ? 'Paga em ${dataCurta(c['pagaEm'])}' : 'Recebida em ${dataCurta(c['pagaEm'])}';
    if (c['situacao'] == 'VENCIDA') return 'Vencida';
    return 'Em aberto';
  }

  Future<void> _acoes(Map<String, dynamic> conta, String tipo) async {
    final paga = conta['status'] == 'PAGA';
    final escolha = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(texto(conta['descricao']), style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(reais(conta['valor']))),
            if (!paga)
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(tipo == 'PAGAR' ? 'Marcar como paga hoje' : 'Marcar como recebida hoje'),
                onTap: () => Navigator.pop(context, 'pagar'),
              ),
            if (paga) ListTile(leading: const Icon(Icons.undo), title: const Text('Reabrir'), onTap: () => Navigator.pop(context, 'reabrir')),
            ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Editar'), onTap: () => Navigator.pop(context, 'editar')),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Cores.erro),
              title: const Text('Excluir', style: TextStyle(color: Cores.erro)),
              onTap: () => Navigator.pop(context, 'excluir'),
            ),
          ],
        ),
      ),
    );
    if (escolha == null || !mounted) return;
    if (escolha == 'editar') return _editar(conta);
    if (escolha == 'excluir') {
      final certo = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Excluir a conta?'),
          content: Text(texto(conta['descricao'])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
          ],
        ),
      );
      if (certo != true) return;
    }
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null) return;
    final id = conta['id'];
    try {
      final api = ref.read(apiProvider);
      switch (escolha) {
        case 'pagar':
          await api.gestaoEnviar(sessao, 'POST', '/api/financeiro/contas/$id/pagar', corpo: {'pagaEm': dataIso(DateTime.now())});
        case 'reabrir':
          await api.gestaoEnviar(sessao, 'POST', '/api/financeiro/contas/$id/reabrir');
        case 'excluir':
          await api.gestaoEnviar(sessao, 'DELETE', '/api/financeiro/contas/$id');
      }
      await _carregar();
    } catch (erro) {
      if (mounted) avisar(context, falhaDe(erro).mensagem, erro: true);
    }
  }

  Future<void> _editar(Map<String, dynamic>? conta) async {
    final tipo = conta == null ? _tipo : texto(conta['tipo']).isEmpty ? 'PAGAR' : texto(conta['tipo']);
    final descricao = TextEditingController(text: texto(conta?['descricao']));
    final quem = TextEditingController(text: texto(conta?['beneficiario']));
    final valor = TextEditingController(text: texto(conta?['valor']).replaceAll('.', ','));
    var categoria = texto(conta?['categoria']).isEmpty ? (tipo == 'PAGAR' ? 'FORNECEDOR' : 'OUTRA') : texto(conta!['categoria']);
    var vencimento = DateTime.tryParse(texto(conta?['vencimento'])) ?? DateTime.now();
    final salvar = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, atualizar) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(conta == null ? (tipo == 'PAGAR' ? 'Nova conta a pagar' : 'Nova conta a receber') : 'Editar conta',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              TextField(controller: descricao, decoration: const InputDecoration(labelText: 'Descrição')),
              TextField(controller: quem, decoration: InputDecoration(labelText: tipo == 'PAGAR' ? 'Para quem (opcional)' : 'De quem (opcional)')),
              TextField(
                controller: valor,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Valor (R\$)'),
              ),
              DropdownButtonFormField<String>(
                initialValue: categoria,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: [for (final c in _categorias.entries) DropdownMenuItem(value: c.key, child: Text(c.value))],
                onChanged: (v) => categoria = v ?? categoria,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vencimento'),
                subtitle: Text(dataCurta(dataIso(vencimento))),
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final escolhido = await showDatePicker(
                    context: context,
                    initialDate: vencimento,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (escolhido != null) atualizar(() => vencimento = escolhido);
                },
              ),
              const SizedBox(height: 8),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
            ],
          ),
        ),
      ),
    );
    if (salvar != true || !mounted) return;
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null) return;
    final corpo = {
      'tipo': tipo,
      'descricao': descricao.text.trim(),
      'beneficiario': quem.text.trim(),
      'valor': valor.text.trim(), // o servidor entende 150,50 e 1.500,00
      'categoria': categoria,
      'vencimento': dataIso(vencimento),
      'lembrete': texto(conta?['lembrete']).isEmpty ? 'NENHUM' : conta!['lembrete'],
    };
    try {
      final api = ref.read(apiProvider);
      if (conta == null) {
        await api.gestaoEnviar(sessao, 'POST', '/api/financeiro/contas', corpo: corpo);
      } else {
        await api.gestaoEnviar(sessao, 'PUT', '/api/financeiro/contas/${conta['id']}', corpo: corpo);
      }
      if (mounted) avisar(context, 'Conta salva.');
      await _carregar();
    } catch (erro) {
      if (mounted) avisar(context, falhaDe(erro).mensagem, erro: true);
    }
  }
}
