import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/constants.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class OCRResultView extends StatefulWidget {
  final String initialText;
  final String documentName;

  const OCRResultView({
    super.key,
    required this.initialText,
    required this.documentName,
  });

  @override
  State<OCRResultView> createState() => _OCRResultViewState();
}

class _OCRResultViewState extends State<OCRResultView> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('OCR Result', style: AppTextStyles.appBarTitle),
        backgroundColor: AppConstants.cardColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppConstants.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy All',
            onPressed: _copyToClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export',
            onPressed: _exportText,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _textController,
            maxLines: null,
            expands: true,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: AppConstants.textPrimary,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(AppConstants.paddingMedium),
              hintText: "No text extracted...",
            ),
          ),
        ),
      ),
    );
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _textController.text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Text copied to clipboard')));
  }

  Future<void> _exportText() async {
    final box = context.findRenderObject() as RenderBox?;
    final text = _textController.text;

    if (text.isEmpty) return;

    try {
      // Create a temporary file
      final directory = await getTemporaryDirectory();
      final fileName = "${widget.documentName}_ocr.txt";
      final file = File('${directory.path}/$fileName');

      await file.writeAsString(text);

      // Share text file
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: "Extracted text from ${widget.documentName}",
          sharePositionOrigin: box != null
              ? box.localToGlobal(Offset.zero) & box.size
              : const Rect.fromLTWH(0, 0, 100, 100),
        ),
      );
    } catch (e) {
      debugPrint("Error exporting text: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to export text')));
      }
    }
  }
}
