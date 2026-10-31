import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_theme.dart';

class OrdersPage extends StatefulWidget {
  final List<Map<String, dynamic>> orders;

  const OrdersPage({super.key, this.orders = const []});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  String _selectedStatus = 'Todos';
  String _selectedPeriodo = 'Todos';
  String _searchQuery = '';

  static final List<Map<String, dynamic>> _mockDefaultOrders = [
    {
      'id': '#NXT-9842',
      'date': 'Hoje, 14:22',
      'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
      'status': 'Concluído',
      'paymentMethod': 'Mastercard Final 4021',
      'store': 'Minimarket Autônomo',
      'itemsList': [
        {'name': 'Red Bull Energy Drink 250ml', 'qty': 2, 'price': 10.90},
        {'name': 'Batata Pringles Original 114g', 'qty': 1, 'price': 13.00},
      ],
      'items': '2x Red Bull 250ml, 1x Pringles Original',
      'total': 'R\$ 34,80',
      'rawTotal': 34.80,
    },
    {
      'id': '#NXT-9510',
      'date': 'Ontem, 08:45',
      'timestamp': DateTime.now().subtract(const Duration(days: 1)),
      'status': 'Concluído',
      'paymentMethod': 'Pix Instantâneo',
      'store': 'Minimarket Autônomo',
      'itemsList': [
        {'name': 'Café Espresso Grãos Selecionados 250g', 'qty': 1, 'price': 16.50},
        {'name': 'Pão de Queijo Tradicional', 'qty': 1, 'price': 10.00},
      ],
      'items': '1x Café Espresso 250g, 1x Pão de Queijo',
      'total': 'R\$ 26,50',
      'rawTotal': 26.50,
    },
    {
      'id': '#NXT-9230',
      'date': '24/10/2026, 21:10',
      'timestamp': DateTime.now().subtract(const Duration(days: 5)),
      'status': 'Concluído',
      'paymentMethod': 'Mastercard Final 4021',
      'store': 'Minimarket Autônomo',
      'itemsList': [
        {'name': 'Cerveja Corona Extra 330ml', 'qty': 4, 'price': 9.50},
        {'name': 'Amendoim Japonês Crocante 150g', 'qty': 2, 'price': 4.90},
      ],
      'items': '4x Corona Extra 330ml, 2x Amendoim Crocante',
      'total': 'R\$ 47,80',
      'rawTotal': 47.80,
    },
    {
      'id': '#NXT-8940',
      'date': '18/10/2026, 12:05',
      'timestamp': DateTime.now().subtract(const Duration(days: 11)),
      'status': 'Concluído',
      'paymentMethod': 'NextPay Saldo Digital',
      'store': 'Minimarket Autônomo',
      'itemsList': [
        {'name': 'Água Mineral Crystal sem Gás 500ml', 'qty': 2, 'price': 3.50},
        {'name': 'Chocolate Milka Caramelo 100g', 'qty': 1, 'price': 12.90},
      ],
      'items': '2x Água Crystal 500ml, 1x Chocolate Milka',
      'total': 'R\$ 19,90',
      'rawTotal': 19.90,
    },
    {
      'id': '#NXT-8520',
      'date': '05/10/2026, 19:30',
      'timestamp': DateTime.now().subtract(const Duration(days: 24)),
      'status': 'Concluído',
      'paymentMethod': 'Visa Infinite Final 8834',
      'store': 'Minimarket Autônomo',
      'itemsList': [
        {'name': 'Refrigerante Coca-Cola 350ml', 'qty': 2, 'price': 5.50},
        {'name': 'Snack Doritos Queijo Nacho 84g', 'qty': 1, 'price': 9.90},
      ],
      'items': '2x Coca-Cola 350ml, 1x Doritos 84g',
      'total': 'R\$ 20,90',
      'rawTotal': 20.90,
    },
  ];

  List<Map<String, dynamic>> get _allOrders {
    if (widget.orders.isNotEmpty) return widget.orders;
    return _mockDefaultOrders;
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

  void _abrirDetalhesComprovante(Map<String, dynamic> order) {
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
                          'R\$ ${(map['price'] as num).toStringAsFixed(2)}',
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
                          'R\$ ${totalGastoMes.toStringAsFixed(2)}',
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
                          '${_allOrders.length} pedidos',
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
                            Text(
                              'Nenhum pedido encontrado',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppColors.navyDark,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tente alterar os filtros ou o termo de busca.',
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
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
                      physics: const BouncingScrollPhysics(),
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
