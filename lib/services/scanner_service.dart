import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for interacting with native VisionKit document scanner
class ScannerService {
  static const MethodChannel _channel = MethodChannel('document_scanner');

  /// Launches the native document scanner
  /// Returns the file path of the generated PDF
  Future<String?> scanDocument() async {
    try {
      final result = await _channel.invokeMethod('scanDocument');
      return result as String?;
    } on PlatformException catch (e) {
      if (e.code == 'CANCELLED') {
        return null;
      }
      throw Exception('Scanner error: ${e.message}');
    }
  }

  /// Extracts text from a PDF using OCR
  Future<String?> extractText(String pdfPath) async {
    try {
      final result = await _channel.invokeMethod('extractText', {
        'pdfPath': pdfPath,
      });
      return result as String?;
    } on PlatformException catch (e) {
      throw Exception('OCR error: ${e.message}');
    }
  }

  /// Opens native share sheet for a PDF
  Future<void> shareDocument(String pdfPath) async {
    try {
      await _channel.invokeMethod('shareDocument', {'pdfPath': pdfPath});
    } on PlatformException catch (e) {
      throw Exception('Share error: ${e.message}');
    }
  }

  /// Opens native PDF viewer with markup tools
  Future<void> openPDFViewer(String pdfPath) async {
    try {
      debugPrint('📱 Invoking openPDFViewer with path: $pdfPath');
      await _channel.invokeMethod('openPDFViewer', {'pdfPath': pdfPath});
      debugPrint('✅ openPDFViewer returned successfully');
    } on PlatformException catch (e) {
      debugPrint('❌ PlatformException: ${e.code} - ${e.message}');
      throw Exception('Viewer error: ${e.message}');
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      rethrow;
    }
  }

  /// Renames a document file
  Future<String?> renameDocument(String oldPath, String newName) async {
    try {
      final result = await _channel.invokeMethod('renameDocument', {
        'oldPath': oldPath,
        'newName': newName,
      });
      return result as String?;
    } on PlatformException catch (e) {
      throw Exception('Rename error: ${e.message}');
    }
  }
}
