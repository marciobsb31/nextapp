import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../controllers/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/next_pdv_logo.dart';

class HelpSupportPage extends StatefulWidget {
  final AuthController authController;

  const HelpSupportPage({super.key, required this.authController});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  String _searchFilter = '';

  final List<Map<String, String>> _faqs = [
    {
      'pergunta': 'Como funciona a abertura da porta (Smart Access)?',
      'resposta':
          'Basta tocar no botão central "ABRIR PORTA" no rodapé do aplicativo e aproximar a câmera do leitor de QR Code localizado na entrada da loja física ou na porta do freezer. A fechadura eletromagnética liberará o acesso em segundos.',
      'categoria': 'Acesso',
    },
    {
      'pergunta': 'Por que não vejo bebidas alcoólicas?',
      'resposta':
          'Em conformidade com a legislação brasileira (Art. 243 da Lei nº 8.069), o NextPDV verifica a maioridade (+18) no momento do cadastro. Usuários menores de 18 anos têm a categoria e os produtos alcoólicos restritos automaticamente.',
      'categoria': 'Produtos',
    },
    {
      'pergunta': 'O que fazer se a porta ou freezer não destravar?',
      'resposta':
          'Verifique se sua conexão com a internet está ativa e se o seu aparelho está com a localização autorizada dentro do condomínio. Você também pode tentar ler o QR Code novamente.',
      'categoria': 'Acesso',
    },
    {
      'pergunta': 'Como adicionar itens aos favoritos?',
      'resposta':
          'Em qualquer produto, toque no ícone de coração. O item ficará salvo na sua prateleira de "Seus Favoritos" na tela inicial para compras rápidas.',
      'categoria': 'Compras',
    },
    {
      'pergunta': 'Quais formas de pagamento são aceitas?',
      'resposta':
          'Aceitamos PIX Instantâneo com QR Code dinâmico Copia-e-Cola e Cartões de Crédito (Visa, Mastercard, Elo) com processamento seguro e criptografia militar via PagBank.',
      'categoria': 'Pagamentos',
    },
    {
      'pergunta': 'Como funciona a ativação da conta por e-mail?',
      'resposta':
          'Ao criar uma conta no NextPDV, nosso servidor envia um e-mail com link de confirmação para o seu endereço de e-mail cadastrado (inclusive Gmail via SMTP seguro). Basta abrir o e-mail e confirmar para ativar seu acesso.',
      'categoria': 'Conta',
    },
    {
      'pergunta': 'Posso comprar em outro condomínio conveniado?',
      'resposta':
          'Por motivos de segurança e isolamento de estoque multi-tenant, você só pode realizar compras e acessar unidades dentro do raio seguro de 500 metros do seu condomínio residencial vinculado.',
      'categoria': 'Segurança',
    },
    {
      'pergunta': 'Como visualizar os comprovantes das minhas compras?',
      'resposta':
          'Acesse a aba "Histórico de Compras" no menu inferior. Lá você encontra todos os pedidos realizados com data, horário, itens discriminados, forma de pagamento e opção para exportar o comprovante digital.',
      'categoria': 'Compras',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredFaqs = _faqs.where((faq) {
      if (_searchFilter.trim().isEmpty) return true;
      final q = _searchFilter.toLowerCase().trim();
      return faq['pergunta']!.toLowerCase().contains(q) ||
          faq['resposta']!.toLowerCase().contains(q) ||
          faq['categoria']!.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            LucideIcons.arrowLeft,
            color: isDark ? Colors.white : AppColors.navyDark,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const NextPdvInlineBrand(height: 26),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Suporte
              Text(
                'Perguntas Frequentes',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.navyDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tire suas dúvidas sobre o funcionamento do minimarket autônomo e Smart Access.',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 18),

              // Campo de Busca nas Perguntas Frequentes
              TextField(
                onChanged: (val) => setState(() => _searchFilter = val),
                decoration: InputDecoration(
                  hintText: 'Pesquisar dúvida (porta, pix, 18+, etc.)...',
                  prefixIcon: const Icon(LucideIcons.search, size: 20, color: AppColors.textSecondary),
                  suffixIcon: _searchFilter.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 18),
                          onPressed: () => setState(() => _searchFilter = ''),
                        )
                      : null,
                ),
              ),

              const SizedBox(height: 18),

              // Lista de Perguntas Frequentes (Somente Perguntas Frequentes, Sem Abertura de Chamado)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardSurfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: AppColors.cardShadow,
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : Colors.transparent,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: filteredFaqs.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(LucideIcons.helpCircle, size: 40, color: Colors.grey),
                                const SizedBox(height: 10),
                                Text(
                                  'Nenhuma pergunta encontrada',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : AppColors.navyDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          children: filteredFaqs.map((faq) {
                            return ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                              childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryOrange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  LucideIcons.helpCircle,
                                  color: AppColors.primaryOrange,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                faq['pergunta']!,
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : AppColors.navyDark,
                                ),
                              ),
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    faq['resposta']!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                ),
              ),
            ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}
