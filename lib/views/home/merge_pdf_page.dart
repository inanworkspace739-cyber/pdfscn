import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../core/constants/constants.dart';

class MergePdfPage extends StatefulWidget {
  final List<File> files;

  const MergePdfPage({super.key, required this.files});

  @override
  State<MergePdfPage> createState() => _MergePdfPageState();
}

class _MergePdfPageState extends State<MergePdfPage> {
  late List<File> _reorderedFiles;
  bool _isMerging = false;

  @override
  void initState() {
    super.initState();
    _reorderedFiles = List.from(widget.files);
  }

  Future<void> _mergeAndSavePdf() async {
    setState(() {
      _isMerging = true;
    });

    try {
      final PdfDocument mergedDocument = PdfDocument();

      for (final file in _reorderedFiles) {
        final PdfDocument loadedDocument = PdfDocument(
          inputBytes: file.readAsBytesSync(),
        );

        for (int i = 0; i < loadedDocument.pages.count; i++) {
          final PdfPage loadedPage = loadedDocument.pages[i];
          final PdfTemplate template = loadedPage.createTemplate();

          mergedDocument.pageSettings.size = loadedPage.size;
          mergedDocument.pageSettings.margins.all = 0;

          mergedDocument.pages.add().graphics.drawPdfTemplate(
            template,
            const Offset(0, 0),
          );
        }
        loadedDocument.dispose();
      }

      final List<int> savedBytes = mergedDocument.saveSync();
      mergedDocument.dispose();

      // Save to temp directory
      final dir = await getTemporaryDirectory();
      final String safeTimestamp = DateTime.now().millisecondsSinceEpoch
          .toString();
      final String filePath = '${dir.path}/merged_document_$safeTimestamp.pdf';
      final file = File(filePath);

      await file.writeAsBytes(savedBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDFs Merged Successfully!')),
        );
      }

      // Share - Get position for iPad
      final box = context.findRenderObject() as RenderBox?;
      final sharePosition = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : const Rect.fromLTWH(0, 0, 100, 100);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          text: 'Here is the merged PDF document.',
          sharePositionOrigin: sharePosition,
        ),
      );

      if (mounted) {
        Navigator.pop(context); // Go back
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to merge PDFs: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMerging = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text(
          "Reorder & Merge",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppConstants.backgroundColor,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Text(
              "Drag and drop files to change their order in the merged document.",
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _reorderedFiles.length,
              onReorder: (int oldIndex, int newIndex) {
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final File item = _reorderedFiles.removeAt(oldIndex);
                  _reorderedFiles.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final file = _reorderedFiles[index];
                final fileName = file.path.split('/').last;

                return Container(
                  key: ValueKey(file.path),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.redAccent,
                      size: 32,
                    ),
                    title: Text(
                      fileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    trailing: const ReorderableDragStartListener(
                      index: 0,
                      child: Icon(Icons.drag_handle, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isMerging ? null : _mergeAndSavePdf,
                  icon: _isMerging
                      ? const SizedBox.shrink()
                      : const Icon(
                          CupertinoIcons.square_fill_on_square_fill,
                          size: 24,
                        ),
                  label: _isMerging
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Merge & Save",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppConstants.primaryColor
                        .withValues(alpha: 0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
