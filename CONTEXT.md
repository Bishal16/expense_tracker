# Project context: Expense Tracker

Handoff notes so work can continue on another machine (or with a new Claude Code session). Last updated 2026-10-29.

## What this app is

A free Flutter app for Android and iPhone used by **two people** to track shared expenses until they are paid back.

- **User 1** (iPhone, `user1.faria@gmail.com`) adds expenses. Only **item name** and **price** (line total in taka) are required. Qty, unit (kg, litre, pcs...) and date are optional; the date defaults to today.
- **User 2 / admin** (Android, `mahathirbishal@gmail.com`) can edit or delete anything, undo payments, and manage users. In practice they only step in when necessary.
- New expenses start **unpaid**. The landing page lists the unpaid ones with the **total remaining**.
- Either user can select one or more expenses and **mark them paid**. Expenses marked together form one *payment*, which appears in **Paid history**.
- Constraints: everything must stay **free** (Firebase Spark plan), and there are only a few users.

## Stack and services

- Flutter (stable 3.47.x, Dart 3.13), Material 3.
- Firebase project **`expensetracker-f38d4`** (Spark/free):
  - Authentication: Email/Password.
  - Cloud Firestore: one shared `expenses` collection, a `users` collection for access approvals, and a `prefs` collection for each user's personal look.
- Packages: `firebase_core`, `firebase_auth`, `cloud_firestore`, `intl`, `share_plus`, `path_provider`, `flutter_secure_storage`, `google_fonts`.
  - ⚠️ `google_fonts` **must stay on ^8.x**. 9.0 depends on the new standalone `material_ui` package, and its `TextTheme` doesn't match Flutter's, which breaks the build.
  - ⚠️ **Never use `GoogleFonts.getFont(name)` or `getTextTheme(name)`.** Looking fonts up by name pulls every Google Font into the app (APK grew 56 → 88 MB). `lib/fonts.dart` maps only the 14 offered fonts to direct references; use `fontStyle()` / `fontTextTheme()` from there. To offer a new font, add it to both maps in `fonts.dart` and to the lists in `models/theme_prefs.dart`.
- Android package / iOS bundle id: `com.mahathir.expense_tracker` / `com.mahathir.expenseTracker`.

## Roles and access (how user 1 vs admin is decided)

- The admin is decided by **email**, which is hardcoded in two places that must stay in sync:
  - `lib/config.dart` → `adminEmail` (controls which UI is shown)
  - `firestore.rules` → `isAdmin()` (enforced on the server)
- Everyone else must be **approved by the admin**:
  - On first sign-in, the app creates `users/{uid}` with `status: pending` and shows a "waiting for approval" screen.
  - The admin approves or blocks the account in the **Admin panel**.
  - The rules only let `approved` users (or the admin) read or write expenses.
- ⚠️ `user1.faria@gmail.com` registered **before** approvals existed. After signing in once on the new build, the admin must tap **Approve** for them in the Admin panel.
- The user decided the admin stays hardcoded; moving roles into Firestore is not needed.

## Data model (Firestore)

```
expenses/{id}
  name, amount (number, line total in taka), date (timestamp)
  qty (number, optional), unit (string, optional: kg, g, litre, ml, pcs, dozen, pack, box)
  paid (bool), paidAt (timestamp), paidBy (email), paymentId (string, shared by a batch)
  createdBy (uid), createdByEmail, createdAt
users/{uid}
  email, status: pending | approved | blocked, requestedAt
prefs/{uid}
  palette, bodyFont, greetingFont, emoji, motif, radius, textScale, decorations, displayName
```

- Queries only filter on `paid` and sort on the device, so **no composite indexes** are needed.
- Expenses saved before qty became optional have `qty: 1` and no `unit`, which is fine.
- A missing `prefs/{uid}` doc means "role defaults". Unknown or invalid values fall back to the defaults (`ThemePrefs.fromMap`).
- Old test data from the very first version may still sit under `users/{uid}/expenses`. The app doesn't read it and the rules block it; it can be deleted.

## Security rules summary (`firestore.rules`)

- **Admin:** can do anything to expenses, and can update or delete `users/*`.
- **Approved member:**
  - Can read all expenses.
  - Can create an expense only with `paid == false` and `createdBy == self`.
  - Can edit their own unpaid expenses (only `name`, `qty`, `unit`, `amount`, `date`).
  - Can mark **any** unpaid expense paid (only the paid fields, with `paidBy == own email`).
  - Can delete their own unpaid expenses.
  - Cannot undo payments or touch paid expenses.
- **Any signed-in user:**
  - can create **their own** `users/{uid}` doc, but only as `pending`
  - can read and write **only their own** `prefs/{uid}`
- Deploy with `firebase deploy --only firestore:rules`.

## Features (all implemented)

- **Login:**
  - Gradient welcome screen.
  - "Remember me" saves email and password **encrypted on the device** (`flutter_secure_storage`). Saved accounts appear as one-tap cards in each user's colors, with ✕ to forget.
  - Works with the Google / Samsung Pass autofill flow.
  - Show/hide password toggle.
- **Home (Unpaid):**
  - Gradient header with greeting ("Good evening / Hi, Faria 🌸"), total remaining and count.
  - Expense cards grouped by day (Today / Yesterday / date) with day totals. Cards show "2 kg" / "pcs" when qty or unit is set.
  - Tap the avatar circle or long-press to select. A selection bar shows "Select all" and **Pay ৳X**.
  - Tapping your own expense (or any expense, for the admin) opens the edit sheet.
- **Add/Edit sheet**, in this order (the user asked for it):
  1. **Item name \*** (gets the focus), with one-tap chips of recent names.
  2. Quantity (optional): +/− stepper; stepping down to 0 clears it.
  3. Unit (optional): kg, g, litre, ml, pcs, dozen, pack, box chips; tap again to clear.
  4. Date (optional): Today / Yesterday / Pick date chips, defaults to today.
  5. **Price (total) \***, big, just above Save.
  - Haptics and a confirmation snackbar.
  - Delete button. For the admin on paid items, a "Mark unpaid" button.
- **Paid history:**
  - Payment cards (day, time, who paid, count, total).
  - Admin ⋮ menu: Mark all unpaid, Export CSV, Delete payment.
  - The admin can tap an item to edit it.
- **Admin panel** (admin only, shield icon):
  - Summary: unpaid, paid, paid this month, and per-user totals.
  - Users: approve or block.
  - Bulk actions: mark all unpaid as paid, clear paid history older than 6/12/24 months.
  - Export CSV (all / unpaid / paid), shared through the phone's share sheet. The file includes a UTF-8 BOM so Excel reads Bangla text correctly.
- **Per-user look** (`lib/theme.dart`, `AppStyle` ThemeExtension built from `ThemePrefs`):
  - Defaults: the admin gets Midnight (navy→teal), Manrope and 💼. Everyone else gets Blossom (pink→lavender), Quicksand, a Dancing Script greeting, flower/heart motifs and 🌸.
  - Login screen: violet→pink "welcome" style. Saved-account cards use each user's default look.
- **"Make it yours" settings** (🎨 palette button in the home header, available to every user):
  - Live preview at the top. Every tap saves to `prefs/{uid}`, and the whole app restyles instantly, because `main.dart` listens to the prefs stream and rebuilds `MaterialApp`'s theme.
  - Options:
    - Your name (used in the greeting)
    - 9 color palettes
    - 8 greeting fonts and 8 text fonts
    - 11 emojis
    - 10 background motifs
    - corners (Crisp / Soft / Round / Bubbly)
    - text size 85–130%
    - "Sweet touches" (hearts and cuter wording) on/off
    - Reset to default
  - **Sign out** lives at the bottom of this page; it's no longer in the header.

## Code map

```
lib/
  main.dart                 auth stream → MaterialApp themed by signed-in user
  config.dart               adminEmail + isAdminEmail()
  theme.dart                AppStyle (from ThemePrefs; resolve/forEmail/welcome), ThemeData builder
  fonts.dart                the 14 offered fonts as direct references (keeps the APK small)
  format.dart               taka(), qty(), shortName(), friendlyName(), timeGreeting(), dayLabel()
  models/expense.dart       Expense (+ optional qty/unit, qtyLabel), units list, totalOf()
  models/app_user.dart      AppUser + UserStatus
  models/theme_prefs.dart   ThemePrefs + Palette list, font lists, emojis, motifs, corner styles
  services/auth_service.dart
  services/expense_repository.dart   watchUnpaid/Paid/All, add/update/delete, markPaid/markUnpaid, deleteAll, recentNames
  services/user_repository.dart      access requests and approvals
  services/saved_accounts.dart       encrypted "remember me" storage
  services/csv_export.dart           CSV building (incl. Unit column) + share sheet
  services/prefs_repository.dart     watch/save/reset prefs/{uid}
  screens/login_screen.dart, access_gate.dart, home_screen.dart,
          expense_form.dart, history_screen.dart, admin_screen.dart, settings_screen.dart
  widgets/ui.dart           GradientBackground, GradientHeader, PageHeader, SoftCard,
                            GradientButton, HeaderIconButton, InitialAvatar, Section
firestore.rules, firebase.json, .firebaserc
test/widget_test.dart       formatting, totals, admin check, CSV, names/day labels,
                            qtyLabel, ThemePrefs round-trip/fallbacks (7 tests)
```

## Current status / where we left off

1. ✅ All features below were **tested on the real Android phone** (Galaxy S23 Ultra), over USB on 2026-10-28 and over Wi-Fi on 2026-10-29:
   - core flow and the 11 permission checks
   - admin panel and approvals
   - user 1 flow
   - premium UI
   - the new add form with qty/unit
   - the settings page (live restyle, persistence across restarts, name, reset)
2. ✅ `user1.faria@gmail.com` has been approved and uses the app (pink theme).
3. ✅ Firestore rules with `unit` and `prefs/{uid}` are **already deployed**.
4. ✅ `flutter analyze` is clean and all 7 tests pass. The release APK is 56.6 MB.
5. ⏳ The 2026-10-29 work isn't committed yet: optional qty/unit, the form order, settings/personalisation, `fonts.dart`, and this file. Commit and push from Linux, then `git pull` on the Mac.
6. ⏳ The iOS build for user 1 was started on the Mac (`flutterfire configure` done, plist added to Xcode in commit `5fee21f`). Still to do: `pod install`, signing, `flutter run --release` on the iPhone.
7. ⏳ Optional: turn off new sign-ups in the Firebase console (Authentication → Settings → User actions). It's an extra layer on top of the approval gate.
8. Ideas not done yet:
   - The empty-state message hardcodes 🎀 rather than the user's chosen emoji.
   - Dark mode isn't supported.

## Continuing on the Mac

```bash
# 1. Tools
#    Install Xcode (App Store), then: xcode-select --install; sudo gem install cocoapods (or brew install cocoapods)
#    Install Flutter: https://docs.flutter.dev/get-started/install/macos
brew install node            # for the Firebase CLI
npm install -g firebase-tools
dart pub global activate flutterfire_cli   # add ~/.pub-cache/bin to PATH

# 2. Code
git clone <repo> && cd expenseTracker
flutter pub get

# 3. Firebase config. These files are gitignored, so regenerate them:
firebase login
flutterfire configure --project=expensetracker-f38d4 --platforms=android,ios \
  --android-package-name=com.mahathir.expense_tracker --ios-bundle-id=com.mahathir.expenseTracker --yes
#    (reuses the existing Firebase apps; creates lib/firebase_options.dart,
#     android/app/google-services.json, ios/Runner/GoogleService-Info.plist)

# 4. iPhone (free Apple ID, re-install every 7 days)
cd ios && pod install && cd ..
open ios/Runner.xcworkspace   # Runner → Signing & Capabilities → pick your personal team
flutter run --release          # with the iPhone plugged in
#    On the iPhone: Settings → General → VPN & Device Management → trust the developer profile
```

- The iOS minimum version may need raising for Firebase. If `pod install` complains, set `platform :ios, '15.0'` (or what it asks for) in `ios/Podfile`.
- `flutter_secure_storage` uses the Keychain on iOS and needs no extra setup.
- Android release APKs are signed with the **debug key of the Linux machine**. Build Android updates on that same machine, or a different key will block installing over the existing app.

## Handy notes for testing

- Android over USB: `adb install -r build/app/outputs/flutter-apk/app-release.apk`. Avoid the Wi-Fi/HTTP download method, because the browser cached an old APK once.
- **Android over Wi-Fi (no cable)**, Android 11+, with phone and PC on the same network:
  1. On the phone, turn on Developer options → **USB debugging** *and* **Wireless debugging**. With USB debugging off, connections show "offline" or get refused.
  2. Wireless debugging → **Pair device with pairing code**. On the PC: `adb pair <ip>:<pairing-port> <code>`.
  3. Connect to the port shown on the main Wireless debugging screen, which is different from the pairing port: `adb connect <ip>:<port>`.
  4. `adb mdns services` often finds the ports automatically. If several entries appear, set `ANDROID_SERIAL` to the one that says `device`.
  5. The port changes whenever Wireless debugging restarts, so reconnect each session.
- UI automation used for testing: `adb shell uiautomator dump` to read on-screen elements and their coordinates, `adb shell input tap/text/swipe`, and `adb exec-out screencap -p` for screenshots. Taps near the very top (y < ~110 px) hit the status bar.
- Owner-level Firestore access for test setup/cleanup is possible with the Firebase CLI login token (`~/.config/configstore/firebase-tools.json`) against the Firestore REST API. Owner requests bypass the rules.
- Prefix test data with `TEST` so it's easy to clean up. Delete temporary test accounts afterwards.
- The first Gradle build after adding plugins sometimes fails once. Re-running it works.
