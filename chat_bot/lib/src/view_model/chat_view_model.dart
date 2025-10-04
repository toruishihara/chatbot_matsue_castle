import 'dart:convert';
import 'dart:io';

import 'package:matsue_castle_chat_bot/src/audio/record_until_silence.dart';
import 'package:matsue_castle_chat_bot/src/network/app_logger.dart';
import 'package:matsue_castle_chat_bot/src/repository/chat_repository.dart';
import 'package:matsue_castle_chat_bot/src/repository/rag_repository.dart';
import 'package:matsue_castle_chat_bot/src/repository/transcription_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../model/chat_message.dart';
import '../network/open_ai_client.dart';

class ChatViewModel extends ChangeNotifier {
  final OpenAiClient _client;
  late final chatRepo = ChatRepository(_client);
  late final transRepo = TranscriptionRepository(_client);
  final RagRepository _repository;
  RecordUntilSilence? _recorder;
  bool _isRecording = false;
  File? lastFile;

  bool get isRecording => _isRecording;

  bool _loading = false;
  bool get loading => _loading;

  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  ChatViewModel(this._client, this._repository);

  Future<String?> sendMessage(String text) async {
    _loading = true;
    notifyListeners();

    try {
      if (kDebugMode) {
        print("added message0: $text");
      }
      _messages.add(ChatMessage(role: ChatRole.user, text: text));
      notifyListeners();
      final json = await chatRepo.sendMessage(text);
      final content = json['choices'][0]['message']['content'] as String;
      final inner = jsonDecode(content) as Map<String, dynamic>;
      final reply = inner['message'] as String;
      if (kDebugMode) {
        print("added message0: $reply");
      }
      _messages.add(ChatMessage(role: ChatRole.openai, text: reply));
      notifyListeners();
      _loading = false;
      notifyListeners();
      return reply;
    } catch (e) {
      _messages.add(ChatMessage(role: ChatRole.openai, text: e.toString()));
      _loading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> handleMicButton() async {
    try {
      await startRecording();
    } catch (e, st) {
      if (kDebugMode) {
        print("Error starting recording: $e");
        print(st);
      }
    }
  }

  Future<void> startRecording() async {
    if (kDebugMode) {
      print("startRecording");
    }
    _recorder = RecordUntilSilence(
      silenceThresholdDb: -10,
      silenceDurationMs: 1000,
      onSentenceEnd: (file) async {
        lastFile = file;
        _isRecording = false;
        notifyListeners();
        if (kDebugMode) {
          print("Sentence ended, saved to: ${file.path}");
        } // twice
        // 👉 here you can upload to Whisper or process text
        final text = await runTranscription(file.path);
        AppLogger.logDebugEvent("question: $text");
        if (text != null && text.isNotEmpty) {
          _messages.add(ChatMessage(role: ChatRole.user, text: text));
          notifyListeners();
          final reply = await _repository.ask(text);
          if (reply.isNotEmpty) {
            if (kDebugMode) {
              print("startRecording added message: $reply");
            }
            _messages.add(ChatMessage(role: ChatRole.openai, text: reply));
            notifyListeners();
            final tts = FlutterTts();
            await tts.setLanguage('en-US');
            await tts.setSpeechRate(0.5);
            await tts.speak(reply);
          }
        } else {
          if (kDebugMode) {
            print("Transcription returned empty text");
          }
        }
      },
    );

    final tmpFile = await createTempFile();
    if (tmpFile == null) {
      throw Exception("Temporary file could not be created.");
    }
    final path = tmpFile.path;

    final file = await _recorder!.start(path);
    lastFile = file;
    _isRecording = true;
    notifyListeners();
  }

  void stopRecording() async {
    if (_recorder != null && _isRecording) {
      await _recorder!.stop(lastFile!);
      _isRecording = false;
      notifyListeners();
    }
  }

  Future<File?> recordToWav() async {
    final record = AudioRecorder();

    if (!await record.hasPermission()) {
      final ok = await record.hasPermission();
      if (kDebugMode) {
        print('Microphone permission: $ok');
      }
      if (!ok) return null;
    }

    final tmpFile = await createTempFile();
    if (tmpFile == null) return null;
    final path = tmpFile.path;

    // 16kHz/PCM WAV（Whisper向けによく使われる設定）
    const config = RecordConfig(
      encoder: AudioEncoder.wav, // WAV で保存
      sampleRate: 16000, // 16kHz
      numChannels: 1, // モノラル
      // bitRate は WAV(PCM)では指定不要（無圧縮）
    );

    await record.start(config, path: path);
    await Future.delayed(const Duration(seconds: 5));
    final outPath = await record.stop(); // 録音停止

    if (outPath == null) return null;
    return File(outPath);
  }

  Future<String?> runTranscription(String path) async {
    if (kDebugMode) {
      print("runTranscription with path: $path");
    }
    return await transRepo.transcribe(path);
  }

  Future<File?> createTempFile() async {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory();
    } else {
      dir = await getTemporaryDirectory();
    }
    if (dir == null) return null;
    final path = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';
    final file = File(path);
    return file;
  }
}