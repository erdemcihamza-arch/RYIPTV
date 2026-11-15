import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'store.dart';

class PlayerPage extends StatefulWidget {
  final String title;
  final String url;
  final bool isLive;
  const PlayerPage({
    super.key,
    required this.title,
    required this.url,
    this.isLive = false,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final List<String> _candidates;
  int _idx = 0;
  int _gen = 0;
  VideoPlayerController? _vc;
  ChewieController? _cc;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = widget.url;
    final fast =
        widget.isLive && Store.lowLatency && u.toLowerCase().endsWith('.m3u8');
    // Once .ts (dusuk gecikme), olmazsa orijinal .m3u8
    _candidates = fast ? ['${u.substring(0, u.length - 5)}.ts', u] : [u];
    _start();
  }

  Future<void> _release() async {
    final cc = _cc;
    final vc = _vc;
    _cc = null;
    _vc = null;
    cc?.dispose();
    try {
      await vc?.dispose();
    } catch (_) {}
  }

  Future<void> _start() async {
    final gen = ++_gen;
    await _release();
    if (!mounted || gen != _gen) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final vc = VideoPlayerController.networkUrl(
      Uri.parse(_candidates[_idx]),
      httpHeaders: const {'User-Agent': 'VLC/3.0.20 LibVLC/3.0.20'},
    );
    try {
      await vc.initialize().timeout(const Duration(seconds: 20));
      if (!mounted || gen != _gen) {
        try {
          await vc.dispose();
        } catch (_) {}
        return;
      }
      final cc = ChewieController(
        videoPlayerController: vc,
        autoPlay: true,
        isLive: widget.isLive,
        allowFullScreen: true,
        showControlsOnInitialize: false,
        errorBuilder: (context, message) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Yayın kesildi.\nGeri dönüp tekrar aç.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
      setState(() {
        _vc = vc;
        _cc = cc;
        _loading = false;
      });
    } catch (e) {
      try {
        await vc.dispose();
      } catch (_) {}
      if (!mounted || gen != _gen) return;
      if (_idx < _candidates.length - 1) {
        _idx++;
        _start();
      } else {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  void dispose() {
    _gen++;
    _cc?.dispose();
    _vc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // StackFit.expand: kapsayici her zaman tum ekrani kaplar. Ust cubuk
      // Positioned oldugu icin video alanini kucultemez.
      body: Stack(fit: StackFit.expand, children: [
        if (_cc != null)
          Positioned.fill(child: Center(child: Chewie(controller: _cc!))),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_error != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                  'Yayın açılamadı.\nSağlayıcı bağlantısını kontrol et.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: () {
                    _idx = 0;
                    _start();
                  },
                  child: const Text('Tekrar dene'),
                ),
              ]),
            ),
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                      backgroundColor: const Color(0x88000000)),
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          shadows: [Shadow(blurRadius: 6)])),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
