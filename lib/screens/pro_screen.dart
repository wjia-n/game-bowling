import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/alley_style.dart';
import '../theme/alley_themes.dart';

/// Bowling PRO: Free-vs-Pro comparison, real purchase, restore, and tip jar.
/// All prices come from the store — never hardcoded, never placeholders.
class ProScreen extends StatefulWidget {
  final AlleyAudio audio;
  final AlleySettings settings;
  final StoreService store;

  const ProScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.store,
  });

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  AlleyThemeDef get _t => AlleyThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    widget.store.lastThanks.addListener(_onThanks);
    widget.store.init();
  }

  @override
  void dispose() {
    widget.store.lastThanks.removeListener(_onThanks);
    super.dispose();
  }

  
  void _onThanks() {
    final msg = widget.store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: Alley.body(15, theme: _t)),
        backgroundColor: _t.deck,
        behavior: SnackBarBehavior.floating,
      ),
    );
    widget.store.lastThanks.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    final store = widget.store;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: t.wall,
        foregroundColor: t.text,
        title: Text('Bowling PRO', style: Alley.label(18, theme: t)),
        elevation: 0,
      ),
      body: WoodBackdrop(
        theme: t,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.accent, width: 2),
                ),
                child: Row(
                  children: [
                    Text('⭐', style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          'You are PRO! All alleys, finishes, hard mode and the alley creator are yours.',
                          style: Alley.body(14, theme: t)),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),
            Text('☕  Tip jar', style: Alley.display(22, theme: t)),
            const SizedBox(height: 4),
            Text('Love the game? Fuel the next frame.',
                style: Alley.body(14, theme: t, color: t.muted)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _tipCard(t, store.coffeeProduct, '☕', 'Coffee')),
                const SizedBox(width: 10),
                Expanded(
                    child: _tipCard(
                        t, store.chocolateProduct, '🍫', 'Chocolate')),
              ],
            ),
            if (!store.storeReady)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Tips appear here once the store is set up.',
                  style: Alley.body(12, theme: t, color: t.muted),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
            Center(
              child: Text('Credits: WAJIHA',
                  style: Alley.label(12, theme: t, color: t.muted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tipCard(
      AlleyThemeDef t, ProductDetails? product, String emoji, String name) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.deck.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 4),
          Text(name, style: Alley.label(14, theme: t)),
          if (product != null)
            Text(product.price,
                style: Alley.body(13, theme: t, color: t.muted)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: t.text,
                side: BorderSide(
                    color: t.accent.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: product == null
                  ? null
                  : () => widget.store.buyTip(product),
              child: Text('Send', style: Alley.body(13, theme: t)),
            ),
          ),
        ],
      ),
    );
  }
}
