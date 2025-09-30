import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

import 'logic/diary_processor.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _fileName;
  String? _csvOutput;
  String? _errorMessage;
  bool _isProcessing = false;
  bool _sortByCount = false;
  String? _fileContent;

  final _diaryProcessor = DiaryProcessor();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日記 文字数カウンター (Web版)'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '日記が記録されたテキストファイル（.txt）を選択してください。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('ファイルを選択'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40.0,
                    vertical: 8.0,
                  ),
                  child: SwitchListTile(
                    title: const Text('文字数が多い順に並べ替える'),
                    value: _sortByCount,
                    onChanged: (bool value) {
                      setState(() {
                        _sortByCount = value;
                        if (_fileContent != null) {
                          _csvOutput = _diaryProcessor.process(
                            _fileContent!,
                            sortByCount: _sortByCount,
                          );
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),

                if (_isProcessing)
                  const CircularProgressIndicator()
                else if (_fileName != null)
                  Text('選択中のファイル: $_fileName')
                else if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),

                const SizedBox(height: 24),

                if (_csvOutput != null)
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          '処理結果プレビュー',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Scrollbar(
                              child: SingleChildScrollView(
                                child: SelectableText(_csvOutput!),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _downloadCsv,
                          icon: const Icon(Icons.download),
                          label: const Text('CSVファイルとして保存'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            textStyle: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _csvOutput = null;
      _fileName = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final file = result.files.single;
        final bytes = file.bytes!;

        final content = utf8.decode(bytes);
        _fileContent = content;

        final csv = _diaryProcessor.process(content, sortByCount: _sortByCount);

        setState(() {
          _fileName = file.name;
          _csvOutput = csv;
          _isProcessing = false;
        });
      } else {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'エラーが発生しました: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  void _downloadCsv() {
    if (_csvOutput == null) return;

    final bytes = utf8.encode(_csvOutput!);
    final base64 = base64Encode(bytes);

    final anchor = html.AnchorElement(
      href: 'data:text/plain;charset=utf-8;base64,$base64',
    )..setAttribute('download', 'numbers_of_letters.csv');

    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }
}
