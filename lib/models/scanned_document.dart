/// Model representing a scanned document
class ScannedDocument {
  final String id;
  final String pdfPath;
  final DateTime createdAt;
  final String? ocrText;
  final String? name;

  ScannedDocument({
    required this.id,
    required this.pdfPath,
    required this.createdAt,
    this.ocrText,
    this.name,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'pdfPath': pdfPath,
    'createdAt': createdAt.toIso8601String(),
    'ocrText': ocrText,
    'name': name,
  };

  factory ScannedDocument.fromJson(Map<String, dynamic> json) =>
      ScannedDocument(
        id: json['id'] as String,
        pdfPath: json['pdfPath'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        ocrText: json['ocrText'] as String?,
        name: json['name'] as String?,
      );
}
