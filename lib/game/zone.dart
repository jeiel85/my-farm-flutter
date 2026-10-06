import 'package:flutter/material.dart';

/// 지도 위 구역. 순서가 칩 순서이자 지도 레이아웃 키다. 이름은 l10n에서 정한다.
enum ZoneId {
  house(Icons.home_outlined),
  tomato(Icons.local_florist_outlined),
  vegetable(Icons.eco_outlined),
  corn(Icons.grass_outlined),
  animals(Icons.pets_outlined),
  water(Icons.water_drop_outlined),
  storage(Icons.warehouse_outlined),
  greenhouse(Icons.wb_sunny_outlined),
  orchard(Icons.park_outlined);

  const ZoneId(this.icon);
  final IconData icon;
}
