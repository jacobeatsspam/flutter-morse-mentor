import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Mobile implementation - uses native share sheet
Future<bool> shareAudioFile({
  required Uint8List wavData,
  required String filename,
  required String text,
}) async {
  try {
    // Get temporary directory and save file
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(wavData);
    
    // Share via native share sheet
    await Share.shareXFiles(
      [XFile(file.path)],
      text: text,
      subject: 'Morse Code Message',
    );
    
    return true;
  } catch (e) {
    print('Mobile share error: $e');
    return false;
  }
}
