import 'dart:foundation';

class DiaryProcessor {
  Future<String> process(String fileContent) async {
    try {
      final pattern = r'(^|\n\s*\n)(\d{4}/\d{2}/\d{2})';
      final regex = RegExp(pattern);
      final matches = regex.allMatches(fileContent);
      final List<String> parts = [];
      String? lastPart;

    }
  }
}