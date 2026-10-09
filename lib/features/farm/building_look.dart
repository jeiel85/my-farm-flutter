import 'package:flutter/material.dart';

import '../../game/defs.dart';

/// 건물별 아이콘과 지붕 색(평면 그림·세운 그림·화면이 같은 색을 쓴다).
///
/// 원본의 빨간 헛간과 겹치지 않게, 소 외양간은 판자벽에 청회색 함석지붕이다.
abstract final class BuildingLook {
  static const coopRoof = Color(0xFFB58A52);
  static const goatRoof = Color(0xFF9C7A54);
  static const sheepRoof = Color(0xFF7E8C6A);
  static const cowBarnRoof = Color(0xFF6F8796);
  static const warehouseRoof = Color(0xFF8E7A68);
  static const millRoof = Color(0xFF9A6A4A);
  static const jamRoof = Color(0xFFB5566A);
  static const dairyRoof = Color(0xFF5E86A8);
  static const bakeryRoof = Color(0xFFB06A3A);

  static IconData icon(BuildingId b) => switch (b) {
    BuildingId.farmhouse => Icons.home_outlined,
    BuildingId.storehouse => Icons.warehouse_outlined,
    BuildingId.field => Icons.grass_outlined,
    BuildingId.coop => Icons.egg_outlined,
    BuildingId.goatPen || BuildingId.sheepPen || BuildingId.cowBarn => Icons.pets_outlined,
    BuildingId.greenhouse => Icons.wb_sunny_outlined,
    BuildingId.orchard => Icons.park_outlined,
    BuildingId.mill => Icons.grain,
    BuildingId.jamKitchen => Icons.kitchen_outlined,
    BuildingId.dairy => Icons.local_drink_outlined,
    BuildingId.bakery => Icons.bakery_dining_outlined,
    BuildingId.pond => Icons.water_outlined,
    BuildingId.scarecrow => Icons.accessibility_new_rounded,
    BuildingId.flowerBed => Icons.local_florist_outlined,
  };

  /// 짓기 목록에 보이는 그림 문자.
  static String emoji(BuildingId b) => switch (b) {
    BuildingId.farmhouse => '🏡',
    BuildingId.storehouse => '🏚️',
    BuildingId.field => '🌱',
    BuildingId.coop => '🐔',
    BuildingId.goatPen => '🐐',
    BuildingId.sheepPen => '🐑',
    BuildingId.cowBarn => '🐄',
    BuildingId.greenhouse => '🍓',
    BuildingId.orchard => '🍎',
    BuildingId.mill => '🌾',
    BuildingId.jamKitchen => '🫙',
    BuildingId.dairy => '🧀',
    BuildingId.bakery => '🍞',
    BuildingId.pond => '🪷',
    BuildingId.scarecrow => '🧑‍🌾',
    BuildingId.flowerBed => '🌷',
  };
}
