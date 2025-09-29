import 'package:ai_shop_list/src/network/open_ai_client.dart';
import 'package:flutter/foundation.dart';
// ignore: depend_on_referenced_packages
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

class TranscriptionRepository {
  TranscriptionRepository(this.api);
  final OpenAiClient api;

  Future<String?> transcribe(String path) async {
    try {
      final file = File(path); // e.g. /storage/emulated/0/…/sample.wav
      final text = await transcribeWav(
        file,
        language: 'en', // optional
      );
      // use `text` (update state, notify listeners, etc.)
      if (kDebugMode) {
        print(' $text');
      }
      return text;
    } catch (e, st) {
      // handle errors (network, file not found, 401, etc.)
      if (kDebugMode) {
        print('Transcription failed: $e\n$st');
      }
      return null;
    }
  }

  Future<String> transcribeWav(File wavFile, {String? language}) async {
    final uri = Uri.https(api.base, '/v1/audio/transcriptions');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${OpenAiClient.apiKey}'
      ..fields['model'] = 'whisper-1'; // model name
    if (language != null && language.isNotEmpty) {
      req.fields['language'] = language; // e.g. "ja", "en"
    }
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
