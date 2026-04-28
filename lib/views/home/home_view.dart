import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'image_to_pdf_page.dart';
import 'merge_pdf_page.dart';
import 'split_pdf_page.dart';
import 'compress_pdf_page.dart';
import 'lock_pdf_page.dart';
import 'watermark_pdf_page.dart';
import 'reorder_pdf_page.dart';
import 'package:share_plus/share_plus.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../core/constants/constants.dart';
import '../../services/cloudconvert_service.dart';
import '../../services/ad_service.dart';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../conversion/conversion_page.dart';
import '../settings/settings_view.dart';

/// Home Dashboard - Professional, Modern UI
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeViewModel>().loadDocuments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopHeader(),
            Expanded(
              child: Consumer<HomeViewModel>(
                builder: (context, viewModel, child) {
                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(
                            AppConstants.paddingMedium,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMainActions(context),
                              const SizedBox(height: 32),
                              _buildSectionHeader(
                                "Recent Documents",
                                onSeeAll: () {},
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                      _buildRecentScansList(viewModel),
                      const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: AppConstants.paddingMedium,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            AppConstants.appName,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppConstants.textPrimary,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(
                CupertinoIcons.settings,
                color: AppConstants.primaryColor,
                size: 28,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsView()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActions(BuildContext context) {
    return Row(
      children: [
        // Card A: Document Scanner
        Expanded(
          child: _buildActionCard(
            title: "Document\nScanner",
            icon: CupertinoIcons.viewfinder,
            color: AppConstants.primaryColor,
            onTap: () => context.read<HomeViewModel>().scanDocument(),
          ),
        ),
        const SizedBox(width: 16),
        // Card B: PDF Magic Tools
        Expanded(
          child: _buildActionCard(
            title: "PDF Magic\nTools",
            icon: CupertinoIcons.wand_stars,
            color: Colors.purple, // Professional Purple accent
            onTap: () => _showToolsMenu(context),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppConstants.textPrimary,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppConstants.textPrimary,
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: const Text(
              'See All',
              style: TextStyle(color: AppConstants.primaryColor),
            ),
          ),
      ],
    );
  }

  Widget _buildRecentScansList(HomeViewModel viewModel) {
    if (viewModel.isLoading) {
      return const SliverToBoxAdapter(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!viewModel.hasDocuments) {
      return SliverToBoxAdapter(child: _buildEmptyState());
    }

    // Take top 4 recent documents
    final recentDocs = viewModel.documents.take(4).toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final document = recentDocs[index];
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMedium,
            vertical: 6,
          ),
          child: _buildDocumentTile(context, viewModel, document),
        );
      }, childCount: recentDocs.length),
    );
  }

  Widget _buildDocumentTile(
    BuildContext context,
    HomeViewModel viewModel,
    document,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => viewModel.viewDocument(document),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.picture_as_pdf,
                      color: Colors.red,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.name ?? 'Untitled Scan',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppConstants.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(document.createdAt),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppConstants.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Action: 3-point menu
                Theme(
                  data: Theme.of(context).copyWith(
                    popupMenuTheme: const PopupMenuThemeData(
                      color: Colors.white,
                      surfaceTintColor: Colors.white,
                    ),
                  ),
                  child: PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey[400]),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    offset: const Offset(0, 40),
                    onSelected: (value) {
                      switch (value) {
                        case 'rename':
                          _renameDocument(viewModel, document);
                          break;
                        case 'share':
                          viewModel.shareDocument(document);
                          break;
                        case 'delete':
                          _deleteDocument(viewModel, document);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20, color: Colors.blue),
                            SizedBox(width: 12),
                            Text(
                              'Rename',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share, size: 20, color: Colors.green),
                            SizedBox(width: 12),
                            Text(
                              'Share',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 12),
                            Text(
                              'Delete',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.red,
                              ),
                            ),
                          ],
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.doc_text_viewfinder,
                size: 48,
                color: AppConstants.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "No recent scans yet",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppConstants.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Start scanning now to keep your documents organized!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppConstants.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showToolsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: false,
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: AppConstants.backgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.wand_stars,
                      color: Colors.purple,
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Text(
                      "PDF Magic Tools",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppConstants.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  children: [
                    _buildToolSection("Convert", [
                      _ToolData(
                        "PDF to Word (OCR)",
                        CupertinoIcons.doc_text,
                        Colors.red,
                        "ocr",
                      ),
                      _ToolData(
                        "Image to PDF",
                        CupertinoIcons.photo_on_rectangle,
                        Colors.purple,
                        "img_to_pdf",
                      ),
                      _ToolData(
                        "Word to PDF",
                        Icons.description,
                        Colors.red,
                        "word_to_pdf",
                      ),
                      _ToolData(
                        "Excel to PDF",
                        Icons.table_view,
                        Colors.green,
                        "excel_to_pdf",
                      ),
                      _ToolData(
                        "PPT to PDF",
                        Icons.slideshow,
                        Colors.orange,
                        "ppt_to_pdf",
                      ),
                    ]),
                    _buildToolSection("Edit", [
                      _ToolData(
                        "Merge PDFs",
                        CupertinoIcons.rectangle_on_rectangle_angled,
                        Colors.orange,
                        "merge",
                      ),
                      _ToolData(
                        "Split PDF",
                        CupertinoIcons.scissors,
                        Colors.red,
                        "split",
                      ),
                      _ToolData(
                        "Compress PDF",
                        CupertinoIcons.arrow_right_arrow_left,
                        Colors.green,
                        "compress",
                      ),
                    ]),
                    _buildToolSection("Security & Org", [
                      _ToolData(
                        "Lock PDF",
                        CupertinoIcons.lock_shield,
                        Colors.indigo,
                        "lock",
                      ),
                      _ToolData(
                        "Watermark",
                        CupertinoIcons.checkmark_seal,
                        Colors.teal,
                        "watermark",
                      ),
                      _ToolData(
                        "Reorder Pages",
                        CupertinoIcons.rectangle_grid_1x2,
                        Colors.pink,
                        "reorder",
                      ),
                    ]),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolSection(String title, List<_ToolData> tools) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12, top: 16),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppConstants.textSecondary,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: tools.length,
          itemBuilder: (context, index) {
            return _MagicToolCard(
              tool: tools[index],
              onTap: () => _handleToolTap(context, tools[index]),
            );
          },
        ),
      ],
    );
  }

  final AdService _adService = AdService();

  void _handleToolTap(BuildContext context, _ToolData tool) async {
    // Show interstitial ad before opening the tool
    _adService.showInterstitialAd(
      onAdDismissed: () => _executeToolAction(context, tool),
    );
  }

  void _executeToolAction(BuildContext context, _ToolData tool) async {
    if (tool.id == 'ocr') {
      Navigator.pop(context); // Close the bottom sheet
      _showDocumentPicker(context);
    } else if (tool.id == 'img_to_pdf') {
      try {
        final List<XFile> selectedImages = await ImagePicker().pickMultiImage();
        if (selectedImages.isNotEmpty && context.mounted) {
          Navigator.pop(context); // Close the tools menu bottom sheet
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ImageToPdfPage(images: selectedImages),
            ),
          );
        }
      } catch (e) {
        debugPrint("Error picking images: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Failed to pick images: $e")));
        }
      }
    } else if (tool.id == 'merge') {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          allowMultiple: true,
        );

        if (result != null) {
          final selectedFiles = result.paths
              .where((p) => p != null)
              .map((p) => File(p!))
              .toList();

          if (selectedFiles.length < 2) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Please select at least 2 PDFs to merge."),
                ),
              );
            }
          } else {
            if (context.mounted) {
              Navigator.pop(context); // Close the tools menu bottom sheet
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MergePdfPage(files: selectedFiles),
                ),
              );
            }
          }
        }
      } catch (e) {
        debugPrint("Error picking PDFs: $e");
      }
    } else if (tool.id == 'split') {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          allowMultiple: false,
        );

        if (result != null && result.files.single.path != null) {
          final selectedFile = File(result.files.single.path!);
          if (context.mounted) {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SplitPdfPage(file: selectedFile),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint("Error picking PDF: $e");
      }
    } else if (tool.id == 'compress') {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          allowMultiple: false,
        );

        if (result != null && result.files.single.path != null) {
          final selectedFile = File(result.files.single.path!);
          if (context.mounted) {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CompressPdfPage(file: selectedFile),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint("Error picking PDF: $e");
      }
    } else if (tool.id == 'word_to_pdf' ||
        tool.id == 'excel_to_pdf' ||
        tool.id == 'ppt_to_pdf') {
      List<String> allowedExtensions = [];
      if (tool.id == 'word_to_pdf') allowedExtensions = ['doc', 'docx'];
      if (tool.id == 'excel_to_pdf') allowedExtensions = ['xls', 'xlsx'];
      if (tool.id == 'ppt_to_pdf') allowedExtensions = ['ppt', 'pptx'];

      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: allowedExtensions,
          allowMultiple: false,
          withData: true, // CRITICAL: Forces file_picker to read actual bytes
        );

        if (result != null && result.files.single.bytes != null) {
          final fileBytes = result.files.single.bytes!;
          final originalName = result.files.single.name;
          debugPrint(
            '📄 Selected: $originalName, ${fileBytes.length} bytes (withData)',
          );

          final mainContext = this.context;

          if (context.mounted) {
            Navigator.pop(context); // Close bottom sheet
          }

          if (!mainContext.mounted) return;

          showDialog(
            context: mainContext,
            barrierDismissible: false,
            builder: (ctx) => const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Expanded(child: Text("Converting via CloudConvert...")),
                ],
              ),
            ),
          );

          try {
            final service = CloudConvertService();
            final pdfFile = await service.convertOfficeToPdf(
              fileBytes,
              originalName,
            );

            if (mainContext.mounted) {
              Navigator.pop(mainContext); // Close loading dialog

              String finalName = "converted_document";
              bool nameEntered = false;

              await showDialog(
                context: mainContext,
                barrierDismissible: false,
                builder: (ctx) {
                  final renameController = TextEditingController(
                    text: finalName,
                  );
                  return AlertDialog(
                    title: const Text("Save Document As..."),
                    content: TextField(
                      controller: renameController,
                      decoration: const InputDecoration(
                        hintText: "Enter document name",
                      ),
                      autofocus: true,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () {
                          if (renameController.text.trim().isNotEmpty) {
                            finalName = renameController.text.trim();
                            nameEntered = true;
                          }
                          Navigator.pop(ctx);
                        },
                        child: const Text("Save"),
                      ),
                    ],
                  );
                },
              );

              if (nameEntered) {
                // Rename file via copy
                final dir = await getTemporaryDirectory();
                final renamedFile = File(
                  '${dir.path}/${finalName.replaceAll(' ', '_')}.pdf',
                );
                await pdfFile.copy(renamedFile.path);

                if (mainContext.mounted) {
                  ScaffoldMessenger.of(mainContext).showSnackBar(
                    const SnackBar(content: Text('Converted Successfully!')),
                  );
                }

                // Get share position for iPad
                final box = mainContext.findRenderObject() as RenderBox?;
                final sharePosition = box != null
                    ? box.localToGlobal(Offset.zero) & box.size
                    : const Rect.fromLTWH(0, 0, 100, 100);

                await SharePlus.instance.share(
                  ShareParams(
                    files: [XFile(renamedFile.path)],
                    text: 'Here is your PDF.',
                    sharePositionOrigin: sharePosition,
                  ),
                );
              }
            }
          } catch (e) {
            if (mainContext.mounted) {
              Navigator.pop(mainContext); // Close loading dialog
              ScaffoldMessenger.of(
                mainContext,
              ).showSnackBar(SnackBar(content: Text('Conversion Error: $e')));
            }
          }
        }
      } catch (e) {
        debugPrint("Error picking file: $e");
      }
    } else if (tool.id == 'lock') {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          allowMultiple: false,
        );

        if (result != null && result.files.single.path != null) {
          final selectedFile = File(result.files.single.path!);
          if (context.mounted) {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LockPdfPage(file: selectedFile),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint("Error picking PDF: $e");
      }
    } else if (tool.id == 'watermark') {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          allowMultiple: false,
        );

        if (result != null && result.files.single.path != null) {
          final selectedFile = File(result.files.single.path!);
          if (context.mounted) {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WatermarkPdfPage(file: selectedFile),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint("Error picking PDF: $e");
      }
    } else if (tool.id == 'reorder') {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          allowMultiple: false,
        );

        if (result != null && result.files.single.path != null) {
          final selectedFile = File(result.files.single.path!);
          if (context.mounted) {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReorderPdfPage(file: selectedFile),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint("Error picking PDF: $e");
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(tool.icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text('${tool.title} is coming soon!'),
            ],
          ),
          backgroundColor: tool.color.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _showDocumentPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: false,
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
      builder: (context) {
        Future<void> pickFile() async {
          try {
            FilePickerResult? result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['pdf'],
            );

            if (result != null && result.files.single.path != null) {
              final file = File(result.files.single.path!);
              if (context.mounted) {
                Navigator.pop(context); // Close the bottom sheet immediately
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConversionPage(file: file),
                  ),
                );
              }
            }
          } catch (e) {
            debugPrint("Error picking file: $e");
          }
        }

        return Container(
          height:
              MediaQuery.of(context).size.height * 0.45, // Responsive height
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Centered Professional Title
              const Padding(
                padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Center(
                  child: Text(
                    "Select Document for OCR",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppConstants.textPrimary,
                    ),
                  ),
                ),
              ),
              // Clean Empty State
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.doc_text_viewfinder,
                        size: 64,
                        color: AppConstants.primaryColor.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Ready to extract text",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Supported format: PDF",
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
              // Single Prominent Button
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: pickFile,
                      icon: const Icon(CupertinoIcons.folder_open, size: 24),
                      label: const Text(
                        "Import from Files",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        foregroundColor: Colors.white,
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
      },
    );
  }

  // ... (previous helper methods: _renameDocument, _deleteDocument, _formatDate)
  // But wait, the previous replace removed them from correct position if not careful.
  // The replace is targeting _showToolsMenu downwards.

  // Need to ensure _renameDocument etc are preserved or we rely on them being there.
  // The start line of replace is 453. _renameDocument starts around 533 in previous file.
  // I will include them in replacement content just to be safe if I am overwriting them.
  // ... inside _HomeViewState ...

  void _renameDocument(HomeViewModel viewModel, document) async {
    final controller = TextEditingController(text: document.name ?? '');

    if (!mounted) return;

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Document Name',
            hintText: 'Enter new name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != document.name) {
      if (!mounted) return;
      await viewModel.renameDocument(document, newName);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Renamed to: $newName')));
      }
    }
  }

  void _deleteDocument(HomeViewModel viewModel, document) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to delete this document?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await viewModel.deleteDocument(document);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// External classes for the Magic Tools Grid

class _ToolData {
  final String title;
  final IconData icon;
  final Color color;
  final String id;

  _ToolData(this.title, this.icon, this.color, this.id);
}

class _MagicToolCard extends StatefulWidget {
  final _ToolData tool;
  final VoidCallback onTap;

  const _MagicToolCard({required this.tool, required this.onTap});

  @override
  State<_MagicToolCard> createState() => _MagicToolCardState();
}

class _MagicToolCardState extends State<_MagicToolCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnimation.value, child: child),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.tool.color.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.tool.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.tool.icon,
                  color: widget.tool.color,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  widget.tool.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.textPrimary,
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
