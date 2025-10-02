import 'package:flutter/foundation.dart';

class _DiaryEntry {
  final String year;
  final int month;
  final int day;
  final int count;
  _DiaryEntry(this.year, this.month, this.day, this.count);
}

class DiaryProcessor {
  String process(
    String fileContent, {
    bool sortByCount = false,
    bool aggregateByMonth = false, // <-- 引数を追加
  }) {
    try {
      final pattern = r'\n\s*\n(?=\d{4}/\d{2}/\d{2})';
      final regex = RegExp(pattern, multiLine: true);
      final parts = fileContent.trim().split(regex);

      if (parts.isEmpty || (parts.length == 1 && parts.first.trim().isEmpty)) {
        return '';
      }

      final entries = <_DiaryEntry>[];
      for (final part in parts) {
        final trimmedPart = part.trim();
        if (trimmedPart.isEmpty) continue;

        final lines = trimmedPart.split('\n');
        final dateString = lines.first.trim();

        if (!RegExp(r'^\d{4}/\d{2}/\d{2}$').hasMatch(dateString)) continue;

        final body = lines.skip(1).join('\n').trim();
        final count = body.runes
            .where((r) => r != 0x3000 && !String.fromCharCode(r).trim().isEmpty)
            .length;

        final dateComponents = dateString.split('/');
        if (dateComponents.length == 3) {
          final year = dateComponents[0];
          final month = int.tryParse(dateComponents[1]) ?? 0;
          final day = int.tryParse(dateComponents[2]) ?? 0;
          entries.add(_DiaryEntry(year, month, day, count));
        }
      }

      // --- ▼▼▼ ここからロジックの分岐 ▼▼▼ ---
      if (aggregateByMonth) {
        // 【月別集計の処理】
        final monthlyTotals = <String, int>{};
        for (final entry in entries) {
          final key = '${entry.year}-${entry.month.toString().padLeft(2, '0')}';
          monthlyTotals[key] = (monthlyTotals[key] ?? 0) + entry.count;
        }

        final sortedKeys = monthlyTotals.keys.toList()..sort();

        final csvBuffer = StringBuffer();
        for (final key in sortedKeys) {
          final parts = key.split('-');
          final year = parts[0];
          final month = int.parse(parts[1]);
          final totalCount = monthlyTotals[key];
          csvBuffer.writeln('$year,$month,$totalCount');
        }
        return csvBuffer.toString();
      } else {
        // 【今まで通りの日別処理】
        if (sortByCount) {
          entries.sort((a, b) => b.count.compareTo(a.count));
        }

        final csvBuffer = StringBuffer();
        for (final entry in entries) {
          csvBuffer.writeln('${entry.year},${entry.month},${entry.day},${entry.count}');
        }
        return csvBuffer.toString();
      }
      // --- ▲▲▲ ロジックの分岐はここまで ▲▲▲ ---
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error processing file: $e\n$stackTrace');
      }
      return 'エラー: ファイルの処理中に問題が発生しました。';
    }
  }
}