import 'package:flutter/material.dart';

import '../data/models.dart';

/// 가축 아이콘(옆모습). 이미지 에셋 없이 코드로 그린다.
class AnimalAvatar extends StatelessWidget {
  const AnimalAvatar({super.key, required this.kind, this.size = 48, this.variant = 0});

  final AnimalKind kind;
  final double size;

  /// 같은 종이라도 개체마다 무늬를 조금씩 다르게 한다.
  final int variant;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _AnimalPainter(kind, variant));
}

class _AnimalPainter extends CustomPainter {
  _AnimalPainter(this.kind, this.variant);

  final AnimalKind kind;
  final int variant;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    switch (kind) {
      case AnimalKind.cow:
        _cow(canvas);
      case AnimalKind.chicken:
        _chicken(canvas);
      case AnimalKind.sheep:
        _sheep(canvas);
      case AnimalKind.goat:
        _goat(canvas);
    }
    canvas.restore();
  }

  Paint _p(Color c) => Paint()..color = c;

  void _legs(Canvas c, Color color, List<double> xs, double top, double bottom, double w) {
    for (final x in xs) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(x, top, x + w, bottom), const Radius.circular(3)), _p(color));
    }
  }

  void _cow(Canvas c) {
    const dark = Color(0xFF262626);
    // 예시 데이터의 품종 순서(홀스타인·저지·한우·앵거스)에 맞춘 털색.
    final (coat, spots) = switch (variant % 4) {
      1 => (const Color(0xFFC9935A), false),
      2 => (const Color(0xFFA8642E), false),
      3 => (const Color(0xFF2E2A28), false),
      _ => (Colors.white, true),
    };
    c.drawOval(const Rect.fromLTWH(14, 82, 70, 8), _p(const Color(0x22000000)));
    _legs(c, coat, [24, 34, 62, 72], 58, 84, 8);
    _legs(c, dark, [24, 34, 62, 72], 80, 85, 8);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(16, 34, 66, 32), const Radius.circular(16)), _p(coat));
    if (spots) {
      c.drawCircle(const Offset(34, 44), 9, _p(dark));
      c.drawCircle(const Offset(60, 54), 7, _p(dark));
      c.drawCircle(const Offset(48, 38), 5, _p(dark));
    }
    c.drawLine(
      const Offset(16, 42),
      const Offset(8, 58),
      Paint()
        ..color = coat
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    // 머리
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(70, 22, 22, 28), const Radius.circular(10)), _p(coat));
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(72, 40, 22, 14), const Radius.circular(7)),
      _p(const Color(0xFFF2A9A2)),
    );
    c.drawCircle(const Offset(78, 46), 1.6, _p(const Color(0xFFB35A55)));
    c.drawCircle(const Offset(88, 46), 1.6, _p(const Color(0xFFB35A55)));
    c.drawCircle(const Offset(84, 30), 2.4, _p(variant % 4 == 3 ? Colors.white : dark));
    c.drawOval(const Rect.fromLTWH(62, 22, 12, 7), _p(spots ? dark : Color.lerp(coat, Colors.black, 0.2)!));
    c.drawOval(const Rect.fromLTWH(70, 14, 5, 8), _p(const Color(0xFFE8D9B8)));
    c.drawOval(const Rect.fromLTWH(86, 14, 5, 8), _p(const Color(0xFFE8D9B8)));
  }

  void _chicken(Canvas c) {
    final body = [const Color(0xFFC0682F), const Color(0xFFF4F0E6), const Color(0xFF3A2A28)][variant % 3];
    c.drawOval(const Rect.fromLTWH(24, 82, 52, 7), _p(const Color(0x22000000)));
    final leg = Paint()
      ..color = const Color(0xFFE9A23B)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    c.drawLine(const Offset(44, 68), const Offset(42, 84), leg);
    c.drawLine(const Offset(56, 68), const Offset(58, 84), leg);
    // 꼬리
    final tail = Path()
      ..moveTo(28, 50)
      ..quadraticBezierTo(14, 24, 30, 22)
      ..quadraticBezierTo(34, 38, 40, 46)
      ..close();
    c.drawPath(tail, _p(Color.lerp(body, Colors.black, 0.25)!));
    c.drawOval(const Rect.fromLTWH(24, 36, 50, 36), _p(body));
    c.drawOval(const Rect.fromLTWH(36, 46, 24, 14), _p(Color.lerp(body, Colors.black, 0.15)!));
    c.drawCircle(const Offset(68, 34), 13, _p(body));
    // 볏·부리·턱볏
    c.drawCircle(const Offset(64, 20), 4.5, _p(const Color(0xFFE2453A)));
    c.drawCircle(const Offset(70, 19), 4.5, _p(const Color(0xFFE2453A)));
    final beak = Path()
      ..moveTo(79, 31)
      ..lineTo(90, 35)
      ..lineTo(79, 39)
      ..close();
    c.drawPath(beak, _p(const Color(0xFFF0B03A)));
    c.drawOval(const Rect.fromLTWH(75, 39, 6, 9), _p(const Color(0xFFE2453A)));
    c.drawCircle(const Offset(71, 31), 2.3, _p(const Color(0xFF1E1E1E)));
  }

  void _sheep(Canvas c) {
    const wool = Color(0xFFF6F2E8);
    const face = Color(0xFF3B3431);
    c.drawOval(const Rect.fromLTWH(16, 82, 66, 7), _p(const Color(0x22000000)));
    _legs(c, face, [28, 38, 58, 68], 60, 84, 6);
    for (final o in const [
      Offset(30, 46),
      Offset(44, 40),
      Offset(58, 40),
      Offset(68, 48),
      Offset(26, 58),
      Offset(42, 60),
      Offset(58, 60),
      Offset(70, 58),
    ]) {
      c.drawCircle(o, 13, _p(const Color(0xFFE4DDCF)));
      c.drawCircle(o - const Offset(1.5, 1.5), 11.5, _p(wool));
    }
    c.drawOval(const Rect.fromLTWH(72, 30, 20, 26), _p(face));
    c.drawCircle(const Offset(80, 30), 8, _p(wool));
    c.drawOval(const Rect.fromLTWH(64, 36, 11, 6), _p(face));
    c.drawCircle(const Offset(84, 40), 2, _p(Colors.white));
  }

  void _goat(Canvas c) {
    final coat = [const Color(0xFFD9BD94), const Color(0xFFF3EEE4)][variant % 2];
    const dark = Color(0xFF5B4632);
    c.drawOval(const Rect.fromLTWH(18, 82, 64, 7), _p(const Color(0x22000000)));
    _legs(c, coat, [26, 36, 58, 68], 56, 84, 6);
    _legs(c, dark, [26, 36, 58, 68], 80, 85, 6);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(20, 36, 58, 26), const Radius.circular(13)), _p(coat));
    c.drawLine(
      const Offset(22, 40),
      const Offset(14, 32),
      Paint()
        ..color = coat
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    // 목·머리
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(64, 24, 14, 26), const Radius.circular(7)), _p(coat));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(68, 18, 24, 18), const Radius.circular(9)), _p(coat));
    final horn = Paint()
      ..color = const Color(0xFF8E7A62)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    c.drawArc(const Rect.fromLTWH(64, 6, 16, 18), 3.4, 1.9, false, horn);
    c.drawOval(const Rect.fromLTWH(62, 22, 10, 6), _p(Color.lerp(coat, Colors.black, 0.2)!));
    c.drawCircle(const Offset(82, 25), 2.2, _p(const Color(0xFF1E1E1E)));
    // 수염
    final beard = Path()
      ..moveTo(84, 34)
      ..lineTo(88, 46)
      ..lineTo(91, 34)
      ..close();
    c.drawPath(beard, _p(Color.lerp(coat, Colors.black, 0.25)!));
  }

  @override
  bool shouldRepaint(_AnimalPainter old) => old.kind != kind || old.variant != variant;
}
