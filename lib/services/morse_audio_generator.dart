import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../core/constants/morse_code.dart';

/// Service for generating morse code audio files (WAV format)
class MorseAudioGenerator {
  /// Audio parameters
  static const int sampleRate = 44100;
  static const int bitsPerSample = 16;
  static const int numChannels = 1; // Mono

  /// Default tone frequency (Hz) - typical CW tone
  final int toneFrequency;

  /// Words per minute for timing (effective speed, used for gaps in Farnsworth)
  final int wordsPerMinute;

  /// Character WPM for Farnsworth timing (null = use wordsPerMinute for everything)
  /// When set, characters are sent at this speed but gaps use wordsPerMinute
  final int? characterWpm;

  MorseAudioGenerator({
    this.toneFrequency = 700,
    this.wordsPerMinute = 20,
    this.characterWpm,
  });

  /// Generate WAV bytes from a morse code pattern string (sync, no file I/O)
  /// Pattern should be dots, dashes, spaces (letter gap), and slashes (word gap)
  /// Example: ".... . .-.. .-.. --- / .-- --- .-. .-.. -.."
  Uint8List generateWavFromMorseSync(String morsePattern) {
    final audioData = _generateAudioData(morsePattern);
    return _createWavFile(audioData);
  }

  /// Generate WAV bytes from plain text (sync, no file I/O)
  Uint8List generateWavFromTextSync(String text) {
    final morsePattern = MorseCode.textToMorse(text);
    return generateWavFromMorseSync(morsePattern);
  }

  /// Generate WAV bytes from a list of recorded key press durations (sync, no file I/O)
  /// Each duration in milliseconds, with gaps between representing silence
  Uint8List generateWavFromTimingsSync(
    List<int> pressDurations,
    List<int> gapDurations,
  ) {
    final List<int> audioSamples = [];
    
    for (int i = 0; i < pressDurations.length; i++) {
      // Add tone for the press duration
      audioSamples.addAll(_generateTone(pressDurations[i]));
      
      // Add silence for the gap (if not last press)
      if (i < gapDurations.length) {
        audioSamples.addAll(_generateSilence(gapDurations[i]));
      }
    }
    
    // Add tail silence
    audioSamples.addAll(_generateSilence(100));
    
    return _createWavFile(audioSamples);
  }

  /// Generate a WAV file from a morse code pattern string
  /// Pattern should be dots, dashes, spaces (letter gap), and slashes (word gap)
  /// Example: ".... . .-.. .-.. --- / .-- --- .-. .-.. -.."
  Future<File> generateWavFromMorse(String morsePattern, {String? filename}) async {
    final wavData = generateWavFromMorseSync(morsePattern);
    
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${filename ?? 'morse_${DateTime.now().millisecondsSinceEpoch}.wav'}');
    await file.writeAsBytes(wavData);
    
    return file;
  }

  /// Generate a WAV file from plain text
  Future<File> generateWavFromText(String text, {String? filename}) async {
    final morsePattern = MorseCode.textToMorse(text);
    return generateWavFromMorse(morsePattern, filename: filename);
  }

  /// Generate a WAV file from a list of recorded key press durations
  /// Each duration in milliseconds, with gaps between representing silence
  Future<File> generateWavFromTimings(
    List<int> pressDurations,
    List<int> gapDurations, {
    String? filename,
  }) async {
    final wavData = generateWavFromTimingsSync(pressDurations, gapDurations);
    
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${filename ?? 'morse_${DateTime.now().millisecondsSinceEpoch}.wav'}');
    await file.writeAsBytes(wavData);
    
    return file;
  }

  /// Generate audio samples for a morse pattern
  /// Supports Farnsworth timing when characterWpm is set
  List<int> _generateAudioData(String morsePattern) {
    final List<int> samples = [];
    
    // For Farnsworth timing:
    // - Characters (dots, dashes, symbol gaps) use characterWpm (faster)
    // - Letter and word gaps use wordsPerMinute (slower, giving time to decode)
    final charSpeed = characterWpm ?? wordsPerMinute;
    
    // Character elements at character speed
    final dotDuration = MorseCode.getDotDuration(charSpeed);
    final dashDuration = MorseCode.getDashDuration(charSpeed);
    final symbolGap = MorseCode.getSymbolGap(charSpeed);
    
    // Gaps at effective (slower) speed for Farnsworth
    final letterGap = MorseCode.getLetterGap(wordsPerMinute);
    final wordGap = MorseCode.getWordGap(wordsPerMinute);

    for (int i = 0; i < morsePattern.length; i++) {
      final char = morsePattern[i];
      
      switch (char) {
        case '.':
          samples.addAll(_generateTone(dotDuration));
          // Add symbol gap if next char is also a symbol
          if (i + 1 < morsePattern.length && 
              (morsePattern[i + 1] == '.' || morsePattern[i + 1] == '-')) {
            samples.addAll(_generateSilence(symbolGap));
          }
          break;
          
        case '-':
          samples.addAll(_generateTone(dashDuration));
          // Add symbol gap if next char is also a symbol
          if (i + 1 < morsePattern.length && 
              (morsePattern[i + 1] == '.' || morsePattern[i + 1] == '-')) {
            samples.addAll(_generateSilence(symbolGap));
          }
          break;
          
        case ' ':
          // Space between letters (letter gap minus symbol gap already added)
          samples.addAll(_generateSilence(letterGap - symbolGap));
          break;
          
        case '/':
          // Word separator (word gap)
          samples.addAll(_generateSilence(wordGap));
          break;
      }
    }
    
    // Add a small tail of silence
    samples.addAll(_generateSilence(100));
    
    return samples;
  }

  /// Generate sine wave tone samples
  List<int> _generateTone(int durationMs) {
    final numSamples = (sampleRate * durationMs / 1000).round();
    final List<int> samples = [];
    
    // Fade in/out duration (5ms)
    final fadeSamples = (sampleRate * 0.005).round();
    
    for (int i = 0; i < numSamples; i++) {
      // Calculate sine wave
      final t = i / sampleRate;
      double sample = sin(2 * pi * toneFrequency * t);
      
      // Apply envelope to avoid clicks
      double envelope = 1.0;
      if (i < fadeSamples) {
        // Fade in
        envelope = i / fadeSamples;
      } else if (i > numSamples - fadeSamples) {
        // Fade out
        envelope = (numSamples - i) / fadeSamples;
      }
      
      // Convert to 16-bit integer
      final int16Sample = (sample * envelope * 32767 * 0.8).round().clamp(-32768, 32767);
      samples.add(int16Sample);
    }
    
    return samples;
  }

  /// Generate silence samples
  List<int> _generateSilence(int durationMs) {
    final numSamples = (sampleRate * durationMs / 1000).round();
    return List.filled(numSamples, 0);
  }

  /// Create a complete WAV file from audio samples
  Uint8List _createWavFile(List<int> samples) {
    final dataSize = samples.length * 2; // 16-bit = 2 bytes per sample
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
    buffer.setUint32(offset, 16, Endian.little); // Subchunk1Size (16 for PCM)
    offset += 4;
    buffer.setUint16(offset, 1, Endian.little); // AudioFormat (1 = PCM)
    offset += 2;
    buffer.setUint16(offset, numChannels, Endian.little);
    offset += 2;
    buffer.setUint32(offset, sampleRate, Endian.little);
    offset += 4;
    buffer.setUint32(offset, sampleRate * numChannels * bitsPerSample ~/ 8, Endian.little); // ByteRate
    offset += 4;
    buffer.setUint16(offset, numChannels * bitsPerSample ~/ 8, Endian.little); // BlockAlign
    offset += 2;
    buffer.setUint16(offset, bitsPerSample, Endian.little);
    offset += 2;
    
    // data subchunk
    buffer.setUint8(offset++, 0x64); // 'd'
    buffer.setUint8(offset++, 0x61); // 'a'
    buffer.setUint8(offset++, 0x74); // 't'
    buffer.setUint8(offset++, 0x61); // 'a'
    buffer.setUint32(offset, dataSize, Endian.little);
    offset += 4;
    
    // Audio data
    for (final sample in samples) {
      buffer.setInt16(offset, sample, Endian.little);
      offset += 2;
    }
    
    return buffer.buffer.asUint8List();
  }
}
