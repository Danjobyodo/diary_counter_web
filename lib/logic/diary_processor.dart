import 'package:flutter/foundation.dart';

// データを一時的に保持するための小さなクラスを定義すると便利です
class _DiaryEntry {
  final String year;
  final int month;
  final int day;
  final int count;

  _DiaryEntry(this.year, this.month, this.day, this.count);
}

/// 日記ファイルの処理と文字数カウントを行うクラス
class DiaryProcessor {
  /// ファイルの文字列コンテンツを受け取り、CSV形式の文字列を返す
  String process(String fileContent, {bool sortByCount = false}) {
    // <-- sortByCountを受け取る
    try {
      final pattern = r'\n\s*\n(?=\d{4}/\d{2}/\d{2})';
      final regex = RegExp(pattern, multiLine: true);
      final parts = fileContent.trim().split(regex);

      if (parts.isEmpty || (parts.length == 1 && parts.first.trim().isEmpty)) {
        return '';
      }

      // --- ↓↓↓ ここから変更箇所 ↓↓↓ ---

      // データを一時的に格納するためのリストを作成
      final entries = <_DiaryEntry>[];

      for (final part in parts) {
        final trimmedPart = part.trim();
        if (trimmedPart.isEmpty) continue;

        final lines = trimmedPart.split('\n');
        final dateString = lines.first.trim();

        if (!RegExp(r'^\d{4}/\d{2}/\d{2}$').hasMatch(dateString)) {
          continue;
        }

        final body = lines.skip(1).join('\n').trim();

        final count = body.runes
            .where(
              (rune) =>
                  rune != 0x3000 && !String.fromCharCode(rune).trim().isEmpty,
            )
            .length;

        final dateComponents = dateString.split('/');
        if (dateComponents.length == 3) {
          final year = dateComponents[0];
          final month = int.tryParse(dateComponents[1]) ?? 0;
          final day = int.tryParse(dateComponents[2]) ?? 0;

          // すぐに文字列にせず、リストにデータを追加する
          entries.add(_DiaryEntry(year, month, day, count));
        }
      }

      // sortByCountがtrueの場合、リストを文字数の降順（多い順）で並べ替える
      if (sortByCount) {
        entries.sort((a, b) => b.count.compareTo(a.count));
      }

      // 最終的なCSV文字列を生成する
      final csvBuffer = StringBuffer();
      for (final entry in entries) {
        csvBuffer.writeln(
          '${entry.year},${entry.month},${entry.day},${entry.count}',
        );
      }

      return csvBuffer.toString();

      // --- ↑↑↑ ここまで変更箇所 ↑↑↑ ---
    } catch (e, stackTrace) {
      // エラーハンドリングを強化
      if (kDebugMode) {
        print('Error processing file: $e');
        print(stackTrace);
      }
      // エラーが発生した場合は、ユーザーに分かるようにエラーメッセージを返す
      return 'エラー: ファイルの処理中に問題が発生しました。ファイル形式を確認してください。';
    }
  }
}
