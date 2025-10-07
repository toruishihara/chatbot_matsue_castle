import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatRepository {
  ChatRepository();

  final List<Map<String, String>> _history = [];
  List<Map<String, String>> get history => List.unmodifiable(_history);

  void dumpBodyAsHex(http.Response res) {
    final bytes = res.bodyBytes; // Raw bytes
    final hexDump =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    if (kDebugMode) {
      print('Response HEX: $hexDump');
    }
  }

  Future<String> sendMessage(String userText) async {
    final uri = Uri.https('api.openai.com', '/v1/chat/completions');
    final openAiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $openAiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {
            'role': 'user',
            'content': jsonEncode({'instruction': userText})
          }
        ],
      }),
    );
    if (kDebugMode) {
      print('Response status: ${res.statusCode}');
    }
    dumpBodyAsHex(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body;
      //return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('OpenAI error: ${res.statusCode} ${res.body}');
  }

}
