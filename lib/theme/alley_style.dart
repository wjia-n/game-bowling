import 'package:flutter/material.dart';
import 'alley_themes.dart';

/// Alley design system for Bowling: physical bowling-alley warmth.
/// Real woods, painted pins, polished balls. No neon, no cyberpunk,
/// no generic Material look.
///
/// All widgets accept an optional [AlleyThemeDef]; they default to the
/// Classic Maple theme so existing call sites keep working.
class Alley {
  static const displayFont = 'serif';

  static TextStyle display(double size,
          {Color? color, AlleyThemeDef? theme}) =>
      TextStyle(
        fontFamily: displayFont,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? theme?.accentLight ?? const Color(0xFFE06666),
        letterSpacing: 1.2,
        shadows: const [
          Shadow(color: Color(0xAA000000), offset: Offset(0, 2), blurRadius: 4),
        ],
      );

  static TextStyle body(double size, {Color? color, AlleyThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? theme?.text ?? const Color(0xFFF8F1E3),
        height: 1.35,
      );

  static TextStyle label(double size, {Color? color, AlleyThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? theme?.accentLight ?? const Color(0xFFE06666),
        letterSpacing: 0.8,
      );

  static ThemeData theme([AlleyThemeDef? t]) {
    t ??= AlleyThemes.byId('classic');
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: t.wall,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: t.accent,
        onPrimary: t.wall,
        secondary: t.accentLight,
        onSecondary: t.wall,
        surface: t.deck,
        onSurface: t.text,
        error: t.playerColors[0],
        onError: t.text,
      ),
      textTheme: TextTheme(
        displayLarge: display(34, theme: t),
        displayMedium: display(26, theme: t),
        titleLarge: display(22, theme: t),
        bodyLarge: body(16, theme: t),
        bodyMedium: body(14, theme: t),
        labelLarge: label(14, theme: t),
      ),
      dialogTheme: DialogThemeData(backgroundColor: t.deck),
    );
  }
}

/// Warm lane-wood backdrop with a vignette, theme-aware.
class WoodBackdrop extends StatelessWidget {
  final Widget child;
  final AlleyThemeDef? theme;
  const WoodBackdrop({super.key, required this.child, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? AlleyThemes.byId('classic');
    return Container(
      decoration: BoxDecoration(color: t.wall),
      child: CustomPaint(
        painter: _WoodGrainPainter(t),
        child: child,
      ),
    );
  }
}

class _WoodGrainPainter extends CustomPainter {
  final AlleyThemeDef t;
  _WoodGrainPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final vignette = RadialGradient(
      center: const Alignment(0, -0.25),
      radius: 1.15,
      colors: [
        t.laneMid.withValues(alpha: 0.35),
        Colors.transparent,
        Colors.black.withValues(alpha: 0.45),
      ],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = vignette.createShader(
          Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    // Subtle vertical wood-grain streaks.
    final paint = Paint()
      ..color = t.laneDark.withValues(alpha: 0.18)
      ..strokeWidth = 2;
    for (int i = 0; i < 9; i++) {
      final x = size.width * (0.08 + i * 0.105);
      canvas.drawLine(Offset(x, 0), Offset(x + 12, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
