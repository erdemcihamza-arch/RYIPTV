enum Kind { live, movie, series }

final Map<String, int> _yearCache = {};
final RegExp _yearParen = RegExp(r'\(((?:19|20)\d{2})\)');
final RegExp _yearTail = RegExp(r'((?:19|20)\d{2})\s*$');

/// Ad icinden yayin yilini bulur: "Film (2016)" veya "Film 2016". Yoksa 0.
int yearOfName(String name) => _yearCache.putIfAbsent(name, () {
      final m = _yearParen.firstMatch(name) ?? _yearTail.firstMatch(name);
      return m == null ? 0 : int.parse(m.group(1)!);
    });

/// Once yayin yili, sonra eklenme zamani; en yeni en uste.
int newestFirst(Item a, Item b) {
  final y = b.year.compareTo(a.year);
  if (y != 0) return y;
  return b.added.compareTo(a.added);
}

class Item {
  final String id;
  final String name;
  final String url; // oynatma adresi (Xtream dizilerinde bos)
  final String group;
  final String? logo; // kanal logosu / film-dizi afisi
  final Kind kind;
  final String? rating;
  final String? ref; // Xtream stream_id veya series_id
  final int added; // eklenme zamani (unix saniye), bilinmiyorsa 0

  int get year => yearOfName(name);

  const Item({
    required this.id,
    required this.name,
    required this.url,
    required this.group,
    required this.kind,
    this.logo,
    this.rating,
    this.ref,
    this.added = 0,
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
        'added': added,
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
        added: (j['added'] ?? 0) as int,
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

  Profile copyWith({
    String? name,
    bool? xtream,
    String? m3u,
    String? server,
    String? user,
    String? pass,
  }) =>
      Profile(
        id: id,
        name: name ?? this.name,
        xtream: xtream ?? this.xtream,
        m3u: m3u ?? this.m3u,
        server: server ?? this.server,
        user: user ?? this.user,
        pass: pass ?? this.pass,
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
