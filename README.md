# Expense Tracker

A simple Flutter app for Android and iPhone that tracks expenses month by month. Each user has their own account. Login and data storage use Firebase's free Spark plan.

## Tooling on this Linux machine

Add this to `~/.bashrc`:

```bash
export PATH="$HOME/development/flutter/bin:$HOME/.pub-cache/bin:$HOME/.npm-global/bin:$PATH"
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
```

## One-time Firebase setup

1. In https://console.firebase.google.com, create a project. It stays on the free Spark plan, so no billing is needed.
2. Go to **Authentication → Sign-in method** and enable **Email/Password**.
3. Go to **Firestore Database** and create a database in production mode.
4. In this folder, run:
   ```bash
   firebase login
   flutterfire configure --platforms=android,ios
   firebase deploy --only firestore:rules
   ```
   `flutterfire configure` generates `lib/firebase_options.dart` and `android/app/google-services.json`. Both are gitignored, so every fresh clone must run it. You can also paste `firestore.rules` into the console under Firestore → Rules instead of running the deploy command.

## Run / build

```bash
flutter run                    # on a connected phone or emulator
flutter build apk --release    # build/app/outputs/flutter-apk/app-release.apk
```

To install on Android, share `app-release.apk` with each user and have them allow installs from unknown sources.

## iPhone (on a Mac, free Apple ID)

1. Install Xcode and Flutter on the Mac, then copy or clone this project there.
2. `cd ios && pod install && cd ..`
3. `open ios/Runner.xcworkspace`. Under Runner → Signing & Capabilities, choose your personal team and change the bundle ID if Xcode asks.
4. Plug in the iPhone, then run `flutter run --release`.
5. On the iPhone, go to Settings → General → VPN & Device Management and trust your developer profile.

Apps signed with a free Apple ID stop working after 7 days. Run `flutter run --release` again to reinstall.
