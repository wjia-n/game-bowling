import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Bowling — 10 frames, flick to throw, real scoring, pass-and-play party.
class BowlingScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;

  const BowlingScreen({super.key, required this.players, required this.callbacks});

  @override
  State<BowlingScreen> createState() => _BowlingScreenState();
}

// Pin deck positions (x, y) in lane coords; pin i+1.
const _pinPos = [
  [0.50, 0.40], // 1 head pin
  [0.44, 0.29], [0.56, 0.29], // 2, 3
  [0.38, 0.18], [0.50, 0.18], [0.62, 0.18], // 4, 5, 6
  [0.32, 0.07], [0.44, 0.07], [0.56, 0.07], [0.68, 0.07], // 7..10
];
const _neighbors = [
  [1, 2], [0, 2, 3, 4], [0, 1, 4, 5], [1, 4, 6, 7],
  [1, 2, 3, 5, 7, 8], [2, 4, 8, 9], [3, 7], [3, 4, 6, 8],
  [4, 5, 7, 9], [5, 8],
];

class _BowlingScreenState extends State<BowlingScreen>
    with SingleTickerProviderStateMixin {
  final rnd = Random();
  late Ticker _ticker;
  double _t = 0; // animation clock (seconds)

  // Match state
  late List<List<List<int>>> frames; // per player: 10 frames of rolls
  int frameIdx = 0, turnIdx = 0;
  bool over = false;

  // Throw state
  String phase = 'aim'; // aim | roll | scatter
  Set<int> standing = {};
  Set<int> knockedThisThrow = {};
  Map<int, Offset> scatterDir = {};
  double aimX = 0.5, curve = 0, power = 0.7;
  double _phaseStart = 0, _rollDur = 1.0;
  double _impactX = 0.5;
  String lastMsg = '';

  @override
  void initState() {
    super.initState();
    frames = [for (var _ in widget.players) List.generate(10, (_) => <int>[])];
    _ticker = createTicker(_tick)..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startTurn());
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    if (over) return;
    setState(() => _t = elapsed.inMilliseconds / 1000.0);
    if (phase == 'roll' && _t - _phaseStart >= _rollDur) _impact();
    if (phase == 'scatter' && _t - _phaseStart >= 0.8) _settleThrow();
  }

  // ---------- turn flow ----------

  void _startTurn() {
    if (!mounted || over) return;
    setState(() {
      standing = {for (int i = 0; i < 10; i++) i};
      knockedThisThrow = {};
      aimX = 0.5;
      curve = 0;
      phase = 'aim';
      lastMsg = _ballLabel();
    });
    widget.callbacks.setActivePlayer(turnIdx);
  }

  String _ballLabel() {
    final r = frames[turnIdx][frameIdx];
    if (frameIdx < 9) return r.isEmpty ? 'Ball 1 of 2' : 'Ball 2 of 2';
    if (r.isEmpty) return 'Ball 1';
    if (r.length == 1) return r[0] == 10 ? 'Ball 2 — fresh rack!' : 'Ball 2';
    return 'Ball 3 — bonus ball!';
  }

  void _throw(double p, double c) {
    if (phase != 'aim' || over) return;
    setState(() {
      power = p.clamp(0.35, 1.0);
      curve = c.clamp(-0.35, 0.35);
      phase = 'roll';
      _phaseStart = _t;
      _rollDur = 1.7 - 0.8 * power;
    });
    Sfx.move();
  }

  double _ballX(double prog) =>
      (aimX + curve * prog * prog).clamp(0.03, 0.97);
  double _ballY(double prog) => 0.97 - 0.77 * prog * prog;

  void _impact() {
    _impactX = _ballX(1.0);
    knockedThisThrow = {};
    scatterDir = {};
    // primary hits
    for (final i in standing.toList()) {
      final dx = (_pinPos[i][0] - _impactX).abs();
      if (dx < 0.075 + rnd.nextDouble() * 0.02) _knock(i);
    }
    if (knockedThisThrow.isEmpty) {
      // gutter-ish: always knock the nearest pin a little love (min 0)
      final near = standing.reduce((a, b) =>
          (_pinPos[a][0] - _impactX).abs() < (_pinPos[b][0] - _impactX).abs()
              ? a
              : b);
      if ((_pinPos[near][0] - _impactX).abs() < 0.11 && rnd.nextBool()) _knock(near);
    }
    // chain reactions, two passes
    for (int p = 0; p < 2; p++) {
      for (final i in standing.toList()) {
        if (_neighbors[i].any(knockedThisThrow.contains) && rnd.nextDouble() < 0.32) {
          _knock(i);
        }
      }
    }
    setState(() {
      phase = 'scatter';
      _phaseStart = _t;
    });
    Sfx.tap();
  }

  void _knock(int i) {
    knockedThisThrow.add(i);
    final dx = _pinPos[i][0] - _impactX;
    scatterDir[i] = Offset(
      (dx >= 0 ? 1 : -1) * (0.15 + rnd.nextDouble() * 0.35),
      -(0.1 + rnd.nextDouble() * 0.3),
    );
  }

  void _settleThrow() {
    final pinsDown = knockedThisThrow.length;
    final fr = frames[turnIdx][frameIdx];
    setState(() {
      standing.removeAll(knockedThisThrow);
      fr.add(pinsDown);
      lastMsg = pinsDown == 10 && fr.length == 1 && frameIdx < 9
          ? 'STRIKE!! 🎳🔥'
          : pinsDown == 10 && frameIdx == 9 && fr.length == 1
              ? 'STRIKE!! 🎳🔥'
              : fr.length >= 2 && fr[fr.length - 2] + pinsDown == 10 && standing.isEmpty && frameIdx < 9
                  ? 'SPARE! Nice pickup! ✨'
                  : pinsDown == 0
                      ? 'Gutter... the lane betrayed you 😅'
                      : '$pinsDown down!';
    });
    if (pinsDown == 10 && fr.length == 1) {
      Sfx.win();
    } else {
      Sfx.click();
    }
    widget.players[turnIdx].score = _scoreUpTo(frames[turnIdx], 9);
    widget.callbacks.refreshHud();
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted || over) return;
      _advance();
    });
  }

  bool _frameDone(List<int> r, int f) {
    if (f < 9) return r.isNotEmpty && (r[0] == 10 || r.length == 2);
    if (r.length < 2) return false;
    if (r[0] == 10 || r[0] + r[1] == 10) return r.length == 3;
    return r.length == 2;
  }

  bool _resetPins(int f, List<int> r) {
    // fresh rack for ball 2/3 in the 10th after strike or spare
    if (f < 9) return false;
    if (r.length == 1) return r[0] == 10;
    if (r.length == 2) {
      return (r[0] == 10 && r[1] == 10) || (r[0] == 10 && r[1] < 10 ? false : r[0] + r[1] == 10);
    }
    return false;
  }

  void _advance() {
    final fr = frames[turnIdx][frameIdx];
    if (!_frameDone(fr, frameIdx)) {
      if (_resetPins(frameIdx, fr)) standing = {for (int i = 0; i < 10; i++) i};
      setState(() {
        knockedThisThrow = {};
        aimX = 0.5;
        curve = 0;
        phase = 'aim';
        lastMsg = _ballLabel();
      });
      return;
    }
    // next player / frame
    if (turnIdx + 1 < widget.players.length) {
      turnIdx++;
    } else {
      turnIdx = 0;
      frameIdx++;
    }
    if (frameIdx >= 10) {
      _endGame();
      return;
    }
    _startTurn();
  }

  void _endGame() {
    setState(() => over = true);
    int best = -1, bi = 0;
    for (int i = 0; i < widget.players.length; i++) {
      final s = _scoreUpTo(frames[i], 9);
      widget.players[i].score = s;
      if (s > best) {
        best = s;
        bi = i;
      }
    }
    widget.callbacks.refreshHud();
    Sfx.win();
    widget.callbacks.finish(
      winner: widget.players[bi],
      headline: '${widget.players[bi].name} takes the trophy! 🏆',
      subline: 'Final score: $best. Rematch, champ?',
    );
  }

  // ---------- scoring ----------

  List<int> _nextBalls(List<List<int>> fr, int f, int n) {
    final out = <int>[];
    for (int k = f + 1; k < 10 && out.length < n; k++) {
      out.addAll(fr[k]);
    }
    return out;
  }

  int _scoreUpTo(List<List<int>> fr, int upto) {
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

  String _mark(List<int> r, int f, int ball) {
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

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    final current = widget.players[turnIdx];
    return Column(
      children: [
        if (!over)
          TurnBanner(
              player: current,
              action: ' — frame ${frameIdx + 1}/10 🎳'),
        _scoreCard(t),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: GestureDetector(
              onPanUpdate: (d) {
                if (phase != 'aim' || over) return;
                setState(() => aimX =
                    (aimX + d.delta.dx / context.size!.width * 1.4)
                        .clamp(0.05, 0.95));
              },
              onPanEnd: (d) {
                if (phase != 'aim' || over) return;
                final v = d.velocity.pixelsPerSecond;
                if (v.dy < -350) {
                  _throw(-v.dy / 1500, v.dx / 2500);
                }
              },
              child: CustomPaint(
                painter: _LanePainter(
                  t: t,
                  standing: standing,
                  knocked: knockedThisThrow,
                  scatterDir: scatterDir,
                  scatterT: phase == 'scatter'
                      ? ((_t - _phaseStart) / 0.8).clamp(0.0, 1.0)
                      : 0,
                  ballX: phase == 'roll' ? _ballX(((_t - _phaseStart) / _rollDur).clamp(0.0, 1.0)) : aimX,
                  ballY: phase == 'roll' ? _ballY(((_t - _phaseStart) / _rollDur).clamp(0.0, 1.0)) : 0.97,
                  ballVisible: phase != 'scatter',
                  aimX: aimX,
                  aiming: phase == 'aim',
                  playerColor: current.color,
                ),
                child: Container(),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            over ? 'Game over! 🎉' : lastMsg,
            style: TextStyle(
                color: t.text, fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        if (phase == 'aim' && !over)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Drag ◀ ▶ to aim • flick ▲ to throw • sideways flick = curve',
                style: TextStyle(color: t.muted, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _scoreCard(GameTheme t) {
    final fr = frames[turnIdx];
    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 10,
        itemBuilder: (_, f) {
          final r = fr[f];
          final cum = _scoreUpTo(fr, f);
          final done = _frameDone(r, f);
          return Container(
            width: 52,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: f == frameIdx && !over ? t.primary.withValues(alpha: 0.25) : t.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${f + 1}',
                    style: TextStyle(color: t.muted, fontSize: 10)),
                Text(
                  f < 9
                      ? '${_mark(r, f, 0)} ${_mark(r, f, 1)}'
                      : '${_mark(r, f, 0)}${_mark(r, f, 1)}${_mark(r, f, 2)}',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w800),
                ),
                Text(done ? '$cum' : '',
                    style: TextStyle(
                        color: t.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LanePainter extends CustomPainter {
  final GameTheme t;
  final Set<int> standing, knocked;
  final Map<int, Offset> scatterDir;
  final double scatterT, ballX, ballY, aimX;
  final bool ballVisible, aiming;
  final Color playerColor;

  _LanePainter({
    required this.t,
    required this.standing,
    required this.knocked,
    required this.scatterDir,
    required this.scatterT,
    required this.ballX,
    required this.ballY,
    required this.ballVisible,
    required this.aimX,
    required this.aiming,
    required this.playerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final lane = RRect.fromLTRBR(
        0, 0, size.width, size.height, const Radius.circular(18));
    canvas.drawRRect(
        lane,
        Paint()
          ..shader = LinearGradient(
            colors: [t.surface, t.background],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    // lane arrows
    final arrowPaint = Paint()
      ..color = t.primary.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 5; i++) {
      final x = size.width * (0.3 + i * 0.1);
      final y = size.height * 0.62;
      canvas.drawCircle(Offset(x, y), 3, arrowPaint);
    }
    // foul line
    canvas.drawLine(Offset(0, size.height * 0.78),
        Offset(size.width, size.height * 0.78),
        Paint()..color = t.muted.withValues(alpha: 0.5)..strokeWidth = 2);
    // aim guide
    if (aiming) {
      final p = Paint()
        ..color = playerColor.withValues(alpha: 0.5)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(size.width * aimX, size.height * 0.94),
          Offset(size.width * aimX, size.height * 0.45), p..strokeWidth = 2);
    }
    // pins
    final pinR = size.width * 0.035;
    final pinPaint = Paint()..color = t.text;
    final stripePaint = Paint()..color = t.primary..strokeWidth = 3;
    for (int i = 0; i < 10; i++) {
      if (!standing.contains(i) && !knocked.contains(i)) continue;
      var px = _pinPos[i][0] * size.width;
      var py = _pinPos[i][1] * size.height;
      double alpha = 1;
      if (knocked.contains(i)) {
        final d = scatterDir[i] ?? Offset.zero;
        px += d.dx * size.width * scatterT;
        py += d.dy * size.height * scatterT;
        alpha = 1 - scatterT;
      }
      pinPaint.color = t.text.withValues(alpha: alpha);
      stripePaint.color = t.primary.withValues(alpha: alpha);
      canvas.drawCircle(Offset(px, py), pinR, pinPaint);
      canvas.drawLine(Offset(px - pinR * 0.6, py - pinR * 0.2),
          Offset(px + pinR * 0.6, py - pinR * 0.2), stripePaint);
    }
    // ball
    if (ballVisible) {
      final bx = ballX * size.width, by = ballY * size.height;
      final br = size.width * 0.045;
      canvas.drawCircle(
          Offset(bx, by), br, Paint()..color = playerColor);
      final hole = Paint()..color = t.background.withValues(alpha: 0.85);
      canvas.drawCircle(Offset(bx - br * 0.3, by - br * 0.25), br * 0.18, hole);
      canvas.drawCircle(Offset(bx + br * 0.3, by - br * 0.25), br * 0.18, hole);
      canvas.drawCircle(Offset(bx, by + br * 0.25), br * 0.18, hole);
    }
  }

  @override
  bool shouldRepaint(covariant _LanePainter o) => true;
}
