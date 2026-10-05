import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      child: MaterialApp(title: '마이팜', debugShowCheckedModeBanner: false, theme: buildTheme(), home: const AppShell()),
    ),
  );
}
