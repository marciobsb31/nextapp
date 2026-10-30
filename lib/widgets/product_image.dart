import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Widget de imagem de produto que resolve problemas de CORS em Flutter Web,
/// lida com URLs vazias/nulas e erros de carregamento com fallback elegante.
class ProductImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color placeholderColor;
  final double iconSize;

  const ProductImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholderColor = const Color(0xFFF3F4F6),
    this.iconSize = 32,
  });

  /// Converte a URL da imagem aplicando proxy de CORS seguro se estiver rodando no Web
  static String formatProxyUrl(String originalUrl) {
    final clean = originalUrl.trim();
    if (clean.isEmpty) return '';

    // No mobile nativo (Android/iOS), não há restrição de CORS
    if (!kIsWeb) return clean;

    // Se já for data URI ou blob local, retorna direto
    if (clean.startsWith('data:') || clean.startsWith('blob:')) {
      return clean;
    }

    // Google Cloud Storage ou URLs externas sem cabeçalho Access-Control-Allow-Origin
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      if (clean.contains('wsrv.nl') || clean.contains('weserv.nl')) {
        return clean;
      }
      // wsrv.nl provê entrega com CORS (Access-Control-Allow-Origin: *), cache em CDN e otimização
      return 'https://wsrv.nl/?url=${Uri.encodeComponent(clean)}';
    }

    return clean;
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();

    final Widget placeholder = Container(
      width: width,
      height: height,
      color: placeholderColor,
      child: Center(
        child: Icon(
          LucideIcons.package,
          color: Colors.grey.shade400,
          size: iconSize,
        ),
      ),
    );

    if (cleanUrl.isEmpty) return placeholder;

    final resolvedUrl = formatProxyUrl(cleanUrl);

    return Image.network(
      resolvedUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: width,
          height: height,
          color: placeholderColor,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                    : null,
                color: Colors.grey.shade400,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        // Fallback: se falhar pelo proxy, tenta a URL direta caso o ambiente suporte
        if (resolvedUrl != cleanUrl) {
          return Image.network(
            cleanUrl,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => placeholder,
          );
        }
        return placeholder;
      },
    );
  }
}
