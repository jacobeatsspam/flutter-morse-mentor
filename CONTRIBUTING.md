# Contributing

## Install Needed Tools

### Flutter

Install this first

```bash
git clone https://github.com/flutter/flutter.git -b stable "$HOME/Flutter"
```

```bash
cat >> .envrc <EOF
# Flutter Path
export PATH="$PATH:$HOME/Flutter/bin"
EOF
direnv allow
```

```bash
flutter doctor
```

### Android SDK

```bash
mkdir -p ~/Android/cmdline-tools
cd ~/Android/cmdline-tools
wget https://dl.google.com/android/repository/commandlinetools-linux-14742923_latest.zip -O tools.zip
unzip tools.zip
rm tools.zip
mv cmdline-tools latest
```

```bash
cat >> .envrc <EOF
# Android SDK Paths
export ANDROID_HOME=$HOME/Android
export ANDROID_SDK_ROOT=$HOME/Android
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/emulator
EOF
```

```bash
yes | sdkmanager --licenses
sdkmanager 'platform-tools' 'platforms;android-36' 'build-tools;36.0.0'
flutter config --android-sdk ~/Android
flutter doctor --android-licenses
flutter doctor
```

### Android Emulator

```bash
sdkmanager 'system-images;android-36;google_apis;x86_64'
avdmanager create avd \
  -n pixel9 \
  -d pixel_9 \
  -k 'system-images;android-36;google_apis;x86_64'
flutter emulators
flutter devices
flutter emulators --launch pixel9
```
