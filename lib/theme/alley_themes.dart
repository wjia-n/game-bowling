import 'package:flutter/material.dart';

/// Theme, ball-style and pin-style catalog for Bowling.
///
/// Every theme stays inside the physical bowling-alley world: real wood
/// lanes (maple, mahogany, walnut, cherry), warm hall lighting, painted
/// pins and polished balls. No neon, no cyberpunk, no AI-dashboard looks.
class AlleyThemeDef {
  final String id;
  final String name;
  final Color laneLight;
  final Color laneMid;
  final Color laneDark;
  final Color gutter;
  final Color deck; // pin deck / pit surround
  final Color wall; // hall backdrop
  final Color accent;
  final Color accentLight;
  final Color accentDark;
  final Color text;
  final Color muted;
  final List<Color> playerColors;

  const AlleyThemeDef({
    required this.id,
    required this.name,
    required this.laneLight,
    required this.laneMid,
    required this.laneDark,
    required this.gutter,
    required this.deck,
    required this.wall,
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.text,
    required this.muted,
    required this.playerColors,
  });
}

class AlleyThemes {
  /// First 4 are the FREE starter themes. The rest are PRO.
  static const List<String> freeThemeIds = [
    'classic',
    'mahogany',
    'midnight',
    'sunset',
  ];

  static bool isProTheme(String id) => !freeThemeIds.contains(id);

  static const List<AlleyThemeDef> all = [
    AlleyThemeDef(
      id: 'classic',
      name: 'Classic Maple',
      laneLight: Color(0xFFE8C98A),
      laneMid: Color(0xFFD9AC66),
      laneDark: Color(0xFFB3854A),
      gutter: Color(0xFF5C4326),
      deck: Color(0xFF2E1F12),
      wall: Color(0xFF17100A),
      accent: Color(0xFFB3282D),
      accentLight: Color(0xFFE06666),
      accentDark: Color(0xFF7A1B1F),
      text: Color(0xFFF8F1E3),
      muted: Color(0xFFC9B896),
      playerColors: [Color(0xFFB3282D), Color(0xFF1F5FA8)],
    ),
    AlleyThemeDef(
      id: 'mahogany',
      name: 'Royal Mahogany',
      laneLight: Color(0xFFB06A3F),
      laneMid: Color(0xFF8F4E2C),
      laneDark: Color(0xFF6B3620),
      gutter: Color(0xFF3E2012),
      deck: Color(0xFF241209),
      wall: Color(0xFF140C06),
      accent: Color(0xFFD4AF37),
      accentLight: Color(0xFFF3DC8E),
      accentDark: Color(0xFF96702A),
      text: Color(0xFFF8F1E2),
      muted: Color(0xFFD3B98A),
      playerColors: [Color(0xFF7A1B5C), Color(0xFF1B7A6B)],
    ),
    AlleyThemeDef(
      id: 'midnight',
      name: 'Midnight League',
      laneLight: Color(0xFF8A6A44),
      laneMid: Color(0xFF6B4E30),
      laneDark: Color(0xFF4A3320),
      gutter: Color(0xFF2A1E12),
      deck: Color(0xFF191007),
      wall: Color(0xFF0D0A06),
      accent: Color(0xFF7FA8C9),
      accentLight: Color(0xFFB9D4EA),
      accentDark: Color(0xFF4A6B87),
      text: Color(0xFFF2EEE4),
      muted: Color(0xFFA89A7E),
      playerColors: [Color(0xFFD64545), Color(0xFF4A90D9)],
    ),
    AlleyThemeDef(
      id: 'sunset',
      name: 'Sunset Stripes',
      laneLight: Color(0xFFF0BE7E),
      laneMid: Color(0xFFE09A55),
      laneDark: Color(0xFFC07A3E),
      gutter: Color(0xFF6B4423),
      deck: Color(0xFF33200F),
      wall: Color(0xFF1B1008),
      accent: Color(0xFFE07830),
      accentLight: Color(0xFFF5A866),
      accentDark: Color(0xFFA84E18),
      text: Color(0xFFFFF6E8),
      muted: Color(0xFFD8B98C),
      playerColors: [Color(0xFFC0392B), Color(0xFF2E7D5B)],
    ),
    // ---- PRO themes ----
    AlleyThemeDef(
      id: 'cherry',
      name: 'Cherrywood Glow',
      laneLight: Color(0xFFC25E4A),
      laneMid: Color(0xFFA34432),
      laneDark: Color(0xFF7E2F22),
      gutter: Color(0xFF471A12),
      deck: Color(0xFF2A100A),
      wall: Color(0xFF170B06),
      accent: Color(0xFFFFD166),
      accentLight: Color(0xFFFFE3A1),
      accentDark: Color(0xFFC9982F),
      text: Color(0xFFFFF6E8),
      muted: Color(0xFFD8AE8C),
      playerColors: [Color(0xFF1F5FA8), Color(0xFFE07830)],
    ),
    AlleyThemeDef(
      id: 'forest',
      name: 'Forest Pines',
      laneLight: Color(0xFFD9B87E),
      laneMid: Color(0xFFB8945A),
      laneDark: Color(0xFF8F6E3C),
      gutter: Color(0xFF4A3A20),
      deck: Color(0xFF1E2A16),
      wall: Color(0xFF0E150B),
      accent: Color(0xFF5FA85C),
      accentLight: Color(0xFF9BD498),
      accentDark: Color(0xFF3A6E38),
      text: Color(0xFFF4F1E4),
      muted: Color(0xFFB3AC8E),
      playerColors: [Color(0xFF2E7D5B), Color(0xFFC0392B)],
    ),
    AlleyThemeDef(
      id: 'ocean',
      name: 'Harbor Nights',
      laneLight: Color(0xFFD9B87E),
      laneMid: Color(0xFFB8945A),
      laneDark: Color(0xFF8F6E3C),
      gutter: Color(0xFF2E3A4A),
      deck: Color(0xFF16202E),
      wall: Color(0xFF0A0F16),
      accent: Color(0xFF5C9BC4),
      accentLight: Color(0xFF9CC8E4),
      accentDark: Color(0xFF35617E),
      text: Color(0xFFF0F4F8),
      muted: Color(0xFF9AA9B8),
      playerColors: [Color(0xFF1F5FA8), Color(0xFFE0A83C)],
    ),
    AlleyThemeDef(
      id: 'royal',
      name: 'Royal Velvet',
      laneLight: Color(0xFF9A6A42),
      laneMid: Color(0xFF7C4E2E),
      laneDark: Color(0xFF5C3620),
      gutter: Color(0xFF3A2214),
      deck: Color(0xFF241232),
      wall: Color(0xFF120A1A),
      accent: Color(0xFFB78FD4),
      accentLight: Color(0xFFD8BDEA),
      accentDark: Color(0xFF7A5496),
      text: Color(0xFFF6F0FA),
      muted: Color(0xFFB9A4C9),
      playerColors: [Color(0xFF7A1B5C), Color(0xFFD4AF37)],
    ),
    AlleyThemeDef(
      id: 'retro',
      name: 'Retro 70s',
      laneLight: Color(0xFFE8B86A),
      laneMid: Color(0xFFD09344),
      laneDark: Color(0xFFA86E2E),
      gutter: Color(0xFF5C3E1C),
      deck: Color(0xFF3A2410),
      wall: Color(0xFF1C1208),
      accent: Color(0xFFD35400),
      accentLight: Color(0xFFF08C3C),
      accentDark: Color(0xFF8E3A00),
      text: Color(0xFFFFF3E0),
      muted: Color(0xFFD8B57E),
      playerColors: [Color(0xFFD35400), Color(0xFF2E6B4F)],
    ),
    AlleyThemeDef(
      id: 'desert',
      name: 'Desert Dunes',
      laneLight: Color(0xFFF2D49A),
      laneMid: Color(0xFFE0B86E),
      laneDark: Color(0xFFBE9448),
      gutter: Color(0xFF6B5228),
      deck: Color(0xFF3A2E16),
      wall: Color(0xFF1B150A),
      accent: Color(0xFFB8860B),
      accentLight: Color(0xFFE4B84A),
      accentDark: Color(0xFF7E5E06),
      text: Color(0xFFFFF8E8),
      muted: Color(0xFFD8C48C),
      playerColors: [Color(0xFF8E5B00), Color(0xFF1B7A6B)],
    ),
    AlleyThemeDef(
      id: 'walnut',
      name: 'Dark Walnut',
      laneLight: Color(0xFF7E5A38),
      laneMid: Color(0xFF61422A),
      laneDark: Color(0xFF45301E),
      gutter: Color(0xFF2A1D12),
      deck: Color(0xFF180F08),
      wall: Color(0xFF0C0704),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      text: Color(0xFFF5EFE0),
      muted: Color(0xFFA89468),
      playerColors: [Color(0xFFA31621), Color(0xFF1B7A4D)],
    ),
    AlleyThemeDef(
      id: 'copper',
      name: 'Copper Penny',
      laneLight: Color(0xFFC98A5A),
      laneMid: Color(0xFFA86A3E),
      laneDark: Color(0xFF844C28),
      gutter: Color(0xFF4A2C16),
      deck: Color(0xFF2A180C),
      wall: Color(0xFF140C05),
      accent: Color(0xFFDA7F4A),
      accentLight: Color(0xFFF2A878),
      accentDark: Color(0xFF96511F),
      text: Color(0xFFFFF2E4),
      muted: Color(0xFFD4A87C),
      playerColors: [Color(0xFFB3282D), Color(0xFF35617E)],
    ),
  ];

  static AlleyThemeDef byId(String id, {AlleyThemeDef? custom}) {
    if (id == 'custom' && custom != null) return custom;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }
}

// ---------------------------------------------------------------------------
// Ball styles: physical finishes — marble, pearl, swirl, tiger stripe…
// ---------------------------------------------------------------------------
class BallStyle {
  final String name;
  final Color base;
  final Color swirl;
  final bool pro;

  const BallStyle(
      {required this.name,
      required this.base,
      required this.swirl,
      this.pro = false});
}

class BallStyles {
  static const List<BallStyle> all = [
    BallStyle(
        name: 'Classic Marble', base: Color(0xFFB3282D), swirl: Color(0xFF7A1B1F)),
    BallStyle(
        name: 'Midnight Swirl', base: Color(0xFF232A3A), swirl: Color(0xFF4A6B87)),
    BallStyle(
        name: 'Cherry Red', base: Color(0xFFC0392B), swirl: Color(0xFFFFE3A1)),
    BallStyle(
        name: 'Golden Pearl', base: Color(0xFFE4B84A), swirl: Color(0xFFB8860B)),
    BallStyle(
        name: 'Emerald', base: Color(0xFF1B7A4D), swirl: Color(0xFF0E4A2E),
        pro: true),
    BallStyle(
        name: 'Cobalt', base: Color(0xFF1F5FA8), swirl: Color(0xFF123A6B),
        pro: true),
    BallStyle(
        name: 'Tiger Stripe', base: Color(0xFFE07830), swirl: Color(0xFF3A2410),
        pro: true),
    BallStyle(
        name: 'Copper Penny', base: Color(0xFFA86A3E), swirl: Color(0xFF6B3A1A),
        pro: true),
    BallStyle(
        name: 'Ivory Antique', base: Color(0xFFF5EFE0), swirl: Color(0xFFC9B896),
        pro: true),
  ];

  static List<String> get names => [for (final s in all) s.name];
  static bool isPro(int i) => i >= 0 && i < all.length && all[i].pro;
}

// ---------------------------------------------------------------------------
// Pin styles: painted pin finishes — classic, midnight, gold…
// ---------------------------------------------------------------------------
class PinStyle {
  final String name;
  final Color body;
  final Color stripe;
  final bool pro;

  const PinStyle(
      {required this.name,
      required this.body,
      required this.stripe,
      this.pro = false});
}

class PinStyles {
  static const List<PinStyle> all = [
    PinStyle(
        name: 'Classic White', body: Color(0xFFF8F4E8), stripe: Color(0xFFB3282D)),
    PinStyle(
        name: 'Midnight Black', body: Color(0xFF23242A), stripe: Color(0xFFC9A227)),
    PinStyle(
        name: 'Cherrywood', body: Color(0xFF8F4E2C), stripe: Color(0xFFF5EFE0)),
    PinStyle(
        name: 'Harbor Blue', body: Color(0xFFDCE8F2), stripe: Color(0xFF1F5FA8)),
    PinStyle(
        name: 'Golden', body: Color(0xFFE4B84A), stripe: Color(0xFF7E5E06),
        pro: true),
    PinStyle(
        name: 'Forest Green', body: Color(0xFFEAF2E4), stripe: Color(0xFF1B7A4D),
        pro: true),
    PinStyle(
        name: 'Royal Plum', body: Color(0xFF7A1B5C), stripe: Color(0xFFD8BDEA),
        pro: true),
    PinStyle(
        name: 'Crimson', body: Color(0xFF7A1B1F), stripe: Color(0xFFFFE3A1),
        pro: true),
    PinStyle(
        name: 'Ghost Glow', body: Color(0xFFE8E4D8), stripe: Color(0xFF4A6B87),
        pro: true),
  ];

  static List<String> get names => [for (final s in all) s.name];
  static bool isPro(int i) => i >= 0 && i < all.length && all[i].pro;
}
