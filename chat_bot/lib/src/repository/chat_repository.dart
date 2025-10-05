import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:matsue_castle_chat_bot/src/network/open_ai_client.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// https://matsue-castle-qbt5u45.svc.aped-4627-b74a.pinecone.io

class ChatRepository {
  ChatRepository(this.api);
  final OpenAiClient api;

  final List<Map<String, String>> _history = [];
  List<Map<String, String>> get history => List.unmodifiable(_history);

  Future<Map<String, dynamic>> sendMessage(
      String userText) async {
    final uri = Uri.https(api.base, '/v1/chat/completions');
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
            'content': jsonEncode({
              'instruction': userText
            })
          }
        ],
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('OpenAI error: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> sendMessageToPinecone(
      String userText, List<double> vector) async {
    final uri =
        Uri.parse('https://matsue-castle-qbt5u45.svc.aped-4627-b74a.pinecone.io/query');

    final res = await http.post(
      uri,
      headers: {
        'Api-Key': 'PINECONE_API_KEY',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "vector": vector,
        "topK": 3,
        "includeMetadata": true,
      }),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Pinecone error: ${res.statusCode} ${res.body}');
  }
}
