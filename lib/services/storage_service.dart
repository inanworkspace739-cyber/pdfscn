import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/scanned_document.dart';
import 'package:flutter/foundation.dart'; // Added for debugPrint

/// Service for managing local storage of scanned documents
class StorageService {
  static const String _metadataFileName = 'scans_metadata.json';

  /// Load all scanned documents from storage
  Future<List<ScannedDocument>> loadDocuments() async {
    try {
      final file = await _getMetadataFile();

      if (!await file.exists()) {
        return [];
      }

      final contents = await file.readAsString();
      final List<dynamic> jsonList = json.decode(contents);

      // Load all documents
      final allDocuments = jsonList
          .map((json) => ScannedDocument.fromJson(json))
          .toList();

      // Filter out documents whose PDF files no longer exist
      final validDocuments = <ScannedDocument>[];
      final invalidDocuments = <ScannedDocument>[];

      for (final doc in allDocuments) {
        final file = File(doc.pdfPath);
        if (await file.exists()) {
          validDocuments.add(doc);
        } else {
          debugPrint('⚠️ Document file not found, will remove: ${doc.pdfPath}');
          invalidDocuments.add(doc);
        }
      }

      // If we found invalid documents, update the metadata file
      if (invalidDocuments.isNotEmpty) {
        debugPrint('🗑️ Removing ${invalidDocuments.length} invalid documents');
        final validJsonList = validDocuments
            .map((doc) => doc.toJson())
            .toList();
        await file.writeAsString(json.encode(validJsonList));
      }

      return validDocuments..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint('Error loading documents: $e');
      return [];
    }
  }

  /// Save a new scanned document
  Future<void> saveDocument(ScannedDocument document) async {
    try {
      final documents = await loadDocuments();
      documents.add(document);

      final file = await _getMetadataFile();
      final jsonList = documents.map((doc) => doc.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      debugPrint('Error saving document: $e');
    }
  }

  /// Delete a scanned document
  Future<bool> deleteDocument(ScannedDocument document) async {
    try {
      // Delete PDF file
      final pdfFile = File(document.pdfPath);
      if (await pdfFile.exists()) {
        await pdfFile.delete();
      }

      // Update metadata
      final documents = await loadDocuments();
      documents.removeWhere((doc) => doc.id == document.id);

      final file = await _getMetadataFile();
      final jsonList = documents.map((doc) => doc.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));

      return true;
    } catch (e) {
      debugPrint('Error deleting document: $e');
      return false;
    }
  }

  Future<File> _getMetadataFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_metadataFileName');
  }
}
