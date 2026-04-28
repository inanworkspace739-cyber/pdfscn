import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:archive/archive.dart';

// Required dependencies in pubspec.yaml:
// path_provider, share_plus, syncfusion_flutter_pdf, archive

class ConversionPage extends StatefulWidget {
  final File file;

  const ConversionPage({super.key, required this.file});

  @override
  State<ConversionPage> createState() => _ConversionPageState();
}

class _ConversionPageState extends State<ConversionPage> {
  bool isExtracting = false;
  Future<List<int>?> _generateDocxBytes(String text) async {
    final archive = Archive();

    // 1. _rels/.rels
    const rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', rels.length, utf8.encode(rels)));

    // 2. word/_rels/document.xml.rels
    const wordRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
</Relationships>''';
    archive.addFile(
      ArchiveFile(
        'word/_rels/document.xml.rels',
        wordRels.length,
        utf8.encode(wordRels),
      ),
    );

    // 3. word/document.xml
    final escapedText = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    final paragraphs = escapedText
        .split('\n')
        .map((p) => '<w:p><w:r><w:t>$p</w:t></w:r></w:p>')
        .join('');

    final docXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>$paragraphs</w:body>
</w:document>''';
    archive.addFile(
      ArchiveFile('word/document.xml', docXml.length, utf8.encode(docXml)),
    );

    // 4. [Content_Types].xml
    const contentTypes =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';
    archive.addFile(
      ArchiveFile(
        '[Content_Types].xml',
        contentTypes.length,
        utf8.encode(contentTypes),
      ),
    );

    return ZipEncoder().encode(archive);
  }

  Future<void> _downloadDirectlyAsWord() async {
    // Show rename dialog FIRST
    String defaultName = widget.file.path
        .split('/')
        .last
        .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    String finalName = defaultName;
    bool nameEntered = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final renameController = TextEditingController(text: defaultName);
        return AlertDialog(
          title: const Text("Save Document As..."),
          content: TextField(
            controller: renameController,
            decoration: const InputDecoration(
              hintText: "Enter document name",
              suffixText: ".docx",
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

    if (!nameEntered || !mounted) return;

    setState(() {
      isExtracting = true;
    });

    try {
      final bytes = await widget.file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);

      PdfTextExtractor extractor = PdfTextExtractor(document);
      String text = extractor.extractText();
      document.dispose();

      if (text.isEmpty) {
        if (mounted) {
          setState(() => isExtracting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No text could be extracted.')),
          );
        }
        return;
      }

      final docxBytes = await _generateDocxBytes(text);
      if (docxBytes == null) throw Exception('Failed to encode DOCX');

      final directory = await getApplicationDocumentsDirectory();
      final displayFileName = '${finalName.replaceAll(' ', '_')}.docx';

      final file = File('${directory.path}/$displayFileName');
      await file.writeAsBytes(docxBytes);

      if (mounted) {
        setState(() => isExtracting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully saved as $displayFileName'),
            backgroundColor: Colors.green,
          ),
        );

        // Get share position for iPad
        final box = context.findRenderObject() as RenderBox?;
        final sharePosition = box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : const Rect.fromLTWH(0, 0, 100, 100);

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'Here is your converted Word Document',
            sharePositionOrigin: sharePosition,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isExtracting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading Word document: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String displayFileName = widget.file.path.split('/').last;

    return Scaffold(
      appBar: AppBar(title: const Text('Conversion')),
      body: _buildInitialView(displayFileName),
    );
  }

  Widget _buildInitialView(String displayFileName) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf, size: 80, color: Colors.red),
            const SizedBox(height: 24),
            Text(
              'Selected File:',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              displayFileName,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            if (isExtracting)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    "Extracting text...",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _downloadDirectlyAsWord,
                  icon: const Icon(Icons.download),
                  label: const Text(
                    'Download as Word',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
