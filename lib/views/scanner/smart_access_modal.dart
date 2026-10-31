import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/rede/api.dart';
import '../../core/rede/falha_api.dart';
import '../../core/sessao/sessao.dart';
import '../../core/util/chave_unica.dart';
import '../../core/util/qr_equipamento.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import '../geladeira/geladeira_page.dart';

/// Chave única por leitura: repetir a mesma chave não abre duas vezes.
String novaChaveLeitura([Random? sorte]) => chaveUnica(sorte);

class SmartAccessModal extends StatefulWidget {
  const SmartAccessModal({super.key, this.sessao, this.api});

  final Sessao? sessao;
  final ApiPdv? api;

  @override
  State<SmartAccessModal> createState() => _SmartAccessModalState();
}

class _SmartAccessModalState extends State<SmartAccessModal>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late MobileScannerController _scannerController = _novoControle();
  late AnimationController _laserController;
  late final ApiPdv _api = widget.api ?? ApiPdv.padrao();
  bool _isTorchOn = false;
  bool _hasUnlocked = false;
  bool _enviando = false;

  /// Câmera ligada; enquanto falso, a tela mostra [_problemaCamera] ou "ligando".
  bool _cameraPronta = false;
  String? _problemaCamera;
  bool _negadaDeVez = false;
  bool _ligando = false;

  MobileScannerController _novoControle() => MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        returnImage: false,
        autoStart: false,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _ligarCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    _laserController.dispose();
    super.dispose();
  }

  /// Volta das configurações do celular: se a câmera foi liberada, liga.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_cameraPronta) _ligarCamera();
  }

  /// Pede a câmera e liga o leitor. O leitor guarda a recusa anterior e não
  /// tenta de novo sozinho, por isso cada nova tentativa usa um controle novo.
  Future<void> _ligarCamera() async {
    if (_ligando) return;
    _ligando = true;
    try {
      await _ligar();
    } finally {
      _ligando = false;
    }
  }

  Future<void> _ligar() async {
    setState(() {
      _problemaCamera = null;
      _negadaDeVez = false;
    });
    if (!kIsWeb) {
      final status = await Permission.camera.request();
      if (!mounted) return;
      if (!status.isGranted && !status.isLimited) {
        setState(() {
          _negadaDeVez = status.isPermanentlyDenied || status.isRestricted;
          _problemaCamera = _negadaDeVez
              ? 'A câmera está bloqueada para o NextPDV. Libere em Configurações > Apps > NextPDV > Permissões > Câmera.'
              : 'Permita o uso da câmera para ler o QR Code do equipamento.';
        });
        return;
      }
    }
    final anterior = _scannerController;
    _scannerController = _novoControle();
    setState(() {});
    await anterior.dispose();
    try {
      await _scannerController.start();
      if (mounted) setState(() => _cameraPronta = true);
    } on MobileScannerException catch (erro) {
      if (mounted) setState(() => _problemaCamera = _motivo(erro));
    } catch (erro) {
      if (mounted) setState(() => _problemaCamera = 'A câmera não ligou: $erro');
    }
  }

  String _motivo(MobileScannerException erro) {
    final detalhe = erro.errorDetails?.message;
    final base = switch (erro.errorCode) {
      MobileScannerErrorCode.permissionDenied => 'Permita o uso da câmera para ler o QR Code do equipamento.',
      MobileScannerErrorCode.unsupported => 'Este aparelho não tem câmera compatível com a leitura de QR Code.',
      _ => 'A câmera não ligou (${erro.errorCode.name}).',
    };
    return detalhe == null || detalhe.isEmpty ? base : '$base\n$detalhe';
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasUnlocked || _enviando) return;
    final codigo = capture.barcodes
        .map((b) => (b.rawValue ?? '').trim())
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (codigo.isNotEmpty) _abrir(codigo);
  }

  /// Envia o QR lido à API. Só mostra "liberado" quando o servidor autoriza e
  /// enfileira a ordem para a placa.
  Future<void> _abrir(String codigo) async {
    final sessao = widget.sessao;
    if (sessao == null || !sessao.autenticada) {
      _mostrarRecusa('Entre na sua conta para usar o Smart Access.');
      return;
    }
    final lido = QrEquipamento.ler(codigo);
    if (lido != null && lido.geladeira) {
      // QR colado na geladeira autônoma: abre o catálogo dela para comprar.
      await _scannerController.stop();
      if (!mounted) return;
      if (lido.contrato != null && lido.contrato != sessao.tenantId) {
        _mostrarRecusa('Esta geladeira é de outro condomínio ou empresa. Entre com a conta cadastrada nela.');
        return;
      }
      _abrirGeladeira(sessao, lido.id);
      return;
    }
    setState(() => _enviando = true);
    await _scannerController.stop();
    try {
      final resposta = await _api.abrirPorQr(sessao, qrCode: codigo, chave: novaChaveLeitura());
      if (!mounted) return;
      final motivo = (resposta['motivo'] ?? '').toString();
      if (resposta['autorizado'] != true && lido != null && motivo.contains('depois da compra')) {
        // Aparelho que exige compra: leva para a compra em vez de recusar.
        _abrirGeladeira(sessao, lido.id);
        return;
      }
      if (resposta['autorizado'] == true && resposta['comandoEnfileirado'] == true) {
        _triggerUnlockSuccess();
      } else {
        _mostrarRecusa((resposta['motivo'] ?? '').toString().isEmpty
            ? 'Acesso não autorizado para este equipamento.'
            : resposta['motivo'].toString());
      }
    } catch (erro) {
      if (mounted) _mostrarRecusa(falhaDe(erro).mensagem);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Widget _telaCamera(String texto, {bool comAcao = false}) {
    return Container(
      color: AppColors.navyDark,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(comAcao ? LucideIcons.cameraOff : LucideIcons.camera, color: Colors.white70, size: 48),
              const SizedBox(height: 16),
              Text(
                texto,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
              ),
              if (comAcao) ...[
                const SizedBox(height: 20),
                if (_negadaDeVez)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                    icon: const Icon(LucideIcons.settings, size: 16),
                    label: const Text('Abrir configurações'),
                    onPressed: openAppSettings,
                  ),
                TextButton(
                  onPressed: _ligarCamera,
                  child: const Text('Tentar de novo', style: TextStyle(color: Colors.white)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _abrirGeladeira(Sessao sessao, int id) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => GeladeiraPage(sessao: sessao, geladeiraId: id, api: widget.api)),
    );
  }

  void _mostrarRecusa(String motivo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Acesso não liberado', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 17)),
        content: Text(motivo, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _scannerController.start();
            },
            child: const Text('Ler de novo'),
          ),
        ],
      ),
    );
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
              'Ordem enviada para a fechadura. A porta destrava em instantes.',
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
          if (_problemaCamera != null)
            _telaCamera(_problemaCamera!, comAcao: true)
          else
            MobileScanner(
              key: ValueKey(_scannerController),
              controller: _scannerController,
              onDetect: _onDetect,
              errorBuilder: (context, error) => _telaCamera(_motivo(error), comAcao: true),
              placeholderBuilder: (context) => _telaCamera('Ligando a câmera...'),
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
                        Icon(LucideIcons.keyRound, color: AppColors.primaryOrange, size: 16),
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
                      decoration: BoxDecoration(
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
                      decoration: BoxDecoration(
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
                      decoration: BoxDecoration(
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
                      decoration: BoxDecoration(
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
                            gradient: LinearGradient(
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
                if (_enviando) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(color: Colors.white),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
