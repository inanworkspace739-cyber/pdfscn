import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../core/constants/constants.dart';

class ReorderPdfPage extends StatefulWidget {
  final File file;

  const ReorderPdfPage({super.key, required this.file});

  @override
  State<ReorderPdfPage> createState() => _ReorderPdfPageState();
}

class _ReorderPdfPageState extends State<ReorderPdfPage> {
  bool _isReordering = false;
  bool _isLoading = true;
  List<int> _pageOrder = [];
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadPageCount();
  }

  Future<void> _loadPageCount() async {
    try {
      final bytes = await widget.file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      _totalPages = document.pages.count;
      document.dispose();

      setState(() {
        _pageOrder = List.generate(_totalPages, (i) => i);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load PDF: $e')));
      }
    }
  }

  Future<void> _saveReorderedPdf() async {
    setState(() => _isReordering = true);

    try {
      final bytes = await widget.file.readAsBytes();
      final originalDoc = PdfDocument(inputBytes: bytes);
      final newDoc = PdfDocument();

      // Remove the default blank page that PdfDocument() creates
      if (newDoc.pages.count > 0) {
        newDoc.pages.removeAt(0);
      }

      for (final pageIndex in _pageOrder) {
        final oldPage = originalDoc.pages[pageIndex];
        final pageSize = oldPage.getClientSize();
        final template = oldPage.createTemplate();

        final newPage = newDoc.pages.add();
        newPage.graphics.drawPdfTemplate(template, Offset.zero, pageSize);
      }

      final List<int> savedBytes = newDoc.saveSync();
      newDoc.dispose();
      originalDoc.dispose();

      // Generate _reordered filename
      final originalFileName = widget.file.path.split('/').last;
      final baseName = originalFileName.replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );
      final reorderedFileName = '${baseName}_reordered.pdf';

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/$reorderedFileName';
      final file = File(filePath);
      await file.writeAsBytes(savedBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pages Reordered Successfully!'),
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
          text: 'Here is your reordered PDF.',
          sharePositionOrigin: sharePosition,
        ),
      );

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
                const Expanded(child: Text("Reorder Complete!")),
              ],
            ),
            content: const Text(
              "Your reordered PDF is ready.\n\n"
              "You can manually delete the original file from your device if you no longer need it.",
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to reorder PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isReordering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.file.path.split('/').last;

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text(
          "Reorder Pages",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppConstants.backgroundColor,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // File Info Card
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Container(
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
                            color: Colors.teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            CupertinoIcons.arrow_up_arrow_down,
                            color: Colors.teal,
                            size: 28,
                          ),
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
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "$_totalPages pages • Drag to reorder",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Reorderable List
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    buildDefaultDragHandles: false, // Use our own listener
                    itemCount: _pageOrder.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _pageOrder.removeAt(oldIndex);
                        _pageOrder.insert(newIndex, item);
                      });
                    },
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        shadowColor: AppConstants.primaryColor.withValues(
                          alpha: 0.3,
                        ),
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final originalPageNum = _pageOrder[index] + 1;
                      final isReordered = _pageOrder[index] != index;

                      return Container(
                        key: ValueKey(_pageOrder[index]),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isReordered
                              ? Colors.teal.withValues(alpha: 0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isReordered
                                ? Colors.teal.withValues(alpha: 0.3)
                                : Colors.grey.withValues(alpha: 0.15),
                          ),
                        ),
                        child: ReorderableDelayedDragStartListener(
                          index: index,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: isReordered
                                  ? Colors.teal
                                  : Colors.grey[300],
                              foregroundColor: isReordered
                                  ? Colors.white
                                  : Colors.black87,
                              radius: 18,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            title: Text(
                              "Page $originalPageNum",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: isReordered
                                ? Text(
                                    "Originally page $originalPageNum",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.teal[400],
                                    ),
                                  )
                                : null,
                            trailing: ReorderableDragStartListener(
                              index: index,
                              child: const Icon(
                                CupertinoIcons.chevron_up_chevron_down,
                                color: Colors.grey,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Save Button
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isReordering ? null : _saveReorderedPdf,
                        icon: _isReordering
                            ? const SizedBox.shrink()
                            : const Icon(
                                CupertinoIcons.checkmark_alt,
                                size: 22,
                              ),
                        label: _isReordering
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "Save New Order",
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
