import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
  bool _aggregateByMonth = false;

  final _diaryProcessor = DiaryProcessor();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日記 文字数カウンター'),
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
                    title: Text(
                      '文字数が多い順に並べ替える',
                      style: TextStyle(
                        color: _aggregateByMonth ? Colors.grey : null,
                      ),
                    ),
                    value: _sortByCount,
                    onChanged: _aggregateByMonth
                        ? null
                        : (bool value) {
                            setState(() {
                              _sortByCount = value;
                              if (_fileContent != null) {
                                _processContent();
                              }
                            });
                          },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: SwitchListTile(
                    title: const Text('月別にまとめる'),
                    value: _aggregateByMonth,
                    onChanged: (bool value) {
                      setState(() {
                        _aggregateByMonth = value;
                        if (_aggregateByMonth) {
                          _sortByCount = false;
                        }
                        if (_fileContent != null) {
                          _processContent();
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
                        // --- ▼▼▼ UIの変更箇所 ▼▼▼ ---
                        // Builderでボタンをラップし、固有のBuildContextを取得
                        Builder(
                          builder: (BuildContext context) {
                            return ElevatedButton.icon(
                              onPressed: () => _shareOrDownloadCsv(context),
                              icon: const Icon(Icons.share),
                              label: const Text('結果を共有 / 保存'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                textStyle: const TextStyle(fontSize: 18),
                              ),
                            );
                          },
                        ),
                        // --- ▲▲▲ UIの変更箇所 ▲▲▲ ---
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

  void _processContent() {
    if (_fileContent == null) return;
    final csv = _diaryProcessor.process(
      _fileContent!,
      sortByCount: _sortByCount,
      aggregateByMonth: _aggregateByMonth,
    );
    setState(() {
      _csvOutput = csv;
    });
  }

  Future<void> _pickFile() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _csvOutput = null;
      _fileName = null;
      _fileContent = null;
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
        _fileContent = utf8.decode(bytes);
        _fileName = file.name;
        _processContent();
      }
    } catch (e) {
      _errorMessage = 'エラーが発生しました: ${e.toString()}';
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // --- ▼▼▼ 変更/追加したメソッド ▼▼▼ ---

  /// プラットフォームを判定してCSVの共有またはダウンロードを実行する
  /// iPad/macOSでの動作安定のため、ボタンのBuildContextを受け取るように変更
  Future<void> _shareOrDownloadCsv(BuildContext context) async {
    if (_csvOutput == null) return;

    if (kIsWeb) {
      _downloadCsvForWeb();
    } else {
      await _shareCsvForNative(context);
    }
  }

  /// Webプラットフォーム用のCSVダウンロード処理
  void _downloadCsvForWeb() {
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

  /// ネイティブプラットフォーム用のCSV共有処理
  /// iPad/macOSで共有メニューの表示位置を特定するためにBuildContextを受け取る
  Future<void> _shareCsvForNative(BuildContext context) async {
    if (_csvOutput == null) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/numbers_of_letters.csv';
      final file = File(filePath);

      await file.writeAsString(_csvOutput!, flush: true, encoding: utf8);

      final xFile = XFile(filePath, mimeType: 'text/csv');

      // contextからUI要素の位置とサイズを取得
      final box = context.findRenderObject() as RenderBox?;

      // 共有シートを表示する際に、起点となる位置情報を渡す
      // これによりiPadでのエラーが解消され、macOSでも安定動作する
      await Share.shareXFiles(
        [xFile],
        subject: '日記文字数カウント結果',
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('共有に失敗しました: ${e.toString()}')));
      }
    }
  }

  // --- ▲▲▲ 変更/追加したメソッド ▲▲▲ ---
}
