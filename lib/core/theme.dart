import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// 앱 색. 농지 도면 느낌의 팔레트: 잉크 블루(주색), 테라코타(강조·주의), 세이지·황토(보조), 따뜻한 회색 종이(바탕).
/// 이름(orange, yellow 등)은 쓰임새를 뜻하고, 실제 색은 이 팔레트의 가까운 색이다.
abstract final class AppColors {
  static const bg = Color(0xFFF1EDE4);
  static const surface = Color(0xFFFFFDF9);
  static const surfaceSoft = Color(0xFFF8F5EE);
  static const line = Color(0xFFE3DED3);
  static const primary = Color(0xFF2D4A63);
  static const primaryLight = Color(0xFF3F6585);
  static const primarySoft = Color(0xFFDCE5EE);
  static const text = Color(0xFF1F2429);
  static const muted = Color(0xFF6F757C);
  static const orange = Color(0xFFC4633F);
  static const orangeLight = Color(0xFFD5825F);
  static const blue = Color(0xFF3E7BAA);
  static const blueDeep = Color(0xFF2F5F86);
  static const red = Color(0xFFB9473D);
  static const yellow = Color(0xFFD8A23E);
  static const sage = Color(0xFF6F8F5C);
  static const plum = Color(0xFF7D6A9A);
}

/// 카드·타일 배경용 옅은 색.
abstract final class AppTints {
  static const terracotta = Color(0xFFF3E2D9);
  static const slate = Color(0xFFDFE8EF);
  static const ochre = Color(0xFFF5EBD3);
  static const stone = Color(0xFFE7E3DA);
  static const brick = Color(0xFFF2DED8);
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
