// Stub implementation for web - decoding from file is not supported

class DecodeResult {
  final String morsePattern;
  final String decodedText;
  
  DecodeResult({required this.morsePattern, required this.decodedText});
}

Future<DecodeResult> decodeAudioFile(String filePath) async {
  return DecodeResult(
    morsePattern: '',
    decodedText: '[Decoding not supported on web]',
  );
}
