import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../core/constants/constants.dart';

class CompressPdfPage extends StatefulWidget {
  final File file;

  const CompressPdfPage({super.key, required this.file});

  @override
  State<CompressPdfPage> createState() => _CompressPdfPageState();
}

class _CompressPdfPageState extends State<CompressPdfPage> {
  bool _isCompressing = false;
  String _originalSize = "";

  @override
  void initState() {
    super.initState();
    _calculateOriginalSize();
  }

  Future<void> _calculateOriginalSize() async {
    final int bytes = await widget.file.length();
    setState(() {
      _originalSize = _formatBytes(bytes);
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
  }

  Future<void> _compressAndSavePdf() async {
    String finalName = "compressed_document";
    bool nameEntered = false;

    // Show custom rename dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final renameController = TextEditingController(text: finalName);
        return AlertDialog(
          title: const Text("Save Document As..."),
          content: TextField(
            controller: renameController,
            decoration: const InputDecoration(hintText: "Enter document name"),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (renameController.text.trim().isNotEmpty) {
                  finalName = renameController.text.trim();
                  nameEntered = true;
                }
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    if (!nameEntered) return;

    setState(() {
      _isCompressing = true;
    });

    try {
      final originalBytes = await widget.file.readAsBytes();
      final originalDocument = PdfDocument(inputBytes: originalBytes);

      // Syncfusion PDF compression features
      // Note: Free version has limited aggressive compression. We rewrite the logic which often strips unused metadata and slightly reduces size.
      // Additionally, we can set standard properties.
      originalDocument.compressionLevel = PdfCompressionLevel.best;

      final List<int> savedBytes = originalDocument.saveSync();
      originalDocument.dispose();

      final dir = await getTemporaryDirectory();
      final String filePath =
          '${dir.path}/${finalName.replaceAll(' ', '_')}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(savedBytes);

      final newSize = await file.length();
      final formattedNewSize = _formatBytes(newSize);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reduced to: $formattedNewSize')),
        );
      }

      // Get share position for iPad
      final box = context.findRenderObject() as RenderBox?;
      final sharePosition = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : const Rect.fromLTWH(0, 0, 100, 100);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          text: 'Here is your compressed PDF.',
          sharePositionOrigin: sharePosition,
        ),
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to compress PDF: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCompressing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.file.path.split('/').last;

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text(
          "Compress PDF",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppConstants.backgroundColor,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.picture_as_pdf,
                    color: Colors.green,
                    size: 40,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Original Size: $_originalSize",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Compression removes unused elements, metadata, and optimizes structures to slightly reduce PDF size locally.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isCompressing ? null : _compressAndSavePdf,
                  icon: _isCompressing
                      ? const SizedBox.shrink()
                      : const Icon(
                          CupertinoIcons.arrow_right_arrow_left,
                          size: 24,
                        ),
                  label: _isCompressing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Compress PDF",
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
          ],
        ),
      ),
    );
  }
}
