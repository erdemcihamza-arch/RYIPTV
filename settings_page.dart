import 'package:flutter/material.dart';

import 'models.dart';
import 'pin.dart';
import 'store.dart';
import 'theme.dart';

class SettingsPage extends StatefulWidget {
  final Library lib;
  final VoidCallback onLogout;
  const SettingsPage({super.key, required this.lib, required this.onLogout});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  void _snack(String t) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(t)));

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
    final lockedCount =
        widget.lib.groups().where(Store.isLockedGroup).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(children: [
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
          leading: const Icon(Icons.logout),
          title: const Text('Çıkış yap'),
          subtitle: const Text('Kayıtlı liste bilgisini siler'),
          onTap: widget.onLogout,
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
