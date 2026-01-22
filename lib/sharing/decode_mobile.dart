import 'dart:io';

import '../services/morse_audio_decoder.dart';

class DecodeResult {
  final String morsePattern;
  final String decodedText;
  
  DecodeResult({required this.morsePattern, required this.decodedText});
}

Future<DecodeResult> decodeAudioFile(String filePath) async {
  final file = File(filePath);
  final decoder = MorseAudioDecoder();
  final result = await decoder.decodeWavFile(file);
  
  return DecodeResult(
    morsePattern: result.morsePattern,
    decodedText: result.decodedText,
  );
}
