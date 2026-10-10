import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/alley_themes.dart';

/// Persisted settings + stats for Bowling. Survives app restarts.
///
/// Stores: audio toggles, player names (2 seats), theme/appearance choices
/// (incl. custom alley colors), mode setup (vs AI difficulty / pass-and-play),
/// Pro unlock state, and lifetime stats.
class AlleySettings extends ChangeNotifier {
  static const _kMusic = 'bowling_music_on';
  static const _kSfx = 'bowling_sfx_on';
  static const _kVolume = 'bowling_volume';
  static const _kMode = 'bowling_mode'; // 0 = vs AI, 1 = 2-player pass-and-play
  static const _kDifficulty = 'bowling_bot_difficulty'; // 0 easy, 1 medium, 2 hard
  static const _kNames = 'bowling_player_names'; // legacy unordered StringSet key
  /// Order-safe player-name storage: a single JSON string. Android's
  /// SharedPreferences stores StringLists as an unordered StringSet, so the
  /// old key scrambled name order on every app restart. Never use a
  /// StringList for ordered data on Android.
  static const _kNamesJson = 'bowling_player_names_json';
  static const _kTheme = 'bowling_theme_id';
  static const _kBallStyle = 'bowling_ball_style';
  static const _kPinStyle = 'bowling_pin_style';
  static const _kGames = 'bowling_games_played';
  static const _kWins = 'bowling_human_wins';
  static const _kBest = 'bowling_best_score';
  static const _kStrikes = 'bowling_strikes';
  static const _kIsPro = 'bowling_is_pro';
  static const _kCustomPrefix = 'bowling_custom_';

  static const defaultNames = ['You', 'Rex'];

  /// Encode the player names as one JSON string (order-preserving).
  static String encodePlayerNames(List<String> names) => jsonEncode(names);

  static String _cleanName(int i, Object? v) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? defaultNames[i] : s;
  }

  /// Decode persisted names; falls back to defaults on missing/corrupt data.
  static List<String> decodePlayerNames(String? raw) {
    if (raw == null) return List.of(defaultNames);
    try {
      final d = jsonDecode(raw);
      if (d is List && d.length == 2) {
        return [for (int i = 0; i < 2; i++) _cleanName(i, d[i])];
      }
    } catch (_) {}
    return List.of(defaultNames);
  }

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  int mode = 0; // 0 = vs AI, 1 = 2-player pass-and-play
  int difficulty = 1; // medium default
  List<String> playerNames = List.of(defaultNames);
  String themeId = 'classic';
  int ballStyle = 0;
  int pinStyle = 0;
  int gamesPlayed = 0;
  int humanWins = 0;
  int bestScore = 0;
  int strikes = 0;
  bool isPro = true; // everything unlocked — no Pro version

  /// Custom alley colors (ARGB ints). Defaults mirror Classic Maple.
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'laneLight': 0xFFE8C98A,
    'laneMid': 0xFFD9AC66,
    'laneDark': 0xFFB3854A,
    'gutter': 0xFF5C4326,
    'deck': 0xFF2E1F12,
    'wall': 0xFF17100A,
    'accent': 0xFFB3282D,
    'accentLight': 0xFFE06666,
    'accentDark': 0xFF7A1B1F,
    'text': 0xFFF8F1E3,
    'muted': 0xFFC9B896,
    'pc0': 0xFFB3282D,
    'pc1': 0xFF1F5FA8,
  };

  /// Builds the user-designed custom alley from stored colors.
  AlleyThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return AlleyThemeDef(
      id: 'custom',
      name: 'My Alley',
      laneLight: c('laneLight'),
      laneMid: c('laneMid'),
      laneDark: c('laneDark'),
      gutter: c('gutter'),
      deck: c('deck'),
      wall: c('wall'),
      accent: c('accent'),
      accentLight: c('accentLight'),
      accentDark: c('accentDark'),
      text: c('text'),
      muted: c('muted'),
      playerColors: [c('pc0'), c('pc1')],
    );
  }

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    mode = (p.getInt(_kMode) ?? 0).clamp(0, 1);
    difficulty = (p.getInt(_kDifficulty) ?? 1).clamp(0, 2);
    // Player names: prefer the order-safe JSON key. Fall back to the legacy
    // StringList key once (one-time migration); it may already be scrambled
    // on Android, which is exactly the bug this replaces.
    final namesRaw = p.getString(_kNamesJson);
    if (namesRaw != null) {
      playerNames = decodePlayerNames(namesRaw);
    } else {
      final legacy = p.getStringList(_kNames);
      playerNames = (legacy != null && legacy.length == 2)
          ? [for (int i = 0; i < 2; i++) _cleanName(i, legacy[i])]
          : List.of(defaultNames);
    }
    themeId = p.getString(_kTheme) ?? 'classic';
    ballStyle = (p.getInt(_kBallStyle) ?? 0).clamp(0, BallStyles.all.length - 1);
    pinStyle = (p.getInt(_kPinStyle) ?? 0).clamp(0, PinStyles.all.length - 1);
    gamesPlayed = p.getInt(_kGames) ?? 0;
    humanWins = p.getInt(_kWins) ?? 0;
    bestScore = p.getInt(_kBest) ?? 0;
    strikes = p.getInt(_kStrikes) ?? 0;
    isPro = true; // everything unlocked
    for (final k in _defaultCustomColors.keys) {
      customColors[k] =
          p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setInt(_kMode, mode);
    await p.setInt(_kDifficulty, difficulty);
    await p.setString(_kNamesJson, encodePlayerNames(playerNames));
    await p.remove(_kNames); // drop the legacy unordered key for good
    await p.setString(_kTheme, themeId);
    await p.setInt(_kBallStyle, ballStyle);
    await p.setInt(_kPinStyle, pinStyle);
    await p.setInt(_kGames, gamesPlayed);
    await p.setInt(_kWins, humanWins);
    await p.setInt(_kBest, bestScore);
    await p.setInt(_kStrikes, strikes);
    await p.setBool(_kIsPro, isPro);
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  /// Called after load and whenever Pro status could have changed.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    // The custom alley creator is a Pro feature ('custom' is not covered by
    // AlleyThemes.isProTheme, so it needs an explicit check).
    if (themeId == 'custom' || AlleyThemes.isProTheme(themeId)) {
      themeId = 'classic';
      changed = true;
    }
    if (BallStyles.isPro(ballStyle)) {
      ballStyle = 0;
      changed = true;
    }
    if (PinStyles.isPro(pinStyle)) {
      pinStyle = 0;
      changed = true;
    }
    if (difficulty > 1) {
      difficulty = 1;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return; // custom alley creator is a Pro feature
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setMode(int v) async {
    mode = v.clamp(0, 1);
    notifyListeners();
    await _save();
  }

  Future<void> setDifficulty(int v) async {
    v = v.clamp(0, 2);
    // Hard mode is a Pro feature.
    if (!isPro && v > 1) return;
    difficulty = v;
    notifyListeners();
    await _save();
  }

  Future<void> setPlayerName(int index, String name) async {
    if (index < 0 || index > 1) return;
    final clean = name.trim();
    playerNames[index] = clean.isEmpty ? defaultNames[index] : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    // Pro-only themes (incl. the custom alley creator) require Pro;
    // silently ignore otherwise (UI shows lock).
    if (!isPro && (id == 'custom' || AlleyThemes.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setBallStyle(int v) async {
    v = v.clamp(0, BallStyles.all.length - 1);
    if (!isPro && BallStyles.isPro(v)) return;
    ballStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setPinStyle(int v) async {
    v = v.clamp(0, PinStyles.all.length - 1);
    if (!isPro && PinStyles.isPro(v)) return;
    pinStyle = v;
    notifyListeners();
    await _save();
  }

  /// Record a finished game. [humanWon] true if a human player won.
  /// [bestHumanScore] is the best score among human players.
  Future<void> recordGame(
      {required bool humanWon,
      required int bestHumanScore,
      int strikeCount = 0}) async {
    gamesPlayed++;
    if (humanWon) humanWins++;
    if (bestHumanScore > bestScore) bestScore = bestHumanScore;
    strikes += strikeCount;
    notifyListeners();
    await _save();
  }
}
