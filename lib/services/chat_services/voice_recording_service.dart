import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class VoiceRecordingService {
  static final VoiceRecordingService _instance = VoiceRecordingService._internal();
  factory VoiceRecordingService() => _instance;
  VoiceRecordingService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  String? _currentRecordingPath;

  Stream<int> get recordingDurationStream => _recordingDurationController.stream;
  final StreamController<int> _recordingDurationController = StreamController<int>.broadcast();

  bool get isRecording => _recordingTimer?.isActive ?? false;
  int get recordingDuration => _recordingDuration;

  Future<bool> checkPermissions() async {
    final permission = await Permission.microphone.request();
    return permission.isGranted;
  }

  Future<String?> startRecording() async {
    try {
      if (!await checkPermissions()) {
        throw Exception('Microphone permission not granted');
      }

      final directory = await getTemporaryDirectory();
      final fileName = 'voice_message_${DateTime.now().millisecondsSinceEpoch}.aac';
      _currentRecordingPath = '${directory.path}/$fileName';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      _recordingDuration = 0;
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _recordingDuration++;
        _recordingDurationController.add(_recordingDuration);
      });

      return _currentRecordingPath;
    } catch (e) {
      print('Error starting recording: $e');
      return null;
    }
  }

  Future<String?> stopRecording() async {
    try {
      _recordingTimer?.cancel();
      _recordingTimer = null;

      final path = await _recorder.stop();

      if (path != null && File(path).existsSync()) {
        return path;
      }

      return _currentRecordingPath;
    } catch (e) {
      print('Error stopping recording: $e');
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      _recordingTimer?.cancel();
      _recordingTimer = null;

      await _recorder.stop();

      if (_currentRecordingPath != null && File(_currentRecordingPath!).existsSync()) {
        await File(_currentRecordingPath!).delete();
      }

      _currentRecordingPath = null;
      _recordingDuration = 0;
    } catch (e) {
      print('Error cancelling recording: $e');
    }
  }

  void dispose() {
    _recordingTimer?.cancel();
    _recordingDurationController.close();
    _recorder.dispose();
  }
}