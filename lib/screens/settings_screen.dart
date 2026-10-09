import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/alley_style.dart';
import '../theme/alley_themes.dart';
import 'custom_theme_screen.dart';
import 'pro_screen.dart';

/// Settings: music/SFX toggles, volume, renameable players, stats,
/// alley creator shortcut, Pro.
class SettingsScreen extends StatelessWidget {
  final AlleyAudio audio;
  final AlleySettings settings;
  final StoreService store;

  const SettingsScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.store});

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final t = AlleyThemes.byId(s.themeId, custom: s.customTheme);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: t.wall,
        foregroundColor: t.text,
        title: Text('Settings', style: Alley.label(18, theme: t)),
        elevation: 0,
      ),
      body: WoodBackdrop(
        theme: t,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _card(t, [
              _switchRow(t, 'Music', 'Menu & alley tunes', s.musicOn,
                  (v) {
                s.setMusic(v);
                audio.configure(
                    musicOn: v, sfxOn: s.sfxOn, volume: s.volume);
                if (v) {
                  audio.startMenuMusic();
                } else {
                  audio.stopMusic();
                }
              }),
              _switchRow(t, 'Sound effects', 'Balls, pins, jingles', s.sfxOn,
                  (v) {
                s.setSfx(v);
                audio.configure(
                    musicOn: s.musicOn, sfxOn: v, volume: s.volume);
                if (v) audio.click();
              }),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
                child: Row(
                  children: [
                    Text('Volume', style: Alley.body(15, theme: t)),
                    Expanded(
                      child: Slider(
                        value: s.volume,
                        activeColor: t.accent,
                        onChanged: (v) {
                          s.setVolume(v);
                          audio.configure(
                              musicOn: s.musicOn,
                              sfxOn: s.sfxOn,
                              volume: v);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _card(t, [
              _titleRow(t, 'PLAYERS'),
              for (int i = 0; i < 2; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                            color: t.playerColors[i],
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _NameField(
                          t: t,
                          label: i == 0 ? 'Player 1' : 'Player 2',
                          initial: s.playerNames[i],
                          onChanged: (v) => s.setPlayerName(i, v),
                          onCommitted: (v) => s.setPlayerName(i, v),
                        ),
                      ),
                    ],
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            _card(t, [
              _titleRow(t, 'YOUR STATS'),
              _statRow(t, 'Games played', '${s.gamesPlayed}'),
              _statRow(t, 'Matches won', '${s.humanWins}'),
              _statRow(t, 'Best score', '${s.bestScore}'),
              _statRow(t, 'Strikes thrown', '${s.strikes}'),
            ]),
            const SizedBox(height: 12),
            _card(t, [
              _navRow(t, Icons.palette, 'Alley creator',
                  'Design your own lane (PRO)', () {
                audio.click();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        CustomThemeScreen(audio: audio, settings: s)));
              }),
              _navRow(t, Icons.star, 'Bowling PRO',
                  s.isPro ? 'Pro is unlocked!' : 'Unlock everything', () {
                audio.click();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        ProScreen(audio: audio, settings: s, store: store)));
              }),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _card(AlleyThemeDef t, List<Widget> children) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.deck.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.accent.withValues(alpha: 0.35)),
        ),
        child: Column(children: children),
      );

  Widget _titleRow(AlleyThemeDef t, String s) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(s, style: Alley.label(13, theme: t)),
        ),
      );

  Widget _switchRow(AlleyThemeDef t, String title, String sub, bool value,
      ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: Alley.body(15, theme: t)),
      subtitle: Text(sub, style: Alley.body(12, theme: t, color: t.muted)),
      value: value,
      activeThumbColor: t.accent,
      onChanged: onChanged,
    );
  }

  Widget _statRow(AlleyThemeDef t, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(label, style: Alley.body(14, theme: t, color: t.muted)),
            const Spacer(),
            Text(value, style: Alley.label(15, theme: t)),
          ],
        ),
      );

  Widget _navRow(AlleyThemeDef t, IconData icon, String title, String sub,
      VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: t.accentLight),
      title: Text(title, style: Alley.body(15, theme: t)),
      subtitle: Text(sub, style: Alley.body(12, theme: t, color: t.muted)),
      trailing: Icon(Icons.chevron_right, color: t.muted),
      onTap: onTap,
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
  final String? label;
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
