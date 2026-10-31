import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/config/ambiente.dart';

/// Endereço completo de um arquivo do servidor: o painel guarda "/uploads/...".
String urlDoServidor(String caminho) {
  final c = caminho.trim();
  if (c.isEmpty || c.startsWith('http://') || c.startsWith('https://')) return c;
  final base = Ambiente.resolveBaseUrl().replaceFirst(RegExp(r'/api/?$'), '').replaceFirst(RegExp(r'/$'), '');
  return '$base${c.startsWith('/') ? '' : '/'}$c';
}

/// MP4 ou WEBM enviado no painel (YouTube não toca dentro do banner).
bool ehVideoDeArquivo(String? url) {
  final u = (url ?? '').trim().toLowerCase().split('?').first;
  return u.endsWith('.mp4') || u.endsWith('.webm') || u.endsWith('.m4v');
}

/// Vídeo do banner: sem som, em repetição, cobrindo o cartão. Enquanto carrega ou se falhar,
/// mostra [reserva] (a imagem do banner).
class BannerVideo extends StatefulWidget {
  const BannerVideo({super.key, required this.url, this.reserva});

  final String url;
  final Widget? reserva;

  @override
  State<BannerVideo> createState() => _BannerVideoState();
}

class _BannerVideoState extends State<BannerVideo> {
  VideoPlayerController? _video;
  var _pronto = false;

  @override
  void initState() {
    super.initState();
    _abrir();
  }

  Future<void> _abrir() async {
    final video = VideoPlayerController.networkUrl(
      Uri.parse(urlDoServidor(widget.url)),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _video = video;
    try {
      await video.initialize();
      await video.setVolume(0);
      await video.setLooping(true);
      await video.play();
      if (mounted) setState(() => _pronto = true);
    } catch (_) {
      // Fica a imagem do banner.
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    if (!_pronto || video == null || !video.value.isInitialized) return widget.reserva ?? const SizedBox.shrink();
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: video.value.size.width,
        height: video.value.size.height,
        child: VideoPlayer(video),
      ),
    );
  }
}
