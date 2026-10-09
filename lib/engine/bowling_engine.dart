import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Pin deck geometry (canonical 10-pin triangle) and neighbor graph for
// chain reactions. Pin indices 0..9; pin 0 is the head pin.
// ---------------------------------------------------------------------------
const pinPos = [
  [0.50, 0.40], // 1 head pin
  [0.44, 0.29], [0.56, 0.29], // 2, 3
  [0.38, 0.18], [0.50, 0.18], [0.62, 0.18], // 4, 5, 6
  [0.32, 0.07], [0.44, 0.07], [0.56, 0.07], [0.68, 0.07], // 7..10
];
const pinNeighbors = [
  [1, 2], [0, 2, 3, 4], [0, 1, 4, 5], [1, 4, 6, 7],
  [1, 2, 3, 5, 7, 8], [2, 4, 8, 9], [3, 7], [3, 4, 6, 8],
  [4, 5, 7, 9], [5, 8],
];

// ---------------------------------------------------------------------------
// Players and phases
// ---------------------------------------------------------------------------
class Bowler {
  String name;
  final Color color;
  final bool isBot;
  int score = 0;

  Bowler({required this.name, required this.color, required this.isBot});
}

/// Turn phases owned entirely by the engine. The UI only renders.
enum BowlPhase {
  aiming, // human aiming (input open) or AI narrated aiming
  throwing, // ball rolling down the lane
  scattering, // pins flying
  settling, // result message, input locked
  over, // game finished
}

/// A throw in flight (visual). Logical pin results are computed at impact;
/// the UI interpolates the ball from release to impact.
class ThrowAnim {
  final double aimX;
  final double curve;
  final double power;
  final int totalMs;
  final DateTime startedAt = DateTime.now();

  ThrowAnim(
      {required this.aimX,
      required this.curve,
      required this.power,
      required this.totalMs});

  double get progress {
    final e = DateTime.now().difference(startedAt).inMilliseconds;
    return (e / totalMs).clamp(0.0, 1.0);
  }
}

class PinScatter {
  final Set<int> knocked;
  final Map<int, Offset> dirs;
  final int totalMs;
  final DateTime startedAt = DateTime.now();

  PinScatter({required this.knocked, required this.dirs, required this.totalMs});

  double get progress {
    final e = DateTime.now().difference(startedAt).inMilliseconds;
    return (e / totalMs).clamp(0.0, 1.0);
  }
}

// ---------------------------------------------------------------------------
// Engine: deterministic rules, state, AI. UI-agnostic.
// ---------------------------------------------------------------------------
class BowlingEngine extends ChangeNotifier {
  final List<Bowler> players;
  final int botDifficulty; // 0 easy, 1 medium, 2 hard

  late List<List<int>> frames; // per player: 10 frames of pin counts
  int turn = 0;
  int frameIdx = 0;
  BowlPhase phase = BowlPhase.aiming;
  Set<int> standing = {};
  Set<int> knockedThisThrow = {};
  ThrowAnim? throwAnim;
  PinScatter? scatter;
  bool over = false;
  int? winner;
  String banner = '';
  String lastResult = '';

  // Human aim state (engine-owned so AI can drive the same path).
  double aimX = 0.5;
  double curve = 0;
  double power = 0.7;

  final _rand = Random();
  Timer? _timer; // single phase-transition timer
  Timer? _watchdog; // stuck-state recovery
  bool _disposed = false;
  bool paused = false;

  static const int scatterMs = 900;
  static const int settleMs = 1300;

  /// UI hook for sounds / haptics. Set by the screen.
  void Function(BowlEvent event)? onEvent;

  BowlingEngine({required this.players, this.botDifficulty = 1}) {
    frames = [for (var _ in players) List.generate(10, (_) => <int>[])];
    _resetRack();
    banner = _aimBanner();
    _watchdog = Timer.periodic(const Duration(seconds: 3), (_) => _recover());
    // First player might be a bot — kick off their turn.
    _afterPhase();
  }

  Bowler get current => players[turn];
  bool get aiming => phase == BowlPhase.aiming && !over;
  bool get awaitingHumanAim => aiming && !current.isBot;

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  void _arm(Duration d, void Function() fn) {
    if (_disposed || paused) return;
    _timer?.cancel();
    _timer = Timer(d, () {
      _timer = null;
      if (!_disposed && !paused) fn();
    });
  }

  /// Pause: freeze the phase timer. Resume re-arms the current phase.
  void setPaused(bool v) {
    if (paused == v || _disposed) return;
    paused = v;
    if (v) {
      _timer?.cancel();
      _timer = null;
    } else {
      _recover();
    }
    notifyListeners();
  }

  /// Watchdog: if the single phase timer ever dies without progress, recover.
  /// Stuck states are impossible by construction. Respects [paused].
  void _recover() {
    if (_disposed || over || paused || _timer != null) return;
    switch (phase) {
      case BowlPhase.aiming:
        if (current.isBot) {
          _aiAim();
        }
      case BowlPhase.throwing:
        _impact();
      case BowlPhase.scattering:
        _settleThrow();
      case BowlPhase.settling:
        _advance();
      case BowlPhase.over:
        break;
    }
  }

  // --------------------------------------------------------------- ballistics
  double ballX(double aim, double curve, double prog) =>
      (aim + curve * prog * prog).clamp(0.03, 0.97);
  double ballY(double prog) => 0.97 - 0.77 * prog * prog;

  void _resetRack() {
    standing = {for (int i = 0; i < 10; i++) i};
    knockedThisThrow = {};
  }

  // ---------------------------------------------------------------- turn flow
  /// Human flick: throws the ball with power/curve. Guarded — aim phase only.
  void humanThrow(double p, double c) {
    if (!awaitingHumanAim || over) return;
    power = p.clamp(0.35, 1.0);
    curve = c.clamp(-0.35, 0.35);
    _beginThrow();
  }

  /// Human drag: adjust aim while in the aim phase.
  void setAim(double x) {
    if (!awaitingHumanAim || over) return;
    aimX = x.clamp(0.05, 0.95);
    notifyListeners();
  }

  void _beginThrow() {
    phase = BowlPhase.throwing;
    final rollDurMs = (1700 - 800 * power).round();
    throwAnim = ThrowAnim(
      aimX: aimX,
      curve: curve,
      power: power,
      totalMs: rollDurMs,
    );
    onEvent?.call(BowlEvent.ballRolling);
    notifyListeners();
    _arm(Duration(milliseconds: rollDurMs), _impact);
  }

  /// Ball reaches the deck: compute which pins fall.
  void _impact() {
    if (over || phase != BowlPhase.throwing || throwAnim == null) return;
    final anim = throwAnim!;
    final impactX = ballX(anim.aimX, anim.curve, 1.0);
    final power = anim.power;
    knockedThisThrow = {};
    final dirs = <int, Offset>{};

    // Primary hits: pins near the ball's path get clipped.
    for (final i in standing.toList()) {
      final dx = (pinPos[i][0] - impactX).abs();
      if (dx < 0.06 + power * 0.035 + _rand.nextDouble() * 0.02) {
        _knock(i, dirs, impactX);
      }
    }
    if (knockedThisThrow.isEmpty) {
      // Near-miss: the closest pin can still wobble down.
      final near = standing.reduce((a, b) =>
          (pinPos[a][0] - impactX).abs() < (pinPos[b][0] - impactX).abs()
              ? a
              : b);
      if ((pinPos[near][0] - impactX).abs() < 0.11 && _rand.nextBool()) {
        _knock(near, dirs, impactX);
      }
    }
    // Chain reactions: two passes over the neighbor graph.
    for (int p = 0; p < 2; p++) {
      for (final i in standing.toList()) {
        if (pinNeighbors[i].any(knockedThisThrow.contains) &&
            _rand.nextDouble() < 0.28 + power * 0.12) {
          _knock(i, dirs, impactX);
        }
      }
    }
    final pinsDown = knockedThisThrow.length;
    scatter = PinScatter(
        knocked: Set.of(knockedThisThrow), dirs: dirs, totalMs: scatterMs);
    phase = BowlPhase.scattering;
    onEvent?.call(pinsDown == 0 ? BowlEvent.gutter : BowlEvent.pinCrash);
    notifyListeners();
    _arm(const Duration(milliseconds: scatterMs), _settleThrow);
  }

  void _knock(int i, Map<int, Offset> dirs, double impactX) {
    knockedThisThrow.add(i);
    final dx = pinPos[i][0] - impactX;
    dirs[i] = Offset(
      (dx >= 0 ? 1 : -1) * (0.15 + _rand.nextDouble() * 0.35),
      -(0.1 + _rand.nextDouble() * 0.3),
    );
  }

  /// Pins settle: score the throw, narrate, then advance.
  void _settleThrow() {
    if (over || phase != BowlPhase.scattering) return;
    scatter = null;
    final pinsDown = knockedThisThrow.length;
    final fr = frames[turn][frameIdx];
    fr.add(pinsDown);
    standing.removeAll(knockedThisThrow);
    throwAnim = null;

    final firstBall = fr.length == 1;
    final isStrike = pinsDown == 10 && firstBall;
    final isSpare = !firstBall &&
        fr.length >= 2 &&
        fr[fr.length - 2] + pinsDown == 10 &&
        standing.isEmpty &&
        !(frameIdx == 9 && fr[fr.length - 2] == 10 && fr.length == 2);
    if (isStrike) {
      lastResult = 'STRIKE!! 🎳🔥';
      onEvent?.call(BowlEvent.strike);
    } else if (isSpare) {
      lastResult = 'SPARE! Nice pickup! ✨';
      onEvent?.call(BowlEvent.spare);
    } else if (pinsDown == 0) {
      lastResult = 'Gutter… the lane betrayed you 😅';
      onEvent?.call(BowlEvent.gutter);
    } else {
      lastResult = '$pinsDown down!';
      onEvent?.call(BowlEvent.ballSettled);
    }
    phase = BowlPhase.settling;
    players[turn].score = scoreUpTo(frames[turn], 9);
    notifyListeners();
    _arm(const Duration(milliseconds: settleMs), _advance);
  }

  bool frameDone(List<int> r, int f) {
    if (f < 9) return r.isNotEmpty && (r[0] == 10 || r.length == 2);
    if (r.length < 2) return false;
    if (r[0] == 10 || r[0] + r[1] == 10) return r.length == 3;
    return r.length == 2;
  }

  bool _resetPins(int f, List<int> r) {
    // Fresh rack for ball 2/3 in the 10th after strike or spare (RULES §8).
    if (f < 9) return false;
    if (r.length == 1) return r[0] == 10;
    if (r.length == 2) {
      return (r[0] == 10 && r[1] == 10) || (r[0] < 10 && r[0] + r[1] == 10);
    }
    return false;
  }

  void _advance() {
    if (over) return;
    final fr = frames[turn][frameIdx];
    if (!frameDone(fr, frameIdx)) {
      // Same player, next ball in this frame.
      if (_resetPins(frameIdx, fr)) _resetRack();
      knockedThisThrow = {};
      aimX = 0.5;
      curve = 0;
      phase = BowlPhase.aiming;
      banner = _aimBanner();
      notifyListeners();
      _afterPhase();
      return;
    }
    // Next player / frame.
    if (turn + 1 < players.length) {
      turn++;
    } else {
      turn = 0;
      frameIdx++;
    }
    if (frameIdx >= 10) {
      _finish();
      return;
    }
    _resetRack();
    knockedThisThrow = {};
    aimX = 0.5;
    curve = 0;
    phase = BowlPhase.aiming;
    banner = _aimBanner();
    notifyListeners();
    _afterPhase();
  }

  String _ballLabel() {
    final r = frames[turn][frameIdx];
    if (frameIdx < 9) return r.isEmpty ? 'Ball 1 of 2' : 'Ball 2 of 2';
    if (r.isEmpty) return 'Ball 1';
    if (r.length == 1) return r[0] == 10 ? 'Ball 2 — fresh rack!' : 'Ball 2';
    return 'Ball 3 — bonus ball!';
  }

  String _aimBanner() {
    final who = current.name;
    final label = _ballLabel();
    if (current.isBot) return '$who is sizing up the lane… ($label)';
    return '$who — $label. Drag to aim, flick up to throw!';
  }

  /// Called whenever we enter the aim phase: bots aim + throw themselves,
  /// fully visible with narration. Never silent auto-play.
  void _afterPhase() {
    if (over || phase != BowlPhase.aiming) return;
    if (current.isBot) _aiAim();
  }

  /// Bot aiming sequence: visible aim drift, narration, then a real throw.
  void _aiAim() {
    if (over || phase != BowlPhase.aiming || !current.isBot) return;
    banner = '${current.name} eyes the pins…';
    notifyListeners();
    // Visible aim drift toward the bot's chosen line.
    final target = _aiTargetAim();
    final mid = 0.5 + (target - 0.5) * 0.5;
    _arm(const Duration(milliseconds: 450), () {
      if (over || phase != BowlPhase.aiming || !current.isBot) return;
      aimX = mid;
      notifyListeners();
      _arm(const Duration(milliseconds: 450), () {
        if (over || phase != BowlPhase.aiming || !current.isBot) return;
        aimX = target;
        banner = '${current.name} sets the line…';
        notifyListeners();
        _arm(const Duration(milliseconds: 600), _aiThrow);
      });
    });
  }

  void _aiThrow() {
    if (over || phase != BowlPhase.aiming || !current.isBot) return;
    power = _aiPower();
    curve = _aiCurve();
    banner = '${current.name} throws! 🎳';
    _beginThrow();
  }

  /// Difficulty skill: pocket aim gets tighter, power cleaner, curve smarter.
  double _aiTargetAim() {
    final pocket = _rand.nextBool() ? 0.44 : 0.56;
    switch (botDifficulty.clamp(0, 2)) {
      case 0: // Easy: sloppy, often misses the pocket.
        return 0.5 + (_rand.nextDouble() * 0.8 - 0.4);
      case 1: // Medium: decent line, some drift.
        return (pocket + (_rand.nextDouble() * 0.16 - 0.08))
            .clamp(0.05, 0.95);
      default: // Hard: threads the pocket.
        return (pocket + (_rand.nextDouble() * 0.07 - 0.035))
            .clamp(0.05, 0.95);
    }
  }

  double _aiPower() {
    switch (botDifficulty.clamp(0, 2)) {
      case 0:
        return 0.45 + _rand.nextDouble() * 0.25;
      case 1:
        return 0.6 + _rand.nextDouble() * 0.25;
      default:
        return 0.7 + _rand.nextDouble() * 0.25;
    }
  }

  double _aiCurve() {
    switch (botDifficulty.clamp(0, 2)) {
      case 0:
        return _rand.nextDouble() * 0.5 - 0.25;
      case 1:
        return _rand.nextDouble() * 0.24 - 0.12;
      default:
        return _rand.nextDouble() * 0.1 - 0.05;
    }
  }

  void _finish() {
    over = true;
    phase = BowlPhase.over;
    int best = -1, bi = 0, atBest = 0;
    for (int i = 0; i < players.length; i++) {
      final s = scoreUpTo(frames[i], 9);
      players[i].score = s;
      if (s > best) {
        best = s;
        bi = i;
        atBest = 1;
      } else if (s == best) {
        atBest++;
      }
    }
    lastResult = 'Final score: $best';
    if (atBest > 1) {
      // RULES §10: equal final scores = a draw, shared trophy.
      winner = null;
      banner = "It's a draw! 🤝 Both bowlers share the trophy 🏆";
      notifyListeners();
      onEvent?.call(BowlEvent.humanWon); // celebratory jingle for both
    } else {
      winner = bi;
      banner = '${players[bi].name} takes the trophy! 🏆';
      notifyListeners();
      onEvent?.call(
          players[bi].isBot ? BowlEvent.botWon : BowlEvent.humanWon);
    }
  }

  void restart() {
    _timer?.cancel();
    paused = false;
    frames = [for (var _ in players) List.generate(10, (_) => <int>[])];
    for (final p in players) {
      p.score = 0;
    }
    turn = 0;
    frameIdx = 0;
    _resetRack();
    throwAnim = null;
    scatter = null;
    over = false;
    winner = null;
    lastResult = '';
    aimX = 0.5;
    curve = 0;
    power = 0.7;
    phase = BowlPhase.aiming;
    banner = _aimBanner();
    notifyListeners();
    _afterPhase();
  }

  // ---------------------------------------------------------------- scoring
  List<int> _nextBalls(List<List<int>> fr, int f, int n) {
    final out = <int>[];
    for (int k = f + 1; k < 10 && out.length < n; k++) {
      out.addAll(fr[k]);
    }
    return out;
  }

  /// Standard 10-frame scoring (RULES §8): strikes/spare bonuses roll over;
  /// the 10th frame counts pins as-is.
  int scoreUpTo(List<List<int>> fr, int upto) {
    int total = 0;
    for (int f = 0; f <= upto && f < 10; f++) {
      final r = fr[f];
      if (r.isEmpty) break;
      if (f < 9) {
        if (r[0] == 10) {
          final n = _nextBalls(fr, f, 2);
          if (n.length < 2) break;
          total += 10 + n[0] + n[1];
        } else if (r.length < 2) {
          break;
        } else if (r[0] + r[1] == 10) {
          final n = _nextBalls(fr, f, 1);
          if (n.isEmpty) break;
          total += 10 + n[0];
        } else {
          total += r[0] + r[1];
        }
      } else {
        total += r.fold(0, (a, b) => a + b);
      }
    }
    return total;
  }

  /// Display mark for one ball (X, /, –, or pins).
  String mark(List<int> r, int f, int ball) {
    if (ball >= r.length) return '';
    final v = r[ball];
    if (f < 9) {
      if (ball == 0) return v == 10 ? 'X' : (v == 0 ? '–' : '$v');
      return r[0] + v == 10 ? '/' : (v == 0 ? '–' : '$v');
    }
    if (v == 10) return 'X';
    if (ball > 0 && r[ball - 1] != 10 && r[ball - 1] + v == 10) return '/';
    return v == 0 ? '–' : '$v';
  }
}

enum BowlEvent {
  ballRolling,
  pinCrash,
  strike,
  spare,
  gutter,
  ballSettled,
  humanWon,
  botWon,
}
