import 'package:flutter/material.dart';

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

  static const _videoModes = [
    'Otomatik',
    'Uyumlu (yazılım çözücü)',
    'Alternatif (doğrudan yüzey)',
  ];

  Future<void> _pickVideoMode() async {
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Görüntü modu'),
        children: [
          for (var i = 0; i < _videoModes.length; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, i),
              child: Row(children: [
                Icon(
                  i == Store.videoMode
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(_videoModes[i])),
              ]),
            ),
        ],
      ),
    );
    if (v != null) {
      await Store.setVideoMode(v);
      if (mounted) setState(() {});
    }
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
              tooltip: 'Adı değiştir',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _rename(p),
            ),
            onTap: p.id == Store.activeId ? null : () => widget.onSwitch(p),
          ),
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
        ListTile(
          leading: const Icon(Icons.tv_outlined),
          title: const Text('Görüntü modu'),
          subtitle: Text(
              '${_videoModes[Store.videoMode]}. Görüntü ekranın üstünde ince kalıyorsa ya da siyahsa başka bir mod dene. Sonraki açılışta geçerli olur.'),
          onTap: _pickVideoMode,
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
