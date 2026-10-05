import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_shell.dart';
import 'core/theme.dart';
import 'data/farm_store.dart';
import 'data/weather.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko');
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  final store = await FarmStore.load(PrefsFarmStorage());
  runApp(MyFarmApp(store: store, weather: WeatherController(WeatherService())));
}

class MyFarmApp extends StatelessWidget {
  const MyFarmApp({super.key, required this.store, required this.weather});

  final FarmStore store;
  final WeatherController weather;

  @override
  Widget build(BuildContext context) => FarmScope(
    store: store,
    child: WeatherScope(
      controller: weather,
      child: MaterialApp(
        title: '마이팜',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => PhoneWidthFrame(child: child!),
        home: const AppShell(),
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
