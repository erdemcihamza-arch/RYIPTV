import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:http/http.dart' as http;
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
  static const _pipChannel = MethodChannel('ryiptv/pip');

  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);
  final List<StreamSubscription> _subs = [];
  late final List<(String, String?, bool)> _candidates;
  String? _ip; // alan adinin IPv4 adresi (IPv6 takilmasina karsi)
  late Tracks _tracks;
  int _idx = 0;

  Timer? _watchdog;
  Timer? _hideTimer;
  Timer? _hintTimer;

  bool _show = true;
  bool _inPip = false;
  bool _fullscreen = false;
  bool _playing = false;
  bool _started = false;
  bool _buffering = true;
  bool _autoPicked = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  double? _drag;
  String? _error;
  String? _probeInfo;
  String? _hint;
  bool _hintRight = true;

  @override
  void initState() {
    super.initState();
    _tracks = _player.state.tracks;

    // Resim icinde resim: ana ekrana cikinca video kucuk pencerede devam eder
    _pipChannel.setMethodCallHandler((call) async {
      if (call.method == 'pip' && mounted) {
        setState(() => _inPip = call.arguments == true);
      }
    });
    _pipChannel.invokeMethod<void>('setEnabled', true).catchError((_) {});

    final u = widget.url;
    final fast =
        widget.isLive && Store.lowLatency && u.toLowerCase().endsWith('.m3u8');
    // Adres cesitleri: canlida .ts ve .m3u8 ikisi de denenir
    final low = u.toLowerCase();
    final String? alt = !widget.isLive
        ? null
        : low.endsWith('.m3u8')
            ? '${u.substring(0, u.length - 5)}.ts'
            : (low.endsWith('.ts')
                ? '${u.substring(0, u.length - 3)}.m3u8'
                : null);
    final base = <String>[
      if (fast && alt != null) alt,
      u,
      if (!fast && alt != null) alt,
    ];
    // M3U listesi: yayin adresindeki sunucu / port, liste linkinden farkliysa
    // (ornegin :2086 yerine :8080) once liste linkinin sunucusunu dene
    final urls = <String>[
      for (final x in base)
        if (_fixed(x) != null) _fixed(x)!,
      ...base,
    ];
    // Kimlik (User-Agent) cesitleri: bazi saglayicilar VLC'yi engeller
    const uas = <String?>[
      'VLC/3.0.20 LibVLC/3.0.20',
      null,
      'IPTVSmartersPro',
      'ExoPlayerLib/2.19.1',
    ];
    // Once IPv4 adresiyle (varsa), sonra normal adresle farkli kimlikler
    _candidates = [
      for (final x in urls) (x, uas[0], true),
      for (final ua in uas)
        for (final x in urls) (x, ua, false),
    ];

    _subs.addAll([
      _player.stream.playing.listen((p) {
        if (!mounted) return;
        setState(() => _playing = p);
      }),
      _player.stream.buffering.listen((b) {
        if (!mounted) return;
        setState(() => _buffering = b);
      }),
      _player.stream.position.listen((p) {
        if (!mounted) return;
        // Yayin ancak sure gercekten ilerleyince "basladi" sayilir
        if (p > Duration.zero) _markStarted();
        if (_drag == null && _show) setState(() => _pos = p);
      }),
      _player.stream.duration.listen((d) {
        if (mounted) setState(() => _dur = d);
      }),
      _player.stream.tracks.listen(_onTracks),
      _player.stream.error.listen(_fail),
    ]);

    _setup();
    _scheduleHide();
  }

  String? _fixed(String u) {
    final p = Store.active;
    if (p == null || p.xtream || p.m3u.isEmpty) return null;
    try {
      final a = Uri.parse(u);
      final b = Uri.parse(p.m3u);
      if (!b.hasAuthority || b.host.isEmpty) return null;
      if (a.host == b.host && a.port == b.port) return null;
      if (!RegExp(r'^/(live|movie|series)/').hasMatch(a.path)) return null;
      return a
          .replace(scheme: b.scheme, host: b.host, port: b.port)
          .toString();
    } catch (_) {
      return null;
    }
  }

  // Yayin gercekten akmaya basladi (veri geliyor)
  void _markStarted() {
    if (!mounted || _started) return;
    _watchdog?.cancel();
    setState(() {
      _started = true;
      _error = null;
    });
  }

  Future<void> _setup() async {
    // Bazi saglayicilar gecersiz / kendinden imzali https sertifikasi kullanir;
    // diger uygulamalar gibi bunu kabul et
    try {
      final p = _player.platform as dynamic;
      await p.setProperty('tls-verify', 'no');
      await p.setProperty('network-timeout', '15');
    } catch (_) {}
    if (widget.isLive && Store.lowLatency) {
      try {
        final p = _player.platform as dynamic;
        await p.setProperty('profile', 'low-latency');
        await p.setProperty('cache', 'no');
        await p.setProperty('demuxer-readahead-secs', '2');
      } catch (_) {}
    }
    await _resolveIp();
    if (mounted) _openCurrent();
  }

  Future<void> _resolveIp() async {
    try {
      final uri = Uri.parse(widget.url);
      if (uri.scheme != 'http') return;
      if (InternetAddress.tryParse(uri.host) != null) return;
      final r = await InternetAddress.lookup(uri.host,
              type: InternetAddressType.IPv4)
          .timeout(const Duration(seconds: 5));
      if (r.isNotEmpty) _ip = r.first.address;
    } catch (_) {}
  }

  void _openCurrent() {
    _watchdog?.cancel();
    var (url, ua, viaIp) = _candidates[_idx];
    final headers = <String, String>{if (ua != null) 'User-Agent': ua};
    if (viaIp) {
      if (_ip == null) {
        // IPv4 cozulemediyse bu varyanti atla
        if (_idx < _candidates.length - 1) {
          _idx++;
          _openCurrent();
          return;
        }
      } else {
        final uri = Uri.parse(url);
        headers['Host'] = uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
        url = uri.replace(host: _ip).toString();
      }
    }
    _player.open(Media(url, httpHeaders: headers));
    // Yayin 8 sn icinde baslamazsa bir sonraki varyanta gec
    final last = _idx >= _candidates.length - 1;
    _watchdog = Timer(Duration(seconds: last ? 20 : 8), () {
      if (mounted && !_started) _fail('timeout');
    });
  }

  void _fail(String reason) {
    if (!mounted) return;
    // Yayin zaten oynuyorsa veya mesaj zararsiz bir uyariysa hata sayma
    if (_started) return;
    if (reason.contains('force-seekable')) return;
    if (_idx < _candidates.length - 1) {
      _idx++;
      _openCurrent();
    } else {
      setState(() => _error = reason == 'timeout'
          ? 'Sunucu veri göndermedi (zaman aşımı)'
          : reason);
      _runProbe();
    }
  }

  // ------------------------------------------------ baglanti testi

  // Kullanici adi / sifre ekranda gorunmesin
  String _mask(String s) => s
      .replaceAllMapped(RegExp(r'/(live|movie|series)/[^/]+/[^/]+/'),
          (m) => '/${m[1]}/***/***/')
      .replaceAll(RegExp(r'(username|password)=[^&]*'), r'$1=***');

  Future<String> _probeOne(String url, String? ua) async {
    final c = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url));
      if (ua != null) req.headers['User-Agent'] = ua;
      final res = await c.send(req).timeout(const Duration(seconds: 10));
      var got = 0;
      try {
        final first = await res.stream.first.timeout(const Duration(seconds: 8));
        got = first.length;
      } catch (_) {}
      final ct = res.headers['content-type'] ?? '-';
      final loc = res.headers['location'];
      return 'HTTP ${res.statusCode} · $ct · ${got}B'
          '${loc != null ? ' · yönlendirme: ${_mask(loc)}' : ''}';
    } catch (e) {
      final t = e.toString();
      return 'Hata: ${t.length > 90 ? t.substring(0, 90) : t}';
    } finally {
      c.close();
    }
  }

  Future<void> _runProbe() async {
    setState(() => _probeInfo = 'Bağlantı test ediliyor…');
    final a = await _probeOne(widget.url, 'VLC/3.0.20 LibVLC/3.0.20');
    final b = await _probeOne(widget.url, null);
    if (!mounted) return;
    setState(() => _probeInfo =
        '${_mask(widget.url)}\nVLC kimliği: $a\nKimliksiz: $b');
  }

  // ------------------------------------------------ ses / altyazi

  bool _isTr(String? lang, String? title) {
    final l = (lang ?? '').toLowerCase();
    final t = (title ?? '').toLowerCase();
    return l == 'tr' ||
        l == 'tur' ||
        l.startsWith('tr-') ||
        t.contains('turk') ||
        t.contains('türk');
  }

  String? _langName(String? lang) {
    switch ((lang ?? '').toLowerCase()) {
      case 'tr':
      case 'tur':
        return 'Türkçe';
      case 'en':
      case 'eng':
        return 'İngilizce';
      case 'de':
      case 'ger':
      case 'deu':
        return 'Almanca';
      case 'fr':
      case 'fre':
      case 'fra':
        return 'Fransızca';
      case 'es':
      case 'spa':
        return 'İspanyolca';
      case 'it':
      case 'ita':
        return 'İtalyanca';
      case 'ru':
      case 'rus':
        return 'Rusça';
      case 'ar':
      case 'ara':
        return 'Arapça';
      case 'ja':
      case 'jpn':
        return 'Japonca';
      case 'ko':
      case 'kor':
        return 'Korece';
      case 'zh':
      case 'chi':
      case 'zho':
        return 'Çince';
      default:
        return null;
    }
  }

  String _label(String? lang, String? title, int n) {
    final ln = _langName(lang);
    final t = (title ?? '').trim();
    if (ln != null && t.isNotEmpty && !t.toLowerCase().contains(ln.toLowerCase())) {
      return '$ln · $t';
    }
    if (ln != null) return ln;
    if (t.isNotEmpty) return t;
    if ((lang ?? '').isNotEmpty) return lang!;
    return 'Parça $n';
  }

  List<AudioTrack> get _audioList =>
      _tracks.audio.where((a) => a.id != 'auto' && a.id != 'no').toList();

  List<SubtitleTrack> get _subList =>
      _tracks.subtitle.where((s) => s.id != 'auto' && s.id != 'no').toList();

  bool get _hasTrackChoices {
    if (widget.isLive) return false;
    return _audioList.length > 1 || _subList.isNotEmpty;
  }

  void _onTracks(Tracks t) {
    if (!mounted) return;
    setState(() => _tracks = t);
    if (_autoPicked || widget.isLive) return;
    final audio = _audioList;
    final subs = _subList;
    if (audio.isEmpty && subs.isEmpty) return;
    _autoPicked = true;
    // Turkce dublaj varsa onu sec; yoksa Turkce altyazi varsa onu ac
    final trAudio = audio.where((a) => _isTr(a.language, a.title)).toList();
    if (trAudio.isNotEmpty) {
      _player.setAudioTrack(trAudio.first);
    } else {
      final trSub = subs.where((s) => _isTr(s.language, s.title)).toList();
      if (trSub.isNotEmpty) _player.setSubtitleTrack(trSub.first);
    }
  }

  void _openTracks() {
    _hideTimer?.cancel();
    final audio = _audioList;
    final subs = _subList;
    final curA = _player.state.track.audio.id;
    final curS = _player.state.track.subtitle.id;
    Widget head(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
        );
    Icon dot(bool on) =>
        Icon(on ? Icons.radio_button_checked : Icons.radio_button_off);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF161622),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            head('Ses'),
            if (audio.isEmpty)
              const ListTile(title: Text('Bu içerikte ek ses parçası yok')),
            for (var i = 0; i < audio.length; i++)
              ListTile(
                leading: dot(curA == audio[i].id),
                title: Text(_label(audio[i].language, audio[i].title, i + 1)),
                onTap: () {
                  _player.setAudioTrack(audio[i]);
                  Navigator.pop(ctx);
                },
              ),
            head('Altyazı'),
            ListTile(
              leading: dot(curS == 'no'),
              title: const Text('Kapalı'),
              onTap: () {
                _player.setSubtitleTrack(SubtitleTrack.no());
                Navigator.pop(ctx);
              },
            ),
            for (var i = 0; i < subs.length; i++)
              ListTile(
                leading: dot(curS == subs[i].id),
                title: Text(_label(subs[i].language, subs[i].title, i + 1)),
                onTap: () {
                  _player.setSubtitleTrack(subs[i]);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ).whenComplete(_scheduleHide);
  }

  // ------------------------------------------------ kontroller

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _started) setState(() => _show = false);
    });
  }

  void _toggleUi() {
    setState(() => _show = !_show);
    if (_show) _scheduleHide();
  }

  void _seekBy(int sec) {
    if (widget.isLive) return;
    var t = _player.state.position + Duration(seconds: sec);
    if (t < Duration.zero) t = Duration.zero;
    final d = _player.state.duration;
    if (d > Duration.zero && t > d) t = d;
    _player.seek(t);
    _hintTimer?.cancel();
    setState(() {
      _pos = t;
      _hint = sec > 0 ? '+$sec sn' : '$sec sn';
      _hintRight = sec > 0;
    });
    _hintTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _hint = null);
    });
  }

  Future<void> _toggleFullscreen() async {
    _fullscreen = !_fullscreen;
    if (_fullscreen) {
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (mounted) setState(() {});
    _scheduleHide();
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _hideTimer?.cancel();
    _hintTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _pipChannel.invokeMethod<void>('setEnabled', false).catchError((_) {});
    _pipChannel.setMethodCallHandler(null);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _player.dispose();
    super.dispose();
  }

  // ------------------------------------------------ arayuz

  Widget _roundBtn(IconData icon, VoidCallback onTap,
      {String? tip, double size = 24}) {
    return IconButton.filledTonal(
      tooltip: tip,
      iconSize: size,
      style: IconButton.styleFrom(backgroundColor: const Color(0x88000000)),
      icon: Icon(icon),
      onPressed: onTap,
    );
  }

  Widget _topBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xAA000000), Color(0x00000000)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              _roundBtn(Icons.arrow_back, () => Navigator.of(context).pop(),
                  tip: 'Geri'),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(blurRadius: 6)])),
              ),
              if (_hasTrackChoices) ...[
                _roundBtn(Icons.subtitles, _openTracks,
                    tip: 'Ses ve altyazı'),
                const SizedBox(width: 6),
              ],
              _roundBtn(Icons.picture_in_picture_alt, () {
                _pipChannel.invokeMethod<void>('enter').catchError((_) {});
              }, tip: 'Küçük pencere'),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final max = _dur.inMilliseconds > 0 ? _dur.inMilliseconds.toDouble() : 1.0;
    final cur =
        (_drag ?? _pos.inMilliseconds.toDouble()).clamp(0.0, max).toDouble();
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xAA000000), Color(0x00000000)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(children: [
              if (widget.isLive) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('CANLI',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                ),
                const Spacer(),
              ] else ...[
                Text(_fmt(Duration(milliseconds: cur.round())),
                    style: const TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: cur,
                    max: max,
                    onChanged: (v) {
                      _hideTimer?.cancel();
                      setState(() => _drag = v);
                    },
                    onChangeEnd: (v) {
                      _player.seek(Duration(milliseconds: v.round()));
                      setState(() {
                        _pos = Duration(milliseconds: v.round());
                        _drag = null;
                      });
                      _scheduleHide();
                    },
                  ),
                ),
                Text(_fmt(_dur), style: const TextStyle(fontSize: 12)),
              ],
              IconButton(
                tooltip: 'Tam ekran',
                icon:
                    Icon(_fullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
                onPressed: _toggleFullscreen,
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showUi = _show && !_inPip;
    final loading = _error == null && (_buffering || !_started);

    return Scaffold(
      backgroundColor: Colors.black,
      // StackFit.expand: kapsayici her zaman tum ekrani kaplar.
      body: Stack(fit: StackFit.expand, children: [
        Positioned.fill(
          child: Video(
            controller: _controller,
            controls: NoVideoControls,
            fill: Colors.black,
            subtitleViewConfiguration: SubtitleViewConfiguration(
              style: const TextStyle(
                fontSize: 18,
                height: 1.3,
                color: Colors.white,
                backgroundColor: Color(0xAA000000),
              ),
              padding: EdgeInsets.fromLTRB(16, 0, 16, showUi ? 96 : 32),
            ),
          ),
        ),
        // Dokunma katmani: tek dokunus kontrolleri ac/kapat,
        // ciftli dokunus sagda +20 sn, solda -20 sn
        Positioned.fill(
          child: Row(children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleUi,
                onDoubleTap: widget.isLive ? null : () => _seekBy(-20),
                child: const SizedBox.expand(),
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleUi,
                onDoubleTap: widget.isLive ? null : () => _seekBy(20),
                child: const SizedBox.expand(),
              ),
            ),
          ]),
        ),
        if (_hint != null && !_inPip)
          IgnorePointer(
            child: Align(
              alignment: _hintRight
                  ? const Alignment(0.6, 0)
                  : const Alignment(-0.6, 0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0x99000000),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(_hint!,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        if (loading && !_inPip)
          const IgnorePointer(
              child: Center(child: CircularProgressIndicator())),
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
                if (_probeInfo != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _probeInfo!,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _probeInfo = null;
                      _idx = 0;
                    });
                    _openCurrent();
                  },
                  child: const Text('Tekrar dene'),
                ),
              ]),
            ),
          ),
        if (showUi) ...[
          Center(
            child: _roundBtn(
              _playing ? Icons.pause : Icons.play_arrow,
              () {
                _player.playOrPause();
                _scheduleHide();
              },
              size: 40,
            ),
          ),
          _topBar(),
          _bottomBar(),
        ],
      ]),
    );
  }
}
