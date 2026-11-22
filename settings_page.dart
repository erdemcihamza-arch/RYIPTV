import 'package:flutter/material.dart';

import 'api.dart';
import 'models.dart';
import 'pin.dart';
import 'store.dart';
import 'theme.dart';

class SettingsPage extends StatefulWidget {
  final Library lib;
  final VoidCallback onRemove;
  final VoidCallback onAdd;
  final void Function(Profile) onSwitch;
  const SettingsPage({
    super.key,
    required this.lib,
    required this.onRemove,
    required this.onAdd,
    required this.onSwitch,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<AccountInfo?>? _acc;

  @override
  void initState() {
    super.initState();
    _loadAcc();
  }

  void _loadAcc() {
    final p = Store.active;
    _acc = p == null ? null : fetchAccount(p);
  }

  String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  String _status(String s) {
    switch (s.toLowerCase()) {
      case 'active':
        return 'Aktif';
      case 'expired':
        return 'Süresi dolmuş';
      case 'disabled':
        return 'Devre dışı';
      case 'banned':
        return 'Engellenmiş';
      default:
        return s.isEmpty ? '-' : s;
    }
  }

  Widget _accountTile() {
    return FutureBuilder<AccountInfo?>(
      future: _acc,
      builder: (ctx, s) {
        if (s.connectionState != ConnectionState.done) {
          return const ListTile(
            leading: Icon(Icons.event_outlined),
            title: Text('Abonelik bilgisi alınıyor…'),
          );
        }
        final a = s.data;
        if (a == null) {
          return ListTile(
            leading: const Icon(Icons.event_busy_outlined),
            title: const Text('Bitiş tarihi alınamadı'),
            subtitle: const Text(
                'Sağlayıcı bilgi vermiyor ya da ulaşılamadı. Yenilemek için dokun.'),
            onTap: () => setState(_loadAcc),
          );
        }
        final exp = a.expires;
        final now = DateTime.now();
        final expired = exp != null && exp.isBefore(now);
        final left = exp?.difference(now).inDays;
        final warn = expired || (left != null && left <= 7);
        final parts = <String>[
          if (left != null) (expired ? 'Süresi dolmuş' : '$left gün kaldı'),
          'Durum: ${_status(a.status)}',
          if (a.active != null && a.max != null)
            'Bağlantı: ${a.active}/${a.max}',
        ];
        return ListTile(
          leading: Icon(
            warn ? Icons.warning_amber_rounded : Icons.event_available_outlined,
            color: warn ? Colors.amber : null,
          ),
          title: Text(exp == null
              ? 'Bitiş tarihi: süresiz'
              : 'Bitiş tarihi: ${_d(exp)}'),
          subtitle: Text(parts.join(' · ')),
          trailing: const Icon(Icons.refresh),
          onTap: () => setState(_loadAcc),
        );
      },
    );
  }

  Future<void> _edit(Profile p) async {
    final name = TextEditingController(text: p.name);
    final m3u = TextEditingController(text: p.m3u);
    final server = TextEditingController(text: p.server);
    final user = TextEditingController(text: p.user);
    final pass = TextEditingController(text: p.pass);
    var xtream = p.xtream;
    var hide = true;
    String? err;
    final np = await showDialog<Profile>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Listeyi düzenle'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('M3U linki')),
                  ButtonSegment(value: true, label: Text('Xtream')),
                ],
                selected: {xtream},
                onSelectionChanged: (s) => setD(() => xtream = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Liste adı'),
              ),
              const SizedBox(height: 12),
              if (!xtream)
                TextField(
                  controller: m3u,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'M3U linki'),
                )
              else ...[
                TextField(
                  controller: server,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Sunucu adresi',
                    hintText: 'http://sunucu.com:8080',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: user,
                  decoration: const InputDecoration(labelText: 'Kullanıcı adı'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pass,
                  obscureText: hide,
                  decoration: InputDecoration(
                    labelText: 'Şifre',
                    suffixIcon: IconButton(
                      icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setD(() => hide = !hide),
                    ),
                  ),
                ),
              ],
              if (err != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(err!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () {
                final bad = xtream
                    ? (server.text.trim().isEmpty ||
                        user.text.trim().isEmpty ||
                        pass.text.trim().isEmpty)
                    : m3u.text.trim().isEmpty;
                if (bad) {
                  setD(() => err = 'Boş alan bırakma');
                  return;
                }
                Navigator.pop(
                  ctx,
                  p.copyWith(
                    name: name.text.trim().isEmpty ? p.name : name.text.trim(),
                    xtream: xtream,
                    m3u: m3u.text.trim(),
                    server: server.text.trim(),
                    user: user.text.trim(),
                    pass: pass.text.trim(),
                  ),
                );
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    if (np == null || !mounted) return;

    // Xtream bilgileri dogru mu? Dogrulanamazsa kullaniciya sor
    if (np.xtream) {
      _snack('Bilgiler kontrol ediliyor…');
      final a = await fetchAccount(np);
      if (!mounted) return;
      if (a == null) {
        final keep = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Bilgiler doğrulanamadı'),
            content: const Text(
                'Sunucuya ulaşılamadı ya da kullanıcı adı / şifre hatalı olabilir. Yine de kaydedilsin mi?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Vazgeç')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Kaydet')),
            ],
          ),
        );
        if (keep != true) return;
      }
    }
    await Store.updateProfile(np);
    if (!mounted) return;
    if (np.id == Store.activeId) {
      widget.onSwitch(np); // aktif liste: yeni bilgilerle yeniden yukle
    } else {
      setState(() {});
    }
  }

  void _snack(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _rename(Profile p) async {
    final c = TextEditingController(text: p.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Liste adı'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Kaydet')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await Store.renameProfile(p.id, name);
      if (mounted) setState(() {});
    }
  }

  Future<void> _confirmRemove() async {
    final p = Store.active;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Listeyi sil'),
        content: Text(
            '${p?.name ?? 'Bu liste'} silinsin mi? Bu listenin favorileri ve izleme geçmişi de silinir.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (ok == true) widget.onRemove();
  }

  Future<void> _setPin() async {
    if (Store.hasPin && !await verifyPin(context)) return;
    if (!mounted) return;
    if (await createPin(context)) {
      Store.unlock();
      _snack('PIN kaydedildi');
      setState(() {});
    }
  }

  Future<void> _removePin() async {
    if (!await verifyPin(context)) return;
    await Store.removePin();
    Store.lock();
    if (mounted) {
      _snack('PIN kaldırıldı');
      setState(() {});
    }
  }

  Future<void> _toggleAuto(bool v) async {
    if (Store.hasPin && !await verifyPin(context)) return;
    await Store.setAutoAdult(v);
    if (mounted) setState(() {});
  }

  Future<void> _manageGroups() async {
    final ok = Store.hasPin ? await verifyPin(context) : await createPin(context);
    if (!ok || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _LockedGroupsPage(groups: widget.lib.groups()),
    ));
    if (mounted) setState(() {});
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
        child: Text(t,
            style: const TextStyle(
                color: AppColors.pink,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5)),
      );

  @override
  Widget build(BuildContext context) {
    final lockedCount = widget.lib.groups().where(Store.isLockedGroup).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(children: [
        _section('Listelerim'),
        for (final p in Store.profiles)
          ListTile(
            leading: Icon(
              p.id == Store.activeId
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: p.id == Store.activeId ? AppColors.pink : null,
            ),
            title: Text(p.name),
            subtitle: Text(
              p.xtream ? 'Xtream · ${p.server}' : 'M3U linki',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: 'Düzenle',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _edit(p),
            ),
            onTap: p.id == Store.activeId ? null : () => widget.onSwitch(p),
          ),
        _accountTile(),
        ListTile(
          leading: const Icon(Icons.add_circle_outline),
          title: const Text('Yeni liste ekle'),
          onTap: widget.onAdd,
        ),
        _section('Ebeveyn kilidi'),
        ListTile(
          leading: const Icon(Icons.pin_outlined),
          title: Text(Store.hasPin ? 'PIN değiştir' : 'PIN belirle'),
          subtitle: Text(Store.hasPin ? 'PIN ayarlı' : 'Henüz PIN yok'),
          onTap: _setPin,
        ),
        if (Store.hasPin)
          ListTile(
            leading: const Icon(Icons.no_encryption_outlined),
            title: const Text('PIN\'i kaldır'),
            onTap: _removePin,
          ),
        SwitchListTile(
          secondary: const Icon(Icons.shield_outlined),
          title: const Text('Yetişkin kategorilerini otomatik kilitle'),
          subtitle: const Text('Adı +18, XXX, Adult gibi olan kategoriler'),
          value: Store.autoAdult,
          onChanged: _toggleAuto,
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Kilitli kategoriler'),
          subtitle: Text('$lockedCount kategori kilitli'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _manageGroups,
        ),
        ListTile(
          leading: const Icon(Icons.lock_clock_outlined),
          title: const Text('Şimdi kilitle'),
          subtitle: Text(Store.isUnlocked
              ? 'Kilitli içerik şu an açık (15 dk)'
              : 'Kilitli içerik gizli'),
          enabled: Store.isUnlocked,
          onTap: () {
            Store.lock();
            setState(() {});
          },
        ),
        _section('Oynatıcı'),
        SwitchListTile(
          secondary: const Icon(Icons.bolt_outlined),
          title: const Text('Düşük gecikme modu'),
          subtitle: const Text(
              'Canlı kanallar daha az gecikmeyle açılır. İnternet zayıfsa kapat.'),
          value: Store.lowLatency,
          onChanged: (v) async {
            await Store.setLowLatency(v);
            if (mounted) setState(() {});
          },
        ),
        _section('Hesap'),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Son izlenenleri temizle'),
          onTap: () {
            Store.clearRecents();
            _snack('Temizlendi');
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Bu listeyi sil'),
          subtitle: const Text('Listenin favorileri ve geçmişi de silinir'),
          onTap: _confirmRemove,
        ),
      ]),
    );
  }
}

class _LockedGroupsPage extends StatefulWidget {
  final List<String> groups;
  const _LockedGroupsPage({required this.groups});

  @override
  State<_LockedGroupsPage> createState() => _LockedGroupsPageState();
}

class _LockedGroupsPageState extends State<_LockedGroupsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kilitli kategoriler')),
      body: ListView(children: [
        for (final g in widget.groups)
          Builder(builder: (_) {
            final auto = Store.autoAdult && isAdultGroup(g);
            return SwitchListTile(
              title: Text(g),
              subtitle: auto ? const Text('Otomatik kilitli') : null,
              value: auto || Store.lockedGroups.contains(g),
              onChanged: auto
                  ? null
                  : (_) {
                      Store.toggleLockedGroup(g);
                      setState(() {});
                    },
            );
          }),
      ]),
    );
  }
}
