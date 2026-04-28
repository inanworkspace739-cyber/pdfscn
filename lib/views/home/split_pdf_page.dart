import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../core/constants/constants.dart';
import '../../services/scanner_service.dart';

class SplitPdfPage extends StatefulWidget {
  final File file;

  const SplitPdfPage({super.key, required this.file});

  @override
  State<SplitPdfPage> createState() => _SplitPdfPageState();
}

class _SplitPdfPageState extends State<SplitPdfPage> {
  bool _isLoading = true;
  bool _isProcessing = false;
  int _totalPages = 0;

  final TextEditingController _pagesController = TextEditingController();
  final List<String> _selectedSegments = [];
  final List<String> _deletedSegments = [];

  @override
  void initState() {
    super.initState();
    _loadPdfInfo();
  }

  Future<void> _loadPdfInfo() async {
    try {
      final bytes = await widget.file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      setState(() {
        _totalPages = document.pages.count;
        _isLoading = false;
      });
      document.dispose();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load PDF: $e')));
      }
    }
  }

  void _addSegment() {
    final text = _pagesController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _selectedSegments.add(text);
        _pagesController.clear();
      });
    }
  }

  void _removeSegment(String segment) {
    setState(() {
      _selectedSegments.remove(segment);
      _deletedSegments.add(segment);
    });
  }

  void _undoRemove() {
    if (_deletedSegments.isNotEmpty) {
      setState(() {
        _selectedSegments.add(_deletedSegments.removeLast());
      });
    }
  }

  List<int> _parsePages(String input, int maxPages) {
    Set<int> pages = {};
    if (input.trim().isEmpty) return [];

    final parts = input.split(',');
    for (var part in parts) {
      part = part.trim();
      if (part.contains('-')) {
        final rangeParts = part.split('-');
        if (rangeParts.length == 2) {
          final start = int.tryParse(rangeParts[0].trim());
          final end = int.tryParse(rangeParts[1].trim());
          if (start != null && end != null && start <= end) {
            for (int i = start; i <= end; i++) {
              if (i >= 1 && i <= maxPages) pages.add(i);
            }
          }
        }
      } else {
        final pageNum = int.tryParse(part);
        if (pageNum != null && pageNum >= 1 && pageNum <= maxPages) {
          pages.add(pageNum);
        }
      }
    }
    final sortedPages = pages.toList()..sort();
    return sortedPages;
  }

  Future<File?> _generateSplitPdf(String fileName) async {
    final pageNumbers = _parsePages(_selectedSegments.join(','), _totalPages);
    if (pageNumbers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select valid page numbers.')),
      );
      return null;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final originalBytes = await widget.file.readAsBytes();
      final originalDocument = PdfDocument(inputBytes: originalBytes);
      final newDocument = PdfDocument();

      for (int pageNum in pageNumbers) {
        final zeroBasedIndex = pageNum - 1;
        if (zeroBasedIndex >= 0 &&
            zeroBasedIndex < originalDocument.pages.count) {
          final PdfPage loadedPage = originalDocument.pages[zeroBasedIndex];
          final PdfTemplate template = loadedPage.createTemplate();

          newDocument.pageSettings.size = loadedPage.size;
          newDocument.pageSettings.margins.all = 0;

          newDocument.pages.add().graphics.drawPdfTemplate(
            template,
            const Offset(0, 0),
          );
        }
      }

      final List<int> savedBytes = newDocument.saveSync();
      originalDocument.dispose();
      newDocument.dispose();

      final dir = await getTemporaryDirectory();
      final String filePath =
          '${dir.path}/${fileName.replaceAll(' ', '_')}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(savedBytes);

      return file;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to process PDF: $e')));
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _showPreview() async {
    final splitFile = await _generateSplitPdf("preview_split");
    if (splitFile != null) {
      await ScannerService().openPDFViewer(splitFile.path);
    }
  }

  Future<void> _renameAndSavePdf() async {
    if (_selectedSegments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select valid page numbers.')),
      );
      return;
    }

    String finalName = "split_document";
    bool nameEntered = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final renameController = TextEditingController(text: finalName);
        return AlertDialog(
          title: const Text("Rename & Save As..."),
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

    final splitFile = await _generateSplitPdf(finalName);
    if (splitFile != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF Split Successfully!')),
        );
      }

      // Get share position for iPad
      final box = context.findRenderObject() as RenderBox?;
      final sharePosition = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : const Rect.fromLTWH(0, 0, 100, 100);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(splitFile.path)],
          text: 'Here is your split PDF.',
          sharePositionOrigin: sharePosition,
        ),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        appBar: AppBar(
          title: const Text("Split PDF"),
          backgroundColor: AppConstants.backgroundColor,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final fileName = widget.file.path.split('/').last;

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text(
          "Split PDF",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppConstants.backgroundColor,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              top: 24.0,
              bottom: 100,
            ),
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
                      const Icon(
                        Icons.picture_as_pdf,
                        color: Colors.blue,
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
                              "Total Pages: $_totalPages",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            CupertinoIcons.eye,
                            color: Colors.blue,
                          ),
                          onPressed: () {
                            ScannerService().openPDFViewer(widget.file.path);
                          },
                          tooltip: 'Preview Original PDF',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                const Text(
                  "Pages to Extract",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "Type a page or range (e.g. 1, or 3-5) and tap Add",
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
                const SizedBox(height: 16),

                // Input Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pagesController,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          hintText: "Enter page / range",
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
                        ),
                        onSubmitted: (_) => _addSegment(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _addSegment,
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Selected Pages Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Selected Pages",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_deletedSegments.isNotEmpty)
                      TextButton.icon(
                        onPressed: _undoRemove,
                        icon: const Icon(Icons.undo, size: 16),
                        label: const Text("Undo"),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Chips Wrap
                Expanded(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _selectedSegments.map((segment) {
                        return Chip(
                          label: Text(
                            segment.contains('-')
                                ? "Pages $segment"
                                : "Page $segment",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          side: BorderSide.none,
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () => _removeSegment(segment),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Buttons
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: AppConstants.backgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.9),
                    blurRadius: 20,
                    spreadRadius: 20,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _showPreview,
                          icon: _isProcessing
                              ? const SizedBox.shrink()
                              : const Icon(
                                  CupertinoIcons.doc_text_viewfinder,
                                  size: 20,
                                  color: Colors.blue,
                                ),
                          label: _isProcessing
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(),
                                )
                              : const Text(
                                  "Show",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.withValues(alpha: 0.1),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _renameAndSavePdf,
                          icon: _isProcessing
                              ? const SizedBox.shrink()
                              : const Icon(
                                  CupertinoIcons.floppy_disk,
                                  size: 24,
                                ),
                          label: _isProcessing
                              ? const SizedBox.shrink()
                              : const Text(
                                  "Rename & Save",
                                  style: TextStyle(
                                    fontSize: 16,
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
          ),
        ],
      ),
    );
  }
}
