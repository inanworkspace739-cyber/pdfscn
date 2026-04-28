import 'package:flutter/foundation.dart';
import '../models/scanned_document.dart';
import '../services/scanner_service.dart';
import '../services/storage_service.dart';

/// ViewModel for Home Screen
class HomeViewModel extends ChangeNotifier {
  final _scannerService = ScannerService();
  final _storageService = StorageService();

  List<ScannedDocument> _documents = [];
  bool _isLoading = false;

  List<ScannedDocument> get documents => _documents;
  bool get isLoading => _isLoading;
  bool get hasDocuments => _documents.isNotEmpty;

  /// Load scanned documents from storage
  Future<void> loadDocuments() async {
    _isLoading = true;
    notifyListeners();

    _documents = await _storageService.loadDocuments();

    _isLoading = false;
    notifyListeners();
  }

  /// Launch scanner and save results
  Future<void> scanDocument() async {
    try {
      final pdfPath = await _scannerService.scanDocument();

      if (pdfPath != null) {
        final document = ScannedDocument(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          pdfPath: pdfPath,
          createdAt: DateTime.now(),
        );

        await _storageService.saveDocument(document);
        await loadDocuments();
      }
    } catch (e) {
      debugPrint('Scan error: $e');
    }
  }

  /// Extract text from document using OCR
  Future<String?> extractText(ScannedDocument document) async {
    try {
      return await _scannerService.extractText(document.pdfPath);
    } catch (e) {
      debugPrint('OCR error: $e');
      return null;
    }
  }

  /// Share document
  Future<void> shareDocument(ScannedDocument document) async {
    try {
      await _scannerService.shareDocument(document.pdfPath);
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }

  /// Delete a scanned document
  Future<bool> deleteDocument(ScannedDocument document) async {
    final success = await _storageService.deleteDocument(document);
    if (success) {
      await loadDocuments();
    }
    return success;
  }

  /// View document in native PDF viewer with markup tools
  Future<void> viewDocument(ScannedDocument document) async {
    try {
      debugPrint('🔍 Opening viewer for: ${document.pdfPath}');
      await _scannerService.openPDFViewer(document.pdfPath);
      debugPrint('✅ Viewer opened, reloading documents');
      // Reload documents in case they were renamed
      await loadDocuments();
    } catch (e) {
      debugPrint('❌ Viewer error: $e');
    }
  }

  /// Rename a document
  Future<void> renameDocument(ScannedDocument document, String newName) async {
    try {
      final newPath = await _scannerService.renameDocument(
        document.pdfPath,
        newName,
      );

      if (newPath != null) {
        // Update document in storage
        await _storageService.deleteDocument(document);
        final updatedDocument = ScannedDocument(
          id: document.id,
          pdfPath: newPath,
          createdAt: document.createdAt,
          ocrText: document.ocrText,
          name: newName,
        );
        await _storageService.saveDocument(updatedDocument);
        await loadDocuments();
      }
    } catch (e) {
      debugPrint('Rename error: $e');
    }
  }

  /// Add an imported document to storage
  Future<ScannedDocument?> addImportedDocument(
    String name,
    String filePath,
  ) async {
    try {
      final document = ScannedDocument(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        pdfPath: filePath,
        createdAt: DateTime.now(),
        name: name,
      );

      await _storageService.saveDocument(document);
      await loadDocuments();
      return document;
    } catch (e) {
      debugPrint('Import error: $e');
      return null;
    }
  }
}
