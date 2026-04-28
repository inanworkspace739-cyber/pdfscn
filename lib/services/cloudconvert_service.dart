import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class CloudConvertService {
  static const String apiKey =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdWQiOiIxIiwianRpIjoiMmM2OThiZWZhNTg3MDA4NGZlMzg2MzY5MTQ1ODc0MDZjNGMyNGQzOWY0YjMzN2IzOTNkZGI1MzBhMGViNDUxYWRkM2Q0OTUxMmZmODA1OWIiLCJpYXQiOjE3NzM4NDc5OTkuNDM0NDI1LCJuYmYiOjE3NzM4NDc5OTkuNDM0NDI2LCJleHAiOjQ5Mjk1MjE1OTkuNDI4OTk4LCJzdWIiOiI3NDc1Nzk3NiIsInNjb3BlcyI6WyJ1c2VyLnJlYWQiLCJ1c2VyLndyaXRlIiwidGFzay5yZWFkIiwidGFzay53cml0ZSIsIndlYmhvb2sucmVhZCIsIndlYmhvb2sud3JpdGUiLCJwcmVzZXQucmVhZCIsInByZXNldC53cml0ZSJdfQ.hZH09ewRGr4Csb4HDOKmho0eyBi-XBUw63n7zC8f5mdZ2NK5bYluRdkU_VLhtjrTafhuof3QZUY3uYLZ4EpM9JgWDcI7-qPemISWYiWTDohXqaQ2kf1qFaMZZaypM4aDqZtVHEBpttmFWL12tumFjU6dmABHPcj7F4IJFm4kOpgE_g_CCQM68DY13pyIfpWvNaW5rObL8S5R2RJrBaF--ERMozcpy74XxogG0JtyyAUdxMlJv-KMQEeZ9lsYmkilSF0VedGMSOHpSXwB1UMdLhweTWuq06qmPdeeA1piOCkhuIK_v5ZmUD1l3b-eKo-i11NGPFxOV5liWLOmxmJ8Pon6CIqAZ00CuX60JQeG53qy1oJ-aQ3qm7VJ35ogFB6jdSxyjhkuRmhOqRulGB6HwwE_yxRqfLS9iUMN5GRUAOlIxoJ8JJLBzafHlKkSeFDdXLQxIg82dS5OHTBqwPoVjSQZn2sxhOURqenxT3kKv8aB6OWF8cVMMrMiOiMIEmiqKCt390IRWF6v5DEqGLI8E-7NpBXCJbQhomNhNQpeZULZAv7X5xC4tfrFvkp4OXgV5gPx8X956ZbU8ZUpeBDdiB6kzA22hpJu20zjbsWVob30wR85iGcYwBl9VAt4fcnuI5dLmApmNFYV73qQNt5afMkA6QxPEC6RnDImfGWwRws';
  static const String apiUrl = 'https://api.cloudconvert.com/v2';

  /// Extracts extension from filename (e.g. "report.docx" -> "docx")
  String _getInputFormat(String fileName) {
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return '';
  }

  /// Converts an office file to PDF using CloudConvert API.
  /// [fileBytes] - the raw bytes of the file (read immediately after picking).
  /// [originalFileName] - the original file name with extension.
  Future<File> convertOfficeToPdf(
    Uint8List fileBytes,
    String originalFileName,
  ) async {
    const String importTaskName = 'import-my-file';
    const String convertTaskName = 'convert-my-file';
    const String exportTaskName = 'export-my-file';

    final inputFormat = _getInputFormat(originalFileName);
    debugPrint(
      '📄 CloudConvert: fileName=$originalFileName, format=$inputFormat, size=${fileBytes.length} bytes',
    );

    if (fileBytes.length < 500) {
      throw Exception(
        'File appears to be empty or corrupted (${fileBytes.length} bytes). '
        'Please try selecting the file again.',
      );
    }

    // Step A: Create Job
    final jobPayload = {
      'tasks': {
        importTaskName: {'operation': 'import/upload'},
        convertTaskName: {
          'operation': 'convert',
          'input': importTaskName,
          'input_format': inputFormat,
          'output_format': 'pdf',
        },
        exportTaskName: {'operation': 'export/url', 'input': convertTaskName},
      },
    };

    debugPrint('📄 CloudConvert: Creating job...');

    final jobResponse = await http.post(
      Uri.parse('$apiUrl/jobs'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(jobPayload),
    );

    debugPrint('📄 CloudConvert: Job status=${jobResponse.statusCode}');

    if (jobResponse.statusCode != 200 && jobResponse.statusCode != 201) {
      throw Exception(
        'Failed to create CloudConvert job: ${jobResponse.body}',
      );
    }

    final jobData = jsonDecode(jobResponse.body)['data'];
    final jobSelfUrl = jobData['links']['self'];

    // Find import task
    final tasks = jobData['tasks'] as List;
    final importTask = tasks.firstWhere((t) => t['name'] == importTaskName);

    // Step B: Upload File
    final uploadForm = importTask['result']?['form'];
    if (uploadForm == null) {
      throw Exception('CloudConvert import task did not return upload form.');
    }

    final uploadUrl = uploadForm['url'];
    final uploadParams = uploadForm['parameters'] as Map<String, dynamic>;

    debugPrint('📄 CloudConvert: Uploading ${fileBytes.length} bytes...');

    var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    uploadParams.forEach((key, value) {
      request.fields[key] = value.toString();
    });

    // Upload from raw bytes directly, not from file path
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: originalFileName,
      ),
    );

    final uploadResponse = await request.send();
    debugPrint('📄 CloudConvert: Upload status=${uploadResponse.statusCode}');

    if (uploadResponse.statusCode != 200 &&
        uploadResponse.statusCode != 201 &&
        uploadResponse.statusCode != 204) {
      final respStr = await uploadResponse.stream.bytesToString();
      throw Exception('Failed to upload: $respStr');
    }

    // Step C: Poll Job
    Map<String, dynamic> currentJobData = jobData;
    bool isFinished = false;
    int pollCount = 0;

    while (!isFinished) {
      await Future.delayed(const Duration(seconds: 3));
      pollCount++;
      debugPrint('📄 CloudConvert: Polling #$pollCount...');

      final pollResponse = await http.get(
        Uri.parse(jobSelfUrl),
        headers: {'Authorization': 'Bearer $apiKey'},
      );

      if (pollResponse.statusCode != 200) {
        throw Exception(
          'Failed to poll CloudConvert job: ${pollResponse.body}',
        );
      }

      currentJobData = jsonDecode(pollResponse.body)['data'];
      final status = currentJobData['status'];
      debugPrint('📄 CloudConvert: status=$status');

      if (status == 'finished') {
        isFinished = true;
      } else if (status == 'error') {
        final tasksList = currentJobData['tasks'] as List;
        String errorDetails = 'Unknown error';
        for (final task in tasksList) {
          if (task['status'] == 'error') {
            errorDetails = task['message']?.toString() ?? 'Unknown error';
            debugPrint('📄 CloudConvert: FAILED: ${jsonEncode(task)}');
            break;
          }
        }
        throw Exception('CloudConvert job failed: $errorDetails');
      }

      if (pollCount > 60) {
        throw Exception('CloudConvert timed out.');
      }
    }

    // Step D: Download
    final finishedTasks = currentJobData['tasks'] as List;
    final exportTask = finishedTasks.firstWhere(
      (t) => t['name'] == exportTaskName,
    );

    final exportResult = exportTask['result'];
    if (exportResult == null || exportResult['files'] == null) {
      throw Exception('CloudConvert export task has no files.');
    }

    final files = exportResult['files'] as List;
    final fileUrl = files[0]['url'];
    debugPrint('📄 CloudConvert: Downloading result...');

    final downloadResponse = await http.get(Uri.parse(fileUrl));
    if (downloadResponse.statusCode != 200) {
      throw Exception('Failed to download converted file.');
    }

    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final String filePath = '${dir.path}/converted_$ts.pdf';
    final savedFile = File(filePath);
    await savedFile.writeAsBytes(downloadResponse.bodyBytes);

    debugPrint('📄 CloudConvert: ✅ Success! Saved to $filePath');
    return savedFile;
  }
}
