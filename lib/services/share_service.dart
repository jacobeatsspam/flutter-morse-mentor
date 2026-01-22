import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import 'morse_audio_generator.dart';

// Conditional imports for web vs mobile
import 'share_service_stub.dart'
    if (dart.library.html) 'share_service_web.dart'
    if (dart.library.io) 'share_service_mobile.dart' as platform;

/// Result of audio generation
class AudioGenerationResult {
  final Uint8List wavData;
  final String filename;
  
  AudioGenerationResult({
    required this.wavData,
    required this.filename,
  });
}

/// Service for sharing morse code audio files
class ShareService {
  final MorseAudioGenerator _audioGenerator;

  ShareService({
    int toneFrequency = 700,
    int wordsPerMinute = 20,
    int? characterWpm,
  }) : _audioGenerator = MorseAudioGenerator(
          toneFrequency: toneFrequency,
          wordsPerMinute: wordsPerMinute,
          characterWpm: characterWpm,
        );

  /// Generate WAV audio bytes from morse pattern or timings
  Future<AudioGenerationResult> generateAudio({
    required String morsePattern,
    List<int>? pressDurations,
    List<int>? gapDurations,
  }) async {
    Uint8List wavData;
    
    if (pressDurations != null && 
        gapDurations != null && 
        pressDurations.isNotEmpty) {
      wavData = _audioGenerator.generateWavFromTimingsSync(
        pressDurations,
        gapDurations,
      );
    } else {
      wavData = _audioGenerator.generateWavFromMorseSync(morsePattern);
    }
    
    final filename = 'morse_${DateTime.now().millisecondsSinceEpoch}.wav';
    
    return AudioGenerationResult(
      wavData: wavData,
      filename: filename,
    );
  }

  /// Share morse code audio generated from a morse pattern
  /// Returns true if sharing was initiated successfully
  Future<bool> shareMorseAudio({
    required String morsePattern,
    required String decodedText,
    List<int>? pressDurations,
    List<int>? gapDurations,
  }) async {
    try {
      final result = await generateAudio(
        morsePattern: morsePattern,
        pressDurations: pressDurations,
        gapDurations: gapDurations,
      );
      
      final shareText = _createShareText(morsePattern, decodedText);
      
      // Use platform-specific sharing
      return await platform.shareAudioFile(
        wavData: result.wavData,
        filename: result.filename,
        text: shareText,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error sharing morse audio: $e');
      }
      return false;
    }
  }

  /// Share morse code as text only (without audio)
  Future<bool> shareMorseText({
    required String morsePattern,
    required String decodedText,
  }) async {
    try {
      final shareText = _createShareText(morsePattern, decodedText);
      
      await Share.share(
        shareText,
        subject: 'Morse Code Message',
      );

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error sharing morse text: $e');
      }
      return false;
    }
  }

  /// Create formatted share text
  String _createShareText(String morsePattern, String decodedText) {
    final buffer = StringBuffer();
    
    buffer.writeln('📻 Morse Code Message');
    buffer.writeln();
    
    if (decodedText.isNotEmpty) {
      buffer.writeln('Message: $decodedText');
      buffer.writeln();
    }
    
    buffer.writeln('Morse: $morsePattern');
    buffer.writeln();
    buffer.writeln('Sent via Morse Mentor');
    
    return buffer.toString();
  }
}
