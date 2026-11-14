import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class Session {
  static XtreamApi? api;
}

String? _attr(String line, String key) {
  final m = RegExp('$key="([^"]*)"').firstMatch(line);
  final v = m?.group(1);
  return (v == null || v.isEmpty) ? null : v;
}

String? _str(dynamic v) {
  if (v == null) return null;
  final t = '$v'.trim();
  return (t.isEmpty || t == 'null') ? null : t;
}

String? _rating(dynamic v) {
  final d = double.tryParse('${v ?? ''}');
  if (d == null || d <= 0) return null;
  return d.toStringAsFixed(1);
}

// ---------------------------------------------------------------- M3U

Library parseM3u(String text) {
  final live = <Item>[], movies = <Item>[], series = <Item>[];
  String? name, group, logo;
  for (final raw in const LineSplitter().convert(text)) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#EXTINF')) {
      final comma = line.lastIndexOf(',');
      name = comma >= 0 ? line.substring(comma + 1).trim() : null;
      group = _attr(line, 'group-title') ?? 'Diğer';
      logo = _attr(line, 'tvg-logo');
    } else if (!line.startsWith('#')) {
      final kind = line.contains('/movie/')
          ? Kind.movie
          : line.contains('/series/')
              ? Kind.series
              : Kind.live;
      final item = Item(
        id: line,
        name: (name == null || name.isEmpty) ? line : name,
        url: line,
        group: group ?? 'Diğer',
        logo: logo,
        kind: kind,
      );
      if (kind == Kind.live) {
        live.add(item);
      } else if (kind == Kind.movie) {
        movies.add(item);
      } else {
        series.add(item);
      }
      name = group = logo = null;
    }
  }
  return Library(live: live, movies: movies, series: series);
}

Future<Library> loadM3u(String url) async {
  final res = await http
      .get(Uri.parse(url.trim()))
      .timeout(const Duration(seconds: 90));
  if (res.statusCode != 200) {
    throw Exception('Liste indirilemedi (HTTP ${res.statusCode})');
  }
  return parseM3u(utf8.decode(res.bodyBytes, allowMalformed: true));
}

// ---------------------------------------------------------------- Xtream

class XtreamApi {
  final String base;
  final String user;
  final String pass;

  XtreamApi(String server, String user, String pass)
      : base = _normalize(server),
        user = user.trim(),
        pass = pass.trim();

  static String _normalize(String s) {
    var b = s.trim();
    if (!b.startsWith('http')) b = 'http://$b';
    return b.replaceAll(RegExp(r'/+$'), '');
  }

  String get _api =>
      '$base/player_api.php?username=${Uri.encodeComponent(user)}&password=${Uri.encodeComponent(pass)}';

  Future<dynamic> _get(String action, [String extra = '']) async {
    final res = await http
        .get(Uri.parse('$_api&action=$action$extra'))
        .timeout(const Duration(seconds: 120));
    if (res.statusCode != 200) {
      throw Exception('Sunucu hatası (HTTP ${res.statusCode})');
    }
    return jsonDecode(utf8.decode(res.bodyBytes, allowMalformed: true));
  }

  Future<Map<String, String>> _cats(String action) async {
    final r = await _get(action);
    final m = <String, String>{};
    if (r is List) {
      for (final c in r) {
        m['${c['category_id']}'] = '${c['category_name']}';
      }
    }
    return m;
  }

  Future<List<Item>> _live() async {
    final cats = await _cats('get_live_categories');
    final r = await _get('get_live_streams');
    if (r is! List) throw Exception('Kullanıcı adı / şifre hatalı olabilir');
    return r.map<Item>((s) {
      return Item(
        id: 'l${s['stream_id']}',
        name: '${s['name']}',
        url: '$base/live/$user/$pass/${s['stream_id']}.m3u8',
        group: cats['${s['category_id']}'] ?? 'Diğer',
        logo: _str(s['stream_icon']),
        kind: Kind.live,
        ref: '${s['stream_id']}',
      );
    }).toList();
  }

  Future<List<Item>> _movies() async {
    final cats = await _cats('get_vod_categories');
    final r = await _get('get_vod_streams');
    if (r is! List) return [];
    return r.map<Item>((s) {
      final ext = _str(s['container_extension']) ?? 'mp4';
      return Item(
        id: 'm${s['stream_id']}',
        name: '${s['name']}',
        url: '$base/movie/$user/$pass/${s['stream_id']}.$ext',
        group: cats['${s['category_id']}'] ?? 'Diğer',
        logo: _str(s['stream_icon']),
        kind: Kind.movie,
        rating: _rating(s['rating']),
        ref: '${s['stream_id']}',
      );
    }).toList();
  }

  Future<List<Item>> _series() async {
    final cats = await _cats('get_series_categories');
    final r = await _get('get_series');
    if (r is! List) return [];
    return r.map<Item>((s) {
      return Item(
        id: 's${s['series_id']}',
        name: '${s['name']}',
        url: '',
        group: cats['${s['category_id']}'] ?? 'Diğer',
        logo: _str(s['cover']),
        kind: Kind.series,
        rating: _rating(s['rating']),
        ref: '${s['series_id']}',
      );
    }).toList();
  }

  Future<Library> loadAll() async {
    final live = await _live();
    var movies = <Item>[];
    var series = <Item>[];
    try {
      movies = await _movies();
    } catch (_) {}
    try {
      series = await _series();
    } catch (_) {}
    return Library(live: live, movies: movies, series: series);
  }

  Future<String?> movieInfo(String vodId) async {
    final r = await _get('get_vod_info', '&vod_id=$vodId');
    if (r is Map && r['info'] is Map) {
      final info = r['info'] as Map;
      return _str(info['plot']) ?? _str(info['description']);
    }
    return null;
  }

  Future<SeriesDetails> seriesInfo(String seriesId) async {
    final r = await _get('get_series_info', '&series_id=$seriesId');
    String? plot;
    final out = <int, List<Episode>>{};
    if (r is Map) {
      if (r['info'] is Map) plot = _str((r['info'] as Map)['plot']);
      final eps = r['episodes'];
      if (eps is Map) {
        eps.forEach((k, v) {
          final season = int.tryParse('$k') ?? 1;
          if (v is List) {
            out[season] = v.map<Episode>((e) {
              final info = e['info'];
              return Episode(
                season: season,
                number: int.tryParse('${e['episode_num']}') ?? 0,
                title: _str(e['title']) ?? 'Bölüm',
                url:
                    '$base/series/$user/$pass/${e['id']}.${_str(e['container_extension']) ?? 'mp4'}',
                image: info is Map ? _str(info['movie_image']) : null,
              );
            }).toList();
          }
        });
      }
    }
    return SeriesDetails(plot: plot, episodes: out);
  }
}
