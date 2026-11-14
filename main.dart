import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Root(),
    );
  }
}

// ---------------------------------------------------------------- root

Future<Library> fetchLibrary(Profile p) async {
  if (!p.xtream) {
    Session.api = null;
    return loadM3u(p.m3u);
  }
  final api = XtreamApi(p.server, p.user, p.pass);
  final lib = await api.loadAll();
  Session.api = api;
  return lib;
}

class Root extends StatefulWidget {
  const Root({super.key});
  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  bool _loading = true;
  bool _adding = false;
  String? _error;
  Library? _lib;

  @override
  void initState() {
    super.initState();
    final p = Store.active;
    if (p == null) {
      _loading = false;
    } else {
      _switchTo(p);
    }
  }

  Future<void> _switchTo(Profile p) async {
    setState(() {
      _loading = true;
      _adding = false;
      _error = null;
    });
    try {
      await Store.selectProfile(p.id);
      Store.lock();
      final lib = await fetchLibrary(p);
      if (!mounted) return;
      setState(() {
        _lib = lib;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lib = null;
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _removeActive() async {
    final id = Store.activeId;
    if (id == null) return;
    await Store.removeProfile(id);
    Store.lock();
    final next = Store.active;
    if (next == null) {
      Session.api = null;
      if (mounted) {
        setState(() {
          _lib = null;
          _error = null;
        });
      }
    } else {
      await _switchTo(next);
    }
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
    if (_lib != null && !_adding) {
      return Shell(
        key: ValueKey(Store.activeId),
        lib: _lib!,
        onRemove: _removeActive,
        onAdd: () => setState(() => _adding = true),
        onSwitch: _switchTo,
      );
    }
    return LoginPage(
      initialError: _error,
      canCancel: _lib != null,
      onCancel: () => setState(() => _adding = false),
      onSwitch: _switchTo,
      onLoaded: (lib) => setState(() {
        _lib = lib;
        _adding = false;
        _error = null;
      }),
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
  final VoidCallback onRemove;
  final VoidCallback onAdd;
  final void Function(Profile) onSwitch;
  const Shell({
    super.key,
    required this.lib,
    required this.onRemove,
    required this.onAdd,
    required this.onSwitch,
  });

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
      _Tab(
        'Ayarlar',
        Icons.settings_outlined,
        Icons.settings,
        SettingsPage(
          lib: lib,
          onRemove: widget.onRemove,
          onAdd: widget.onAdd,
          onSwitch: widget.onSwitch,
        ),
      ),
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
  final bool canCancel;
  final VoidCallback onCancel;
  final void Function(Profile) onSwitch;
  final void Function(Library) onLoaded;
  const LoginPage({
    super.key,
    this.initialError,
    required this.canCancel,
    required this.onCancel,
    required this.onSwitch,
    required this.onLoaded,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _xtream = false;
  final _name = TextEditingController();
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
      final name = _name.text.trim().isEmpty
          ? 'Liste ${Store.profiles.length + 1}'
          : _name.text.trim();
      final profile = Profile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        xtream: _xtream,
        m3u: _m3u.text.trim(),
        server: _server.text.trim(),
        user: _user.text.trim(),
        pass: _pass.text.trim(),
      );
      final lib = await fetchLibrary(profile);
      if (lib.all.isEmpty) throw Exception('Hiç içerik bulunamadı');
      await Store.addProfile(profile);
      Store.lock();
      widget.onLoaded(lib);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = widget.canCancel ? <Profile>[] : Store.profiles;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (widget.canCancel)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Vazgeç',
                  icon: const Icon(Icons.close),
                  onPressed: widget.onCancel,
                ),
              )
            else
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
            Center(
              child: Text(
                  widget.canCancel
                      ? 'Yeni liste ekle'
                      : 'Canlı TV, filmler ve diziler tek yerde',
                  style: const TextStyle(color: Colors.white54)),
            ),
            if (saved.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('Kayıtlı listelerin',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final p in saved)
                Card(
                  color: AppColors.card,
                  child: ListTile(
                    leading: const Icon(Icons.playlist_play),
                    title: Text(p.name),
                    subtitle: Text(p.xtream ? 'Xtream' : 'M3U linki'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => widget.onSwitch(p),
                  ),
                ),
            ],
            const SizedBox(height: 28),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('M3U linki')),
                ButtonSegment(value: true, label: Text('Xtream')),
              ],
              selected: {_xtream},
              onSelectionChanged: (s) => setState(() => _xtream = s.first),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Liste adı (isteğe bağlı)',
                hintText: 'Ev, Yedek, Aile…',
              ),
            ),
            const SizedBox(height: 12),
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
