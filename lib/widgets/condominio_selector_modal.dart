import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../controllers/auth_controller.dart';
import '../controllers/cart_controller.dart';
import '../models/loja_unidade.dart';
import '../theme/app_theme.dart';

/// Modal interativo para seleção de condomínio com isolamento de catálogo e proteção de carrinho
class CondominioSelectorModal {
  static void show(
    BuildContext context, {
    required AuthController authController,
    required CartController cartController,
    VoidCallback? onCondominioChanged,
  }) {
    final unidades = LojaUnidade.mockUnidadesCadastradas;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.building2, color: AppColors.primaryOrange, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Condomínios Conveniados',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navyDark,
                          ),
                        ),
                        Text(
                          'Cada condomínio possui seu estoque, catálogo e regras exclusivas',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ...unidades.map((unidade) {
                final isAtiva = authController.unidadeAtual.tenantId == unidade.tenantId;
                final estaNoRaio = unidade.estaNoRaio500m;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: !estaNoRaio
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            if (isAtiva) return;

                            // Alerta de troca de condomínio para proteger isolamento do carrinho
                            if (cartController.totalItemCount > 0) {
                              cartController.clear();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Carrinho reiniciado devido à troca de condomínio (Isolamento garantido).'),
                                  backgroundColor: AppColors.navyDark,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }

                            authController.selecionarUnidade(unidade, syncApi: true);
                            onCondominioChanged?.call();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Conectado a ${unidade.nome} • Catálogo exclusivo carregado'),
                                backgroundColor: const Color(0xFF2E7D32),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isAtiva ? AppColors.primaryOrange.withValues(alpha: 0.08) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isAtiva
                              ? AppColors.primaryOrange
                              : (estaNoRaio ? Colors.grey.shade300 : Colors.red.shade200),
                          width: isAtiva ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isAtiva
                                ? LucideIcons.checkCircle2
                                : (estaNoRaio ? LucideIcons.building : LucideIcons.shieldAlert),
                            color: isAtiva ? AppColors.primaryOrange : (estaNoRaio ? AppColors.navyDark : Colors.red),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  unidade.nome,
                                  style: GoogleFonts.poppins(
                                    fontWeight: isAtiva ? FontWeight.w700 : FontWeight.w600,
                                    fontSize: 13,
                                    color: estaNoRaio ? AppColors.navyDark : Colors.grey,
                                  ),
                                ),
                                Text(
                                  '${unidade.endereco} • ${unidade.bairro}',
                                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isAtiva
                                  ? AppColors.primaryOrange
                                  : (estaNoRaio ? Colors.green.shade50 : Colors.red.shade50),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isAtiva ? 'ATIVO' : unidade.distanciaFormatada,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isAtiva
                                    ? Colors.white
                                    : (estaNoRaio ? Colors.green.shade800 : Colors.red.shade700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
