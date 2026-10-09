import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/bowling_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/alley_style.dart';
import '../theme/alley_themes.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

const storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.bowling';

const _difficultyNames = ['Easy', 'Medium', 'Hard'];

/// Main menu: mode setup (vs AI 3 difficulties / 2-player pass-and-play),
/// renameable players, alley + ball + pin customization, Pro, settings,
/// share and rate.
class MenuScreen extends StatefulWidget {
  final AlleyAudio audio;
  final AlleySettings settings;
  final StoreService store;

  const MenuScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.store});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  AlleySettings get _s => widget.settings;
  AlleyAudio get _a => widget.audio;

  AlleyThemeDef get _t =>
      AlleyThemes.byId(_s.themeId, custom: _s.customTheme);

  @override
  void initState() {
    super.initState();
    _a.startMenuMusic();
  }

  Future<void> _requestReview() async {
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      }
    } catch (_) {
      // Not installed from Play (or review unavailable) — stay graceful.
    }
  }

  void _play() {
    _a.click();
    _a.startGameMusic();
    final players = <Bowler>[
      Bowler(
          name: _s.playerNames[0],
          color: _t.playerColors[0],
          isBot: false),
      Bowler(
          name: _s.playerNames[1],
          color: _t.playerColors[1],
          isBot: _s.mode == 0),
    ];
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: _a,
          settings: _s,
          store: widget.store,
          engine: BowlingEngine(
              players: players,
              botDifficulty: _s.mode == 0 ? _s.difficulty : 0),
          theme: _t,
          onExit: () => _a.startMenuMusic(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      body: WoodBackdrop(
        theme: t,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              // Header
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset('assets/bowling_logo.png',
                        width: 64, height: 64, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bowling', style: Alley.display(34, theme: t)),
                      Text('Strike up some fun',
                          style: Alley.body(13, theme: t, color: t.muted)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Settings',
                    icon: Icon(Icons.settings, color: t.accentLight),
                    onPressed: () {
                      _a.click();
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => SettingsScreen(
                              audio: _a, settings: _s, store: widget.store)));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _sectionTitle(t, 'WHO’S PLAYING'),
              _modeCard(t),
              const SizedBox(height: 10),
              _nameCard(t),
              const SizedBox(height: 18),
              _sectionTitle(t, 'ALLEY'),
              _themeGrid(t),
              const SizedBox(height: 18),
              _sectionTitle(t, 'BALL & PINS'),
              _stylePicker(
                t,
                title: 'Ball finish',
                names: BallStyles.names,
                selected: _s.ballStyle,
                isPro: BallStyles.isPro,
                onPick: _s.setBallStyle,
              ),
              const SizedBox(height: 10),
              _stylePicker(
                t,
                title: 'Pin paint',
                names: PinStyles.names,
                selected: _s.pinStyle,
                isPro: PinStyles.isPro,
                onPick: _s.setPinStyle,
              ),
              const SizedBox(height: 18),
              // Play button
              SizedBox(
                height: 58,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  onPressed: _play,
                  child: Text('🎳  HIT THE LANES',
                      style: Alley.label(18, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _menuBtn(t, Icons.star, 'PRO', () {
                    _a.click();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProScreen(
                            audio: _a,
                            settings: _s,
                            store: widget.store)));
                  })),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _menuBtn(t, Icons.share, 'Share', () async {
                    _a.click();
                    await Share.share(
                        'Strike with me in Bowling! $storeUrl');
                  })),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _menuBtn(t, Icons.thumb_up, 'Rate',
                          () async {
                    _a.click();
                    await _requestReview();
                  })),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Credits: WAJIHA',
                  style: Alley.label(12, theme: t, color: t.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(AlleyThemeDef t, String s) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(s, style: Alley.label(13, theme: t)),
      );

  Widget _menuBtn(
      AlleyThemeDef t, IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.text,
        side: BorderSide(color: t.accent.withValues(alpha: 0.6)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: Alley.body(13, theme: t)),
    );
  }

  // ------------------------------------------------------------ mode + names
  Widget _modeCard(AlleyThemeDef t) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.deck.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _modeOption(t, 0, '🤖', 'Vs the alley bot',
                      'Solo match against AI')),
              const SizedBox(width: 8),
              Expanded(
                  child: _modeOption(t, 1, '👥', '2 players',
                      'Pass-and-play with a friend')),
            ],
          ),
          if (_s.mode == 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Bot skill', style: Alley.body(13, theme: t)),
                const Spacer(),
                for (int i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _difficultyChip(t, i),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _modeOption(
      AlleyThemeDef t, int mode, String emoji, String title, String sub) {
    final selected = _s.mode == mode;
    return GestureDetector(
      onTap: () {
        _a.click();
        _s.setMode(mode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? t.accent.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? t.accent : t.muted.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(title,
                style: Alley.label(13, theme: t),
                textAlign: TextAlign.center),
            Text(sub,
                style: Alley.body(11, theme: t, color: t.muted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _difficultyChip(AlleyThemeDef t, int i) {
    final selected = _s.difficulty == i;
    final locked = !_s.isPro && i == 2;
    return GestureDetector(
      onTap: () {
        if (locked) {
          _a.invalid();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hard mode is a PRO feature',
                style: Alley.body(14, theme: t)),
            backgroundColor: t.deck,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ));
          return;
        }
        _a.click();
        _s.setDifficulty(i);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? t.accent
              : Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? t.accentLight : t.muted.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (locked) const Icon(Icons.lock, size: 12, color: Colors.white70),
            Text(_difficultyNames[i],
                style: Alley.label(12,
                    theme: t,
                    color: selected ? Colors.white : t.text)),
          ],
        ),
      ),
    );
  }

  Widget _nameCard(AlleyThemeDef t) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.deck.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          _nameRow(t, 0, _s.mode == 0 ? 'Your name' : 'Player 1',
              t.playerColors[0]),
          const SizedBox(height: 8),
          _nameRow(
              t,
              1,
              _s.mode == 0 ? 'Bot name' : 'Player 2',
              t.playerColors[1],
              botBadge: _s.mode == 0),
        ],
      ),
    );
  }

  Widget _nameRow(AlleyThemeDef t, int i, String label, Color dot,
      {bool botBadge = false}) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 74,
          child: Text(label,
              style: Alley.body(12, theme: t, color: t.muted)),
        ),
        if (botBadge)
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: t.accent.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('BOT', style: Alley.label(10, theme: t)),
          ),
        Expanded(
          child: _NameField(
            t: t,
            label: null, // side label already rendered by _nameRow
            initial: _s.playerNames[i],
            onChanged: (v) => _s.setPlayerName(i, v),
            onCommitted: (v) => _s.setPlayerName(i, v),
          ),
        ),
      ],
    );
  }
  // ---------------------------------------------------------------- themes
  Widget _themeGrid(AlleyThemeDef t) {
    final themes = [
      ...AlleyThemes.all,
      if (_s.isPro || _s.themeId == 'custom') _s.customTheme,
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.15,
      ),
      itemCount: themes.length,
      itemBuilder: (_, i) {
        final th = themes[i];
        final selected = _s.themeId == th.id;
        final locked = !_s.isPro &&
            (th.id == 'custom' || AlleyThemes.isProTheme(th.id));
        return GestureDetector(
          onTap: () {
            if (th.id == 'custom' && !_s.isPro) {
              _a.invalid();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('The alley creator is a PRO feature',
                    style: Alley.body(14, theme: t)),
                backgroundColor: t.deck,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ));
              return;
            }
            if (locked) {
              _a.invalid();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('“${th.name}” is a PRO alley',
                    style: Alley.body(14, theme: t)),
                backgroundColor: t.deck,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ));
              return;
            }
            _a.click();
            _s.setTheme(th.id);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? t.accent : t.muted.withValues(alpha: 0.3),
                width: selected ? 3 : 1,
              ),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(10)),
                          gradient: LinearGradient(
                            colors: [th.laneLight, th.laneMid, th.laneDark],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _dot(th.playerColors[0]),
                              const SizedBox(width: 6),
                              _dot(th.playerColors[1]),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: selected
                            ? t.accent.withValues(alpha: 0.35)
                            : Colors.black.withValues(alpha: 0.55),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(10)),
                      ),
                      child: Text(th.name,
                          style: Alley.label(10, theme: t),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                if (locked)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.lock,
                          size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dot(Color c) => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white70, width: 1),
        ),
      );

  Widget _stylePicker(AlleyThemeDef t,
      {required String title,
      required List<String> names,
      required int selected,
      required bool Function(int) isPro,
      required Future<void> Function(int) onPick}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.deck.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Alley.label(13, theme: t)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < names.length; i++)
                GestureDetector(
                  onTap: () {
                    if (!_s.isPro && isPro(i)) {
                      _a.invalid();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('“${names[i]}” is a PRO finish',
                            style: Alley.body(14, theme: t)),
                        backgroundColor: t.deck,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ));
                      return;
                    }
                    _a.click();
                    onPick(i);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected == i
                          ? t.accent
                          : Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: selected == i
                              ? t.accentLight
                              : t.muted.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_s.isPro && isPro(i))
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.lock,
                                size: 12, color: Colors.white70),
                          ),
                        Text(names[i],
                            style: Alley.label(12,
                                theme: t,
                                color: selected == i
                                    ? Colors.white
                                    : t.text)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Editable player-name field with a persistent controller.
///
/// Saves on every keystroke (never only on keyboard-done) and commits on
/// focus loss. The controller is created once in initState — recreating it
/// in build would jump the cursor and lose the user's edit on every
/// keystroke.
class _NameField extends StatefulWidget {
  final AlleyThemeDef t;
  final String? label; // null = side label shown elsewhere, no field label
  final String initial;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCommitted;

  const _NameField({
    required this.t,
    required this.label,
    required this.initial,
    required this.onChanged,
    required this.onCommitted,
  });

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _c;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
    _focus = FocusNode();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (!_focus.hasFocus) widget.onCommitted(_c.text);
  }

  @override
  void didUpdateWidget(covariant _NameField old) {
    super.didUpdateWidget(old);
    if (old.initial != widget.initial && _c.text != widget.initial) {
      _c.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      focusNode: _focus,
      style: Alley.body(15, theme: widget.t),
      maxLength: 14,
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: Alley.body(12, theme: widget.t, color: widget.t.muted),
        counterText: '',
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.3),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
      ),
      onChanged: widget.onChanged,
      onSubmitted: widget.onCommitted,
    );
  }
}
