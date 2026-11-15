import 'package:flutter/material.dart';

import 'models.dart';
import 'nav.dart';
import 'pin.dart';
import 'store.dart';
import 'widgets.dart';

class VodPage extends StatefulWidget {
  final Kind kind;
  final List<Item> items;
  const VodPage({super.key, required this.kind, required this.items});

  @override
  State<VodPage> createState() => _VodPageState();
}

class _VodPageState extends State<VodPage> {
  String _q = '';
  String _gq = '';
  String? _group;
  int _sort = 0; // 0 yeni cikanlar, 1 yeni eklenenler, 2 A-Z

  static const _sortNames = ['Yeni çıkanlar', 'Yeni eklenenler', 'A-Z'];

  Future<void> _pickGroup(String? g) async {
    if (g != null && Store.isLockedGroup(g)) {
      final ok = await requestUnlock(context);
      if (!ok) return;
    }
    if (mounted) setState(() => _group = g);
  }

  int _compare(Item a, Item b) {
    switch (_sort) {
      case 1:
        final x = b.added.compareTo(a.added);
        return x != 0 ? x : b.year.compareTo(a.year);
      case 2:
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      default:
        return newestFirst(a, b);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMovie = widget.kind == Kind.movie;
    final groups = widget.items.map((e) => e.group).toSet().toList()..sort();
    final gq = _gq.toLowerCase();
    final shownGroups = groups
        .where((g) => g == _group || g.toLowerCase().contains(gq))
        .toList();
    final q = _q.toLowerCase();
    final shown = widget.items.where((c) {
      if (!Store.visible(c)) return false;
      if (_group != null && c.group != _group) return false;
      return q.isEmpty || c.name.toLowerCase().contains(q);
    }).toList()
      ..sort(_compare);

    return Scaffold(
      appBar: AppBar(
        title: Text(isMovie ? 'Filmler' : 'Diziler'),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Sırala',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => [
              for (var i = 0; i < _sortNames.length; i++)
                PopupMenuItem(value: i, child: Text(_sortNames[i])),
            ],
          ),
        ],
      ),
      body: Column(children: [
        SearchField(
          hint: isMovie ? 'Film ara' : 'Dizi ara',
          onChanged: (v) => setState(() => _q = v),
        ),
        SearchField(
          hint: 'Kategori ara',
          icon: Icons.category_outlined,
          onChanged: (v) => setState(() => _gq = v),
        ),
        GroupChips(groups: shownGroups, selected: _group, onSelect: _pickGroup),
        Expanded(
          child: shown.isEmpty
              ? EmptyState(
                  icon: Icons.movie_filter_outlined,
                  text: isMovie ? 'Film bulunamadı' : 'Dizi bulunamadı')
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.55,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: shown.length,
                  itemBuilder: (_, i) => PosterCard(
                    item: shown[i],
                    onTap: () async {
                      await openItem(context, shown[i]);
                      if (mounted) setState(() {});
                    },
                  ),
                ),
        ),
      ]),
    );
  }
}
