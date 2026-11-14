enum Kind { live, movie, series }

class Item {
  final String id;
  final String name;
  final String url; // oynatma adresi (Xtream dizilerinde bos)
  final String group;
  final String? logo; // kanal logosu / film-dizi afisi
  final Kind kind;
  final String? rating;
  final String? ref; // Xtream stream_id veya series_id

  const Item({
    required this.id,
    required this.name,
    required this.url,
    required this.group,
    required this.kind,
    this.logo,
    this.rating,
    this.ref,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'group': group,
        'logo': logo,
        'kind': kind.index,
        'rating': rating,
        'ref': ref,
      };

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        id: j['id'] as String,
        name: j['name'] as String,
        url: j['url'] as String,
        group: j['group'] as String,
        logo: j['logo'] as String?,
        kind: Kind.values[j['kind'] as int],
        rating: j['rating'] as String?,
        ref: j['ref'] as String?,
      );
}

class Episode {
  final int season;
  final int number;
  final String title;
  final String url;
  final String? image;
  const Episode({
    required this.season,
    required this.number,
    required this.title,
    required this.url,
    this.image,
  });
}

class SeriesDetails {
  final String? plot;
  final Map<int, List<Episode>> episodes;
  const SeriesDetails({this.plot, this.episodes = const {}});
}

class Library {
  final List<Item> live;
  final List<Item> movies;
  final List<Item> series;
  const Library({
    this.live = const [],
    this.movies = const [],
    this.series = const [],
  });

  List<Item> get all => [...live, ...movies, ...series];

  List<String> groups() {
    final s = all.map((e) => e.group).toSet().toList();
    s.sort();
    return s;
  }
}
