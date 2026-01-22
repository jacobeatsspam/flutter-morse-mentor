import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation - downloads the file directly
Future<bool> shareAudioFile({
  required Uint8List wavData,
  required String filename,
  required String text,
}) async {
  try {
    // Create a blob from the WAV data
    final blob = html.Blob([wavData], 'audio/wav');
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    // Create download link
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    
    // Clean up the blob URL
    html.Url.revokeObjectUrl(url);
    
    return true;
  } catch (e) {
    print('Web share error: $e');
    return false;
  }
}
