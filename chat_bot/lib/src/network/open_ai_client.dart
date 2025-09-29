class OpenAiClient {
  final String base = 'api.openai.com';
  static const String apiKey = String.fromEnvironment('OPENAI_API_KEY'); // set via --dart-define

  final String systemPrompt = '''
''';

}
