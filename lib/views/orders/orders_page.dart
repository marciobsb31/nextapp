import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/rede/api.dart';
import '../../core/sessao/sessao.dart';
import '../../core/util/dinheiro.dart';
import '../../theme/app_theme.dart';

/// Histórico de compras do morador: pedidos do app e compras no totem, vindos de `GET /api/app/pedidos`.
class OrdersPage extends StatefulWidget {
  final List<Map<String, dynamic>> orders;
  final Sessao? sessao;
  final ApiPdv? api;

  const OrdersPage({super.key, this.orders = const [], this.sessao, this.api});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  String _selectedStatus = 'Todos';
  String _selectedPeriodo = 'Todos';
  String _searchQuery = '';

  List<Map<String, dynamic>>? _pedidos;
  bool _carregando = false;
  String? _erro;

  ApiPdv get _api => widget.api ?? ApiPdv.padrao();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final sessao = widget.sessao;
    if (sessao == null || !sessao.autenticada) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final lista = <Map<String, dynamic>>[];
      for (final situacao in const ['ANDAMENTO', 'CONCLUIDOS']) {
        final pagina = await _api.gestao(sessao, '/api/app/pedidos', consulta: {'situacao': situacao});
        final itens = pagina is Map ? pagina['itens'] : null;
        if (itens is List) {
          for (final item in itens) {
            if (item is Map) lista.add(_doServidor(Map<String, dynamic>.from(item)));
          }
        }
      }
      lista.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
      if (mounted) setState(() => _pedidos = lista);
    } catch (_) {
      if (mounted) setState(() => _erro = 'Não foi possível carregar seus pedidos. Puxe para baixo para tentar de novo.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  /// Converte o resumo da API para o formato que a tela já usa.
  Map<String, dynamic> _doServidor(Map<String, dynamic> p) {
    final quando = DateTime.tryParse('${p['data'] ?? ''}') ?? DateTime.now();
    final pagamento = '${p['statusPagamento'] ?? ''}'.toUpperCase();
    final pedido = '${p['statusPedido'] ?? ''}'.toUpperCase();
    final status = const ['NEGADO', 'EXPIRADO', 'CANCELADO', 'ESTORNADO'].contains(pagamento) || pedido == 'CANCELADO'
        ? 'Cancelado'
        : const ['RECEBIDO', 'EM_SEPARACAO', 'PRONTO'].contains(pedido)
            ? (pagamento == 'PAGO' ? 'Em andamento' : 'Pendente')
            : 'Concluído';
    final total = num.tryParse('${p['total'] ?? 0}') ?? 0;
    return {
      'vendaId': p['id'],
      'id': '${p['numero'] ?? '#${p['id']}'}',
      'date': _dataCurta(quando),
      'timestamp': quando,
      'status': status,
      'paymentMethod': _formaPagamento('${p['metodoPagamento'] ?? ''}'),
      'store': p['origem'] == 'APP' ? 'Pedido pelo app' : 'Compra no totem',
      'itemsList': const <Map<String, dynamic>>[],
      'items': '${p['itensResumo'] ?? ''}',
      'total': reaisBr(total),
      'rawTotal': total.toDouble(),
    };
  }

  static String _dataCurta(DateTime d) {
    final hoje = DateTime.now();
    String dois(int n) => n.toString().padLeft(2, '0');
    final hora = '${dois(d.hour)}:${dois(d.minute)}';
    final dia = DateTime(d.year, d.month, d.day);
    final diferenca = DateTime(hoje.year, hoje.month, hoje.day).difference(dia).inDays;
    if (diferenca == 0) return 'Hoje, $hora';
    if (diferenca == 1) return 'Ontem, $hora';
    return '${dois(d.day)}/${dois(d.month)}/${d.year}, $hora';
  }

  static String _formaPagamento(String metodo) => switch (metodo.toUpperCase()) {
        'PIX' => 'Pix',
        'CREDITO' || 'CREDIT_CARD' => 'Cartão de crédito',
        'DEBITO' || 'DEBIT_CARD' => 'Cartão de débito',
        'NA_LOJA' || 'MAQUININHA' => 'Na maquininha',
        '' => 'Pagamento',
        _ => metodo,
      };

  List<Map<String, dynamic>> get _allOrders {
    if (widget.orders.isNotEmpty) return widget.orders;
    return _pedidos ?? const [];
  }

  List<Map<String, dynamic>> get _filteredOrders {
    return _allOrders.where((order) {
      // 1. Filtro de Status
      if (_selectedStatus != 'Todos') {
        final status = (order['status']?.toString() ?? '').toLowerCase().trim();
        final corresponde = switch (_selectedStatus) {
          'Concluído' => const ['concluído', 'concluido', 'pago', 'entregue', 'finalizado'].contains(status),
          'Em andamento' => const ['em andamento', 'pendente', 'recebido', 'processando'].contains(status),
          'Cancelado' => const ['cancelado', 'cancelada', 'estornado'].contains(status),
          _ => true,
        };
        if (!corresponde) return false;
      }

      // 2. Filtro de Período
      if (_selectedPeriodo != 'Todos' && order['timestamp'] is DateTime) {
        final date = order['timestamp'] as DateTime;
        final now = DateTime.now();
        if (_selectedPeriodo == 'Últimos 7 dias') {
          if (now.difference(date).inDays > 7) return false;
        } else if (_selectedPeriodo == 'Este mês') {
          if (date.month != now.month || date.year != now.year) return false;
        } else if (_selectedPeriodo == 'Últimos 3 meses') {
          if (now.difference(date).inDays > 90) return false;
        }
      }

      // 3. Filtro de Busca por Texto
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final id = (order['id']?.toString() ?? '').toLowerCase();
        final items = (order['items']?.toString() ?? '').toLowerCase();
        final payment = (order['paymentMethod']?.toString() ?? '').toLowerCase();
        final store = (order['store']?.toString() ?? '').toLowerCase();
        return id.contains(query) || items.contains(query) || payment.contains(query) || store.contains(query);
      }

      return true;
    }).toList();
  }

  Future<void> _abrirDetalhesComprovante(Map<String, dynamic> order) async {
    final sessao = widget.sessao;
    if (sessao != null && order['vendaId'] != null && (order['itemsList'] as List).isEmpty) {
      try {
        final detalhe = await _api.gestao(sessao, '/api/app/pedidos/${order['vendaId']}');
        final itens = detalhe is Map ? detalhe['itens'] : null;
        if (itens is List) {
          order['itemsList'] = [
            for (final item in itens)
              if (item is Map)
                {
                  'name': '${item['nome'] ?? ''}',
                  'qty': item['quantidade'] ?? 1,
                  'price': num.tryParse('${item['subtotal'] ?? item['precoUnitario'] ?? 0}') ?? 0,
                },
          ];
        }
      } catch (_) {
        // Sem os itens, o comprovante mostra o resumo.
      }
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final itemsList = (order['itemsList'] as List?) ?? [];

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardSurfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(LucideIcons.receiptText, color: AppColors.primaryOrange, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Comprovante Digital',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.navyDark,
                            ),
                          ),
                          Text(
                            order['id']?.toString() ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.primaryOrange,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      order['status']?.toString() ?? 'Concluído',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.successGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Divider(color: isDark ? AppColors.borderDark : Colors.grey.shade200),
              const SizedBox(height: 10),
              _buildDetailRow('Data e Hora', order['date']?.toString() ?? '', isDark),
              _buildDetailRow('Unidade', order['store']?.toString() ?? 'Minimarket Autônomo', isDark),
              _buildDetailRow('Forma de Pagamento', order['paymentMethod']?.toString() ?? 'Cartão', isDark),
              const SizedBox(height: 10),
              Divider(color: isDark ? AppColors.borderDark : Colors.grey.shade200),
              const SizedBox(height: 10),
              Text(
                'Itens Comprados:',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.navyDark,
                ),
              ),
              const SizedBox(height: 8),
              if (itemsList.isNotEmpty)
                ...itemsList.map((item) {
                  final map = item as Map;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${map['qty']}x ${map['name']}',
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          reaisBr((map['price'] as num)),
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.navyDark,
                          ),
                        ),
                      ],
                    ),
                  );
                })
              else
                Text(
                  order['items']?.toString() ?? '',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary),
                ),
              const SizedBox(height: 14),
              Divider(color: isDark ? AppColors.borderDark : Colors.grey.shade200),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Valor Total Pago',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.navyDark,
                    ),
                  ),
                  Text(
                    order['total']?.toString() ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.cardSurfaceDarkSecondary : const Color(0xFFF1F5F9),
                    foregroundColor: isDark ? Colors.white : AppColors.navyDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(LucideIcons.share2, size: 18),
                  label: Text('Compartilhar Comprovante', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Comprovante gerado em PDF com sucesso!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : AppColors.navyDark,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ordersList = _filteredOrders;

    double totalGastoMes = 0;
    for (final o in ordersList) {
      if (o['rawTotal'] is num) {
        totalGastoMes += (o['rawTotal'] as num).toDouble();
      }
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Histórico de Compras',
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : AppColors.navyDark,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Resumo de Compras no Topo
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total filtrado',
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
                        ),
                        Text(
                          reaisBr(totalGastoMes),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 36, color: Colors.white24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Compras no Minimarket',
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
                        ),
                        Text(
                          _allOrders.length == 1 ? '1 pedido' : '${_allOrders.length} pedidos',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Barra de Busca
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Filtrar por pedido, item ou pagamento...',
                  prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 16),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                ),
              ),
            ),

            // Filtros de Período & Status (Chips Horizontais)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                children: [
                  _buildFilterChip('Todos', isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('Últimos 7 dias', isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('Este mês', isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('Últimos 3 meses', isDark),
                ],
              ),
            ),

            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                children: [
                  _buildStatusFilterChip('Todos', isDark),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('Em andamento', isDark),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('Concluído', isDark),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('Cancelado', isDark),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Lista de Pedidos
            Expanded(
              child: ordersList.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: AppColors.primaryOrange.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                LucideIcons.receiptText,
                                color: AppColors.primaryOrange,
                                size: 44,
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (_carregando) ...[
                              const CircularProgressIndicator(),
                              const SizedBox(height: 18),
                            ],
                            Text(
                              _carregando
                                  ? 'Carregando seus pedidos...'
                                  : _erro != null
                                      ? 'Sem conexão com a loja'
                                      : (_pedidos?.isEmpty ?? true)
                                          ? 'Você ainda não fez nenhum pedido'
                                          : 'Nenhum pedido encontrado',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppColors.navyDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _erro ??
                                  ((_pedidos?.isEmpty ?? true)
                                      ? 'Suas compras pelo app e no totem aparecem aqui.'
                                      : 'Tente alterar os filtros ou o termo de busca.'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _carregar,
                      child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      itemCount: ordersList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final order = ordersList[index];

                        return InkWell(
                          onTap: () => _abrirDetalhesComprovante(order),
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.cardSurfaceDark : Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: AppColors.cardShadow,
                              border: Border.all(
                                color: isDark ? AppColors.borderDark : Colors.transparent,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryOrange.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            LucideIcons.receipt,
                                            color: AppColors.primaryOrange,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              order['id']?.toString() ?? '',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: isDark ? Colors.white : AppColors.navyDark,
                                              ),
                                            ),
                                            Text(
                                              order['date']?.toString() ?? '',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.successGreen.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        order['status']?.toString() ?? 'Concluído',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.successGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Divider(
                                  height: 1,
                                  thickness: 0.8,
                                  color: isDark ? AppColors.borderDark : Colors.grey.shade200,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  order['items']?.toString() ?? '',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: isDark ? Colors.white70 : AppColors.navyDark,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          LucideIcons.creditCard,
                                          size: 14,
                                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          order['paymentMethod']?.toString() ?? 'Cartão',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      order['total']?.toString() ?? '',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primaryOrange,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isDark) {
    final isSelected = _selectedPeriodo == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryOrange,
      backgroundColor: isDark ? AppColors.cardSurfaceDarkSecondary : Colors.white,
      labelStyle: GoogleFonts.poppins(
        color: isSelected ? Colors.white : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 11.5,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppColors.primaryOrange : (isDark ? AppColors.borderDark : Colors.grey.shade200),
        ),
      ),
      onSelected: (_) => setState(() => _selectedPeriodo = label),
    );
  }

  Widget _buildStatusFilterChip(String label, bool isDark) {
    final isSelected = _selectedStatus == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryOrange,
      backgroundColor: isDark ? AppColors.cardSurfaceDarkSecondary : Colors.white,
      labelStyle: GoogleFonts.poppins(
        color: isSelected ? Colors.white : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 11.5,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppColors.primaryOrange : (isDark ? AppColors.borderDark : Colors.grey.shade200),
        ),
      ),
      onSelected: (_) => setState(() => _selectedStatus = label),
    );
  }
}
