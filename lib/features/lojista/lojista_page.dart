import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/entrada.dart';
import '../../app/provedores.dart';
import '../../app/tema.dart';
import '../../core/rede/falha_api.dart';
import '../../core/sessao/sessao.dart';
import '../admin/catalogo_admin.dart';
import '../admin/clientes_avisos_page.dart';
import '../admin/financeiro_page.dart';
import '../admin/gestao_comum.dart';
import '../admin/nota_foto_page.dart';
import '../admin/notificacoes_admin.dart';
import '../admin/smart_access_admin_page.dart';
import '../admin/usuarios_page.dart';
import '../admin/vendas_admin_page.dart';
import '../inicio/produto_resumo.dart';
import 'cupons_page.dart';
import 'fornecedores_page.dart';
import 'pedidos_loja.dart';

/// Painel de quem opera a loja. O cliente compra em outra tela.
/// Os números vêm de `GET /api/app/admin/dashboard`. O aplicativo não soma venda.
class LojistaPage extends ConsumerStatefulWidget {
  const LojistaPage({super.key, this.aoUsarComoCliente});

  /// Administrador que quer comprar no app como cliente.
  final VoidCallback? aoUsarComoCliente;

  @override
  ConsumerState<LojistaPage> createState() => _LojistaPageState();
}

class _LojistaPageState extends ConsumerState<LojistaPage> {
  Map<String, dynamic>? _conta;
  Map<String, dynamic>? _painel;
  List<_Unidade> _lojas = const [];
  int? _lojaEscolhida;
  var _todas = false;
  var _periodo = 1;
  var _aba = 0;
  var _carregando = true;
  String? _aviso;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_carregar);
  }

  Future<void> _carregar() async {
    final sessao = ref.read(sessaoProvider).asData?.value;
    if (sessao == null) return;
    setState(() => _carregando = true);
    try {
      final conta = await ref.read(apiProvider).eu(sessao);
      final lojas = _unidades(conta['lojasPermitidas']);
      final daConta = conta['lojaId'];
      var unidade = daConta is num ? daConta.toInt() : _lojaEscolhida;
      var todas = sessao.admin && _todas;
      if (daConta is num) todas = false;
      if (!todas && unidade == null && lojas.length == 1) unidade = lojas.first.id;
      Map<String, dynamic>? painel;
      String? aviso;
      if (!todas && unidade == null) {
        aviso = null;
      } else {
        try {
          painel = await ref.read(apiProvider).painelLoja(
                sessao,
                unidadeId: todas ? null : unidade,
                periodo: _periodo,
                todas: todas,
              );
        } catch (erro) {
          aviso = falhaDe(erro).mensagem;
        }
      }
      if (!mounted) return;
      setState(() {
        _conta = conta;
        _lojas = lojas;
        _lojaEscolhida = unidade;
        _todas = todas;
        _painel = painel;
        _aviso = aviso;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() => _aviso = falhaDe(erro).mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _escolher(int? id, {required bool todas}) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _lojaEscolhida = id;
      _todas = todas;
      _aba = 0;
    });
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final nome = texto(_conta?['nome']);
    final primeiro = nome.split(' ').first;
    return Scaffold(
      backgroundColor: Cores.fundo,
      extendBody: true,
      body: SafeArea(
        child: switch (_aba) {
          1 => _pedidos(),
          2 => CatalogoAdmin(unidadeId: _lojaEscolhida),
          3 => _estoque(),
          4 => _perfil(nome),
          _ => _resumo(primeiro.isEmpty ? 'Olá' : 'Olá, $primeiro'),
        },
      ),
      bottomNavigationBar: _barra(),
    );
  }

  Widget _resumo(String saudacao) {
    final painel = _painel;
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        children: [
          Row(
            children: [
              Expanded(child: Text(saudacao, style: const TextStyle(color: Cores.tinta))),
              SinoAdmin(unidadeId: _lojaEscolhida),
            ],
          ),
          const Text('Sua loja', style: TextStyle(color: Cores.marinho, fontWeight: FontWeight.w700, fontSize: 26, height: 1.15)),
          Row(children: [
            Icon(Icons.storefront_outlined, size: 16, color: Cores.laranja),
            const SizedBox(width: 4),
            Text(_nomeLoja(), style: const TextStyle(color: Cores.tinta, fontSize: 13)),
          ]),
          const SizedBox(height: 16),
          if (_carregando) const LinearProgressIndicator(),
          if (_aviso != null) ...[
            const SizedBox(height: 12),
            AvisoAnimado(texto: _aviso!, erro: true),
          ],
          if (_unidadePronta) ...[
            _periodos(),
            const SizedBox(height: 14),
            if (painel != null) ...[
              _faixaFaturamento(painel),
              const SizedBox(height: 12),
              _metricas(painel),
              const SizedBox(height: 14),
              _atalhos(),
              const SizedBox(height: 18),
              _secao('Mais vendidos', _linhasVenda(painel['maisVendidos'])),
              const SizedBox(height: 8),
              Text(
                texto(painel['premissas']).isEmpty
                    ? 'Faturamento é a soma do que foi vendido. Não é lucro.'
                    : texto(painel['premissas']),
                style: const TextStyle(color: Cores.tinta, fontSize: 12),
              ),
            ],
          ] else
            _escolhaUnidade(),
        ],
      ),
    );
  }

  bool get _unidadePronta => _todas || _lojaEscolhida != null;

  Widget _periodos() {
    return Pilulas<int>(
      valor: _periodo,
      opcoes: const [(1, 'Hoje'), (7, '7 dias'), (30, '30 dias')],
      aoEscolher: (dias) {
        setState(() => _periodo = dias);
        _carregar();
      },
    );
  }

  Widget _faixaFaturamento(Map<String, dynamic> painel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(gradient: Cores.gradienteMarca, borderRadius: BorderRadius.circular(24), boxShadow: Cores.brilhoMarca),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_periodo == 1 ? 'Faturamento de hoje' : 'Faturamento do período',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(reais(painel['faturamento']), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('${painel['vendas'] ?? 0} vendas', style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
        ],
      ),
    );
  }

  Widget _metricas(Map<String, dynamic> painel) {
    return Row(
      children: [
        _metrica('Ticket', reais(painel['ticketMedio'])),
        const SizedBox(width: 8),
        _metrica('Itens', '${painel['itens'] ?? 0}'),
        const SizedBox(width: 8),
        _metrica('Vendas', '${painel['vendas'] ?? 0}'),
      ],
    );
  }

  Widget _metrica(String rotulo, String valor) => Indicador(rotulo: rotulo, valor: valor);

  Widget _secao(String titulo, List<Widget> linhas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Cores.marinho)),
        const SizedBox(height: 10),
        if (linhas.isEmpty)
          const Text('Nada neste período.', style: TextStyle(color: Cores.tinta))
        else
          ...linhas,
      ],
    );
  }

  List<Widget> _linhasVenda(Object? valor) {
    return [
      for (final item in _mapas(valor))
        _linha(texto(item['nome']), '${item['quantidade']} un', reais(item['faturamento'])),
    ];
  }

  Widget _linha(String titulo, String detalhe, String valor) {
    return CartaoGestao(titulo: titulo, detalhe: detalhe, valor: valor, icone: Icons.shopping_bag_outlined);
  }

  Widget _escolhaUnidade() {
    final sessao = ref.read(sessaoProvider).asData?.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Qual unidade?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Cores.marinho)),
        const SizedBox(height: 6),
        const Text('O movimento fica na unidade escolhida.', style: TextStyle(color: Cores.tinta)),
        if (sessao?.admin == true)
          _atalhoUnidade('Todas as unidades', () => _escolher(null, todas: true)),
        for (final loja in _lojas) _atalhoUnidade(loja.nome, () => _escolher(loja.id, todas: false)),
      ],
    );
  }

  Widget _atalhoUnidade(String nome, VoidCallback aoTocar) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: CartaoGestao(
        titulo: nome,
        icone: Icons.storefront_outlined,
        fim: Icon(Icons.chevron_right, color: Cores.laranja),
        aoTocar: aoTocar,
      ),
    );
  }

  Widget _pedidos() {
    final unidade = _lojaEscolhida;
    if (unidade == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        children: [
          const Text('Pedidos', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Escolha a unidade para ver os pedidos do aplicativo.', style: TextStyle(color: Cores.tinta)),
          _escolhaUnidade(),
        ],
      );
    }
    return PedidosLoja(unidadeId: unidade);
  }

  Widget _estoque() {
    final painel = _painel;
    final baixo = _mapas(painel?['baixoEstoque']);
    final validades = _mapas(painel?['validades']).where((item) => item['situacao'] == 'VENCIDO' || item['situacao'] == 'PROXIMO').toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        const Text('Estoque', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        Text(_nomeLoja(), style: const TextStyle(color: Cores.tinta)),
        const SizedBox(height: 16),
        if (!_unidadePronta) _escolhaUnidade(),
        if (_aviso != null) AvisoAnimado(texto: _aviso!, erro: true),
        if (_unidadePronta && painel != null) ...[
          _secao('Abaixo do mínimo', [
            for (final item in baixo) _linha(texto(item['nome']), 'Mínimo ${item['minimo']}', '${item['quantidade']}'),
          ]),
          const SizedBox(height: 16),
          _secao('Validade', [
            for (final item in validades) _linha(texto(item['nome']), _rotuloValidade(texto(item['situacao'])), texto(item['validade'])),
          ]),
        ],
      ],
    );
  }

  Widget _atalhos() {
    final sessao = ref.read(sessaoProvider).asData?.value;
    final admin = sessao?.admin == true;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _atalho(Icons.point_of_sale, 'Vendas', () => _ir(VendasAdminPage(unidadeId: _lojaEscolhida))),
        _atalho(Icons.report_gmailerrorred, 'Suspeitas', () => _ir(VendasAdminPage(unidadeId: _lojaEscolhida, abrirSuspeitas: true))),
        if (admin) _atalho(Icons.document_scanner_outlined, 'Nota por foto', () => _ir(NotaFotoPage(unidadeId: _lojaEscolhida))),
        if (admin) _atalho(Icons.sensor_door_outlined, 'Smart Access', () => _ir(const SmartAccessAdminPage())),
      ],
    );
  }

  Widget _atalho(IconData icone, String rotulo, VoidCallback aoTocar) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(color: Cores.cartao, borderRadius: BorderRadius.circular(30), boxShadow: Cores.sombra),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: aoTocar,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icone, color: Cores.laranja, size: 18),
              const SizedBox(width: 6),
              Text(rotulo, style: const TextStyle(fontWeight: FontWeight.w600, color: Cores.marinho, fontSize: 13)),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _ir(Widget tela) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => tela));
    if (mounted) _carregar();
  }

  Widget _perfil(String nome) {
    final sessao = ref.read(sessaoProvider).asData?.value;
    final admin = sessao?.admin == true;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      children: [
        const Text('Gestão', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Cores.marinho)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: Cores.gradienteMarinho, borderRadius: BorderRadius.circular(Cores.raio), boxShadow: Cores.sombra),
          child: Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Cores.laranja,
              child: Text(nome.isEmpty ? 'L' : nome.characters.first.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nome.isEmpty ? 'Lojista' : nome, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                Text(texto(_conta?['email']), style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Cores.laranja.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
              child: Text(admin ? 'Administrador' : 'Operador', style: TextStyle(color: Cores.laranja, fontWeight: FontWeight.w600, fontSize: 11)),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        _secaoMenu('Vendas e clientes', [
          _itemMenu(Icons.point_of_sale, 'Vendas', 'Totem e app, com os itens de cada venda', () => _ir(VendasAdminPage(unidadeId: _lojaEscolhida))),
          _itemMenu(Icons.notifications_none, 'Notificações', 'Venda nova, estoque baixo e venda suspeita', () => _ir(const NotificacoesAdminPage())),
          if (admin) _itemMenu(Icons.people_outline, 'Clientes e avisos', 'Moradores cadastrados e aviso para todos', () => _ir(const ClientesAvisosPage())),
          if (admin) _itemMenu(Icons.local_offer_outlined, 'Cupons', 'Criar e acompanhar cupons de desconto', () => _ir(const CuponsPage())),
        ]),
        _secaoMenu('Estoque e compras', [
          _itemMenu(Icons.shopping_cart_outlined, 'Lista de compras', 'O que está abaixo do mínimo', () => _ir(const ReposicaoPage())),
          if (admin) _itemMenu(Icons.document_scanner_outlined, 'Nota por foto', 'A IA lê a nota e atualiza o estoque', () => _ir(NotaFotoPage(unidadeId: _lojaEscolhida))),
          if (admin) _itemMenu(Icons.local_shipping_outlined, 'Fornecedores', 'Cadastro com CNPJ e CEP', () => _ir(const FornecedoresPage())),
        ]),
        if (admin)
          _secaoMenu('Administração', [
            _itemMenu(Icons.account_balance_wallet_outlined, 'Financeiro', 'Contas a pagar e a receber', () => _ir(const FinanceiroPage())),
            _itemMenu(Icons.manage_accounts_outlined, 'Usuários', 'Equipe, operadores e acessos', () => _ir(const UsuariosPage())),
            _itemMenu(Icons.sensor_door_outlined, 'Smart Access', 'Portas online, abrir à distância e QR mestre', () => _ir(const SmartAccessAdminPage())),
          ]),
        const SizedBox(height: 8),
        if (widget.aoUsarComoCliente != null)
          OutlinedButton.icon(
            onPressed: widget.aoUsarComoCliente,
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Ver o app do cliente'),
          ),
        const SizedBox(height: 12),
        FilledButton(onPressed: () => ref.read(sessaoProvider.notifier).sair(), child: const Text('Sair')),
      ],
    );
  }

  Widget _secaoMenu(String titulo, List<Widget> itens) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo.toUpperCase(), style: const TextStyle(color: Cores.tinta, fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 0.6)),
          const SizedBox(height: 8),
          ...itens,
        ],
      ),
    );
  }

  Widget _itemMenu(IconData icone, String titulo, String detalhe, VoidCallback aoTocar) {
    return CartaoGestao(
      titulo: titulo,
      detalhe: detalhe,
      icone: icone,
      fim: Icon(Icons.chevron_right, color: Cores.laranja),
      aoTocar: aoTocar,
    );
  }

  Widget _barra() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [BoxShadow(color: Color(0x1414233A), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: SizedBox(
          height: 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _item(0, Icons.home_outlined, Icons.home, 'Início'),
              _item(1, Icons.receipt_long_outlined, Icons.receipt_long, 'Pedidos'),
              _item(2, Icons.inventory_2_outlined, Icons.inventory_2, 'Produtos'),
              _item(3, Icons.warning_amber_outlined, Icons.warning_amber, 'Estoque'),
              _item(4, Icons.grid_view_outlined, Icons.grid_view, 'Gestão'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(int aba, IconData icone, IconData ativo, String rotulo) {
    final ligada = _aba == aba;
    return InkWell(
      onTap: () {
        unawaited(HapticFeedback.selectionClick());
        setState(() => _aba = aba);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(ligada ? ativo : icone, color: ligada ? Cores.laranja : Cores.tinta),
          Text(rotulo, style: TextStyle(fontSize: 11, color: ligada ? Cores.laranja : Cores.tinta, fontWeight: ligada ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }

  String _nomeLoja() {
    if (_todas) return 'Todas as unidades';
    for (final loja in _lojas) {
      if (loja.id == _lojaEscolhida) return loja.nome;
    }
    return 'Escolha a unidade';
  }

  List<_Unidade> _unidades(Object? valor) {
    if (valor is! List) return const [];
    return [
      for (final item in valor)
        if (item is Map && item['id'] is num)
          _Unidade((item['id'] as num).toInt(), texto(item['nome']).isEmpty ? 'Unidade ${item['id']}' : texto(item['nome'])),
    ];
  }

  List<Map<String, dynamic>> _mapas(Object? valor) {
    if (valor is! List) return const [];
    return [for (final item in valor) if (item is Map) Map<String, dynamic>.from(item)];
  }

  String _rotuloValidade(String situacao) {
    return switch (situacao) {
      'VENCIDO' => 'Vencido',
      'PROXIMO' => 'Próximo do vencimento',
      'DENTRO' => 'Dentro da validade',
      _ => 'Sem validade informada',
    };
  }
}

class _Unidade {
  const _Unidade(this.id, this.nome);

  final int id;
  final String nome;
}
