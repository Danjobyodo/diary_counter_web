import 'dart:foundation';

class DiaryProcessor {
  Future<String> process(String fileContent) async {
    try {
      final pattern = r'(^|\n\s*\n)(\d{4}/\d{2}/\d{2})';
      final regex = RegExp(pattern);
      final matches = regex.allMatches(fileContent);
      final List<String> parts = [];
      String? lastPart;
      for (final match in matches) {
        final textBetween = fileContent.substring(
          lastPart?.length ?? 0, match.start);
        if (lastPart != null) {
          lastPart += textBetween;
          parts.add(lastPart);
        }
        lastPart = match.group(2)!;
      }
      if (lastPart != null) {
        lastPart += fileContent.substring(
          (lastPart.length) + (parts.join().length));
        parts.add(lastPart);
      }

      final csvBuffer = StringBuffer();
      for (final part in parts) {
        final lines = part.split('\n');
        final dateString = lines.first.trim();
        final body = lines.skip(1).join('\n').trim();
        final count = body.runes
            .where((rune) =>
                rune != 0x3000 &&
                !String.fromCharCode(rune).trim().isEmpty)
            .length;
        final dateComponents = dateString.split('\n');
        if (dateComponents.length == 3) {
          final year = dateComponents[0];
          final month = int.tryParse(dateComponents[1]) ?? 0;
          final day = int.tryParse(dateComponents[2]) ?? 0;
          csvBuffer.writeln('$year,$month,$day,$count');
        }
      }
    }
  }
}