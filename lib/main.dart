import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/theme/app_theme.dart';
import 'services/morse_service.dart';
import 'services/audio_service.dart';
import 'services/progress_service.dart';
import 'services/settings_service.dart';
import 'screens/home_screen.dart';
import 'screens/compose_screen.dart';

// Conditional import for receiving shared files (mobile only)
import 'sharing/sharing_stub.dart'
    if (dart.library.io) 'sharing/sharing_mobile.dart' as sharing;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Lock orientation to portrait for better plunger experience (mobile only)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MorseMentorApp());
}

class MorseMentorApp extends StatefulWidget {
  const MorseMentorApp({super.key});

  @override
  State<MorseMentorApp> createState() => _MorseMentorAppState();
}

class _MorseMentorAppState extends State<MorseMentorApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription? _intentSubscription;

  @override
  void initState() {
    super.initState();
    _initSharingIntent();
  }

  void _initSharingIntent() {
    // Only initialize sharing on mobile platforms
    if (kIsWeb) return;
    
    sharing.initSharingIntent(
      onFileReceived: (filePath) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ComposeScreen(incomingAudioFilePath: filePath),
          ),
        );
      },
      onSubscription: (subscription) {
        _intentSubscription = subscription;
      },
    );
  }

  @override
  void dispose() {
    _intentSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsService()),
        ChangeNotifierProvider(create: (_) => ProgressService()),
        Provider(create: (_) => MorseService()),
        Provider(create: (_) => AudioService()),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settings, _) {
          return MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'Morse Mentor',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
