import 'package:audioplayers/audioplayers.dart';

/// Service for playing morse code audio (dit/dah tones)
class AudioService {
  final AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;

  // Frequency for the morse code tone (typical CW tone is 600-800 Hz)
  static const double toneFrequency = 700.0;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _player.setVolume(0.7);
    await _player.setReleaseMode(ReleaseMode.stop);
    
    _isInitialized = true;
  }

  /// Play a tone for the specified duration (in milliseconds)
  Future<void> playTone(int durationMs) async {
    if (!_isInitialized) await initialize();

    // For now, we'll use a placeholder approach
    // In production, generate a sine wave tone or use pre-recorded audio
    // The audioplayers package can play from bytes or assets
    
    // This is a simplified implementation - in the real app,
    // we would generate audio data programmatically
    await _startTone();
    await Future.delayed(Duration(milliseconds: durationMs));
    await _stopTone();
  }

  Future<void> _startTone() async {
    // In a full implementation, this would start a continuous tone
    // For now, we'll just log - actual audio implementation requires
    // either pre-recorded assets or audio synthesis
  }

  Future<void> _stopTone() async {
    await _player.stop();
  }

  /// Play a complete morse pattern
  Future<void> playPattern(
    String pattern,
    int dotDuration,
    int dashDuration,
    int symbolGap,
  ) async {
    for (int i = 0; i < pattern.length; i++) {
      if (pattern[i] == '.') {
        await playTone(dotDuration);
      } else if (pattern[i] == '-') {
        await playTone(dashDuration);
      }

      // Add gap between symbols (but not after last)
      if (i < pattern.length - 1) {
        await Future.delayed(Duration(milliseconds: symbolGap));
      }
    }
  }

  /// Play a string of morse code with proper timing
  Future<void> playMorseString(
    String morse, {
    required int dotDuration,
    required int dashDuration,
    required int symbolGap,
    required int letterGap,
    required int wordGap,
  }) async {
    final parts = morse.split(' ');

    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];

      if (part == '/') {
        // Word separator
        await Future.delayed(Duration(milliseconds: wordGap - letterGap));
      } else {
        // Play the pattern
        await playPattern(part, dotDuration, dashDuration, symbolGap);

        // Add letter gap (but not after last)
        if (i < parts.length - 1 && parts[i + 1] != '/') {
          await Future.delayed(Duration(milliseconds: letterGap));
        }
      }
    }
  }

  /// Set the volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  void dispose() {
    _player.dispose();
  }
}

/// Audio generator for creating morse code tones programmatically
/// This would be used in a full implementation to generate sine wave tones
class ToneGenerator {
  static const int sampleRate = 44100;

  /// Generate PCM audio data for a sine wave tone
  static List<int> generateTone(double frequency, int durationMs) {
    final numSamples = (sampleRate * durationMs / 1000).round();
    final List<int> samples = [];

    for (int i = 0; i < numSamples; i++) {
      // Generate sine wave sample
      final t = i / sampleRate;
      final sample = (32767 * _sin(2 * 3.14159 * frequency * t)).round();
      
      // Apply envelope to avoid clicks (fade in/out)
      final envelope = _getEnvelope(i, numSamples);
      samples.add((sample * envelope).round());
    }

    return samples;
  }

  static double _sin(double x) {
    // Simple sine approximation
    x = x % (2 * 3.14159);
    if (x > 3.14159) x -= 2 * 3.14159;
    
    // Taylor series approximation
    double result = x;
    double term = x;
    for (int i = 1; i <= 5; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  static double _getEnvelope(int sample, int totalSamples) {
    const fadeTime = 0.005; // 5ms fade
    final fadeSamples = (sampleRate * fadeTime).round();

    if (sample < fadeSamples) {
      // Fade in
      return sample / fadeSamples;
    } else if (sample > totalSamples - fadeSamples) {
      // Fade out
      return (totalSamples - sample) / fadeSamples;
    }
    return 1.0;
  }
}
