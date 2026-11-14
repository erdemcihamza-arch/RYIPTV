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

  static String? _pinHash;
  static DateTime? _unlockedAt;
  static const _unlockMinutes = 15;

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    favs.addAll(prefs.getStringList('favs') ?? []);
    lockedGroups.addAll(prefs.getStringList('locked') ?? []);
    autoAdult = prefs.getBool('autoAdult') ?? true;
    lowLatency = prefs.getBool('lowLatency') ?? true;
    _pinHash = prefs.getString('pin');
    try {
      recents = (prefs.getStringList('recents') ?? [])
          .map((s) => Item.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      recents = [];
    }
  }

  // ------------------------------------------------ favoriler / son izlenen

  static void toggleFav(Item it) {
    if (!favs.remove(it.id)) favs.add(it.id);
    prefs.setStringList('favs', favs.toList());
  }

  static void addRecent(Item it) {
    recents.removeWhere((e) => e.id == it.id);
    recents.insert(0, it);
    if (recents.length > 20) recents = recents.sublist(0, 20);
    prefs.setStringList(
        'recents', recents.map((e) => jsonEncode(e.toJson())).toList());
  }

  static void clearRecents() {
    recents = [];
    prefs.remove('recents');
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

  static Future<void> setLowLatency(bool v) async {
    lowLatency = v;
    await prefs.setBool('lowLatency', v);
  }

  static Future<void> setAutoAdult(bool v) async {
    autoAdult = v;
    await prefs.setBool('autoAdult', v);
  }
}
