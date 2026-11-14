import 'package:flutter/material.dart';

import 'models.dart';
import 'nav.dart';
import 'pin.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

class LivePage extends StatefulWidget {
  final List<Item> items;
  const LivePage({super.key, required this.items});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  String _q = '';
  String? _group;
  bool _favOnly = false;

  Future<void> _pickGroup(String? g) async {
    if (g != null && Store.isLockedGroup(g)) {
      final ok = await requestUnlock(context);
      if (!ok) return;
    }
    if (mounted) setState(() => _group = g);
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.items.map((e) => e.group).toSet().toList()..sort();
    final q = _q.toLowerCase();
    final shown = widget.items.where((c) {
      if (!Store.visible(c)) return false;
      if (_favOnly && !Store.favs.contains(c.id)) return false;
      if (_group != null && c.group != _group) return false;
      return q.isEmpty || c.name.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Canlı TV (${shown.length})'),
        actions: [
          IconButton(
            tooltip: 'Favoriler',
            icon: Icon(_favOnly ? Icons.star : Icons.star_border,
                color: _favOnly ? AppColors.gold : null),
            onPressed: () => setState(() => _favOnly = !_favOnly),
          ),
        ],
      ),
      body: Column(children: [
        SearchField(
            hint: 'Kanal ara', onChanged: (v) => setState(() => _q = v)),
        GroupChips(groups: groups, selected: _group, onSelect: _pickGroup),
        Expanded(
          child: shown.isEmpty
              ? const EmptyState(icon: Icons.tv_off, text: 'Kanal bulunamadı')
              : ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final c = shown[i];
                    final fav = Store.favs.contains(c.id);
                    return Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Material(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          leading: SizedBox(
                            width: 48,
                            height: 48,
                            child: Poster(
                                url: c.logo,
                                icon: Icons.tv,
                                fit: BoxFit.contain),
                          ),
                          title: Text(c.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(c.group,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: Icon(fav ? Icons.star : Icons.star_border,
                                color: fav ? AppColors.gold : null),
                            onPressed: () {
                              Store.toggleFav(c);
                              setState(() {});
                            },
                          ),
                          onTap: () => playItem(context, c),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
