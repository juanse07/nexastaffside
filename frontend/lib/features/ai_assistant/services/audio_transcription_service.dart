import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../auth_service.dart';
import '../config/app_config.dart';

/// Service for handling audio recording and transcription
/// Adapted for staff app - uses staff AI endpoints
class AudioTranscriptionService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _currentRecordingPath;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Request microphone permission
  /// Returns true if permission is granted, false otherwise
  Future<bool> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();

      if (status.isGranted) {
        print('[AudioTranscriptionService] Microphone permission granted');
        return true;
      } else if (status.isDenied) {
        print('[AudioTranscriptionService] Microphone permission denied');
        return false;
      } else if (status.isPermanentlyDenied) {
        print('[AudioTranscriptionService] Microphone permission permanently denied');
        // User needs to go to settings
        await openAppSettings();
        return false;
      }

      return false;
    } catch (e) {
      print('[AudioTranscriptionService] Error requesting microphone permission: $e');
      return false;
    }
  }

  /// Start recording audio
  /// Returns true if recording started successfully, false otherwise
  Future<bool> startRecording() async {
    try {
      // Check and request microphone permission first
      final hasPermission = await requestMicrophonePermission();
      if (!hasPermission) {
        print('[AudioTranscriptionService] Cannot record without microphone permission');
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/voice_input_$timestamp.m4a';

      print('[AudioTranscriptionService] Attempting to start recording...');

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc, // AAC format for best compatibility
          bitRate: 128000, // 128 kbps
          sampleRate: 44100, // 44.1 kHz
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      print('[AudioTranscriptionService] Recording started: $_currentRecordingPath');
      return true;
    } catch (e) {
      print('[AudioTranscriptionService] Failed to start recording: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Stop recording and return the path to the recorded file
  /// Returns null if recording failed or wasn't started
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) {
        print('[AudioTranscriptionService] Not currently recording');
        return null;
      }

      final path = await _audioRecorder.stop();
      _isRecording = false;

      if (path == null || path.isEmpty) {
        print('[AudioTranscriptionService] Recording path is empty');
        return null;
      }

      print('[AudioTranscriptionService] Recording stopped: $path');
      return path;
    } catch (e) {
      print('[AudioTranscriptionService] Failed to stop recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel the current recording and delete the file
  Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _audioRecorder.stop();
        _isRecording = false;
      }

      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
          print('[AudioTranscriptionService] Recording deleted: $_currentRecordingPath');
        }
        _currentRecordingPath = null;
      }
    } catch (e) {
      print('[AudioTranscriptionService] Failed to cancel recording: $e');
    }
  }

  /// Transcribe audio file to text using OpenAI Whisper API via backend
  /// Uses staff AI endpoint: /api/ai/staff/transcribe
  ///
  /// [audioFilePath] Path to the audio file to transcribe
  /// [terminology] Optional terminology preference (jobs, shifts, events) for better transcription context
  Future<String?> transcribeAudio(String audioFilePath, {String? terminology}) async {
    try {
      final token = await AuthService.getJwt();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final baseUrl = AIAssistantConfig.baseUrl;
      final endpoint = '/api/ai/staff/transcribe';
      final fullUrl = '$baseUrl$endpoint';
      final uri = Uri.parse(fullUrl);

      print('[AudioTranscriptionService] Transcribing audio: $audioFilePath');
      print('[AudioTranscriptionService] Using endpoint: $fullUrl');
      if (terminology != null) {
        print('[AudioTranscriptionService] Using terminology: $terminology');
      }

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Add terminology if provided
      if (terminology != null) {
        request.fields['terminology'] = terminology.toLowerCase();
      }

      final file = File(audioFilePath);
      if (!await file.exists()) {
        throw Exception('Audio file not found: $audioFilePath');
      }

      final fileSize = await file.length();
      print('[AudioTranscriptionService] File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          audioFilePath,
          filename: 'voice_input.m4a',
        ),
      );

      // Note: Whisper API automatically detects language (supports 98+ languages)
      // By not specifying 'language' parameter, it will auto-detect Spanish, English, etc.
      // This allows staff to speak naturally in their preferred language

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['text'] as String?;

        if (text != null && text.isNotEmpty) {
          print('[AudioTranscriptionService] Transcription successful: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');

          // Clean up the audio file after successful transcription
          try {
            await file.delete();
            print('[AudioTranscriptionService] Audio file deleted after transcription');
          } catch (e) {
            print('[AudioTranscriptionService] Failed to delete audio file: $e');
          }

          return text;
        } else {
          print('[AudioTranscriptionService] Empty transcription result');
          return null;
        }
      } else {
        print('[AudioTranscriptionService] Transcription failed: ${response.statusCode}');
        print('[AudioTranscriptionService] Response: ${response.body}');

        try {
          final errorData = jsonDecode(response.body);
          final message = errorData['message'] ?? 'Transcription failed';
          throw Exception(message);
        } catch (e) {
          throw Exception('Transcription failed with status ${response.statusCode}');
        }
      }
    } catch (e) {
      print('[AudioTranscriptionService] Error transcribing audio: $e');
      return null;
    }
  }

  /// Dispose of the audio recorder
  Future<void> dispose() async {
    try {
      if (_isRecording) {
        await cancelRecording();
      }
      await _audioRecorder.dispose();
    } catch (e) {
      print('[AudioTranscriptionService] Error disposing audio recorder: $e');
    }
  }
}
