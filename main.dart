import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'api.dart';
import 'home_page.dart';
import 'live_page.dart';
import 'models.dart';
import 'settings_page.dart';
import 'store.dart';
import 'theme.dart';
import 'vod_page.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await Store.init();
  runApp(const IptvApp());
}

class IptvApp extends StatelessWidget {
  const IptvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RYIPTV',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const Root(),
    );
  }
}

// ---------------------------------------------------------------- root

class Root extends StatefulWidget {
  const Root({super.key});
  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  bool _loading = true;
  String? _error;
  Library? _lib;

  @override
  void initState() {
    super.initState();
    _autoLogin();
  }

  Future<void> _autoLogin() async {
    final p = Store.prefs;
    final type = p.getString('type');
    if (type == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      Library lib;
      if (type == 'm3u') {
        Session.api = null;
        lib = await loadM3u(p.getString('m3u') ?? '');
      } else {
        final api = XtreamApi(p.getString('server') ?? '',
            p.getString('user') ?? '', p.getString('pass') ?? '');
        lib = await api.loadAll();
        Session.api = api;
      }
      setState(() {
        _lib = lib;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    for (final k in ['type', 'm3u', 'server', 'user', 'pass']) {
      await Store.prefs.remove(k);
    }
    Session.api = null;
    Store.lock();
    setState(() {
      _lib = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ShaderMask(
              shaderCallback: (r) => brandGradient.createShader(r),
              child: const Text('RYIPTV',
                  style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: Colors.white)),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Kütüphane yükleniyor…',
                style: TextStyle(color: Colors.white54)),
          ]),
        ),
      );
    }
    if (_lib != null) return Shell(lib: _lib!, onLogout: _logout);
    return LoginPage(
      initialError: _error,
      onLoaded: (l) => setState(() => _lib = l),
    );
  }
}

// ---------------------------------------------------------------- shell

class _Tab {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget page;
  _Tab(this.label, this.icon, this.activeIcon, this.page);
}

class Shell extends StatefulWidget {
  final Library lib;
  final VoidCallback onLogout;
  const Shell({super.key, required this.lib, required this.onLogout});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final lib = widget.lib;
    final tabs = <_Tab>[
      _Tab('Ana sayfa', Icons.home_outlined, Icons.home, HomePage(lib: lib)),
      _Tab('Canlı', Icons.live_tv_outlined, Icons.live_tv,
          LivePage(items: lib.live)),
      if (lib.movies.isNotEmpty)
        _Tab('Filmler', Icons.movie_outlined, Icons.movie,
            VodPage(kind: Kind.movie, items: lib.movies)),
      if (lib.series.isNotEmpty)
        _Tab('Diziler', Icons.video_library_outlined, Icons.video_library,
            VodPage(kind: Kind.series, items: lib.series)),
      _Tab('Ayarlar', Icons.settings_outlined, Icons.settings,
          SettingsPage(lib: lib, onLogout: widget.onLogout)),
    ];
    final idx = _i.clamp(0, tabs.length - 1);
    return Scaffold(
      body: tabs[idx].page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.activeIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- login

class LoginPage extends StatefulWidget {
  final String? initialError;
  final void Function(Library) onLoaded;
  const LoginPage({super.key, this.initialError, required this.onLoaded});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _xtream = false;
  final _m3u = TextEditingController();
  final _server = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.initialError;
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = Store.prefs;
      Library lib;
      if (!_xtream) {
        lib = await loadM3u(_m3u.text);
        Session.api = null;
        await p.setString('type', 'm3u');
        await p.setString('m3u', _m3u.text.trim());
      } else {
        final api = XtreamApi(_server.text, _user.text, _pass.text);
        lib = await api.loadAll();
        Session.api = api;
        await p.setString('type', 'xtream');
        await p.setString('server', _server.text.trim());
        await p.setString('user', _user.text.trim());
        await p.setString('pass', _pass.text.trim());
      }
      if (lib.all.isEmpty) throw Exception('Hiç içerik bulunamadı');
      widget.onLoaded(lib);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            Center(
              child: ShaderMask(
                shaderCallback: (r) => brandGradient.createShader(r),
                child: const Text('RYIPTV',
                    style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 5,
                        color: Colors.white)),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text('Canlı TV, filmler ve diziler tek yerde',
                  style: TextStyle(color: Colors.white54)),
            ),
            const SizedBox(height: 36),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('M3U linki')),
                ButtonSegment(value: true, label: Text('Xtream')),
              ],
              selected: {_xtream},
              onSelectionChanged: (s) => setState(() => _xtream = s.first),
            ),
            const SizedBox(height: 20),
            if (!_xtream)
              TextField(
                controller: _m3u,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'M3U linki',
                  hintText: 'http://...get.php?username=...',
                ),
              )
            else ...[
              TextField(
                controller: _server,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Sunucu adresi',
                  hintText: 'http://sunucu.com:8080',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _user,
                decoration: const InputDecoration(labelText: 'Kullanıcı adı'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Şifre'),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 24),
            _busy
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: GradientButton(
                      label: 'Kütüphaneyi yükle',
                      icon: Icons.play_arrow_rounded,
                      onTap: _submit,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
