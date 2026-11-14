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
  String? _group;

  Future<void> _pickGroup(String? g) async {
    if (g != null && Store.isLockedGroup(g)) {
      final ok = await requestUnlock(context);
      if (!ok) return;
    }
    if (mounted) setState(() => _group = g);
  }

  @override
  Widget build(BuildContext context) {
    final isMovie = widget.kind == Kind.movie;
    final groups = widget.items.map((e) => e.group).toSet().toList()..sort();
    final q = _q.toLowerCase();
    final shown = widget.items.where((c) {
      if (!Store.visible(c)) return false;
      if (_group != null && c.group != _group) return false;
      return q.isEmpty || c.name.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text(isMovie ? 'Filmler' : 'Diziler')),
      body: Column(children: [
        SearchField(
          hint: isMovie ? 'Film ara' : 'Dizi ara',
          onChanged: (v) => setState(() => _q = v),
        ),
        GroupChips(groups: groups, selected: _group, onSelect: _pickGroup),
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
