import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:record/record.dart';

class RecordUntilSilence {
  final AudioRecorder _recorder = AudioRecorder();
  IOSink? _fileSink;
  StreamSubscription<Uint8List>? _subscription;
  bool _isRecording = false;
  int _dataLength = 0;
  int _durationMs = 0;
  int _silenceMs = 0;

  /// Parameters
  final int sampleRate;
  final int numChannels;
  final int silenceThresholdDb;
  final int silenceDurationMs;

  /// Callback when recording auto-stops
  final void Function(File wavFile)? onSentenceEnd;

  RecordUntilSilence({
    this.sampleRate = 16000,
    this.numChannels = 1,
    this.silenceThresholdDb = -10,
    this.silenceDurationMs = 2000,
    this.onSentenceEnd,
  });

  void dumpFirst32(Uint8List buffer) {
    final length = buffer.length < 32 ? buffer.length : 32;
    final bytes = buffer.take(length).toList();
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    print('First $length bytes: $hex');
  }

  Future<File> start(String path) async {
    if (_isRecording) {
      throw Exception("Already recording");
    }
    if (!await _recorder.hasPermission()) {
      final ok = await _recorder.hasPermission();
      print('Microphone permission: $ok');
      if (!ok) {
        throw Exception("Microphone permission denied");
      }
    }
    final file = File(path);
    _fileSink = file.openWrite();

    _fileSink!.add(_makeWavHeaderPlaceholder());
    _dataLength = 0;
    _silenceMs = 0;

    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: numChannels,
      ),
    );

    print("RecordUntilSilence.start path=$path");
    _subscription = stream.listen((buffer) async {
      _fileSink?.add(buffer);
      print("Writing to $_fileSink");
      _dataLength += buffer.length;
      _durationMs += _chunkDurationMs(buffer);
      dumpFirst32(buffer);

      if (_durationMs > 5000) {
        print("Max duration reached, stopping");
        await stop(file);
        onSentenceEnd?.call(file); // notify caller
        return;
      }

      if (_isSilent(buffer)) {
        print(
            "_isSilent = true _silenceMs=$_silenceMs silenceDurationMs=$silenceDurationMs");
        _silenceMs += _chunkDurationMs(buffer);
        if (_silenceMs > silenceDurationMs) {
          print("Calling stop()");
          await stop(file); // auto stop
          print("calling onSentenceEnd");
          onSentenceEnd?.call(file); // notify caller
        }
      } else {
        _silenceMs = 0;
      }
    });
    _isRecording = true;
    return file;
  }

  Future<void> stop(File file) async {
    print("stop called");
    if (!_isRecording) return;
    await _recorder.stop();
    await _subscription?.cancel();
    await _fileSink?.flush();
    await _fileSink?.close();

    _patchWavHeader(file, _dataLength, sampleRate, numChannels);
    _isRecording = false;
  }

  Uint8List _makeWavHeaderPlaceholder() {
    return Uint8List(44);
  }

  static const double _ln10 = 2.302585092994046;

  bool _isSilent(Uint8List buffer) {
    final s = buffer.buffer.asInt16List();
    if (s.isEmpty) return true;

    // 1) Mean-center to remove DC bias
    double mean = 0;
    for (var i = 0; i < s.length; i++) {
      mean += s[i];
    }
    mean /= s.length;

    // 2) RMS of zero-mean signal
    double sumSq = 0;
    for (var i = 0; i < s.length; i++) {
      final v = s[i] - mean;
      sumSq += v * v;
    }
    final rms = sqrt(sumSq / s.length);

    // 3) Convert to dBFS using log10, clamp with epsilon
    const double ref = 32768.0; // 16-bit full-scale peak
    const double eps = 1e-12; // avoid log(0)
    final double ratio = (rms / ref).clamp(0.0, 1.0);
    final double db = 20.0 * (log(max(ratio, eps)) / _ln10);

    // Optional: print to tune threshold
    print(
        'dBFS: ${db.toStringAsFixed(1)} silenceThresholdDb:$silenceThresholdDb');

    return db < silenceThresholdDb; // e.g. -40 dB
  }

  bool _isSilentOld(Uint8List buffer) {
    // Convert byte buffer → Int16 samples (PCM16 = 2 bytes per sample)
    final samples = buffer.buffer.asInt16List();

    if (samples.isEmpty) return true;

    // Root Mean Square (RMS)
    double sumSquares = 0;
    for (var s in samples) {
      sumSquares += (s * s);
    }
    final rms = sqrt(sumSquares / samples.length);

    // Convert to decibels relative to full scale (dBFS)
    // 32768 is max amplitude of signed 16-bit PCM
    double db = 20 * log(rms / 32768.0);
    print("db: $db silenceThresholdDb:$silenceThresholdDb");

    // Compare to threshold (e.g. -40 dB)
    return db < silenceThresholdDb;
  }

  void _patchWavHeader(
      File file, int dataLength, int sampleRate, int channels) {
    final byteRate = sampleRate * channels * 2; // 16-bit = 2 bytes per sample
    final blockAlign = channels * 2;
    final fileSize = 36 + dataLength; // 36 + SubChunk2Size

    final header = BytesBuilder();

    // RIFF header
    header.add(ascii.encode('RIFF'));
    header.add(_intToBytes(fileSize, 4));
    header.add(ascii.encode('WAVE'));

    // fmt subchunk
    header.add(ascii.encode('fmt '));
    header.add(_intToBytes(16, 4)); // Subchunk1Size (16 for PCM)
    header.add(_intToBytes(1, 2)); // AudioFormat (1 = PCM)
    header.add(_intToBytes(channels, 2));
    header.add(_intToBytes(sampleRate, 4));
    header.add(_intToBytes(byteRate, 4));
    header.add(_intToBytes(blockAlign, 2));
    header.add(_intToBytes(16, 2)); // BitsPerSample

    // data subchunk
    header.add(ascii.encode('data'));
    header.add(_intToBytes(dataLength, 4));

    // Overwrite first 44 bytes WITHOUT truncating the file
    final raf = file.openSync(mode: FileMode.writeOnlyAppend); 
    try {
      raf.setPositionSync(0);
      final bytes = header.toBytes();
      if (bytes.length != 44) {
        throw StateError('WAV header must be 44 bytes, got ${bytes.length}.');
      }
      raf.writeFromSync(bytes);
      raf.flushSync();
    } finally {
      raf.closeSync();
    }
  }

  /// helper: convert int to little-endian byte array
  Uint8List _intToBytes(int value, int length) {
    final bd = ByteData(length);
    if (length == 2) {
      bd.setInt16(0, value, Endian.little);
    } else if (length == 4) {
      bd.setInt32(0, value, Endian.little);
    }
    return bd.buffer.asUint8List();
  }

  int _chunkDurationMs(Uint8List buffer) {
    final bytesPerSample = 2 * numChannels; // 16-bit PCM = 2 bytes
    final sampleCount = buffer.length ~/ bytesPerSample;
    final seconds = sampleCount / sampleRate;
    return (seconds * 1000).round();
  }
}
