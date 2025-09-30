import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Pick the model that matches your Pinecone index dimensions.
/// - text-embedding-3-small  -> 1536 dims
/// - text-embedding-3-large  -> 3072 dims
const _embeddingModel = "text-embedding-3-large"; // matches your Python

class RagRepository {
  RagRepository();

  String get _pineconeIndexEndpoint => dotenv.env['PINECONE_ENV'] ?? '';
  final int topK = 3;

  String get _openAiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  String get _pineconeKey => dotenv.env['PINECONE_API_KEY'] ?? '';

  // === (1) Embed the query text with OpenAI (same as Python's OpenAIEmbeddings) ===
  Future<List<double>> _embed(String text) async {
    final uri = Uri.parse('https://api.openai.com/v1/embeddings');
    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $_openAiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": _embeddingModel,
        "input": text,
      }),
    );
    if (res.statusCode ~/ 100 != 2) {
      throw Exception('OpenAI embeddings error: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final List emb = data['data'][0]['embedding'];
    return emb.map<double>((e) => (e as num).toDouble()).toList();
  }

  // === (2) Query Pinecone with the vector (same as Python index.query) ===
  Future<Map<String, dynamic>> _pineconeQuery(List<double> vector) async {
    final uri = Uri.parse('$_pineconeIndexEndpoint/query');
    final res = await http.post(
      uri,
      headers: {
        'Api-Key': _pineconeKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "vector": vector,
        "topK": topK,
        "includeMetadata": true,
      }),
    );
    if (res.statusCode ~/ 100 != 2) {
      throw Exception('Pinecone error: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // === (3) Build a prompt from retrieved chunks (equivalent to chain_type="stuff") ===
  String _buildPrompt(String question, List<Map<String, dynamic>> matches) {
    final buf = StringBuffer();
    buf.writeln("あなたは史料に忠実な観光案内ボットです。以下の内容だけを根拠に、簡潔に答えてください。");
    buf.writeln("根拠が無ければ『分かりません』と答えます。");
    buf.writeln("\n# コンテキスト");
    for (var i = 0; i < matches.length; i++) {
      final md = matches[i]['metadata'] as Map<String, dynamic>? ?? {};
      final text = (md['text'] ?? md['page_content'] ?? '').toString();
      final src  = (md['source'] ?? md['url'] ?? '').toString();
      buf.writeln('--- chunk ${i + 1} (source: $src) ---');
      buf.writeln(text);
      buf.writeln();
    }
    buf.writeln("# 質問: $question");
    buf.writeln("**最終回答**（一行で）:");
    //buf.writeln("**最終回答**（一行で。必要なら固有名詞のみ抜き出す）:");
    return buf.toString();
  }

  // === (4) Ask OpenAI Chat to synthesize the final answer (same as RetrievalQA) ===
  Future<String> _chatComplete(String prompt) async {
    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $_openAiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": "gpt-4o-mini",
        "messages": [
          {"role": "system", "content": "You are a helpful, concise RAG assistant."},
          {"role": "user", "content": prompt}
        ],
        "temperature": 0.0
      }),
    );

    if (kDebugMode) {
      print('OpenAI chat response: ${res.body}');
    }
    if (res.statusCode ~/ 100 != 2) {
      throw Exception('OpenAI chat error: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final msg = data['choices'][0]['message']['content'] as String? ?? '';
    return msg.trim();
  }

  /// === Public: Full RetrievalQA (Python's qa.run("質問")) ===
  Future<String> ask(String question) async {
    // 1) embed the question
    final v = await _embed(question);

    // 2) vector search
    final pc = await _pineconeQuery(v);
    final matches = (pc['matches'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

    // (Optional) log top-k like your Python print
    for (var i = 0; i < matches.length; i++) {
      final m = matches[i];
      final score = m['score'];
      final md = (m['metadata'] as Map<String, dynamic>? ?? {});
      final text = (md['text'] ?? md['page_content'] ?? '').toString();
      // ignore: avoid_print
      print('Match ${i + 1}: score=$score  text="${text.replaceAll("\n", " ").substring(0, text.length > 100 ? 100 : text.length)}"');
    }

    // 3) synthesize final answer
    final prompt = _buildPrompt(question, matches);
    final answer = await _chatComplete(prompt);
    print('Final answer: $answer');
    return answer;
  }

  /// === Public: Only Pinecone similarity search (like your embed_query + index.query) ===
  Future<List<Map<String, dynamic>>> searchOnly(String question) async {
    final v = await _embed(question);
    final pc = await _pineconeQuery(v);
    final matches = (pc['matches'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    return matches;
  }
}