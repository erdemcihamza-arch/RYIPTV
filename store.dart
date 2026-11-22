import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

final _adultRe = RegExp(
  r'(adult|xxx|porn|erotic|\bsex\b|\+18|18\+|yeti[sş]kin|nsfw)',
  caseSensitive: false,
);

bool isAdultGroup(String g) => _adultRe.hasMatch(g);

class Store {
  static late SharedPreferences prefs;

  static final Set<String> favs = {};
  static final Set<String> lockedGroups = {};
  static List<Item> recents = [];
  static bool autoAdult = true;
  static bool lowLatency = true;
  static int videoMode = 0; // 0 otomatik, 1 yazilim, 2 alternatif

  static List<Profile> profiles = [];
  static String? activeId;

  static String? _pinHash;
  static DateTime? _unlockedAt;
  static const _unlockMinutes = 15;

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    lockedGroups.addAll(prefs.getStringList('locked') ?? []);
    autoAdult = prefs.getBool('autoAdult') ?? true;
    lowLatency = prefs.getBool('lowLatency') ?? true;
    videoMode = prefs.getInt('videoMode') ?? 0;
    if (videoMode < 0 || videoMode > 2) videoMode = 0;
    _pinHash = prefs.getString('pin');
    await _loadProfiles();
    _loadProfileData();
  }

  // ------------------------------------------------ listeler (profiller)

  static Future<void> _loadProfiles() async {
    try {
      profiles = (prefs.getStringList('profiles') ?? [])
          .map((s) => Profile.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      profiles = [];
    }

    // Eski surumden tasima: tek listeyi ilk profil yap
    final oldType = prefs.getString('type');
    if (oldType != null) {
      if (profiles.isEmpty) {
        final id = DateTime.now().millisecondsSinceEpoch.toString();
        profiles.add(Profile(
          id: id,
          name: 'Listem',
          xtream: oldType == 'xtream',
          m3u: prefs.getString('m3u') ?? '',
          server: prefs.getString('server') ?? '',
          user: prefs.getString('user') ?? '',
          pass: prefs.getString('pass') ?? '',
        ));
        final oldFavs = prefs.getStringList('favs');
        if (oldFavs != null) await prefs.setStringList('favs_$id', oldFavs);
        final oldRec = prefs.getStringList('recents');
        if (oldRec != null) await prefs.setStringList('recents_$id', oldRec);
        await _saveProfiles();
        await prefs.setString('activeProfile', id);
      }
      for (final k in [
        'type',
        'm3u',
        'server',
        'user',
        'pass',
        'favs',
        'recents'
      ]) {
        await prefs.remove(k);
      }
    }

    final saved = prefs.getString('activeProfile');
    if (profiles.any((p) => p.id == saved)) {
      activeId = saved;
    } else {
      activeId = profiles.isEmpty ? null : profiles.first.id;
    }
  }

  static Future<void> _saveProfiles() => prefs.setStringList(
      'profiles', profiles.map((p) => jsonEncode(p.toJson())).toList());

  static Profile? get active {
    for (final p in profiles) {
      if (p.id == activeId) return p;
    }
    return null;
  }

  static void _loadProfileData() {
    favs.clear();
    recents = [];
    final id = activeId;
    if (id == null) return;
    favs.addAll(prefs.getStringList('favs_$id') ?? []);
    try {
      recents = (prefs.getStringList('recents_$id') ?? [])
          .map((s) => Item.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      recents = [];
    }
  }

  static Future<void> selectProfile(String id) async {
    activeId = id;
    await prefs.setString('activeProfile', id);
    _loadProfileData();
  }

  static Future<void> addProfile(Profile p) async {
    profiles.add(p);
    await _saveProfiles();
    await selectProfile(p.id);
  }

  static Future<void> renameProfile(String id, String name) async {
    profiles = [for (final p in profiles) p.id == id ? p.copyWith(name: name) : p];
    await _saveProfiles();
  }

  static Future<void> updateProfile(Profile np) async {
    profiles = [for (final p in profiles) p.id == np.id ? np : p];
    await _saveProfiles();
  }

  static Future<void> removeProfile(String id) async {
    profiles.removeWhere((p) => p.id == id);
    await prefs.remove('favs_$id');
    await prefs.remove('recents_$id');
    if (activeId == id) {
      activeId = profiles.isEmpty ? null : profiles.first.id;
      if (activeId == null) {
        await prefs.remove('activeProfile');
      } else {
        await prefs.setString('activeProfile', activeId!);
      }
    }
    await _saveProfiles();
    _loadProfileData();
  }

  // ------------------------------------------------ favoriler / son izlenen

  static void toggleFav(Item it) {
    if (!favs.remove(it.id)) favs.add(it.id);
    prefs.setStringList('favs_$activeId', favs.toList());
  }

  static void addRecent(Item it) {
    recents.removeWhere((e) => e.id == it.id);
    recents.insert(0, it);
    if (recents.length > 20) recents = recents.sublist(0, 20);
    prefs.setStringList(
        'recents_$activeId', recents.map((e) => jsonEncode(e.toJson())).toList());
  }

  static void clearRecents() {
    recents = [];
    prefs.remove('recents_$activeId');
  }

  // ------------------------------------------------ ebeveyn kilidi

  static String _hash(String pin) =>
      sha256.convert(utf8.encode('iptv-salt:$pin')).toString();

  static bool get hasPin => _pinHash != null;

  static Future<void> setPin(String pin) async {
    _pinHash = _hash(pin);
    await prefs.setString('pin', _pinHash!);
  }

  static Future<void> removePin() async {
    _pinHash = null;
    lockedGroups.clear();
    await prefs.remove('pin');
    await prefs.remove('locked');
  }

  static bool checkPin(String pin) => _pinHash == _hash(pin);

  static bool get isUnlocked {
    final t = _unlockedAt;
    if (t == null) return false;
    return DateTime.now().difference(t).inMinutes < _unlockMinutes;
  }

  static void unlock() => _unlockedAt = DateTime.now();
  static void lock() => _unlockedAt = null;

  static bool isLockedGroup(String g) =>
      (autoAdult && isAdultGroup(g)) || lockedGroups.contains(g);

  /// Kilitli kategorideki icerik, PIN girilmeden listelerde gorunmez.
  static bool visible(Item it) => !isLockedGroup(it.group) || isUnlocked;

  static void toggleLockedGroup(String g) {
    if (!lockedGroups.remove(g)) lockedGroups.add(g);
    prefs.setStringList('locked', lockedGroups.toList());
  }

  static Future<void> setVideoMode(int v) async {
    videoMode = v;
    await prefs.setInt('videoMode', v);
  }

  static Future<void> setLowLatency(bool v) async {
    lowLatency = v;
    await prefs.setBool('lowLatency', v);
  }

  static Future<void> setAutoAdult(bool v) async {
    autoAdult = v;
    await prefs.setBool('autoAdult', v);
  }
}
