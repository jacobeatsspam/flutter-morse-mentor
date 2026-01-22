import 'dart:async';
import 'dart:io';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Mobile implementation - receives shared files
void initSharingIntent({
  required Function(String filePath) onFileReceived,
  required Function(StreamSubscription?) onSubscription,
}) {
  // Handle shared files when app is opened from share intent
  ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> files) {
    _handleSharedFiles(files, onFileReceived);
  });

  // Handle shared files while app is running
  final subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
    (List<SharedMediaFile> files) {
      _handleSharedFiles(files, onFileReceived);
    },
    onError: (err) {
      print('Error receiving shared files: $err');
    },
  );
  
  onSubscription(subscription);
}

void _handleSharedFiles(List<SharedMediaFile> files, Function(String) onFileReceived) {
  for (final file in files) {
    final path = file.path;
    if (path.toLowerCase().endsWith('.wav') ||
        path.toLowerCase().endsWith('.mp3') ||
        path.toLowerCase().endsWith('.m4a') ||
        path.toLowerCase().endsWith('.aac')) {
      
      final audioFile = File(path);
      if (audioFile.existsSync()) {
        onFileReceived(path);
        break;
      }
    }
  }
}
