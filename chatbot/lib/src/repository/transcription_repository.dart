import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
// ignore: depend_on_referenced_packages
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

class TranscriptionRepository {
  TranscriptionRepository();

  Future<String?> transcribe(String path) async {
    if (kDebugMode) {
      print("transccribe called with path: $path");
    } // twice
    try {
      final file = File(path); // e.g. /storage/emulated/0/…/sample.wav
      final text = await transcribeWav(file);
      // use `text` (update state, notify listeners, etc.)
      if (kDebugMode) {
        print('TranscriptionRepository:transcribe $text'); // twice
      }
      return text;
    } catch (e, st) {
      // handle errors (network, file not found, 401, etc.)
      if (kDebugMode) {
        print('Error transcribeWav: $e\n$st');
      }
      return null;
    }
  }

  Future<String> transcribeWav(File wavFile) async {
    if (kDebugMode) {
      print("transcribeWav called with file: ${wavFile.path}");
    }
    final uri = Uri.https('api.openai.com', '/v1/audio/transcriptions');
    final openAiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $openAiKey'
      ..fields['model'] = 'whisper-1'; // model name
      //..fields['language'] = "ja"; // e.g. "ja", "en"
    req.files.add(
      await http.MultipartFile.fromPath(
        'file',
        wavFile.path,
        contentType: MediaType('audio', 'wav'),
      ),
    );

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode ~/ 100 == 2) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return (json['text'] ?? '').toString();
    }
    throw Exception('OpenAI transcribe error: ${res.statusCode} ${res.body}');
  }
}
