import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import '../engine/bowling_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/alley_style.dart';
import '../theme/alley_themes.dart';

/// The bowling match screen: real wooden lane, physical ball and pins,
/// full 10-frame scorecard, turn narration, pause/resume, and game-over.
class GameScreen extends StatefulWidget {
  final AlleyAudio audio;
  final AlleySettings settings;
  final StoreService store;
  final BowlingEngine engine;
  final AlleyThemeDef theme;
  final VoidCallback onExit;

  const GameScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.store,
    required this.engine,
    required this.theme,
    required this.onExit,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  BowlingEngine get _e => widget.engine;
  AlleyThemeDef get _t => widget.theme;
  bool _reviewAsked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _e.onEvent = _onEvent;
    _e.addListener(_onEngine);
    widget.audio.startGameMusic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _e.removeListener(_onEngine);
    _e.onEvent = null;
    _e.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Freeze the engine and pause music on interruption; resume on return.
    if (state == AppLifecycleState.paused) {
      _e.setPaused(true);
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
      _e.setPaused(false);
    }
  }

  void _onEvent(BowlEvent event) {
    final a = widget.audio;
    switch (event) {
      case BowlEvent.ballRolling:
        a.ballRoll();
      case BowlEvent.pinCrash:
        a.pinCrash();
      case BowlEvent.strike:
        a.strike();
      case BowlEvent.spare:
        a.spare();
      case BowlEvent.gutter:
        a.gutter();
      case BowlEvent.ballSettled:
        a.ballSettled();
      case BowlEvent.humanWon:
        a.win();
      case BowlEvent.botWon:
        a.lose();
    }
  }

  void _onEngine() {
    if (_e.over && !_reviewAsked) {
      _reviewAsked = true;
      _finishStats();
    }
    if (mounted) setState(() {});
  }

  /// Record lifetime stats once the match ends.
  Future<void> _finishStats() async {
    int bestHuman = 0;
    bool humanWon = false;
    int humanStrikes = 0;
    for (int i = 0; i < _e.players.length; i++) {
      final p = _e.players[i];
      if (!p.isBot) {
        if (p.score > bestHuman) bestHuman = p.score;
        if (_e.winner == i) humanWon = true;
        for (final fr in _e.frames[i]) {
          if (fr.isNotEmpty && fr[0] == 10) humanStrikes++;
        }
      }
    }
    await widget.settings.recordGame(
        humanWon: humanWon,
        bestHumanScore: bestHuman,
        strikeCount: humanStrikes);
    // Sensible review moment: right after a finished match. The OS
    // rate-limits the prompt; on non-Play installs this is a silent no-op.
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      }
    } catch (_) {}
  }

  void _pause() {
    if (_e.over || _e.paused) return;
    widget.audio.click();
    _e.setPaused(true);
    widget.audio.onAppPaused();
  }

  void _resume() {
    widget.audio.click();
    widget.audio.onAppResumed();
    _e.setPaused(false);
  }

  Future<void> _quit() async {
    widget.audio.click();
    _e.setPaused(false);
    widget.onExit();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      body: WoodBackdrop(
        theme: t,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _topBar(t),
                  _scoreCard(t),
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(14, 6, 14, 6),
                      child: GestureDetector(
                        onPanUpdate: (d) {
                          if (!_e.awaitingHumanAim) return;
                          final w = context.size?.width ?? 300;
                          _e.setAim(_e.aimX +
                              d.delta.dx / w * 1.4);
                        },
                        onPanEnd: (d) {
                          if (!_e.awaitingHumanAim) return;
                          final v = d.velocity.pixelsPerSecond;
                          if (v.dy < -350) {
                            _e.humanThrow(-v.dy / 1500, v.dx / 2500);
                          } else {
                            widget.audio.invalid();
                          }
                        },
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _LanePainter(
                              t: t,
                              e: _e,
                              ballStyle: BallStyles
                                  .all[widget.settings.ballStyle],
                              pinStyle: PinStyles
                                  .all[widget.settings.pinStyle],
                            ),
                            child: Container(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _e.over
                          ? (_e.winner == null
                              ? '🤝 It\'s a draw — both share the trophy! 🏆'
                              : '🎉 ${_e.players[_e.winner!].name} wins with ${_e.players[_e.winner!].score}!')
                          : (_e.lastResult.isNotEmpty &&
                                  _e.phase == BowlPhase.settling
                              ? _e.lastResult
                              : _e.banner),
                      style: Alley.body(16, theme: t),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_e.awaitingHumanAim)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                          'Drag ◀ ▶ to aim • flick ▲ to throw • sideways flick = curve',
                          style: Alley.body(12,
                              theme: t, color: t.muted)),
                    )
                  else
                    const SizedBox(height: 12),
                ],
              ),
              if (_e.paused && !_e.over) _pauseOverlay(t),
              if (_e.over) _gameOverOverlay(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(AlleyThemeDef t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Pause',
            icon: Icon(Icons.pause, color: t.accentLight),
            onPressed: _pause,
          ),
          Expanded(
            child: Text(
              'Frame ${_e.frameIdx + 1} / 10',
              style: Alley.label(16, theme: t),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            tooltip: 'Restart',
            icon: Icon(Icons.refresh, color: t.accentLight),
            onPressed: () {
              widget.audio.click();
              _e.restart();
            },
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- scorecard
  Widget _scoreCard(AlleyThemeDef t) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 2, 10, 2),
      child: Column(
        children: [
          for (int p = 0; p < _e.players.length; p++)
            _playerRow(t, p),
        ],
      ),
    );
  }

  Widget _playerRow(AlleyThemeDef t, int p) {
    final player = _e.players[p];
    final active = p == _e.turn && !_e.over;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: active
            ? t.accent.withValues(alpha: 0.28)
            : t.deck.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? t.accent : t.muted.withValues(alpha: 0.25),
          width: active ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: player.color,
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(player.name,
                          style: Alley.label(11, theme: t),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                Text(
                  '${player.score}',
                  style: Alley.display(18, theme: t),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                for (int f = 0; f < 10; f++)
                  Expanded(child: _frameCell(t, p, f, active && f == _e.frameIdx)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _frameCell(AlleyThemeDef t, int p, int f, bool current) {
    final r = _e.frames[p][f];
    final done = _e.frameDone(r, f);
    final cum = _e.scoreUpTo(_e.frames[p], f);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: current
            ? t.accent.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: current ? t.accent : t.muted.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${f + 1}', style: Alley.body(8, theme: t, color: t.muted)),
          Text(
            f < 9
                ? '${_e.mark(r, f, 0)} ${_e.mark(r, f, 1)}'
                : '${_e.mark(r, f, 0)}${_e.mark(r, f, 1)}${_e.mark(r, f, 2)}',
            style: Alley.label(10, theme: t),
            maxLines: 1,
          ),
          Text(done ? '$cum' : ' ',
              style: Alley.body(9, theme: t, color: t.accentLight)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- overlays
  Widget _pauseOverlay(AlleyThemeDef t) {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: t.deck,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.accent, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Paused', style: Alley.display(30, theme: t)),
              const SizedBox(height: 6),
              Text('The lane is waiting…',
                  style: Alley.body(14, theme: t, color: t.muted)),
              const SizedBox(height: 18),
              _overlayBtn(t, '▶  RESUME', _resume, primary: true),
              const SizedBox(height: 10),
              _overlayBtn(t, '↻  RESTART', () {
                widget.audio.click();
                _e.restart();
              }),
              const SizedBox(height: 10),
              _overlayBtn(t, '🏠  QUIT TO MENU', _quit),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gameOverOverlay(AlleyThemeDef t) {
    final w = _e.winner;
    final draw = w == null;
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: t.deck,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.accent, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🏆', style: const TextStyle(fontSize: 44)),
              const SizedBox(height: 6),
              Text(
                  draw
                      ? "It's a draw! 🤝"
                      : '${_e.players[w].name} wins!',
                  style: Alley.display(28, theme: t),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              for (int i = 0; i < _e.players.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: _e.players[i].color,
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text('${_e.players[i].name}: ${_e.players[i].score}',
                          style: Alley.body(15, theme: t)),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              _overlayBtn(t, '↻  REMATCH', () {
                widget.audio.click();
                _reviewAsked = false;
                _e.restart();
              }, primary: true),
              const SizedBox(height: 10),
              _overlayBtn(t, '🏠  MENU', _quit),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overlayBtn(AlleyThemeDef t, String label, VoidCallback onTap,
      {bool primary = false}) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              primary ? t.accent : Colors.black.withValues(alpha: 0.35),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onTap,
        child: Text(label, style: Alley.label(15, color: Colors.white)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lane painter: real wooden lane, gutters, pin deck, physical pins and ball.
// ---------------------------------------------------------------------------
class _LanePainter extends CustomPainter {
  final AlleyThemeDef t;
  final BowlingEngine e;
  final BallStyle ballStyle;
  final PinStyle pinStyle;

  _LanePainter(
      {required this.t,
      required this.e,
      required this.ballStyle,
      required this.pinStyle});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Lane boards: warm wooden planks.
    final laneRect = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRRect(
        RRect.fromRectAndRadius(laneRect, const Radius.circular(18)),
        Paint()
          ..shader = LinearGradient(
            colors: [t.laneLight, t.laneMid, t.laneDark],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(laneRect));
    // Plank seams.
    final seam = Paint()
      ..color = t.laneDark.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (int i = 1; i < 9; i++) {
      final x = w * i / 9;
      canvas.drawLine(Offset(x, 0), Offset(x, h), seam);
    }
    // Gutters on both sides.
    final gutterPaint = Paint()..color = t.gutter;
    canvas.drawRRect(
        RRect.fromLTRBR(0, 0, w * 0.055, h, const Radius.circular(18)),
        gutterPaint);
    canvas.drawRRect(
        RRect.fromLTRBR(w * 0.945, 0, w, h, const Radius.circular(18)),
        gutterPaint);
    // Pin deck backdrop (dark pit behind the pins).
    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h * 0.26),
        Paint()
          ..shader = LinearGradient(
            colors: [t.deck, t.deck.withValues(alpha: 0.4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, 0, w, h * 0.26)));
    // Lane arrows (the classic dots at ~2/3 down).
    final arrowPaint = Paint()
      ..color = t.laneDark.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 5; i++) {
      final x = w * (0.3 + i * 0.1);
      canvas.drawCircle(Offset(x, h * 0.62), 3.2, arrowPaint);
    }
    // Foul line.
    canvas.drawLine(
        Offset(0, h * 0.78),
        Offset(w, h * 0.78),
        Paint()
          ..color = t.text.withValues(alpha: 0.45)
          ..strokeWidth = 2.5);

    // Aim guide while aiming.
    if (e.phase == BowlPhase.aiming) {
      final p = Paint()
        ..color = e.current.color.withValues(alpha: 0.55)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      // Dotted guide from the ball to the pins.
      for (double yy = 0.90; yy > 0.45; yy -= 0.045) {
        canvas.drawCircle(
            Offset(w * e.aimX, h * yy), 2.2, Paint()..color = p.color);
      }
    }

    // Pins (physical: body + stripe, standing or scattering).
    final pinR = w * 0.034;
    final scatterT = e.scatter?.progress.clamp(0.0, 1.0) ?? 0.0;
    for (int i = 0; i < 10; i++) {
      if (!e.standing.contains(i) && !(e.scatter?.knocked.contains(i) ?? false)) {
        continue;
      }
      var px = pinPos[i][0] * w;
      var py = pinPos[i][1] * h;
      double alpha = 1.0;
      final isScattering = e.scatter?.knocked.contains(i) ?? false;
      if (isScattering) {
        final d = e.scatter!.dirs[i] ?? Offset.zero;
        px += d.dx * w * scatterT;
        py += d.dy * h * scatterT;
        alpha = (1 - scatterT).clamp(0.0, 1.0);
      }
      _drawPin(canvas, Offset(px, py), pinR, alpha);
    }

    // Ball: resting at aim spot, rolling, or gone after impact.
    bool ballVisible = e.phase != BowlPhase.scattering;
    double bx = e.aimX, by = 0.95, scale = 1.0;
    if (e.phase == BowlPhase.throwing && e.throwAnim != null) {
      final a = e.throwAnim!;
      final prog = a.progress;
      bx = e.ballX(a.aimX, a.curve, prog);
      by = e.ballY(prog);
      scale = 1.0 + prog * 0.35; // perspective: grows as it approaches
    }
    if (ballVisible) {
      _drawBall(canvas, Offset(bx * w, by * h), w * 0.046 * scale);
    }
  }

  void _drawPin(Canvas canvas, Offset c, double r, double alpha) {
    // Physical pin: rounded body, shaded edge, red stripe band.
    final body = Paint()..color = pinStyle.body.withValues(alpha: alpha);
    final shade = Paint()
      ..color = Colors.black.withValues(alpha: 0.18 * alpha);
    final stripe = Paint()
      ..color = pinStyle.stripe.withValues(alpha: alpha);
    final bodyRect =
        RRect.fromLTRBR(c.dx - r, c.dy - r * 1.25, c.dx + r, c.dy + r * 1.25,
            Radius.circular(r * 0.8));
    canvas.drawRRect(bodyRect, body);
    // Right-edge shade for depth.
    canvas.drawRRect(
        RRect.fromLTRBR(c.dx + r * 0.35, c.dy - r * 1.1, c.dx + r,
            c.dy + r * 1.1, Radius.circular(r * 0.4)),
        shade);
    // Stripe band across the neck.
    canvas.drawRect(
        Rect.fromLTWH(
            c.dx - r * 0.92, c.dy - r * 0.45, r * 1.84, r * 0.42),
        stripe);
    // Top highlight.
    canvas.drawCircle(
        Offset(c.dx - r * 0.35, c.dy - r * 0.7),
        r * 0.22,
        Paint()..color = Colors.white.withValues(alpha: 0.35 * alpha));
  }

  void _drawBall(Canvas canvas, Offset c, double r) {
    // Polished ball: base, swirl arc, finger holes, gloss highlight.
    canvas.drawCircle(c, r, Paint()..color = ballStyle.base);
    final swirl = Paint()
      ..color = ballStyle.swirl
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.28
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.55), 0.4, 2.4,
        false, swirl);
    final hole = Paint()..color = Colors.black.withValues(alpha: 0.75);
    canvas.drawCircle(Offset(c.dx - r * 0.3, c.dy - r * 0.28), r * 0.14, hole);
    canvas.drawCircle(Offset(c.dx + r * 0.28, c.dy - r * 0.3), r * 0.14, hole);
    canvas.drawCircle(Offset(c.dx, c.dy + r * 0.28), r * 0.14, hole);
    // Gloss.
    canvas.drawCircle(
        Offset(c.dx - r * 0.35, c.dy - r * 0.4),
        r * 0.28,
        Paint()..color = Colors.white.withValues(alpha: 0.28));
  }

  @override
  bool shouldRepaint(covariant _LanePainter oldDelegate) => true;
}
