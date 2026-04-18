// zuralog/lib/features/sleep/data/mock_sleep_repository.dart
library;

import 'package:zuralog/features/sleep/data/sleep_repository_interface.dart';
import 'package:zuralog/features/sleep/domain/sleep_models.dart';

class MockSleepRepository implements SleepRepositoryInterface {
  @override
  Future<SleepDaySummary> getSleepSummary() async => SleepDaySummary(
        hasData: true,
        durationMinutes: 444,
        bedtime: DateTime(2026, 4, 18, 23, 12),
        wakeTime: DateTime(2026, 4, 19, 6, 36),
        qualityRating: 4,
        qualityLabel: 'Good',
        sleepEfficiencyPct: 89.0,
        avgVs7DayMinutes: 12,
        stages: const SleepStages(
          deepMinutes: 108,
          remMinutes: 89,
          lightMinutes: 210,
          awakeMinutes: 37,
        ),
        sleepingHr: SleepingHR(
          avgBpm: 52.4,
          lowBpm: 46.0,
          highBpm: 68.0,
          curve: [
            HRPoint(time: DateTime(2026, 4, 18, 23, 30), bpm: 62),
            HRPoint(time: DateTime(2026, 4, 19, 0, 0), bpm: 55),
            HRPoint(time: DateTime(2026, 4, 19, 1, 0), bpm: 48),
            HRPoint(time: DateTime(2026, 4, 19, 2, 0), bpm: 46),
            HRPoint(time: DateTime(2026, 4, 19, 3, 0), bpm: 52),
            HRPoint(time: DateTime(2026, 4, 19, 4, 0), bpm: 50),
            HRPoint(time: DateTime(2026, 4, 19, 5, 0), bpm: 54),
            HRPoint(time: DateTime(2026, 4, 19, 6, 0), bpm: 61),
            HRPoint(time: DateTime(2026, 4, 19, 6, 30), bpm: 68),
          ],
        ),
        factors: const ['exercise', 'no_caffeine'],
        interruptions: 1,
        notes: 'Woke up once around 3am.',
        aiSummary:
            'Your sleep was 12 minutes above your 7-day average. Deep sleep was strong at 1h 48m — your body did a lot of recovery work. Evening exercise likely helped you fall asleep faster. Watch out: yesterday\'s late meal may have slightly reduced REM quality.',
        aiGeneratedAt: DateTime(2026, 4, 19, 5, 0),
        sources: const [
          SleepSource(name: 'Oura Ring', icon: 'oura', brandColor: '#EC4899'),
          SleepSource(name: 'Manual', icon: 'manual', brandColor: '#5E5CE6'),
        ],
      );

  @override
  Future<List<SleepTrendDay>> getSleepTrend(String range) async => const [
        SleepTrendDay(
            date: '2026-04-12',
            durationMinutes: 390,
            qualityRating: 3,
            isToday: false),
        SleepTrendDay(
            date: '2026-04-13',
            durationMinutes: 420,
            qualityRating: 4,
            isToday: false),
        SleepTrendDay(
            date: '2026-04-14',
            durationMinutes: null,
            qualityRating: null,
            isToday: false),
        SleepTrendDay(
            date: '2026-04-15',
            durationMinutes: 462,
            qualityRating: 5,
            isToday: false),
        SleepTrendDay(
            date: '2026-04-16',
            durationMinutes: 408,
            qualityRating: 3,
            isToday: false),
        SleepTrendDay(
            date: '2026-04-17',
            durationMinutes: 432,
            qualityRating: 4,
            isToday: false),
        SleepTrendDay(
            date: '2026-04-18',
            durationMinutes: 444,
            qualityRating: 4,
            isToday: true),
      ];
}
