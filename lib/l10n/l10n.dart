import 'package:flutter/widgets.dart';

import '../game/defs.dart';
import '../game/engine.dart';
import '../game/state.dart';
import '../game/zone.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// intl 날짜 형식에 넘길 로캘 이름(예: ko, en).
  String get localeName => Localizations.localeOf(this).toLanguageTag();
}

/// 게임 값(enum 등)을 화면 문구로 바꾼다.
extension Labels on AppLocalizations {
  String zoneShort(ZoneId z) => switch (z) {
    ZoneId.house => zoneShortHouse,
    ZoneId.tomato => zoneShortTomato,
    ZoneId.vegetable => zoneShortVegetable,
    ZoneId.corn => zoneShortCorn,
    ZoneId.animals => zoneShortAnimals,
    ZoneId.water => zoneShortWater,
    ZoneId.storage => zoneShortStorage,
    ZoneId.greenhouse => zoneShortGreenhouse,
    ZoneId.orchard => zoneShortOrchard,
  };

  String zone(ZoneId z) => switch (z) {
    ZoneId.house => zoneHouse,
    ZoneId.tomato => zoneTomato,
    ZoneId.vegetable => zoneVegetable,
    ZoneId.corn => zoneCorn,
    ZoneId.animals => zoneAnimals,
    ZoneId.water => zoneWater,
    ZoneId.storage => zoneStorage,
    ZoneId.greenhouse => zoneGreenhouse,
    ZoneId.orchard => zoneOrchard,
  };

  /// 무리 이름(닭, Chickens).
  String species(Species s) => switch (s) {
    Species.chicken => kindChicken,
    Species.goat => kindGoat,
    Species.sheep => kindSheep,
    Species.cow => kindCow,
  };

  /// 새끼 이름(병아리, chick).
  String young(Species s) => switch (s) {
    Species.chicken => youngChicken,
    Species.goat => youngGoat,
    Species.sheep => youngSheep,
    Species.cow => youngCow,
  };

  String item(ItemId i) => switch (i) {
    ItemId.lettuce => itemLettuce,
    ItemId.carrot => itemCarrot,
    ItemId.tomato => itemTomato,
    ItemId.corn => itemCorn,
    ItemId.strawberry => itemStrawberry,
    ItemId.apple => itemApple,
    ItemId.egg => itemEgg,
    ItemId.goatMilk => itemGoatMilk,
    ItemId.wool => itemWool,
    ItemId.milk => itemMilk,
  };

  String crop(CropId c) => item(GameDefs.crops[c]!.item);

  /// 생산물을 거두는 동작(짜기·줍기·깎기).
  String collectVerb(Species s) => switch (s) {
    Species.chicken => collectEggs,
    Species.goat || Species.cow => collectMilk,
    Species.sheep => collectWool,
  };

  String gameError(GameError e) => switch (e) {
    GameError.zoneLocked => errZoneLocked,
    GameError.alreadyUnlocked => errAlreadyUnlocked,
    GameError.levelTooLow => errLevelTooLow,
    GameError.notEnoughCoins => errNotEnoughCoins,
    GameError.notEnoughWater => errNotEnoughWater,
    GameError.fieldNotEmpty => errFieldNotEmpty,
    GameError.wrongPlot => errWrongPlot,
    GameError.notReady => errNotReady,
    GameError.barnFull => errBarnFull,
    GameError.penFull => errPenFull,
    GameError.notAdult => errNotAdult,
    GameError.nothingToCollect => errNothingToCollect,
    GameError.notEnoughItems => errNotEnoughItems,
    GameError.siloFull => errSiloFull,
    GameError.unknownAnimal => errUnknownAnimal,
  };

  /// 남은 시간 같은 길이(3시간 5분, 2시간, 4분 12초, 6분, 30초).
  String duration(Duration d) {
    final secs = d.inSeconds < 0 ? 0 : d.inSeconds;
    final h = secs ~/ 3600;
    final m = secs % 3600 ~/ 60;
    final s = secs % 60;
    if (h > 0) return m == 0 ? durationH(h) : durationHM(h, m);
    if (m > 0) return s == 0 ? durationM(m) : durationMS(m, s);
    return durationS(s);
  }

  /// 사료가 버티는 시간과 한 묶음의 분량. 동물이 없으면 null.
  String? feedLastsText(GameState s) {
    final perHour = s.feedPerHourAll;
    if (perHour == 0) return null;
    return feedLasts(_roughSpan(s.feed / perHour), _roughSpan(GameDefs.feedPackAmount / perHour));
  }

  /// 대략적인 길이(1시간 이상은 시간, 미만은 분 단위로 버림).
  String _roughSpan(double hours) => hours >= 1 ? spanHours(hours.floor()) : spanMinutes((hours * 60).floor());

  /// "3시간 후", "2 days ago" 같은 상대 시간.
  String relative(DateTime target, DateTime now) {
    final diff = target.difference(now);
    final mins = diff.inMinutes.abs();
    if (mins < 1) return timeNow;
    final span = mins < 60
        ? spanMinutes(mins)
        : mins < 60 * 24
        ? spanHours((mins / 60).floor())
        : spanDays((mins / 1440).floor());
    return diff.isNegative ? timeAgo(span) : timeIn(span);
  }
}

/// 물건 그림 문자(창고·시장·말풍선).
String itemEmoji(ItemId i) => switch (i) {
  ItemId.lettuce => '🥬',
  ItemId.carrot => '🥕',
  ItemId.tomato => '🍅',
  ItemId.corn => '🌽',
  ItemId.strawberry => '🍓',
  ItemId.apple => '🍎',
  ItemId.egg => '🥚',
  ItemId.goatMilk => '🍼',
  ItemId.wool => '🧶',
  ItemId.milk => '🥛',
};

String cropEmoji(CropId c) => itemEmoji(GameDefs.crops[c]!.item);
