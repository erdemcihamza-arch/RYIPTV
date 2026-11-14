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

class Profile {
  final String id;
  final String name;
  final bool xtream;
  final String m3u;
  final String server;
  final String user;
  final String pass;

  const Profile({
    required this.id,
    required this.name,
    required this.xtream,
    this.m3u = '',
    this.server = '',
    this.user = '',
    this.pass = '',
  });

  Profile copyWith({String? name}) => Profile(
        id: id,
        name: name ?? this.name,
        xtream: xtream,
        m3u: m3u,
        server: server,
        user: user,
        pass: pass,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'xtream': xtream,
        'm3u': m3u,
        'server': server,
        'user': user,
        'pass': pass,
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        name: j['name'] as String,
        xtream: j['xtream'] as bool,
        m3u: (j['m3u'] ?? '') as String,
        server: (j['server'] ?? '') as String,
        user: (j['user'] ?? '') as String,
        pass: (j['pass'] ?? '') as String,
      );
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
