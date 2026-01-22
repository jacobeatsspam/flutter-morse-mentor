# Morse Mentor

A cross-platform mobile application designed to educate, challenge, and refine morse code skills for the ham radio community. Features an authentic vintage telegraph key interface for an immersive learning experience.

## Features

- **Learn Mode**: Progressive learning system based on the Koch method, starting with simple characters and advancing to complex patterns
- **Practice Mode**:
  - Send practice - tap out characters shown on screen
  - Receive practice - decode morse played to you
  - Freeform - tap freely and see your decoded output
- **Challenge Mode**:
  - Speed Run - send as many characters as possible in 60 seconds
  - Accuracy - perfect run mode where one mistake ends the challenge
  - Endurance - go as long as you can with 3 strikes
- **Reference**: Complete charts for alphabet, numbers, prosigns, and Q-codes
- **Progress Tracking**: Track mastery, streaks, and improvement over time
- **Vintage Aesthetic**: Beautiful UI inspired by brass telegraph equipment and dark wood

## Requirements

### System Requirements

Before you can run this app, you need to set up your Flutter development environment.

### Flutter Installation (Linux)

1. **Download Flutter SDK**:

   ```bash
   cd ~
   mkdir -p development
   cd development
   git clone https://github.com/flutter/flutter.git -b stable
   ```

2. **Add Flutter to PATH** - Add to your `~/.bashrc` or `~/.zshrc`:

   ```bash
   export PATH="$PATH:$HOME/development/flutter/bin"
   ```

3. **Reload your shell**:

   ```bash
   source ~/.bashrc
   ```

4. **Run Flutter Doctor** to check for dependencies:

   ```bash
   flutter doctor
   ```

5. **Install missing dependencies** as indicated by `flutter doctor`:
   - For Android development: Install Android Studio and Android SDK
   - For Linux desktop: `sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev`
   - For Chrome/web: Install Chrome browser

### Android Setup

1. Install Android Studio from https://developer.android.com/studio
2. In Android Studio, go to SDK Manager and install:
   - Android SDK Platform-Tools
   - Android SDK Build-Tools
   - Android SDK Command-line Tools
3. Accept Android licenses:

   ```bash
   flutter doctor --android-licenses
   ```

### iOS Setup (macOS only)

1. Install Xcode from the Mac App Store
2. Install CocoaPods:

   ```bash
   sudo gem install cocoapods
   ```

## Running the App

Once Flutter is set up:

1. **Get dependencies**:

   ```bash
   flutter pub get
   ```

2. **Generate Hive adapters** (for local storage):

   ```bash
   flutter pub run build_runner build
   ```

3. **Run on connected device or emulator**:

   ```bash
   flutter run
   ```

4. **Run on specific platform**:

   ```bash
   # Android
   flutter run -d android
   
   # iOS (macOS only)
   flutter run -d ios
   
   # Web
   flutter run -d chrome
   
   # Linux desktop
   flutter run -d linux
   ```

## Project Structure

```plain
lib/
├── main.dart                 # App entry point
├── core/
│   ├── constants/
│   │   └── morse_code.dart   # Morse code mappings & learning data
│   └── theme/
│       └── app_theme.dart    # Vintage brass/wood theme
├── models/
│   └── user_progress.dart    # Progress tracking models
├── services/
│   ├── morse_service.dart    # Encoding/decoding logic
│   ├── audio_service.dart    # Tone playback
│   ├── progress_service.dart # Progress persistence
│   └── settings_service.dart # App settings
├── screens/
│   ├── home_screen.dart      # Main menu
│   ├── learn_screen.dart     # Learning mode
│   ├── practice_screen.dart  # Practice modes
│   ├── challenge_screen.dart # Challenge modes
│   ├── reference_screen.dart # Morse code charts
│   └── settings_screen.dart  # Settings & stats
└── widgets/
    ├── telegraph_key.dart    # Vintage plunger widget
    └── morse_display.dart    # Morse visualization
```

## Technical Details

### Morse Code Timing

The app uses International Morse Code standard timing based on the PARIS method:

- **Dot (dit)**: 1 unit
- **Dash (dah)**: 3 units  
- **Gap between elements**: 1 unit
- **Gap between letters**: 3 units
- **Gap between words**: 7 units

At 20 WPM, one unit = 60ms.

### Farnsworth Timing

Farnsworth timing sends characters at a higher speed but with extra spacing between letters. This helps learners recognize character patterns at higher speeds while still having time to process each letter.

### Learning Method

The app uses a progressive learning approach inspired by the Koch method:

1. Start with simplest patterns (E, T, A, N)
2. Add new characters as previous ones are mastered
3. Characters organized by difficulty (1-5)
4. Mastery requires 10+ correct attempts with 90%+ accuracy

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

This project is open source and available under the MIT License.
