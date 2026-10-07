import 'package:flutter/material.dart';

class C {
  static const Color cream = Color(0xFFFAF8F5);
  static const Color card = Colors.white;
  static const Color ink = Color(0xFF2B2410);
  static const Color inkSoft = Color(0xFF8A8074);
  static const Color warm = Color(0xFFFFB84C);
  static const Color warmDeep = Color(0xFFE8930C);
  static const Color mint = Color(0xFF7FC8A9);
  static const Color mintDeep = Color(0xFF3E8E6C);
  static const Color rose = Color(0xFFF6A4A4);
  static const Color danger = Color(0xFFD6575E);
  static const Color mascotBody = Color(0xFFFFF3DC);
  static const Color mascotLine = Color(0xFF5B4636);

  static const List<Color> palette = <Color>[
    Color(0xFFFFB84C),
    Color(0xFF7FC8A9),
    Color(0xFFF6A4A4),
    Color(0xFF9BB8E8),
    Color(0xFFC9A7E8),
    Color(0xFFF8C471),
    Color(0xFF96CEB4),
    Color(0xFFE8A2B8),
  ];
}

ThemeData sakuTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: C.warmDeep,
  ).copyWith(
    primary: C.warmDeep,
    primaryContainer: const Color(0xFFFFE7C2),
    secondary: C.mintDeep,
    background: C.cream,
    surface: C.card,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: C.cream,
    fontFamilyFallback: const ['Roboto', 'sans-serif'],
    appBarTheme: const AppBarTheme(
      backgroundColor: C.cream,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: C.ink,
        fontSize: 19,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: C.card,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFEEE8DF)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.warmDeep,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: C.card,
      indicatorColor: const Color(0xFFFFE7C2),
      height: 68,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11, color: C.ink),
      ),
    ),
  );
}
