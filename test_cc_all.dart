// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

const String apiKey =
    'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdWQiOiIxIiwianRpIjoiMmM2OThiZWZhNTg3MDA4NGZlMzg2MzY5MTQ1ODc0MDZjNGMyNGQzOWY0YjMzN2IzOTNkZGI1MzBhMGViNDUxYWRkM2Q0OTUxMmZmODA1OWIiLCJpYXQiOjE3NzM4NDc5OTkuNDM0NDI1LCJuYmYiOjE3NzM4NDc5OTkuNDM0NDI2LCJleHAiOjQ5Mjk1MjE1OTkuNDI4OTk4LCJzdWIiOiI3NDc1Nzk3NiIsInNjb3BlcyI6WyJ1c2VyLnJlYWQiLCJ1c2VyLndyaXRlIiwidGFzay5yZWFkIiwidGFzay53cml0ZSIsIndlYmhvb2sucmVhZCIsIndlYmhvb2sud3JpdGUiLCJwcmVzZXQucmVhZCIsInByZXNldC53cml0ZSJdfQ.hZH09ewRGr4Csb4HDOKmho0eyBi-XBUw63n7zC8f5mdZ2NK5bYluRdkU_VLhtjrTafhuof3QZUY3uYLZ4EpM9JgWDcI7-qPemISWYiWTDohXqaQ2kf1qFaMZZaypM4aDqZtVHEBpttmFWL12tumFjU6dmABHPcj7F4IJFm4kOpgE_g_CCQM68DY13pyIfpWvNaW5rObL8S5R2RJrBaF--ERMozcpy74XxogG0JtyyAUdxMlJv-KMQEeZ9lsYmkilSF0VedGMSOHpSXwB1UMdLhweTWuq06qmPdeeA1piOCkhuIK_v5ZmUD1l3b-eKo-i11NGPFxOV5liWLOmxmJ8Pon6CIqAZ00CuX60JQeG53qy1oJ-aQ3qm7VJ35ogFB6jdSxyjhkuRmhOqRulGB6HwwE_yxRqfLS9iUMN5GRUAOlIxoJ8JJLBzafHlKkSeFDdXLQxIg82dS5OHTBqwPoVjSQZn2sxhOURqenxT3kKv8aB6OWF8cVMMrMiOiMIEmiqKCt390IRWF6v5DEqGLI8E-7NpBXCJbQhomNhNQpeZULZAv7X5xC4tfrFvkp4OXgV5gPx8X956ZbU8ZUpeBDdiB6kzA22hpJu20zjbsWVob30wR85iGcYwBl9VAt4fcnuI5dLmApmNFYV73qQNt5afMkA6QxPEC6RnDImfGWwRws';
const String apiUrl = 'https://api.cloudconvert.com/v2';

Future<void> testConversion(String fileName, Uint8List fileBytes) async {
  // Get input format from filename
  final inputFormat = fileName.split('.').last.toLowerCase();
  print('\n========================================');
  print('Testing: $fileName ($inputFormat → pdf)');
  print('File size: ${fileBytes.length} bytes');
  print('========================================');

  // Step A: Create Job
  final jobPayload = {
    'tasks': {
      'import-my-file': {'operation': 'import/upload'},
      'convert-my-file': {
        'operation': 'convert',
        'input': 'import-my-file',
        'input_format': inputFormat,
        'output_format': 'pdf',
      },
      'export-my-file': {'operation': 'export/url', 'input': 'convert-my-file'},
    },
  };

  final jobResponse = await http.post(
    Uri.parse('$apiUrl/jobs'),
    headers: {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(jobPayload),
  );

  print('Job status: ${jobResponse.statusCode}');
  if (jobResponse.statusCode != 200 && jobResponse.statusCode != 201) {
    print('ERROR creating job: ${jobResponse.body}');
    return;
  }

  final jobData = jsonDecode(jobResponse.body)['data'];
  final jobSelfUrl = jobData['links']['self'];
  final tasks = jobData['tasks'] as List;
  final importTask = tasks.firstWhere((t) => t['name'] == 'import-my-file');

  // Step B: Upload
  final uploadForm = importTask['result']?['form'];
  if (uploadForm == null) {
    print('ERROR: no upload form in response');
    return;
  }

  final uploadUrl = uploadForm['url'];
  final uploadParams = uploadForm['parameters'] as Map<String, dynamic>;

  var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
  uploadParams.forEach((key, value) {
    request.fields[key] = value.toString();
  });
  request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));

  final uploadResponse = await request.send();
  print('Upload status: ${uploadResponse.statusCode}');

  // Step C: Poll
  Map<String, dynamic> currentJobData = jobData;
  bool isFinished = false;

  while (!isFinished) {
    await Future.delayed(const Duration(seconds: 2));
    final pollResponse = await http.get(
      Uri.parse(jobSelfUrl),
      headers: {'Authorization': 'Bearer $apiKey'},
    );
    currentJobData = jsonDecode(pollResponse.body)['data'];
    final status = currentJobData['status'];
    print('Poll: status=$status');

    if (status == 'finished') {
      isFinished = true;
    } else if (status == 'error') {
      final tasksList = currentJobData['tasks'] as List;
      for (final task in tasksList) {
        if (task['status'] == 'error') {
          print('FAILED task: ${task['name']} - ${task['message']}');
        }
      }
      return;
    }
  }

  // Step D: Download
  final finishedTasks = currentJobData['tasks'] as List;
  final exportTask = finishedTasks.firstWhere((t) => t['name'] == 'export-my-file');
  final files = exportTask['result']['files'] as List;
  final fileUrl = files[0]['url'];

  final downloadResponse = await http.get(Uri.parse(fileUrl));
  print('Download status: ${downloadResponse.statusCode}, size: ${downloadResponse.bodyBytes.length} bytes');
  
  final outFile = File('output_${fileName.replaceAll('.', '_')}.pdf');
  await outFile.writeAsBytes(downloadResponse.bodyBytes);
  print('✅ SUCCESS! Saved: ${outFile.path} (${downloadResponse.bodyBytes.length} bytes)');
}

Future<void> main() async {
  // Create a minimal but REAL .docx file
  // A .docx is actually a ZIP file containing XML
  // Minimal valid docx bytes
  print('Testing CloudConvert with real file formats...\n');

  // Test 1: Simple .doc (plain text treated as doc)
  final docFile = File('test_word.doc');
  await docFile.writeAsString('This is a test Word document with some content for conversion testing.');
  final docBytes = await docFile.readAsBytes();
  await testConversion('test_word.doc', docBytes);

  // Test 2: Simple .txt renamed to check
  final txtFile = File('test_excel.csv');
  await txtFile.writeAsString('Name,Age,City\nJohn,25,NYC\nJane,30,LA\n');
  final csvBytes = await txtFile.readAsBytes();
  await testConversion('test_excel.csv', csvBytes);

  print('\n\nAll tests complete!');
}
