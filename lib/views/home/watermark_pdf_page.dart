import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../core/constants/constants.dart';

class WatermarkPdfPage extends StatefulWidget {
  final File file;

  const WatermarkPdfPage({super.key, required this.file});

  @override
  State<WatermarkPdfPage> createState() => _WatermarkPdfPageState();
}

class _WatermarkPdfPageState extends State<WatermarkPdfPage> {
  bool _isWatermarking = false;
  final TextEditingController _textController = TextEditingController(
    text: 'CONFIDENTIAL',
  );

  Future<void> _applyWatermark() async {
    final watermarkText = _textController.text.trim();

    if (watermarkText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter watermark text.')),
      );
      return;
    }

    setState(() => _isWatermarking = true);

    try {
      final bytes = await widget.file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);

      // Dynamically size the font based on text length
      final double fontSize = watermarkText.length > 20 ? 40 : 60;
      final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, fontSize);

      for (int i = 0; i < document.pages.count; i++) {
        final page = document.pages[i];
        final pageSize = page.getClientSize();
        final graphics = page.graphics;

        graphics.save();

        // Set 30% transparency
        graphics.setTransparency(0.25);

        // Calculate center of page
        final double centerX = pageSize.width / 2;
        final double centerY = pageSize.height / 2;

        // Move origin to center, rotate -45 degrees
        graphics.translateTransform(centerX, centerY);
        graphics.rotateTransform(-45);

        // Measure text to center it at origin
        final textSize = font.measureString(watermarkText);

        // Draw watermark text centered at the rotated origin
        graphics.drawString(
          watermarkText,
          font,
          brush: PdfBrushes.gray,
          bounds: Rect.fromCenter(
            center: Offset.zero,
            width: textSize.width,
            height: textSize.height,
          ),
          format: PdfStringFormat(
            alignment: PdfTextAlignment.center,
            lineAlignment: PdfVerticalAlignment.middle,
          ),
        );

        graphics.restore();
      }

      final List<int> savedBytes = document.saveSync();
      document.dispose();

      // Generate _watermarked filename
      final originalFileName = widget.file.path.split('/').last;
      final baseName = originalFileName.replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );
      final watermarkedFileName = '${baseName}_watermarked.pdf';

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/$watermarkedFileName';
      final file = File(filePath);
      await file.writeAsBytes(savedBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Watermark Applied!'),
            backgroundColor: Colors.green,
          ),
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
          text: 'Here is your watermarked PDF.',
          sharePositionOrigin: sharePosition,
        ),
      );

      // Post-share reminder dialog
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  CupertinoIcons.checkmark_seal_fill,
                  color: Colors.green,
                  size: 28,
                ),
                const SizedBox(width: 10),
                const Text("Watermark Applied!"),
              ],
            ),
            content: const Text(
              "Your watermarked PDF is ready.\n\n"
              "Don't forget to delete the original file if you no longer need it.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "Got it",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to apply watermark: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isWatermarking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.file.path.split('/').last;

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text(
          "Watermark PDF",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppConstants.backgroundColor,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // File Info Card
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
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        CupertinoIcons.textformat,
                        color: Colors.orange,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                "Watermark Text",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "This text will appear diagonally across every page.",
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),

              // Watermark Text Field
              TextField(
                controller: _textController,
                decoration: InputDecoration(
                  labelText: "Enter Watermark Text",
                  hintText: "e.g., CONFIDENTIAL or DO NOT COPY",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  prefixIcon: const Icon(
                    CupertinoIcons.text_cursor,
                    color: Colors.orange,
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),

              // Preview hint
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.info,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "The watermark will be semi-transparent and placed diagonally across each page.",
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Apply Button
              SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isWatermarking ? null : _applyWatermark,
                    icon: _isWatermarking
                        ? const SizedBox.shrink()
                        : const Icon(CupertinoIcons.textformat_alt, size: 22),
                    label: _isWatermarking
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Apply Watermark & Save",
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
      ),
    );
  }
}
