import 'package:flutter/widgets.dart';

import '../data/models.dart';
import '../data/weather.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// intl 날짜 형식에 넘길 로캘 이름(예: ko, en).
  String get localeName => Localizations.localeOf(this).toLanguageTag();
}

/// 모델 값(enum 등)을 화면 문구로 바꾼다.
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

  /// 무리 이름(소, Cows).
  String kind(AnimalKind k) => switch (k) {
    AnimalKind.cow => kindCow,
    AnimalKind.chicken => kindChicken,
    AnimalKind.sheep => kindSheep,
    AnimalKind.goat => kindGoat,
  };

  /// 한 마리를 가리킬 때(소, cow).
  String kindOne(AnimalKind k) => switch (k) {
    AnimalKind.cow => kindCowOne,
    AnimalKind.chicken => kindChickenOne,
    AnimalKind.sheep => kindSheepOne,
    AnimalKind.goat => kindGoatOne,
  };

  String status(CropStatus s) => switch (s) {
    CropStatus.excellent => statusExcellent,
    CropStatus.good => statusGood,
    CropStatus.attention => statusAttention,
  };

  String inventoryCategory(InventoryCategory c) => switch (c) {
    InventoryCategory.feed => invFeed,
    InventoryCategory.seed => invSeed,
    InventoryCategory.fertilizer => invFertilizer,
    InventoryCategory.supply => invSupply,
  };

  String eventType(AnimalEventType t) => switch (t) {
    AnimalEventType.added => eventAdded,
    AnimalEventType.sold => eventSold,
    AnimalEventType.died => eventDied,
    AnimalEventType.other => eventOther,
  };

  String careType(CareType t) => switch (t) {
    CareType.vaccine => careVaccine,
    CareType.checkup => careCheckup,
    CareType.deworm => careDeworm,
    CareType.other => careOther,
  };

  String ledgerCategory(LedgerCategory c) => switch (c) {
    LedgerCategory.crops => ledgerCrops,
    LedgerCategory.livestock => ledgerLivestock,
    LedgerCategory.products => ledgerProducts,
    LedgerCategory.subsidy => ledgerSubsidy,
    LedgerCategory.otherIncome => ledgerOtherIncome,
    LedgerCategory.feed => ledgerFeed,
    LedgerCategory.seeds => ledgerSeeds,
    LedgerCategory.fertilizer => ledgerFertilizer,
    LedgerCategory.equipment => ledgerEquipment,
    LedgerCategory.labor => ledgerLabor,
    LedgerCategory.utilities => ledgerUtilities,
    LedgerCategory.vet => ledgerVet,
    LedgerCategory.otherExpense => ledgerOtherExpense,
  };

  String weatherText(WeatherCondition c) => switch (c) {
    WeatherCondition.clear => wxClear,
    WeatherCondition.partlyCloudy => wxPartlyCloudy,
    WeatherCondition.cloudy => wxCloudy,
    WeatherCondition.fog => wxFog,
    WeatherCondition.drizzle => wxDrizzle,
    WeatherCondition.rain => wxRain,
    WeatherCondition.snow => wxSnow,
    WeatherCondition.thunder => wxThunder,
    WeatherCondition.unknown => wxUnknown,
  };

  String age(Animal a, DateTime now) {
    final months = a.ageInMonths(now);
    if (months < 12) return ageMonths(months);
    final years = months / 12;
    return ageYears(years == years.roundToDouble() ? '${years.toInt()}' : years.toStringAsFixed(1));
  }

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

String weatherErrorText(BuildContext context, WeatherException e) => switch (e.problem) {
  WeatherProblem.server => context.l10n.weatherServerError(e.statusCode ?? 0),
  WeatherProblem.badData => context.l10n.weatherDataError,
  WeatherProblem.network => context.l10n.weatherError,
};
