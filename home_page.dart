import 'package:flutter/material.dart';

import 'models.dart';
import 'nav.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

class HomePage extends StatefulWidget {
  final Library lib;
  const HomePage({super.key, required this.lib});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<void> _open(Item it, {bool direct = false}) async {
    if (direct && it.url.isNotEmpty) {
      await playItem(context, it);
    } else {
      await openItem(context, it);
    }
    if (mounted) setState(() {});
  }

  Item? _heroItem() {
    final pool = [...widget.lib.movies, ...widget.lib.series]
        .where((i) => Store.visible(i) && (i.logo ?? '').startsWith('http'))
        .take(30)
        .toList();
    if (pool.isEmpty) return null;
    return pool[DateTime.now().day % pool.length];
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return 'İyi geceler';
    if (h < 12) return 'Günaydın';
    if (h < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }

  @override
  Widget build(BuildContext context) {
    final lib = widget.lib;
    final recents = Store.recents.where(Store.visible).toList();
    final favs = lib.all
        .where((i) => Store.favs.contains(i.id) && Store.visible(i))
        .toList();
    final movies = lib.movies.where(Store.visible).take(25).toList();
    final series = lib.series.where(Store.visible).take(25).toList();
    final live = lib.live.where(Store.visible).take(20).toList();
    final hero = _heroItem();

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _hero(hero),
          if (recents.isNotEmpty)
            PosterRow(
              title: 'Son izlediklerin',
              items: recents,
              onTap: (i) => _open(i, direct: true),
            ),
          if (favs.isNotEmpty)
            PosterRow(title: 'Listem', items: favs, onTap: _open),
          if (movies.isNotEmpty)
            PosterRow(title: 'Yeni filmler', items: movies, onTap: _open),
          if (series.isNotEmpty)
            PosterRow(title: 'Yeni diziler', items: series, onTap: _open),
          if (live.isNotEmpty) ...[
            const SectionTitle('Canlı yayınlar'),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: live.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _liveCard(live[i]),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _liveCard(Item c) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _open(c),
        child: SizedBox(
          width: 110,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Poster(
                    url: c.logo, icon: Icons.tv, fit: BoxFit.contain),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(Item? it) {
    return SizedBox(
      height: 440,
      child: Stack(fit: StackFit.expand, children: [
        if (it != null)
          Poster(url: it.logo)
        else
          Container(color: AppColors.card),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xAA000000), Color(0x00000000), AppColors.bg],
              stops: [0, 0.45, 1],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topLeft,
              child: ShaderMask(
                shaderCallback: (r) => brandGradient.createShader(r),
                child: const Text('RYIPTV',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: Colors.white)),
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting(),
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 4),
              Text(it?.name ?? 'Bugün ne izliyoruz?',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900, height: 1.1)),
              if (it != null) ...[
                const SizedBox(height: 14),
                Row(children: [
                  GradientButton(
                    label: 'İncele',
                    icon: Icons.play_arrow_rounded,
                    onTap: () => _open(it),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    icon: Icon(Store.favs.contains(it.id)
                        ? Icons.check
                        : Icons.add),
                    tooltip: 'Listeme ekle',
                    onPressed: () {
                      Store.toggleFav(it);
                      setState(() {});
                    },
                  ),
                ]),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}
