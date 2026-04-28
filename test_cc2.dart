// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('Creating test doc...');
  final testFile = File('test.doc');
  await testFile.writeAsString('Hello Word');
  
  print('Starting conversion...');
  try {
    const String apiKey = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdWQiOiIxIiwianRpIjoiMmM2OThiZWZhNTg3MDA4NGZlMzg2MzY5MTQ1ODc0MDZjNGMyNGQzOWY0YjMzN2IzOTNkZGI1MzBhMGViNDUxYWRkM2Q0OTUxMmZmODA1OWIiLCJpYXQiOjE3NzM4NDc5OTkuNDM0NDI1LCJuYmYiOjE3NzM4NDc5OTkuNDM0NDI2LCJleHAiOjQ5Mjk1MjE1OTkuNDI4OTk4LCJzdWIiOiI3NDc1Nzk3NiIsInNjb3BlcyI6WyJ1c2VyLnJlYWQiLCJ1c2VyLndyaXRlIiwidGFzay5yZWFkIiwidGFzay53cml0ZSIsIndlYmhvb2sucmVhZCIsIndlYmhvb2sud3JpdGUiLCJwcmVzZXQucmVhZCIsInByZXNldC53cml0ZSJdfQ.hZH09ewRGr4Csb4HDOKmho0eyBi-XBUw63n7zC8f5mdZ2NK5bYluRdkU_VLhtjrTafhuof3QZUY3uYLZ4EpM9JgWDcI7-qPemISWYiWTDohXqaQ2kf1qFaMZZaypM4aDqZtVHEBpttmFWL12tumFjU6dmABHPcj7F4IJFm4kOpgE_g_CCQM68DY13pyIfpWvNaW5rObL8S5R2RJrBaF--ERMozcpy74XxogG0JtyyAUdxMlJv-KMQEeZ9lsYmkilSF0VedGMSOHpSXwB1UMdLhweTWuq06qmPdeeA1piOCkhuIK_v5ZmUD1l3b-eKo-i11NGPFxOV5liWLOmxmJ8Pon6CIqAZ00CuX60JQeG53qy1oJ-aQ3qm7VJ35ogFB6jdSxyjhkuRmhOqRulGB6HwwE_yxRqfLS9iUMN5GRUAOlIxoJ8JJLBzafHlKkSeFDdXLQxIg82dS5OHTBqwPoVjSQZn2sxhOURqenxT3kKv8aB6OWF8cVMMrMiOiMIEmiqKCt390IRWF6v5DEqGLI8E-7NpBXCJbQhomNhNQpeZULZAv7X5xC4tfrFvkp4OXgV5gPx8X956ZbU8ZUpeBDdiB6kzA22hpJu20zjbsWVob30wR85iGcYwBl9VAt4fcnuI5dLmApmNFYV73qQNt5afMkA6QxPEC6RnDImfGWwRws';
    const String apiUrl = 'https://api.cloudconvert.com/v2';

    const String importTaskName = 'import-my-file';
    const String convertTaskName = 'convert-my-file';
    const String exportTaskName = 'export-my-file';

    print('Step A: Create Job');
    final jobPayload = {
      'tasks': {
        importTaskName: {'operation': 'import/upload'},
        convertTaskName: {
          'operation': 'convert',
          'input': importTaskName,
          'output_format': 'pdf'
        },
        exportTaskName: {'operation': 'export/url', 'input': convertTaskName},
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

    print('Job Status: ${jobResponse.statusCode}');
    if (jobResponse.statusCode != 200 && jobResponse.statusCode != 201) {
      throw Exception('Failed to create job: ${jobResponse.body}');
    }

    final jobData = jsonDecode(jobResponse.body)['data'];
    final jobSelfUrl = jobData['links']['self'];
    
    final tasks = jobData['tasks'] as List;
    final importTask = tasks.firstWhere((t) => t['name'] == importTaskName);
    
    print('Step B: Upload File');
    final uploadUrl = importTask['result']['form']['url'];
    final uploadParams = importTask['result']['form']['parameters'] as Map<String, dynamic>;

    var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    uploadParams.forEach((key, value) {
      request.fields[key] = value.toString();
    });
    
    request.files.add(await http.MultipartFile.fromPath('file', testFile.path));

    print('Uploading to S3 form...');
    final uploadResponse = await request.send();
    print('Upload Status: ${uploadResponse.statusCode}');
    if (uploadResponse.statusCode != 200 && uploadResponse.statusCode != 201 && uploadResponse.statusCode != 204) {
      final respStr = await uploadResponse.stream.bytesToString();
      throw Exception('Failed to upload: $respStr');
    }

    print('Step C: Poll Job');
    Map<String, dynamic> currentJobData = jobData;
    bool isFinished = false;

    while (!isFinished) {
      await Future.delayed(const Duration(seconds: 2));
      print('Polling...');
      final pollResponse = await http.get(
        Uri.parse(jobSelfUrl),
        headers: {'Authorization': 'Bearer $apiKey'},
      );

      if (pollResponse.statusCode != 200) {
        throw Exception('Failed to poll: ${pollResponse.body}');
      }

      currentJobData = jsonDecode(pollResponse.body)['data'];
      final status = currentJobData['status'];
      print('Current Status: $status');

      if (status == 'finished') {
        isFinished = true;
      } else if (status == 'error') {
        throw Exception('Job failed: ${jsonEncode(currentJobData)}');
      }
    }

    print('Step D: Download');
    final finishedTasks = currentJobData['tasks'] as List;
    final exportTask = finishedTasks.firstWhere((t) => t['name'] == exportTaskName);
    final files = exportTask['result']['files'] as List;
    final fileUrl = files[0]['url'];

    print('Download URL: $fileUrl');
    print('Success!');
  } catch (e) {
    print('Error: $e');
  }
}
