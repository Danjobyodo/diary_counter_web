import 'dart:convert';
import 'dart:io'; //ネイティブのファイル操作に必要
import 'package:flutter/foundation.dart'; //kIsWebの判定に必要

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart'; //一時フォルダの取得に必要
import 'package:share_plus/share_plus.dart'; //共有機能に必要

// Web専用のHTMLライブラリは条件付きでインポート
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
        // アプリのタイトルを汎用的に変更
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
                        // ボタンの役割を「保存」から「共有/保存」へ変更
                        ElevatedButton.icon(
                          onPressed: _shareOrDownloadCsv,
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

        // ファイルの内容をUTF-8としてデコード
        // 様々な文字コードに対応する場合は、より高度な判定が必要です
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
  Future<void> _shareOrDownloadCsv() async {
    if (_csvOutput == null) return;

    if (kIsWeb) {
      // Webの場合：従来通りダウンロード処理を呼び出す
      _downloadCsvForWeb();
    } else {
      // ネイティブ（iOS, macOSなど）の場合：共有機能を呼び出す
      await _shareCsvForNative();
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
  Future<void> _shareCsvForNative() async {
    if (_csvOutput == null) return;
    try {
      // アプリの一時保存ディレクトリを取得
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/numbers_of_letters.csv';
      final file = File(filePath);

      // CSVデータをファイルに書き込む
      await file.writeAsString(_csvOutput!, flush: true, encoding: utf8);

      // 共有シートを表示
      final xFile = XFile(filePath, mimeType: 'text/csv');
      await Share.shareXFiles([xFile], subject: '日記文字数カウント結果');
    } catch (e) {
      // エラーハンドリング
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('共有に失敗しました: ${e.toString()}')));
      }
    }
  }

  // --- ▲▲▲ 変更/追加したメソッド ▲▲▲ ---
}
