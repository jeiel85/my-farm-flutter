import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/farm_store.dart';
import '../../data/weather.dart';
import '../../l10n/l10n.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = FarmScope.read(context).state.profile;
      WeatherScope.read(context).ensureLoaded(p.latitude, p.longitude);
    });
  }

  /// 예보를 바탕으로 한 농장 작업 조언.
  List<(IconData, String)> _advice(WeatherReport r) {
    final out = <(IconData, String)>[];
    final today = r.daily.isEmpty ? null : r.daily.first;
    if (r.todayRainChance >= 60) {
      out.add((Icons.umbrella_rounded, context.l10n.adviceRain(r.todayRainChance)));
    }
    if ((today?.maxC ?? r.temperatureC) >= 30) {
      out.add((Icons.thermostat_rounded, context.l10n.adviceHeat));
    }
    if ((today?.minC ?? r.temperatureC) <= 2) {
      out.add((Icons.ac_unit_rounded, context.l10n.adviceFrost((today?.minC ?? r.temperatureC).round())));
    }
    if (r.windKmh >= 30) {
      out.add((Icons.air_rounded, context.l10n.adviceWind(r.windKmh.round())));
    }
    if (out.isEmpty) out.add((Icons.thumb_up_alt_rounded, context.l10n.adviceGood));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final weather = WeatherScope.of(context);
    final profile = FarmScope.of(context).state.profile;
    final r = weather.report;
    return Scaffold(
      body: WideBody(
        maxWidth: 760,
        child: SafeArea(
          child: Column(
            children: [
              PageHeader(
                title: context.l10n.weather,
                subtitle: profile.locationLabel,
                trailing: IconButton(
                  onPressed: weather.loading
                      ? null
                      : () => weather.ensureLoaded(profile.latitude, profile.longitude, force: true),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
              Expanded(
                child: r == null
                    ? Center(
                        child: weather.error != null
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.muted),
                                  const SizedBox(height: 8),
                                  Text(
                                    weatherErrorText(context, weather.error!),
                                    style: AppText.caption,
                                    textAlign: TextAlign.center,
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        weather.ensureLoaded(profile.latitude, profile.longitude, force: true),
                                    child: Text(context.l10n.retry),
                                  ),
                                ],
                              )
                            : const CircularProgressIndicator(),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                        children: [
                          if (weather.error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AppCard(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    const Icon(Icons.cloud_off_rounded, color: AppColors.muted),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        context.l10n.weatherOffline(
                                          weatherFetchedLabel(context, r.fetchedAt, DateTime.now()),
                                        ),
                                        style: AppText.caption,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: weather.loading
                                          ? null
                                          : () =>
                                                weather.ensureLoaded(profile.latitude, profile.longitude, force: true),
                                      child: Text(context.l10n.retry),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          rise(_Current(report: r), 0),
                          SectionTitle(context.l10n.farmAdvice),
                          for (final (i, (icon, text)) in _advice(r).indexed)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: rise(
                                AppCard(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Icon(icon, color: AppColors.primary),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text(text, style: AppText.body)),
                                    ],
                                  ),
                                ),
                                1 + i,
                              ),
                            ),
                          SectionTitle(context.l10n.forecast5),
                          rise(
                            AppCard(
                              child: Column(
                                children: [
                                  for (final d in r.daily)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        children: [
                                          // "10. 10. (토)"처럼 두 자리 월·일도 한 줄에 들어가는 폭.
                                          SizedBox(
                                            width: 96,
                                            child: Text(
                                              DateFormat.MEd(context.localeName).format(d.date),
                                              style: AppText.body,
                                              maxLines: 1,
                                              softWrap: false,
                                              overflow: TextOverflow.fade,
                                            ),
                                          ),
                                          Icon(describeWeather(d.code).$2, size: 20, color: AppColors.orange),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              context.l10n.weatherText(describeWeather(d.code).$1),
                                              style: AppText.caption,
                                            ),
                                          ),
                                          Text('💧${d.rainChance}%', style: AppText.caption),
                                          const SizedBox(width: 12),
                                          Text(
                                            '${d.minC.round()}° / ${d.maxC.round()}°',
                                            style: AppText.h3.copyWith(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            5,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            context.l10n.weatherUpdated(weatherFetchedLabel(context, r.fetchedAt, DateTime.now())),
                            style: AppText.tiny,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Current extends StatelessWidget {
  const _Current({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    final (condition, icon) = describeWeather(report.code);
    final label = context.l10n.weatherText(condition);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [AppColors.blue, AppColors.blueDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFFFD66B), size: 56),
              const Spacer(),
              Text(
                '${report.temperatureC.round()}°',
                style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w800, height: 1),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Pill(Icons.water_drop_outlined, context.l10n.humidity(report.humidity)),
              const SizedBox(width: 8),
              _Pill(Icons.air_rounded, context.l10n.wind(report.windKmh.round())),
              const SizedBox(width: 8),
              _Pill(Icons.umbrella_outlined, context.l10n.rainChance(report.todayRainChance)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Flexible(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}
