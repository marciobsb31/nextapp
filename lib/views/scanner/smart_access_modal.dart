import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

class SmartAccessModal extends StatefulWidget {
  const SmartAccessModal({super.key});

  @override
  State<SmartAccessModal> createState() => _SmartAccessModalState();
}

class _SmartAccessModalState extends State<SmartAccessModal>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _scannerController;
  late AnimationController _laserController;
  bool _isTorchOn = false;
  bool _hasUnlocked = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
    );

    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _laserController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasUnlocked) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      _triggerUnlockSuccess();
    }
  }

  void _triggerUnlockSuccess() {
    setState(() => _hasUnlocked = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.checkCircle2,
                color: AppColors.successGreen,
                size: 54,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'ACESSO LIBERADO!',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.navyDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A fechadura inteligente foi destravada. Entre e aproveite seu mercado 24h!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            GradientButton(
              text: 'OK, ENTRAR',
              height: 48,
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera scanner
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return Container(
                color: AppColors.navyDark,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.cameraOff, color: Colors.white70, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Câmera não disponível no ambiente atual',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Você pode simular a abertura com o botão abaixo para testar o Smart Access.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Top Overlay Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black.withOpacity(0.5),
                    child: IconButton(
                      icon: const Icon(LucideIcons.x, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.keyRound, color: AppColors.primaryOrange, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Smart Access Condomínio',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.black.withOpacity(0.5),
                    child: IconButton(
                      icon: Icon(
                        _isTorchOn ? LucideIcons.zap : LucideIcons.zapOff,
                        color: _isTorchOn ? AppColors.primaryOrange : Colors.white,
                      ),
                      onPressed: () {
                        _scannerController.toggleTorch();
                        setState(() => _isTorchOn = !_isTorchOn);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Central QR Code Viewfinder Box
          Center(
            child: SizedBox(
              width: 270,
              height: 270,
              child: Stack(
                children: [
                  // Moldura com cantos destacados
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                    ),
                  ),
                  // Cantoneiras laranjas vibrantes
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.primaryOrange, width: 4),
                          left: BorderSide(color: AppColors.primaryOrange, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.primaryOrange, width: 4),
                          right: BorderSide(color: AppColors.primaryOrange, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.primaryOrange, width: 4),
                          left: BorderSide(color: AppColors.primaryOrange, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.primaryOrange, width: 4),
                          right: BorderSide(color: AppColors.primaryOrange, width: 4),
                        ),
                      ),
                    ),
                  ),

                  // Linha de laser animada
                  AnimatedBuilder(
                    animation: _laserController,
                    builder: (context, child) {
                      return Positioned(
                        top: 20 + (_laserController.value * 230),
                        left: 10,
                        right: 10,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.primaryOrange,
                                Colors.white,
                                AppColors.primaryOrange,
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryOrange.withOpacity(0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Bottom instruction & quick simulate button
          Positioned(
            bottom: 30,
            left: 24,
            right: 24,
            child: Column(
              children: [
                Text(
                  'Aponte para o QR Code da catraca ou porta',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                GradientButton(
                  text: 'Simular Leitura QR Code',
                  icon: LucideIcons.qrCode,
                  onPressed: _triggerUnlockSuccess,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
