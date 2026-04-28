// ignore_for_file: avoid_print
import 'dart:io';
import 'package:pdfsc/services/cloudconvert_service.dart';

void main() async {
  print('Creating test doc...');
  final testFile = File('test.doc');
  await testFile.writeAsString('Hello Word');
  
  print('Starting conversion...');
  try {
    final service = CloudConvertService();
    final bytes = await testFile.readAsBytes();
    final pdf = await service.convertOfficeToPdf(bytes, 'test.doc');
    print('Success: ${pdf.path}');
  } catch (e) {
    print('Error: $e');
  }
}
