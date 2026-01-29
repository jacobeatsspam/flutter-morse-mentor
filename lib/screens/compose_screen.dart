import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/constants/morse_code.dart';
import '../services/morse_audio_generator.dart';
import '../services/morse_service.dart';
import '../services/settings_service.dart';
import '../services/share_service.dart';
import '../widgets/telegraph_key_layout.dart';

// Conditional import for file decoding (mobile only)
import '../sharing/decode_stub.dart'
    if (dart.library.io) '../sharing/decode_mobile.dart' as decoder;

/// Screen for composing and sharing morse code messages
class ComposeScreen extends StatefulWidget {
  /// If provided, decode this audio file on load (path string for cross-platform)
  final String? incomingAudioFilePath;

  const ComposeScreen({super.key, this.incomingAudioFilePath});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  // Timing data
  final List<int> _pressDurations = [];
  final List<int> _gapDurations = [];
  DateTime? _lastKeyUpTime;
  DateTime? _keyDownTime;

  // Decoded content
  final List<String> _inputSymbols = [];
  String _currentPattern = '';
  String _decodedText = '';

  // Text controller for keyboard input
  late TextEditingController _textController;
  late FocusNode _textFieldFocusNode;
  bool _isUpdatingFromTapper = false; // Prevent feedback loop
  bool _keyboardEnabled = false; // Only show keyboard after double-tap

  // UI state
  bool _isSharing = false;
  bool _isDecoding = false;
  bool _isPlaying = false;
  Timer? _decodeTimer;
  Timer? _deleteRepeatTimer;
  
  // Audio playback
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Audio feedback for telegraph key
  bool _audioEnabled = true;
  final AudioPlayer _tonePlayer = AudioPlayer();
  Uint8List? _toneBytes;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _textController.addListener(_onTextChanged);
    _textFieldFocusNode = FocusNode();
    _textFieldFocusNode.addListener(_onFocusChanged);
    _initAudio();
    if (widget.incomingAudioFilePath != null) {
      _decodeIncomingAudio();
    }
  }

  @override
  void dispose() {
    _decodeTimer?.cancel();
    _deleteRepeatTimer?.cancel();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _textFieldFocusNode.removeListener(_onFocusChanged);
    _textFieldFocusNode.dispose();
    _audioPlayer.dispose();
    _tonePlayer.dispose();
    super.dispose();
  }

  /// Initialize audio - generate a tone for playback feedback
  void _initAudio() {
    // Generate 2 seconds of tone at 700Hz (enough for any key press)
    const sampleRate = 44100;
    const frequency = 700.0;
    const durationMs = 2000;
    const numSamples = sampleRate * durationMs ~/ 1000;
    
    // Generate WAV file in memory
    final samples = <int>[];
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      // Sine wave with fade in/out
      var amplitude = sin(2 * pi * frequency * t);
      // Apply envelope for first/last 10ms to avoid clicks
      const fadeSamples = sampleRate * 10 ~/ 1000;
      if (i < fadeSamples) {
        amplitude *= i / fadeSamples;
      } else if (i > numSamples - fadeSamples) {
        amplitude *= (numSamples - i) / fadeSamples;
      }
      samples.add((amplitude * 32767 * 0.7).round().clamp(-32768, 32767));
    }
    
    _toneBytes = _createWavBytes(samples, sampleRate);
  }

  /// Create WAV file bytes from PCM samples
  Uint8List _createWavBytes(List<int> samples, int sampleRate) {
    final byteData = ByteData(44 + samples.length * 2);
    
    // RIFF header
    byteData.setUint8(0, 0x52); // 'R'
    byteData.setUint8(1, 0x49); // 'I'
    byteData.setUint8(2, 0x46); // 'F'
    byteData.setUint8(3, 0x46); // 'F'
    byteData.setUint32(4, 36 + samples.length * 2, Endian.little); // File size - 8
    byteData.setUint8(8, 0x57);  // 'W'
    byteData.setUint8(9, 0x41);  // 'A'
    byteData.setUint8(10, 0x56); // 'V'
    byteData.setUint8(11, 0x45); // 'E'
    
    // fmt chunk
    byteData.setUint8(12, 0x66); // 'f'
    byteData.setUint8(13, 0x6D); // 'm'
    byteData.setUint8(14, 0x74); // 't'
    byteData.setUint8(15, 0x20); // ' '
    byteData.setUint32(16, 16, Endian.little); // Chunk size
    byteData.setUint16(20, 1, Endian.little);  // Audio format (PCM)
    byteData.setUint16(22, 1, Endian.little);  // Num channels (mono)
    byteData.setUint32(24, sampleRate, Endian.little); // Sample rate
    byteData.setUint32(28, sampleRate * 2, Endian.little); // Byte rate
    byteData.setUint16(32, 2, Endian.little);  // Block align
    byteData.setUint16(34, 16, Endian.little); // Bits per sample
    
    // data chunk
    byteData.setUint8(36, 0x64); // 'd'
    byteData.setUint8(37, 0x61); // 'a'
    byteData.setUint8(38, 0x74); // 't'
    byteData.setUint8(39, 0x61); // 'a'
    byteData.setUint32(40, samples.length * 2, Endian.little); // Data size
    
    // Audio data
    for (int i = 0; i < samples.length; i++) {
      byteData.setInt16(44 + i * 2, samples[i], Endian.little);
    }
    
    return byteData.buffer.asUint8List();
  }

  /// Start playing tone (called on key down)
  Future<void> _startTone() async {
    if (!_audioEnabled || _toneBytes == null) return;
    try {
      await _tonePlayer.play(BytesSource(_toneBytes!));
    } catch (e) {
      // Ignore audio player errors during rapid tapping
      // The player can get into an invalid state when play/stop are called quickly
    }
  }

  /// Stop playing tone (called on key up)
  Future<void> _stopTone() async {
    try {
      await _tonePlayer.stop();
    } catch (e) {
      // Ignore audio player errors during rapid tapping
    }
  }

  /// When focus is lost, disable keyboard mode
  void _onFocusChanged() {
    if (!_textFieldFocusNode.hasFocus && _keyboardEnabled) {
      setState(() {
        _keyboardEnabled = false;
      });
    }
  }

  /// Enable keyboard input on double-tap
  void _enableKeyboardInput() {
    setState(() {
      _keyboardEnabled = true;
    });
    _textFieldFocusNode.requestFocus();
  }

  /// Called when the text field is edited via keyboard
  void _onTextChanged() {
    // Avoid feedback loop when we're updating from tapper
    if (_isUpdatingFromTapper) return;

    final newText = _textController.text.toUpperCase();
    
    // Only process if the text actually changed
    if (newText == _decodedText) return;

    final morseService = context.read<MorseService>();

    // Rebuild the morse symbols from the new text
    final newSymbols = <String>[];
    for (int i = 0; i < newText.length; i++) {
      final char = newText[i];
      if (char == ' ') {
        newSymbols.add('/');
      } else {
        final pattern = morseService.charToPattern(char);
        if (pattern != null) {
          newSymbols.addAll(pattern.split(''));
          if (i < newText.length - 1 && newText[i + 1] != ' ') {
            newSymbols.add(' '); // Letter separator
          }
        }
      }
    }

    setState(() {
      _decodedText = newText;
      _inputSymbols.clear();
      _inputSymbols.addAll(newSymbols);
      _currentPattern = '';
      // Clear timing data since keyboard input doesn't have timing
      _pressDurations.clear();
      _gapDurations.clear();
    });
  }

  /// Update the text controller from tapper input without triggering listener
  void _syncTextController() {
    _isUpdatingFromTapper = true;
    _textController.text = _decodedText;
    // Move cursor to end
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: _textController.text.length),
    );
    _isUpdatingFromTapper = false;
  }

  Future<void> _decodeIncomingAudio() async {
    if (widget.incomingAudioFilePath == null) return;
    
    setState(() => _isDecoding = true);

    try {
      final result = await decoder.decodeAudioFile(widget.incomingAudioFilePath!);

      setState(() {
        _decodedText = result.decodedText;
        _inputSymbols.addAll(result.morsePattern.split(''));
        _isDecoding = false;
      });
      _syncTextController();
    } catch (e) {
      if (kDebugMode) {
        print('Error decoding audio: $e');
      }
      setState(() {
        _decodedText = '[Error decoding audio]';
        _isDecoding = false;
      });
      _syncTextController();
    }
  }

  void _onKeyDown() {
    _keyDownTime = DateTime.now();
    _startTone();

    // Record gap since last key up
    if (_lastKeyUpTime != null && _pressDurations.isNotEmpty) {
      final gap = DateTime.now().difference(_lastKeyUpTime!).inMilliseconds;
      _gapDurations.add(gap);
    }
  }

  void _onKeyUp() {
    _stopTone();
    if (_keyDownTime == null) return;

    final duration = DateTime.now().difference(_keyDownTime!).inMilliseconds;
    _pressDurations.add(duration);
    _lastKeyUpTime = DateTime.now();
    _keyDownTime = null;

    // Determine dot or dash
    // Use a more generous threshold for touchscreen input:
    // - Taps under 200ms = dot
    // - Taps 200ms or longer = dash
    // This is more forgiving than strict Morse timing and matches
    // typical touchscreen tap durations (100-200ms for quick taps)
    const int dotThreshold = 200; // milliseconds
    final symbol = duration < dotThreshold ? '.' : '-';

    setState(() {
      // Only add to _currentPattern while typing
      // Symbols move to _inputSymbols when the letter is complete
      _currentPattern += symbol;
    });

    // Schedule auto-decode after letter gap
    // Use a generous timeout for touchscreen input:
    // - Standard Morse at 15 WPM would be ~240ms, way too fast for beginners
    // - Average comfortable inter-tap interval is 400-600ms
    // - We use 800ms to give users plenty of time between symbols
    // This can be adjusted in settings if users want faster input
    _decodeTimer?.cancel();
    const int letterGapTimeout = 800; // milliseconds
    _decodeTimer = Timer(
      const Duration(milliseconds: letterGapTimeout),
      _decodeLetter,
    );
  }

  void _decodeLetter() {
    if (_currentPattern.isEmpty) return;
    
    final morseService = context.read<MorseService>();
    final char = morseService.patternToChar(_currentPattern);

    setState(() {
      // Move the current pattern symbols to the permanent input list
      _inputSymbols.addAll(_currentPattern.split(''));
      
      if (char != null) {
        _decodedText += char;
        _inputSymbols.add(' '); // Letter separator
      } else {
        _decodedText += '?'; // Unknown pattern
        _inputSymbols.add(' ');
      }
      _currentPattern = '';
    });
    _syncTextController();
  }

  void _addWordSpace() {
    if (_currentPattern.isNotEmpty) {
      _decodeLetter();
    }

    // Add word gap timing
    if (_gapDurations.isNotEmpty || _pressDurations.isNotEmpty) {
      final settings = context.read<SettingsService>();
      _gapDurations.add(MorseCode.getWordGap(settings.wordsPerMinute));
    }

    setState(() {
      _decodedText += ' ';
      _inputSymbols.add('/');
    });
    _syncTextController();
  }

  void _deleteLastLetter() {
    _decodeTimer?.cancel();
    
    // If currently typing a pattern, just clear that
    if (_currentPattern.isNotEmpty) {
      setState(() {
        _currentPattern = '';
      });
      return;
    }
    
    // Nothing to delete
    if (_decodedText.isEmpty && _inputSymbols.isEmpty) return;
    
    setState(() {
      // Remove last character from decoded text
      if (_decodedText.isNotEmpty) {
        _decodedText = _decodedText.substring(0, _decodedText.length - 1);
      }
      
      // Remove morse symbols for the last letter (back to previous separator)
      // First, remove the trailing space/slash if present
      while (_inputSymbols.isNotEmpty && 
             (_inputSymbols.last == ' ' || _inputSymbols.last == '/')) {
        _inputSymbols.removeLast();
      }
      
      // Then remove the actual morse symbols until we hit another separator or empty
      while (_inputSymbols.isNotEmpty && 
             _inputSymbols.last != ' ' && 
             _inputSymbols.last != '/') {
        _inputSymbols.removeLast();
      }
    });
    _syncTextController();
  }

  /// Start repeating delete when button is held
  void _startDeleteRepeat() {
    // Delete once immediately
    _deleteLastLetter();
    
    // After initial delay, start repeating
    _deleteRepeatTimer = Timer(const Duration(milliseconds: 400), () {
      // Start periodic deletion
      _deleteRepeatTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (_decodedText.isNotEmpty || _currentPattern.isNotEmpty) {
          _deleteLastLetter();
        } else {
          _stopDeleteRepeat();
        }
      });
    });
  }

  /// Stop repeating delete
  void _stopDeleteRepeat() {
    _deleteRepeatTimer?.cancel();
    _deleteRepeatTimer = null;
  }

  void _clear() {
    _decodeTimer?.cancel();
    setState(() {
      _pressDurations.clear();
      _gapDurations.clear();
      _inputSymbols.clear();
      _currentPattern = '';
      _decodedText = '';
      _lastKeyUpTime = null;
      _keyDownTime = null;
    });
    _syncTextController();
  }

  String get _morsePattern {
    // Reconstruct morse pattern from symbols
    final buffer = StringBuffer();
    for (final symbol in _inputSymbols) {
      if (symbol == '/') {
        buffer.write(' / ');
      } else if (symbol == ' ') {
        buffer.write(' ');
      } else {
        buffer.write(symbol);
      }
    }
    return buffer.toString().trim();
  }

  /// Check if we have complete timing data for all morse symbols.
  /// Returns true only if every dot and dash was tapped (not typed).
  bool get _hasCompleteTimingData {
    if (_pressDurations.isEmpty) return false;
    
    // Count actual morse symbols (dots and dashes) in input
    // Include both completed symbols and any currently being typed
    final completedSymbolCount = _inputSymbols.where((s) => s == '.' || s == '-').length;
    final pendingSymbolCount = _currentPattern.length; // All chars in pattern are dots/dashes
    final totalSymbolCount = completedSymbolCount + pendingSymbolCount;
    
    // We have complete timing if durations match symbol count
    return _pressDurations.length == totalSymbolCount;
  }

  /// Format morse display with current pattern included
  String _formatMorseDisplay() {
    final buffer = StringBuffer();
    for (final symbol in _inputSymbols) {
      if (symbol == '/') {
        buffer.write('  ${MorseCode.displayWordSeparator}  ');
      } else if (symbol == ' ') {
        buffer.write('   ');
      } else if (symbol == '.') {
        buffer.write(MorseCode.displayDot);
      } else if (symbol == '-') {
        buffer.write(MorseCode.displayDash);
      } else {
        buffer.write(symbol);
      }
    }
    // Add current pattern being typed
    for (final char in _currentPattern.split('')) {
      if (char == '.') {
        buffer.write(MorseCode.displayDot);
      } else if (char == '-') {
        buffer.write(MorseCode.displayDash);
      }
    }
    return buffer.toString();
  }

  /// Share audio using user's custom timing (tap durations) - default action
  Future<void> _shareAudio() async {
    // If we have complete custom timing data (all tapped, not typed), use it
    await _shareAudioInternal(useCustomTiming: _hasCompleteTimingData);
  }

  /// Show menu with audio sharing options
  void _showShareAudioMenu() {
    if (_inputSymbols.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tap out a message first!'),
          backgroundColor: AppColors.mahogany,
        ),
      );
      return;
    }

    final hasCompleteTimingData = _hasCompleteTimingData;
    final settings = context.read<SettingsService>();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkWood,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'SHARE AUDIO',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            if (hasCompleteTimingData)
              ListTile(
                leading: const Icon(Icons.touch_app),
                title: const Text('Your Timing'),
                subtitle: const Text('Use your actual tap durations'),
                onTap: () {
                  Navigator.pop(context);
                  _shareAudioInternal(useCustomTiming: true);
                },
              ),
            ListTile(
              leading: const Icon(Icons.speed),
              title: const Text('Standard Timing'),
              subtitle: Text('Generate at ${settings.wordsPerMinute} WPM'),
              onTap: () {
                Navigator.pop(context);
                _shareAudioInternal(useCustomTiming: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.school),
              title: const Text('Farnsworth Timing'),
              subtitle: Text(
                'Characters at ${settings.farnsworthWpm} WPM, gaps at ${settings.wordsPerMinute} WPM',
              ),
              onTap: () {
                Navigator.pop(context);
                _shareAudioInternal(useCustomTiming: false, useFarnsworth: true);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _shareAudioInternal({
    required bool useCustomTiming,
    bool useFarnsworth = false,
  }) async {
    if (_inputSymbols.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tap out a message first!'),
          backgroundColor: AppColors.mahogany,
        ),
      );
      return;
    }

    // Finish any pending letter
    if (_currentPattern.isNotEmpty) {
      _decodeLetter();
    }

    setState(() => _isSharing = true);

    try {
      final settings = context.read<SettingsService>();
      final shareService = ShareService(
        toneFrequency: settings.toneFrequency,
        wordsPerMinute: settings.wordsPerMinute,
        characterWpm: useFarnsworth ? settings.farnsworthWpm : null,
      );

      final success = await shareService.shareMorseAudio(
        morsePattern: _morsePattern,
        decodedText: _decodedText,
        // Only pass timing data if using custom timing and we have it
        pressDurations: useCustomTiming ? _pressDurations : null,
        gapDurations: useCustomTiming ? _gapDurations : null,
      );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to share audio'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<void> _shareText() async {
    if (_inputSymbols.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tap out a message first!'),
          backgroundColor: AppColors.mahogany,
        ),
      );
      return;
    }

    // Finish any pending letter
    if (_currentPattern.isNotEmpty) {
      _decodeLetter();
    }

    final settings = context.read<SettingsService>();
    final shareService = ShareService(
      toneFrequency: settings.toneFrequency,
      wordsPerMinute: settings.wordsPerMinute,
    );

    await shareService.shareMorseText(
      morsePattern: _morsePattern,
      decodedText: _decodedText,
    );
  }

  /// Play audio at specified speed (1.0 = normal, 0.5 = half speed)
  /// Set useFarnsworth to true for Farnsworth timing
  /// Set useCustomTiming to true to use the user's actual tap durations
  Future<void> _playAudio({
    double speed = 1.0,
    bool useFarnsworth = false,
    bool? useCustomTiming,
  }) async {
    if (_inputSymbols.isEmpty && _decodedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tap out a message first!'),
          backgroundColor: AppColors.mahogany,
        ),
      );
      return;
    }

    // Finish any pending letter
    if (_currentPattern.isNotEmpty) {
      _decodeLetter();
    }

    // If already playing, stop
    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() => _isPlaying = false);
      return;
    }

    setState(() => _isPlaying = true);

    try {
      final settings = context.read<SettingsService>();
      
      // Determine if we should use custom timing
      // Default: use custom timing if available and no speed/Farnsworth modifiers
      final shouldUseCustomTiming = useCustomTiming ?? 
          (_hasCompleteTimingData && speed == 1.0 && !useFarnsworth);
      
      Uint8List wavBytes;
      
      if (shouldUseCustomTiming && _hasCompleteTimingData) {
        // Use the user's actual tap durations
        final generator = MorseAudioGenerator(
          toneFrequency: settings.toneFrequency,
          wordsPerMinute: settings.wordsPerMinute,
        );
        wavBytes = generator.generateWavFromTimingsSync(
          _pressDurations,
          _gapDurations,
        );
      } else {
        // Generate with standard/Farnsworth timing
        final adjustedWpm = (settings.wordsPerMinute * speed).round().clamp(5, 50);
        final generator = MorseAudioGenerator(
          toneFrequency: settings.toneFrequency,
          wordsPerMinute: adjustedWpm,
          characterWpm: useFarnsworth ? settings.farnsworthWpm : null,
        );
        wavBytes = generator.generateWavFromMorseSync(_morsePattern);
      }

      // Play from bytes
      await _audioPlayer.play(BytesSource(wavBytes));

      // Listen for completion
      _audioPlayer.onPlayerComplete.first.then((_) {
        if (mounted) {
          setState(() => _isPlaying = false);
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error playing audio: $e');
      }
      if (mounted) {
        setState(() => _isPlaying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to play audio'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  void _showPlaySpeedMenu(BuildContext context) {
    final settings = context.read<SettingsService>();
    final hasCompleteTimingData = _hasCompleteTimingData;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkWood,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'PLAYBACK OPTIONS',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            if (hasCompleteTimingData)
              ListTile(
                leading: const Icon(Icons.touch_app),
                title: const Text('Your Timing'),
                subtitle: const Text('Play with your actual tap durations'),
                onTap: () {
                  Navigator.pop(context);
                  _playAudio(useCustomTiming: true);
                },
              ),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Standard Timing'),
              subtitle: Text('Play at ${settings.wordsPerMinute} WPM'),
              onTap: () {
                Navigator.pop(context);
                _playAudio(useCustomTiming: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.school),
              title: const Text('Farnsworth Timing'),
              subtitle: Text(
                'Characters at ${settings.farnsworthWpm} WPM, gaps at ${settings.wordsPerMinute} WPM',
              ),
              onTap: () {
                Navigator.pop(context);
                _playAudio(useFarnsworth: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.slow_motion_video),
              title: const Text('Half Speed (1/2)'),
              subtitle: Text('Play at ${(settings.wordsPerMinute / 2).round()} WPM'),
              onTap: () {
                Navigator.pop(context);
                _playAudio(speed: 0.5);
              },
            ),
            ListTile(
              leading: const Icon(Icons.hourglass_bottom),
              title: const Text('Quarter Speed (1/4)'),
              subtitle: Text('Play at ${(settings.wordsPerMinute / 4).round()} WPM'),
              onTap: () {
                Navigator.pop(context);
                _playAudio(speed: 0.25);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showReferenceDialog(BuildContext context) {
    // Unfocus the text field to prevent keyboard from popping up when dialog closes
    FocusScope.of(context).unfocus();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkWood,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => DefaultTabController(
          length: 4,
          child: Column(
            children: [
              // Drag handle
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        _insertCharacter(' ');
                      },
                      icon: const Icon(Icons.space_bar),
                      tooltip: 'Add space',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _deleteLastLetter,
                      icon: const Icon(Icons.backspace_outlined),
                      tooltip: 'Delete',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'MORSE CODE KEYBOARD',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'LETTERS'),
                  Tab(text: 'NUMBERS'),
                  Tab(text: 'PUNCTUATION'),
                  Tab(text: 'PROSIGNS'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildReferenceGrid(MorseCode.letters),
                    _buildReferenceGrid(MorseCode.numbers),
                    _buildReferenceGrid(MorseCode.punctuation),
                    _buildProsignsGrid(MorseCode.prosigns),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReferenceGrid(Map<String, String> codes) {
    final entries = codes.entries.toList();
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 1.0,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Material(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _insertCharacter(entry.key),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    entry.key,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    entry.value,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.warningAmber,
                          letterSpacing: 1,
                        ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProsignsGrid(Map<String, String> codes) {
    final entries = codes.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _insertCharacter(entry.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        entry.key,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      entry.value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.warningAmber,
                            letterSpacing: 2,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build a square button with two icons side by side
  Widget _buildDualIconButton({
    required IconData icon1,
    required IconData icon2,
    required String label,
    VoidCallback? onPressed,
    VoidCallback? onLongPress,
  }) {
    final button = SizedBox(
      width: 56,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon1, size: 14),
                Icon(icon2, size: 14),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 8),
            ),
          ],
        ),
      ),
    );

    if (onLongPress != null) {
      return GestureDetector(
        onLongPress: onLongPress,
        child: button,
      );
    }
    return button;
  }

  /// Build a square button for the side columns
  Widget _buildSquareButton({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
    VoidCallback? onLongPress,
    bool highlighted = false,
  }) {
    final button = SizedBox(
      width: 56,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: highlighted ? AppColors.signalGreen.withAlpha(50) : null,
          side: highlighted ? const BorderSide(color: AppColors.signalGreen) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 8),
            ),
          ],
        ),
      ),
    );

    if (onLongPress != null) {
      return GestureDetector(
        onLongPress: onLongPress,
        child: button,
      );
    }
    return button;
  }

  /// Build the delete button with hold-to-repeat functionality
  /// Double-tap to clear all
  Widget _buildDeleteButton() {
    final isEnabled = _decodedText.isNotEmpty || _currentPattern.isNotEmpty;
    
    return GestureDetector(
      onTapDown: isEnabled ? (_) => _deleteLastLetter() : null,
      onDoubleTap: isEnabled ? _clear : null,
      onLongPressStart: isEnabled ? (_) => _startDeleteRepeat() : null,
      onLongPressEnd: isEnabled ? (_) => _stopDeleteRepeat() : null,
      onLongPressCancel: _stopDeleteRepeat,
      child: SizedBox(
        width: 56,
        height: 56,
        child: OutlinedButton(
          onPressed: isEnabled ? () {} : null, // Empty callback to enable visual feedback
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.backspace_outlined, size: 20),
              SizedBox(height: 2),
              Text(
                'DEL',
                style: TextStyle(fontSize: 8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Insert a character from the reference keyboard into the text field
  void _insertCharacter(String char) {
    // Handle space character specially
    if (char == ' ') {
      _addWordSpace();
      return;
    }
    
    final morseService = context.read<MorseService>();
    
    // Get the morse pattern for this character
    final pattern = morseService.charToPattern(char);
    
    setState(() {
      _decodedText += char;
      
      // Add morse symbols
      if (pattern != null) {
        _inputSymbols.addAll(pattern.split(''));
        _inputSymbols.add(' '); // Letter separator
      }
    });
    _syncTextController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.incomingAudioFilePath != null ? 'RECEIVED MESSAGE' : 'COMPOSE'),
        actions: [
          IconButton(
            onPressed: () => _showReferenceDialog(context),
            icon: const Icon(Icons.keyboard),
            tooltip: 'Morse code keyboard',
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          // Detect if keyboard is showing
          final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 50;
          
          return Column(
            children: [
              // Text message and Morse code displays - split available space
              Expanded(
                flex: keyboardVisible ? 1 : 3,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.incomingAudioFilePath != null ? 'DECODED MESSAGE' : 'YOUR MESSAGE',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      if (_decodedText.isNotEmpty)
                        Text(
                          '${_decodedText.replaceAll(' ', '').length} chars',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textMuted,
                              ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _isDecoding
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Decoding morse code...'),
                              ],
                            ),
                          )
                        : GestureDetector(
                            onDoubleTap: _enableKeyboardInput,
                            child: TextField(
                              controller: _textController,
                              focusNode: _textFieldFocusNode,
                              readOnly: !_keyboardEnabled,
                              showCursor: _keyboardEnabled,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                hintText: _keyboardEnabled 
                                    ? 'Type your message...'
                                    : 'Tap the key, or double-tap here to type...',
                                hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: AppColors.textMuted,
                                      height: 1.4,
                                    ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.textPrimary,
                                    height: 1.4,
                                  ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),

          // Morse pattern display (always visible)
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MORSE CODE',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SizedBox(
                        width: double.infinity,
                        child: Text(
                          (_inputSymbols.isNotEmpty || _currentPattern.isNotEmpty)
                              ? _formatMorseDisplay()
                              : MorseCode.formatForDisplay('...---...'), // SOS placeholder
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: (_inputSymbols.isNotEmpty || _currentPattern.isNotEmpty)
                                    ? AppColors.warningAmber
                                    : AppColors.textMuted,
                                letterSpacing: 2,
                                height: 1.4,
                                fontFamily: 'monospace',
                              ),
                          softWrap: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Reply button for received messages
          if (widget.incomingAudioFilePath != null && !_isDecoding)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ComposeScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.reply),
                label: const Text('COMPOSE REPLY'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ).animate().fadeIn().slideY(begin: 0.2),

          // Compact telegraph key with side button columns (hidden when keyboard visible)
          if (widget.incomingAudioFilePath == null && !keyboardVisible)
            TelegraphKeyLayout(
              onKeyDown: _onKeyDown,
              onKeyUp: _onKeyUp,
              enabled: !_isSharing,
              leftColumnButtons: [
                _buildSquareButton(
                  icon: _isPlaying ? Icons.stop : Icons.play_arrow,
                  label: _isPlaying ? 'STOP' : 'PLAY',
                  onPressed: (_inputSymbols.isNotEmpty || _decodedText.isNotEmpty)
                      ? _playAudio
                      : null,
                  onLongPress: (_inputSymbols.isNotEmpty || _decodedText.isNotEmpty) && !_isPlaying
                      ? () => _showPlaySpeedMenu(context)
                      : null,
                ),
                _buildDualIconButton(
                  icon1: Icons.share,
                  icon2: Icons.text_fields,
                  label: 'TEXT',
                  onPressed: _inputSymbols.isNotEmpty ? _shareText : null,
                ),
                _buildDualIconButton(
                  icon1: Icons.share,
                  icon2: _isSharing ? Icons.hourglass_empty : Icons.volume_up,
                  label: 'AUDIO',
                  onPressed: (_inputSymbols.isNotEmpty && !_isSharing) ? _shareAudio : null,
                  onLongPress: (_inputSymbols.isNotEmpty && !_isSharing) ? _showShareAudioMenu : null,
                ),
              ],
              rightColumnButtons: [
                _buildSquareButton(
                  icon: _audioEnabled ? Icons.volume_up : Icons.volume_off,
                  label: _audioEnabled ? 'SOUND' : 'MUTED',
                  onPressed: () {
                    setState(() {
                      _audioEnabled = !_audioEnabled;
                    });
                  },
                  highlighted: _audioEnabled,
                ),
                _buildDeleteButton(),
                _buildSquareButton(
                  icon: Icons.space_bar,
                  label: 'SPACE',
                  onPressed: _addWordSpace,
                ),
              ],
            )
          else
            const SizedBox(height: 40),
          ],
        );
        },
      ),
    );
  }
}
