import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
// ignore: depend_on_referenced_packages
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:matsue_castle_chat_bot/src/settings/settings_controller.dart';

const String whisperPromptJp =
'''      
以下の音声は松江城に関するガイドです。松江城, 千鳥城, 堀尾吉晴, 
宍道湖, 城主, 天守閣, 堀, 土塁, 石垣, 櫓（やぐら）, 城
などの言葉が登場します。
''';
const String whisperPromptEn =
'''
This audio is a guide about Matsue Castle. Words such as Matsue Castle, Chidori Castle, Yoshiharu Horio, 
Lake Shinji, lord, castle keep, moat, earthen rampart, stone wall, turret, and castle
appear.
''';
class TranscriptionRepository {
  final SettingsController settings;
  TranscriptionRepository(this.settings);

  Future<String?> transcribe(String path) async {
    if (kDebugMode) {
      print("transccribe called with path: $path");
    }
    try {
      final file = File(path);
      final text = await transcribeWav(file);
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
      final lang = settings.langMode;
      print('Current language = $lang');
      print("transcribeWav called with file: ${wavFile.path}");
    }
    final uri = Uri.https('api.openai.com', '/v1/audio/transcriptions');
    final openAiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $openAiKey'
      ..fields['model'] = 'whisper-1';

    final lang = settings.langMode;
    if (lang == LangMode.jp) {
      req.fields['language'] = 'ja';
      req.fields['prompt'] = whisperPromptJp;
    } else if (lang == LangMode.en) {
      req.fields['language'] = 'en';
      req.fields['prompt'] = whisperPromptEn;
    } else {
      req.fields['prompt'] = whisperPromptJp + whisperPromptEn;
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
