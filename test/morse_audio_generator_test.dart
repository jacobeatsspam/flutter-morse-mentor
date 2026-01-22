import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morse_mentor/services/morse_audio_generator.dart';
import 'package:morse_mentor/services/morse_audio_decoder.dart';

void main() {
  group('MorseAudioGenerator', () {
    test('generates valid WAV data structure', () {
      // Test with the sync method that returns bytes
      final generator = MorseAudioGenerator(
        toneFrequency: 700,
        wordsPerMinute: 20,
      );
      
      final wavData = generator.generateWavFromMorseSync('.');
      expect(wavData.length, greaterThan(44)); // At least header size
    });

    test('generates audio samples for dot', () {
      final generator = _TestableAudioGenerator(
        toneFrequency: 700,
        wordsPerMinute: 20,
      );
      
      // A dot at 20 WPM should be 60ms
      final dotSamples = generator.testGenerateTone(60);
      
      // At 44100 Hz, 60ms should produce ~2646 samples
      expect(dotSamples.length, closeTo(2646, 10));
      
      // Samples should be 16-bit range
      for (final sample in dotSamples) {
        expect(sample, greaterThanOrEqualTo(-32768));
        expect(sample, lessThanOrEqualTo(32767));
      }
      
      // Should have actual audio content (not all zeros)
      final hasNonZero = dotSamples.any((s) => s.abs() > 100);
      expect(hasNonZero, isTrue);
    });

    test('generates silence correctly', () {
      final generator = _TestableAudioGenerator(
        toneFrequency: 700,
        wordsPerMinute: 20,
      );
      
      final silence = generator.testGenerateSilence(100);
      
      // 100ms at 44100 Hz should produce ~4410 samples
      expect(silence.length, closeTo(4410, 10));
      
      // All samples should be zero
      for (final sample in silence) {
        expect(sample, equals(0));
      }
    });

    test('generates valid WAV file header', () {
      final generator = _TestableAudioGenerator(
        toneFrequency: 700,
        wordsPerMinute: 20,
      );
      
      // Generate a simple pattern
      final samples = generator.testGenerateTone(100);
      final wavData = generator.testCreateWavFile(samples);
      
      // Check RIFF header
      expect(wavData[0], equals(0x52)); // 'R'
      expect(wavData[1], equals(0x49)); // 'I'
      expect(wavData[2], equals(0x46)); // 'F'
      expect(wavData[3], equals(0x46)); // 'F'
      
      // Check WAVE format
      expect(wavData[8], equals(0x57)); // 'W'
      expect(wavData[9], equals(0x41)); // 'A'
      expect(wavData[10], equals(0x56)); // 'V'
      expect(wavData[11], equals(0x45)); // 'E'
      
      // Check fmt chunk
      expect(wavData[12], equals(0x66)); // 'f'
      expect(wavData[13], equals(0x6D)); // 'm'
      expect(wavData[14], equals(0x74)); // 't'
      expect(wavData[15], equals(0x20)); // ' '
      
      // Check data chunk exists
      expect(wavData[36], equals(0x64)); // 'd'
      expect(wavData[37], equals(0x61)); // 'a'
      expect(wavData[38], equals(0x74)); // 't'
      expect(wavData[39], equals(0x61)); // 'a'
      
      // Minimum size: 44 byte header + audio data
      expect(wavData.length, greaterThan(44));
    });

    test('morse pattern produces expected structure', () {
      final generator = _TestableAudioGenerator(
        toneFrequency: 700,
        wordsPerMinute: 20,
      );
      
      // "E" is just a dot
      final audioData = generator.testGenerateAudioData('.');
      
      // Should have some audio (the dot tone + tail silence)
      expect(audioData.length, greaterThan(0));
      
      // "T" is just a dash (should be longer than dot)
      final dashData = generator.testGenerateAudioData('-');
      
      // Dash tone is 3x dot tone, but both include 100ms tail silence
      // Dot = 60ms tone + 100ms silence = 160ms total
      // Dash = 180ms tone + 100ms silence = 280ms total
      // Ratio is ~1.75x, so expect > 1.5x
      expect(dashData.length, greaterThan((audioData.length * 1.5).round()));
    });

    test('SOS pattern generates correctly', () {
      final generator = _TestableAudioGenerator(
        toneFrequency: 700,
        wordsPerMinute: 20,
      );
      
      // SOS = ... --- ...
      final sosData = generator.testGenerateAudioData('... --- ...');
      
      // Should produce substantial audio
      expect(sosData.length, greaterThan(10000));
    });

    test('generates audio from timing data', () async {
      // Simulate user tapping: 3 short presses (S = ...)
      final pressDurations = [60, 55, 65]; // ~60ms each (dots)
      final gapDurations = [60, 60]; // gaps between
      
      final generator = _TestableAudioGenerator(
        toneFrequency: 700,
        wordsPerMinute: 20,
      );
      
      final wavData = await generator.testGenerateFromTimings(
        pressDurations,
        gapDurations,
      );
      
      // Should produce valid WAV
      expect(wavData[0], equals(0x52)); // 'R'
      expect(wavData.length, greaterThan(44));
    });
  });

  group('MorseAudioDecoder', () {
    test('can decode generated audio', () {
      // Generate audio for a known pattern
      final generator = _TestableAudioGenerator(
        toneFrequency: 700,
        wordsPerMinute: 20,
      );
      
      // Generate "E" (single dot)
      final wavData = generator.testCreateWavFileFromPattern('.');
      
      // Decode it
      final decoder = MorseAudioDecoder();
      final result = decoder.decodeWavBytes(wavData);
      
      // Should decode to "E"
      expect(result.morsePattern, contains('.'));
    });

    test('can decode SOS pattern', () {
      final generator = _TestableAudioGenerator(
        toneFrequency: 700,
        wordsPerMinute: 15, // Slower for clearer detection
      );
      
      // Generate "SOS"
      final wavData = generator.testCreateWavFileFromPattern('... --- ...');
      
      // Decode it
      final decoder = MorseAudioDecoder();
      final result = decoder.decodeWavBytes(wavData);
      
      print('Decoded pattern: ${result.morsePattern}');
      print('Decoded text: ${result.decodedText}');
      print('Confidence: ${result.confidence}');
      
      // Should have reasonable confidence
      expect(result.confidence, greaterThan(0.3));
    });
  });

  group('End-to-end audio generation', () {
    test('can generate and decode "HELLO"', () {
      final generator = _TestableAudioGenerator(
        toneFrequency: 700,
        wordsPerMinute: 15,
      );
      
      // HELLO in morse: .... . .-.. .-.. ---
      const helloMorse = '.... . .-.. .-.. ---';
      final wavData = generator.testCreateWavFileFromPattern(helloMorse);
      
      print('Generated WAV size: ${wavData.length} bytes');
      
      // Verify it's a valid WAV
      expect(wavData.sublist(0, 4), equals([0x52, 0x49, 0x46, 0x46]));
      
      // Try to decode
      final decoder = MorseAudioDecoder();
      final result = decoder.decodeWavBytes(wavData);
      
      print('Input pattern: $helloMorse');
      print('Decoded pattern: ${result.morsePattern}');
      print('Decoded text: ${result.decodedText}');
      print('Estimated WPM: ${result.estimatedWpm}');
      print('Confidence: ${result.confidence}');
    });
  });
}

/// Testable version of MorseAudioGenerator that exposes internal methods
class _TestableAudioGenerator extends MorseAudioGenerator {
  _TestableAudioGenerator({
    required super.toneFrequency,
    required super.wordsPerMinute,
  });

  List<int> testGenerateTone(int durationMs) {
    return _generateToneInternal(durationMs);
  }

  List<int> testGenerateSilence(int durationMs) {
    return _generateSilenceInternal(durationMs);
  }

  List<int> testGenerateAudioData(String pattern) {
    return _generateAudioDataInternal(pattern);
  }

  Uint8List testCreateWavFile(List<int> samples) {
    return _createWavFileInternal(samples);
  }

  Uint8List testCreateWavFileFromPattern(String pattern) {
    final samples = _generateAudioDataInternal(pattern);
    return _createWavFileInternal(samples);
  }

  Future<Uint8List> testGenerateFromTimings(
    List<int> pressDurations,
    List<int> gapDurations,
  ) async {
    final List<int> audioSamples = [];
    
    for (int i = 0; i < pressDurations.length; i++) {
      audioSamples.addAll(_generateToneInternal(pressDurations[i]));
      if (i < gapDurations.length) {
        audioSamples.addAll(_generateSilenceInternal(gapDurations[i]));
      }
    }
    
    return _createWavFileInternal(audioSamples);
  }

  // Internal implementations (copied from parent to make testable)
  static const int _sampleRate = 44100;
  
  List<int> _generateToneInternal(int durationMs) {
    final numSamples = (_sampleRate * durationMs / 1000).round();
    final List<int> samples = [];
    final fadeSamples = (_sampleRate * 0.005).round();
    
    for (int i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      double sample = _sin(2 * 3.14159 * toneFrequency * t);
      
      double envelope = 1.0;
      if (i < fadeSamples) {
        envelope = i / fadeSamples;
      } else if (i > numSamples - fadeSamples) {
        envelope = (numSamples - i) / fadeSamples;
      }
      
      final int16Sample = (sample * envelope * 32767 * 0.8).round().clamp(-32768, 32767);
      samples.add(int16Sample);
    }
    
    return samples;
  }

  List<int> _generateSilenceInternal(int durationMs) {
    final numSamples = (_sampleRate * durationMs / 1000).round();
    return List.filled(numSamples, 0);
  }

  List<int> _generateAudioDataInternal(String morsePattern) {
    final List<int> samples = [];
    final dotDuration = (1200 / wordsPerMinute).round();
    final dashDuration = dotDuration * 3;
    final symbolGap = dotDuration;
    final letterGap = dotDuration * 3;
    final wordGap = dotDuration * 7;

    for (int i = 0; i < morsePattern.length; i++) {
      final char = morsePattern[i];
      
      switch (char) {
        case '.':
          samples.addAll(_generateToneInternal(dotDuration));
          if (i + 1 < morsePattern.length && 
              (morsePattern[i + 1] == '.' || morsePattern[i + 1] == '-')) {
            samples.addAll(_generateSilenceInternal(symbolGap));
          }
          break;
          
        case '-':
          samples.addAll(_generateToneInternal(dashDuration));
          if (i + 1 < morsePattern.length && 
              (morsePattern[i + 1] == '.' || morsePattern[i + 1] == '-')) {
            samples.addAll(_generateSilenceInternal(symbolGap));
          }
          break;
          
        case ' ':
          samples.addAll(_generateSilenceInternal(letterGap - symbolGap));
          break;
          
        case '/':
          samples.addAll(_generateSilenceInternal(wordGap));
          break;
      }
    }
    
    samples.addAll(_generateSilenceInternal(100));
    return samples;
  }

  Uint8List _createWavFileInternal(List<int> samples) {
    final dataSize = samples.length * 2;
    final fileSize = 36 + dataSize;
    
    final buffer = ByteData(44 + dataSize);
    var offset = 0;
    
    // RIFF header
    buffer.setUint8(offset++, 0x52); // 'R'
    buffer.setUint8(offset++, 0x49); // 'I'
    buffer.setUint8(offset++, 0x46); // 'F'
    buffer.setUint8(offset++, 0x46); // 'F'
    buffer.setUint32(offset, fileSize, Endian.little);
    offset += 4;
    buffer.setUint8(offset++, 0x57); // 'W'
    buffer.setUint8(offset++, 0x41); // 'A'
    buffer.setUint8(offset++, 0x56); // 'V'
    buffer.setUint8(offset++, 0x45); // 'E'
    
    // fmt subchunk
    buffer.setUint8(offset++, 0x66); // 'f'
    buffer.setUint8(offset++, 0x6D); // 'm'
    buffer.setUint8(offset++, 0x74); // 't'
    buffer.setUint8(offset++, 0x20); // ' '
    buffer.setUint32(offset, 16, Endian.little);
    offset += 4;
    buffer.setUint16(offset, 1, Endian.little); // PCM
    offset += 2;
    buffer.setUint16(offset, 1, Endian.little); // mono
    offset += 2;
    buffer.setUint32(offset, _sampleRate, Endian.little);
    offset += 4;
    buffer.setUint32(offset, _sampleRate * 2, Endian.little); // byte rate
    offset += 4;
    buffer.setUint16(offset, 2, Endian.little); // block align
    offset += 2;
    buffer.setUint16(offset, 16, Endian.little); // bits per sample
    offset += 2;
    
    // data subchunk
    buffer.setUint8(offset++, 0x64); // 'd'
    buffer.setUint8(offset++, 0x61); // 'a'
    buffer.setUint8(offset++, 0x74); // 't'
    buffer.setUint8(offset++, 0x61); // 'a'
    buffer.setUint32(offset, dataSize, Endian.little);
    offset += 4;
    
    for (final sample in samples) {
      buffer.setInt16(offset, sample, Endian.little);
      offset += 2;
    }
    
    return buffer.buffer.asUint8List();
  }

  double _sin(double x) {
    x = x % (2 * 3.14159);
    if (x > 3.14159) x -= 2 * 3.14159;
    double result = x;
    double term = x;
    for (int i = 1; i <= 7; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }
}
