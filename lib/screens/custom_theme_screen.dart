import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/alley_style.dart';
import '../theme/alley_themes.dart';

/// Custom alley creator (PRO): paint your own lane, deck, accents and
/// player colors. Saved to the 'custom' theme.
class CustomThemeScreen extends StatefulWidget {
  final AlleyAudio audio;
  final AlleySettings settings;
  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  static const _labels = {
    'laneLight': 'Lane light wood',
    'laneMid': 'Lane mid wood',
    'laneDark': 'Lane dark wood',
    'gutter': 'Gutters',
    'deck': 'Pin deck',
    'wall': 'Hall backdrop',
    'accent': 'Accent',
    'accentLight': 'Accent light',
    'accentDark': 'Accent dark',
    'text': 'Text',
    'muted': 'Muted text',
    'pc0': 'Player 1 color',
    'pc1': 'Player 2 color',
  };

  static const _swatches = [
    0xFFE8C98A, 0xFFD9AC66, 0xFFB3854A, 0xFF8F4E2C, 0xFF6B3620, 0xFF4A2C16,
    0xFFB3282D, 0xFFE06666, 0xFF7A1B1F, 0xFFC0392B, 0xFFE07830, 0xFFF5A866,
    0xFFD4AF37, 0xFFF3DC8E, 0xFF96702A, 0xFF1F5FA8, 0xFF4A90D9, 0xFF123A6B,
    0xFF1B7A4D, 0xFF9BD498, 0xFF0E4A2E, 0xFF5C9BC4, 0xFF9CC8E4, 0xFF35617E,
    0xFF7A1B5C, 0xFFB78FD4, 0xFFD8BDEA, 0xFFF8F1E3, 0xFFC9B896, 0xFF23242A,
    0xFF1B2A4A, 0xFF3A2E16, 0xFF000000,
  ];

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final t = AlleyThemes.byId(s.themeId, custom: s.customTheme);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: t.wall,
        foregroundColor: t.text,
        title: Text('Alley creator', style: Alley.label(18, theme: t)),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              widget.audio.click();
              s.resetCustomColors();
              s.setTheme('custom');
              setState(() {});
            },
            child: Text('Reset',
                style: Alley.label(14, theme: t, color: t.accentLight)),
          ),
        ],
      ),
      body: WoodBackdrop(
        theme: t,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text('Paint your own alley',
                style: Alley.display(24, theme: t)),
            const SizedBox(height: 4),
            Text('Pick a color for each part of the alley. Saved automatically.',
                style: Alley.body(14, theme: t, color: t.muted)),
            const SizedBox(height: 12),
            for (final key in _labels.keys) _colorRow(t, key),
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  widget.audio.click();
                  s.setTheme('custom');
                  Navigator.of(context).pop();
                },
                child: Text('USE MY ALLEY',
                    style: Alley.label(16, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorRow(AlleyThemeDef t, String key) {
    final s = widget.settings;
    final current = s.customColors[key] ?? 0xFF000000;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Color(current),
                  shape: BoxShape.circle,
                  border: Border.all(color: t.text, width: 1.5),
                ),
              ),
              const SizedBox(width: 8),
              Text(_labels[key]!, style: Alley.body(14, theme: t)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final sw in _swatches)
                GestureDetector(
                  onTap: () {
                    widget.audio.click();
                    s.setCustomColor(key, 0xFF000000 | sw);
                    s.setTheme('custom');
                    setState(() {});
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Color(0xFF000000 | sw),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: current == (0xFF000000 | sw)
                            ? t.accentLight
                            : Colors.white24,
                        width: current == (0xFF000000 | sw) ? 3 : 1,
                      ),
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
