import 'dart:async';

/// Stub implementation for web - sharing is not supported
void initSharingIntent({
  required Function(String filePath) onFileReceived,
  required Function(StreamSubscription?) onSubscription,
}) {
  // No-op on web
  onSubscription(null);
}
