import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/domain/supplement_today_entry.dart';

void main() {
  group('SupplementTodayLogEntry', () {
    test('holds supplement_id and log_id', () {
      const entry = SupplementTodayLogEntry(
        supplementId: 'supp-1',
        logId: 'log-abc',
      );
      expect(entry.supplementId, 'supp-1');
      expect(entry.logId, 'log-abc');
    });
  });

  group('parseTodayLogResponse', () {
    test('parses list of entries', () {
      final json = {
        'entries': [
          {'supplement_id': 'supp-1', 'log_id': 'log-a'},
          {'supplement_id': 'supp-2', 'log_id': 'log-b'},
        ],
      };
      final entries = parseTodayLogResponse(json);
      expect(entries.length, 2);
      expect(entries[0].supplementId, 'supp-1');
      expect(entries[0].logId, 'log-a');
      expect(entries[1].supplementId, 'supp-2');
      expect(entries[1].logId, 'log-b');
    });

    test('returns empty list when entries key is missing', () {
      final entries = parseTodayLogResponse({});
      expect(entries, isEmpty);
    });

    test('returns empty list when entries is empty', () {
      final entries = parseTodayLogResponse({'entries': []});
      expect(entries, isEmpty);
    });
  });
}
