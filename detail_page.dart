import 'package:flutter/material.dart';

import 'api.dart';
import 'models.dart';
import 'nav.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

class DetailPage extends StatefulWidget {
  final Item item;
  const DetailPage({super.key, required this.item});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  String? _plot;
  Map<int, List<Episode>> _eps = {};
  int _season = 1;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = Session.api;
    final it = widget.item;
    try {
      if (api != null && it.ref != null) {
        if (it.kind == Kind.series) {
          final d = await api.seriesInfo(it.ref!);
          _plot = d.plot;
          _eps = d.episodes;
          if (_eps.isNotEmpty) {
            _season = (_eps.keys.toList()..sort()).first;
          }
        } else if (it.kind == Kind.movie) {
          _plot = await api.movieInfo(it.ref!);
        }
      }
    } catch (_) {
      _error = 'Detaylar yüklenemedi';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _playEpisode(Episode e) {
    final it = widget.item;
    playItem(
      context,
      Item(
        id: e.url,
        name: '${it.name} · S${e.season} B${e.number}',
        url: e.url,
        group: it.group,
        logo: e.image ?? it.logo,
        kind: Kind.movie,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final seasons = _eps.keys.toList()..sort();
    final episodes = _eps[_season] ?? const <Episode>[];
    final fav = Store.favs.contains(it.id);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 380,
            child: Stack(fit: StackFit.expand, children: [
              Poster(url: it.logo),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x99000000),
                      Color(0x00000000),
                      AppColors.bg
                    ],
                    stops: [0, 0.5, 1],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: IconButton.filledTonal(
                      style: IconButton.styleFrom(
                          backgroundColor: const Color(0x88000000)),
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.name,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w900, height: 1.1)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (it.rating != null) RatingBadge(it.rating!),
                  Chip(
                    label: Text(it.group),
                    visualDensity: VisualDensity.compact,
                  ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  if (it.url.isNotEmpty)
                    GradientButton(
                      label: 'Oynat',
                      icon: Icons.play_arrow_rounded,
                      onTap: () => playItem(context, it),
                    ),
                  if (it.url.isNotEmpty) const SizedBox(width: 10),
                  OutlinedButton.icon(
                    icon: Icon(fav ? Icons.check : Icons.add),
                    label: Text(fav ? 'Listemde' : 'Listeme ekle'),
                    onPressed: () {
                      Store.toggleFav(it);
                      setState(() {});
                    },
                  ),
                ]),
                const SizedBox(height: 16),
                if (_loading)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator()))
                else ...[
                  if (_plot != null)
                    Text(_plot!,
                        style: const TextStyle(
                            color: Colors.white70, height: 1.45)),
                  if (_error != null)
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
          if (it.kind == Kind.series && it.ref != null && !_loading) ...[
            if (seasons.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Bu dizi için bölüm bulunamadı.',
                    style: TextStyle(color: Colors.white54)),
              )
            else ...[
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  children: [
                    for (final s in seasons)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('Sezon $s'),
                          selected: _season == s,
                          onSelected: (_) => setState(() => _season = s),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              for (final e in episodes)
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 84,
                      height: 52,
                      child: Poster(url: e.image, icon: Icons.play_circle_outline),
                    ),
                  ),
                  title: Text(e.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Sezon ${e.season} · Bölüm ${e.number}'),
                  trailing: const Icon(Icons.play_arrow_rounded),
                  onTap: () => _playEpisode(e),
                ),
            ],
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
