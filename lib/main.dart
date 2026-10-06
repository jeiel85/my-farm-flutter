import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_shell.dart';
import 'core/theme.dart';
import 'data/app_update.dart';
import 'data/farm_store.dart';
import 'data/weather.dart';
import 'features/reminders/reminders.dart';
import 'l10n/l10n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  final systemLanguage = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  final storage = PrefsFarmStorage();
  final store = await FarmStore.load(storage, english: systemLanguage != 'ko');
  final update = appUpdateSupported
      ? UpdateController(storage: storage, platform: MethodChannelUpdatePlatform())
      : null;
  final reminders = remindersSupported
      ? ReminderController(
          store: store,
          platform: LocalNotificationsPlatform(),
          storage: storage,
          localizations: () => reminderLocalizations(store),
        )
      : null;
  runApp(
    MyFarmApp(
      store: store,
      weather: WeatherController(WeatherService(), cache: storage),
      update: update,
      reminders: reminders,
    ),
  );
  // 첫 화면을 막지 않도록 앱을 띄운 뒤 확인한다. 알림은 앱을 열 때마다 앞으로의 예약을 다시 맞춘다.
  unawaited(update?.init());
  unawaited(reminders?.init());
}

class MyFarmApp extends StatelessWidget {
  const MyFarmApp({super.key, required this.store, required this.weather, this.update, this.reminders});

  final FarmStore store;
  final WeatherController weather;

  /// 앱 안 업데이트를 쓰지 않는 플랫폼(웹·Windows)에서는 null.
  final UpdateController? update;

  /// 휴대폰 알림을 쓰지 않는 플랫폼(웹·Windows)에서는 null.
  final ReminderController? reminders;

  @override
  Widget build(BuildContext context) => FarmScope(
    store: store,
    child: WeatherScope(
      controller: weather,
      child: UpdateScope(
        controller: update,
        child: ReminderScope(
          controller: reminders,
          child: ValueListenableBuilder<String?>(
            valueListenable: store.locale,
            builder: (context, localeCode, _) => MaterialApp(
              onGenerateTitle: (context) => context.l10n.appTitle,
              debugShowCheckedModeBanner: false,
              theme: buildTheme(),
              locale: localeCode == null ? null : Locale(localeCode),
              // 한국어·영어가 아닌 기기에서는 영어로 보여 준다(첫 항목이 기본값).
              supportedLocales: AppLocalizations.supportedLocales.reversed.toList(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => PhoneWidthFrame(child: child!),
              home: const AppShell(),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 웹·PC처럼 화면이 넓을 때 휴대폰 폭으로 가운데 정렬한다.
/// 하위 위젯이 실제 앱 영역 크기를 쓰도록 MediaQuery 크기도 함께 줄인다.
class PhoneWidthFrame extends StatelessWidget {
  const PhoneWidthFrame({super.key, required this.child});

  static const maxWidth = 480.0;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= maxWidth + 40) return child;
    return ColoredBox(
      color: const Color(0xFFE4DCCD),
      child: Center(
        child: Container(
          width: maxWidth,
          decoration: const BoxDecoration(
            boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 40, offset: Offset(0, 10))],
          ),
          child: ClipRect(
            child: MediaQuery(
              data: media.copyWith(size: Size(maxWidth, media.size.height)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
