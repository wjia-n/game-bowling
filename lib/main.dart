import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const BowlingApp());

class BowlingApp extends StatelessWidget {
  const BowlingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: 'Bowling',
      tagline: 'Strike down pins in 10-frame bowling nights',
      emoji: '🎳',
      slug: 'bowling',
      howToPlay:
          '• Drag left/right to aim your ball, then flick UP to throw.\n• Flick sideways as you release to add curve (spin!).\n• Knock all 10 pins for a strike — real 10-frame scoring.\n• Pass the phone around: up to 4 bowlers, lowest... no wait, HIGHEST score wins! 😄',
      playerOptions: const [1, 2, 3, 4],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) => BowlingScreen(players: players, callbacks: cb),
    );
  }
}
