import 'package:flutter/foundation.dart';

/// 日記ファイルの処理と文字数カウントを行うクラス
class DiaryProcessor {
  /// ファイルの文字列コンテンツを受け取り、CSV形式の文字列を返す
  /// この関数は非同期である必要がないため、Futureを削除しました
  String process(String fileContent) {
    try {
      // --- 修正箇所 ---
      // 以前のロジックは複雑で、文字列の範囲外にアクセスするバグがありました。
      // ここでは、正規表現を使ってより安全かつシンプルに日記を分割するロジックに全面的に書き換えています。
      //
      // この正規表現は「2回以上の改行の後にyyyy/mm/dd形式が続く箇所」を区切り文字として、
      // テキスト全体を分割します。lookahead `(?=...)` を使うことで、区切り文字自体は
      // 分割後の文字列に含まれないようにしています。
      final pattern = r'\n\s*\n(?=\d{4}/\d{2}/\d{2})';
      final regex = RegExp(pattern, multiLine: true);

      // テキスト全体を、日記ごとのパーツに分割する
      final parts = fileContent.trim().split(regex);

      // ファイルが空、または有効な日記が一つもない場合は、空の文字列を返す
      if (parts.isEmpty || (parts.length == 1 && parts.first.trim().isEmpty)) {
        return '';
      }

      // CSVの各行を生成するためのバッファ
      final csvBuffer = StringBuffer();

      // 分割された各パーツを処理する
      for (final part in parts) {
        // 前後の空白を削除
        final trimmedPart = part.trim();
        if (trimmedPart.isEmpty) continue; // 空のパーツは無視する

        final lines = trimmedPart.split('\n');
        final dateString = lines.first.trim();

        // 最初の行が本当に日付形式か、念のため確認する
        if (!RegExp(r'^\d{4}/\d{2}/\d{2}$').hasMatch(dateString)) {
          continue; // 日付で始まらないパーツは無視する
        }

        // 2行目以降を本文とする
        final body = lines.skip(1).join('\n').trim();

        // 文字数をカウントする（以前のロジックを流用）
        final count = body.runes
            .where(
              (rune) =>
                  rune != 0x3000 && // 全角スペース(U+3000)は除外
                  !String.fromCharCode(rune).trim().isEmpty,
            )
            .length;

        // 日付を yyyy,m,d 形式に変換する
        // 以前ここで '\n' で分割するバグがあったため、'/' に修正
        final dateComponents = dateString.split('/');
        if (dateComponents.length == 3) {
          final year = dateComponents[0];
          // intに変換することで、"09" -> 9 のように先頭のゼロを削除
          final month = int.tryParse(dateComponents[1]) ?? 0;
          final day = int.tryParse(dateComponents[2]) ?? 0;
          // CSVの1行をバッファに追加
          csvBuffer.writeln('$year,$month,$day,$count');
        }
      }

      // 完成したCSV文字列を返す
      return csvBuffer.toString();
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
