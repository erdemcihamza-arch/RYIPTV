import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);
  late final List<String> _candidates;
  int _idx = 0;
  Timer? _watchdog;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = widget.url;
    final fast =
        widget.isLive && Store.lowLatency && u.toLowerCase().endsWith('.m3u8');
    // Once .ts (dusuk gecikme), olmazsa orijinal .m3u8
    _candidates = fast
        ? ['${u.substring(0, u.length - 5)}.ts', u]
        : [u];
    _setup();
  }

  Future<void> _setup() async {
    if (widget.isLive && Store.lowLatency) {
      try {
        final p = _player.platform as dynamic;
        await p.setProperty('profile', 'low-latency');
        await p.setProperty('cache', 'no');
        await p.setProperty('demuxer-readahead-secs', '2');
      } catch (_) {}
    }
    _player.stream.error.listen((e) => _fail(e));
    _openCurrent();
  }

  void _openCurrent() {
    _watchdog?.cancel();
    _player.open(Media(
      _candidates[_idx],
      httpHeaders: const {'User-Agent': 'VLC/3.0.20 LibVLC/3.0.20'},
    ));
    // Yayin 10 sn icinde baslamazsa bir sonraki adrese gec
    if (_idx < _candidates.length - 1) {
      _watchdog = Timer(const Duration(seconds: 10), () {
        if (mounted && !_player.state.playing) _fail('timeout');
      });
    }
  }

  void _fail(String reason) {
    if (!mounted) return;
    if (_idx < _candidates.length - 1) {
      _idx++;
      _openCurrent();
    } else {
      setState(() => _error = reason);
    }
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: Video(controller: _controller)),
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
                    setState(() {
                      _error = null;
                      _idx = 0;
                    });
                    _openCurrent();
                  },
                  child: const Text('Tekrar dene'),
                ),
              ]),
            ),
          ),
        SafeArea(
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
      ]),
    );
  }
}
