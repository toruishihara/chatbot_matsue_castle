import 'package:ai_shop_list/src/network/open_ai_client.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatRepository {
  ChatRepository(this.api);
  final OpenAiClient api;

  final List<Map<String, String>> _history = [];
  List<Map<String, String>> get history => List.unmodifiable(_history);

  Future<Map<String, dynamic>> sendMessageWithExisitingList(String userText, List<Map<String, dynamic>> existingList) async {
    final uri = Uri.https(api.base, '/v1/chat/completions');
    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${OpenAiClient.apiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          //{'role': 'system', 'content': api.systemPrompt},
          {
            'role': 'user',
            'content': jsonEncode({
              'instruction': userText,
              'current_list':
                  existingList,
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
}
