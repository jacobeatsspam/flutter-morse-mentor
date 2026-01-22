import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../core/constants/morse_code.dart';

/// Result of morse code audio decoding
class MorseDecodeResult {
  final String morsePattern;
  final String decodedText;
  final int estimatedWpm;
  final double confidence;

  MorseDecodeResult({
    required this.morsePattern,
    required this.decodedText,
    required this.estimatedWpm,
    required this.confidence,
  });
}

/// Service for decoding morse code from audio files
class MorseAudioDecoder {
  /// Threshold for detecting tone vs silence (0.0 - 1.0)
  final double signalThreshold;

  /// Minimum duration to consider a valid signal (ms)
  final int minSignalDuration;

  MorseAudioDecoder({
    this.signalThreshold = 0.15,
    this.minSignalDuration = 20,
  });

  /// Decode morse code from a WAV file
  Future<MorseDecodeResult> decodeWavFile(File file) async {
    final bytes = await file.readAsBytes();
    return decodeWavBytes(bytes);
  }

  /// Decode morse code from WAV bytes
  MorseDecodeResult decodeWavBytes(Uint8List bytes) {
    // Parse WAV header
    final wavInfo = _parseWavHeader(bytes);
    if (wavInfo == null) {
      return MorseDecodeResult(
        morsePattern: '',
        decodedText: '[Error: Invalid WAV file]',
        estimatedWpm: 0,
        confidence: 0,
      );
    }

    // Extract audio samples
    final samples = _extractSamples(bytes, wavInfo);
    
    // Detect signal envelope
    final envelope = _computeEnvelope(samples, wavInfo.sampleRate);
    
    // Find signal segments (on/off periods)
    final segments = _findSignalSegments(envelope, wavInfo.sampleRate);
    
    if (segments.isEmpty) {
      return MorseDecodeResult(
        morsePattern: '',
        decodedText: '[No morse code detected]',
        estimatedWpm: 0,
        confidence: 0,
      );
    }
    
    // Estimate timing (WPM) from the shortest signal
    final estimatedDotDuration = _estimateDotDuration(segments);
    final estimatedWpm = (1200 / estimatedDotDuration).round().clamp(5, 50);
    
    // Convert segments to morse pattern
    final morsePattern = _segmentsToMorse(segments, estimatedDotDuration);
    
    // Decode morse to text
    final decodedText = MorseCode.morseToText(morsePattern);
    
    // Calculate confidence based on timing consistency
    final confidence = _calculateConfidence(segments, estimatedDotDuration);
    
    return MorseDecodeResult(
      morsePattern: morsePattern,
      decodedText: decodedText,
      estimatedWpm: estimatedWpm,
      confidence: confidence,
    );
  }

  /// Parse WAV file header
  _WavInfo? _parseWavHeader(Uint8List bytes) {
    if (bytes.length < 44) return null;
    
    // Check RIFF header
    if (bytes[0] != 0x52 || bytes[1] != 0x49 || 
        bytes[2] != 0x46 || bytes[3] != 0x46) {
      return null;
    }
    
    // Check WAVE format
    if (bytes[8] != 0x57 || bytes[9] != 0x41 || 
        bytes[10] != 0x56 || bytes[11] != 0x45) {
      return null;
    }
    
    final buffer = ByteData.sublistView(bytes);
    
    // Find fmt chunk
    int offset = 12;
    while (offset < bytes.length - 8) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = buffer.getUint32(offset + 4, Endian.little);
      
      if (chunkId == 'fmt ') {
        final audioFormat = buffer.getUint16(offset + 8, Endian.little);
        final numChannels = buffer.getUint16(offset + 10, Endian.little);
        final sampleRate = buffer.getUint32(offset + 12, Endian.little);
        final bitsPerSample = buffer.getUint16(offset + 22, Endian.little);
        
        // Find data chunk
        int dataOffset = offset + 8 + chunkSize;
        while (dataOffset < bytes.length - 8) {
          final dataChunkId = String.fromCharCodes(bytes.sublist(dataOffset, dataOffset + 4));
          final dataSize = buffer.getUint32(dataOffset + 4, Endian.little);
          
          if (dataChunkId == 'data') {
            return _WavInfo(
              audioFormat: audioFormat,
              numChannels: numChannels,
              sampleRate: sampleRate,
              bitsPerSample: bitsPerSample,
              dataOffset: dataOffset + 8,
              dataSize: dataSize,
            );
          }
          dataOffset += 8 + dataSize;
        }
      }
      offset += 8 + chunkSize;
    }
    
    return null;
  }

  /// Extract audio samples from WAV data
  List<double> _extractSamples(Uint8List bytes, _WavInfo info) {
    final buffer = ByteData.sublistView(bytes);
    final samples = <double>[];
    
    final bytesPerSample = info.bitsPerSample ~/ 8;
    final numSamples = info.dataSize ~/ (bytesPerSample * info.numChannels);
    
    for (int i = 0; i < numSamples; i++) {
      final offset = info.dataOffset + (i * bytesPerSample * info.numChannels);
      
      if (offset + bytesPerSample > bytes.length) break;
      
      double sample;
      if (info.bitsPerSample == 16) {
        sample = buffer.getInt16(offset, Endian.little) / 32768.0;
      } else if (info.bitsPerSample == 8) {
        sample = (bytes[offset] - 128) / 128.0;
      } else {
        sample = 0;
      }
      
      samples.add(sample);
    }
    
    return samples;
  }

  /// Compute signal envelope using RMS over windows
  List<double> _computeEnvelope(List<double> samples, int sampleRate) {
    // Window size: 10ms
    final windowSize = (sampleRate * 0.01).round();
    final hopSize = windowSize ~/ 2;
    final envelope = <double>[];
    
    for (int i = 0; i < samples.length - windowSize; i += hopSize) {
      double rms = 0;
      for (int j = 0; j < windowSize; j++) {
        rms += samples[i + j] * samples[i + j];
      }
      rms = sqrt(rms / windowSize);
      envelope.add(rms);
    }
    
    // Normalize envelope
    if (envelope.isEmpty) return [];
    final maxVal = envelope.reduce(max);
    if (maxVal > 0) {
      for (int i = 0; i < envelope.length; i++) {
        envelope[i] /= maxVal;
      }
    }
    
    return envelope;
  }

  /// Find signal on/off segments
  List<_SignalSegment> _findSignalSegments(List<double> envelope, int sampleRate) {
    final segments = <_SignalSegment>[];
    const windowMs = 10.0 / 2; // hop size in ms
    
    bool inSignal = false;
    int segmentStart = 0;
    
    for (int i = 0; i < envelope.length; i++) {
      final isOn = envelope[i] > signalThreshold;
      
      if (isOn && !inSignal) {
        // Start of signal
        inSignal = true;
        segmentStart = i;
      } else if (!isOn && inSignal) {
        // End of signal
        inSignal = false;
        final durationMs = ((i - segmentStart) * windowMs).round();
        
        if (durationMs >= minSignalDuration) {
          segments.add(_SignalSegment(
            isSignal: true,
            startIndex: segmentStart,
            endIndex: i,
            durationMs: durationMs,
          ));
        }
      }
    }
    
    // Add final segment if still in signal
    if (inSignal) {
      final durationMs = ((envelope.length - segmentStart) * windowMs).round();
      if (durationMs >= minSignalDuration) {
        segments.add(_SignalSegment(
          isSignal: true,
          startIndex: segmentStart,
          endIndex: envelope.length,
          durationMs: durationMs,
        ));
      }
    }
    
    // Calculate gaps between signals
    final withGaps = <_SignalSegment>[];
    for (int i = 0; i < segments.length; i++) {
      withGaps.add(segments[i]);
      
      if (i < segments.length - 1) {
        final gapDuration = ((segments[i + 1].startIndex - segments[i].endIndex) * windowMs).round();
        withGaps.add(_SignalSegment(
          isSignal: false,
          startIndex: segments[i].endIndex,
          endIndex: segments[i + 1].startIndex,
          durationMs: gapDuration,
        ));
      }
    }
    
    return withGaps;
  }

  /// Estimate dot duration from the shortest signals
  int _estimateDotDuration(List<_SignalSegment> segments) {
    final signalDurations = segments
        .where((s) => s.isSignal)
        .map((s) => s.durationMs)
        .toList();
    
    if (signalDurations.isEmpty) return 60;
    
    signalDurations.sort();
    
    // Take the median of the shorter half (likely dots)
    final shortHalf = signalDurations.sublist(0, (signalDurations.length / 2).ceil());
    if (shortHalf.isEmpty) return signalDurations.first;
    
    return shortHalf[shortHalf.length ~/ 2];
  }

  /// Convert signal segments to morse pattern string
  String _segmentsToMorse(List<_SignalSegment> segments, int dotDuration) {
    final buffer = StringBuffer();
    final dashThreshold = dotDuration * 2;
    final letterGapThreshold = dotDuration * 2;
    final wordGapThreshold = dotDuration * 5;
    
    for (final segment in segments) {
      if (segment.isSignal) {
        // Dot or dash
        buffer.write(segment.durationMs < dashThreshold ? '.' : '-');
      } else {
        // Gap
        if (segment.durationMs >= wordGapThreshold) {
          buffer.write(' / ');
        } else if (segment.durationMs >= letterGapThreshold) {
          buffer.write(' ');
        }
        // Symbol gaps are implicit
      }
    }
    
    return buffer.toString().trim();
  }

  /// Calculate confidence score based on timing consistency
  double _calculateConfidence(List<_SignalSegment> segments, int dotDuration) {
    if (segments.isEmpty) return 0;
    
    final signalDurations = segments.where((s) => s.isSignal).map((s) => s.durationMs).toList();
    if (signalDurations.length < 2) return 0.5;
    
    // Check how well durations cluster around dot and dash values
    final dashDuration = dotDuration * 3;
    double totalError = 0;
    
    for (final duration in signalDurations) {
      final dotError = (duration - dotDuration).abs() / dotDuration;
      final dashError = (duration - dashDuration).abs() / dashDuration;
      totalError += min(dotError, dashError);
    }
    
    final avgError = totalError / signalDurations.length;
    final confidence = (1 - avgError).clamp(0.0, 1.0);
    
    return confidence;
  }
}

class _WavInfo {
  final int audioFormat;
  final int numChannels;
  final int sampleRate;
  final int bitsPerSample;
  final int dataOffset;
  final int dataSize;

  _WavInfo({
    required this.audioFormat,
    required this.numChannels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.dataOffset,
    required this.dataSize,
  });
}

class _SignalSegment {
  final bool isSignal;
  final int startIndex;
  final int endIndex;
  final int durationMs;

  _SignalSegment({
    required this.isSignal,
    required this.startIndex,
    required this.endIndex,
    required this.durationMs,
  });
}
