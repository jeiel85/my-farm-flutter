import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/farm_store.dart';
import '../../data/weather.dart';

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
      out.add((Icons.umbrella_rounded, '오늘 비 올 확률이 ${r.todayRainChance}%예요. 노지 밭 관수는 미뤄도 좋아요.'));
    }
    if ((today?.maxC ?? r.temperatureC) >= 30) {
      out.add((Icons.thermostat_rounded, '한낮 기온이 30°C를 넘어요. 가축 그늘과 물통을 확인하고 온실 환기를 늘리세요.'));
    }
    if ((today?.minC ?? r.temperatureC) <= 2) {
      out.add((Icons.ac_unit_rounded, '최저 기온이 ${today?.minC.round()}°C예요. 서리 피해에 대비해 보온을 해 주세요.'));
    }
    if (r.windKmh >= 30) {
      out.add((Icons.air_rounded, '바람이 강해요(${r.windKmh.round()}km/h). 온실 비닐과 지주대를 점검하세요.'));
    }
    if (out.isEmpty) out.add((Icons.thumb_up_alt_rounded, '밭일하기 좋은 날씨예요.'));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final weather = WeatherScope.of(context);
    final profile = FarmScope.of(context).state.profile;
    final r = weather.report;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: '날씨',
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
                                Text(weather.error!, style: AppText.caption, textAlign: TextAlign.center),
                                TextButton(
                                  onPressed: () =>
                                      weather.ensureLoaded(profile.latitude, profile.longitude, force: true),
                                  child: const Text('다시 시도'),
                                ),
                              ],
                            )
                          : const CircularProgressIndicator(),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      children: [
                        rise(_Current(report: r), 0),
                        const SectionTitle('농장 조언'),
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
                        const SectionTitle('5일 예보'),
                        rise(
                          AppCard(
                            child: Column(
                              children: [
                                for (final d in r.daily)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 64,
                                          child: Text(DateFormat('E d일', 'ko').format(d.date), style: AppText.body),
                                        ),
                                        Icon(describeWeather(d.code).$2, size: 20, color: AppColors.orange),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(describeWeather(d.code).$1, style: AppText.caption)),
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
                          '날씨 데이터: Open-Meteo.com (CC BY 4.0) · ${DateFormat('HH:mm').format(r.fetchedAt)} 갱신',
                          style: AppText.tiny,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
            ),
          ],
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
    final (label, icon) = describeWeather(report.code);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF3B8ED8), Color(0xFF2A6CB3)],
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
              _Pill(Icons.water_drop_outlined, '습도 ${report.humidity}%'),
              const SizedBox(width: 8),
              _Pill(Icons.air_rounded, '바람 ${report.windKmh.round()}km/h'),
              const SizedBox(width: 8),
              _Pill(Icons.umbrella_outlined, '강수 ${report.todayRainChance}%'),
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
