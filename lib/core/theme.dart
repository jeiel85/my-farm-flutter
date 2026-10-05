import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const bg = Color(0xFFF4EFE6);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFFAF7F1);
  static const line = Color(0xFFEAE3D6);
  static const primary = Color(0xFF1F4D2C);
  static const primarySoft = Color(0xFFE2EEDB);
  static const text = Color(0xFF1C211E);
  static const muted = Color(0xFF7C837D);
  static const orange = Color(0xFFE8963A);
  static const blue = Color(0xFF3D8ED8);
  static const red = Color(0xFFD6534A);
  static const yellow = Color(0xFFF1C04B);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, primary: AppColors.primary, surface: AppColors.bg),
    scaffoldBackgroundColor: AppColors.bg,
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: AppColors.primary),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceSoft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
    ),
  );
}

abstract final class AppText {
  static const title = TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: AppColors.text);
  static const h2 = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: AppColors.text);
  static const h3 = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text);
  static const body = TextStyle(fontSize: 14, color: AppColors.text);
  static const caption = TextStyle(fontSize: 12, color: AppColors.muted);
  static const tiny = TextStyle(fontSize: 11, color: AppColors.muted);
  static const number = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: AppColors.text,
  );
}
