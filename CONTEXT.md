# Project context: Expense Tracker

Handoff notes so work can continue on another machine (or with a new Claude Code session). Last updated 2026-10-28.

## What this app is

A free Flutter app for Android and iPhone used by **two people** to track shared expenses until they are paid back.

- **User 1** (iPhone, `user1.faria@gmail.com`) adds expenses: name, qty, taka (line total), and date (defaults to today).
- **User 2 / admin** (Android, `mahathirbishal@gmail.com`) can edit or delete anything, undo payments, and manage users. In practice they only step in when necessary.
- New expenses start **unpaid**. The landing page lists the unpaid ones with the **total remaining**.
- Either user can select one or more expenses and **mark them paid**. Expenses marked together form one *payment*, which appears in **Paid history**.
- Constraints: everything must stay **free** (Firebase Spark plan), and there are only a few users.

## Stack and services

- Flutter (stable 3.47.x, Dart 3.13), Material 3.
- Firebase project **`expensetracker-f38d4`** (Spark/free):
  - Authentication: Email/Password.
  - Cloud Firestore: one shared `expenses` collection plus a `users` collection for access approvals.
- Packages: `firebase_core`, `firebase_auth`, `cloud_firestore`, `intl`, `share_plus`, `path_provider`, `flutter_secure_storage`, `google_fonts`.
  - ⚠️ `google_fonts` **must stay on ^8.x**. 9.0 depends on the new standalone `material_ui` package, and its `TextTheme` doesn't match Flutter's, which breaks the build.
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
  name, qty (number), amount (number, line total in taka), date (timestamp)
  paid (bool), paidAt (timestamp), paidBy (email), paymentId (string, shared by a batch)
  createdBy (uid), createdByEmail, createdAt
users/{uid}
  email, status: pending | approved | blocked, requestedAt
```

- Queries only filter on `paid` and sort on the device, so **no composite indexes** are needed.
- Old test data from the very first version may still sit under `users/{uid}/expenses`. The app doesn't read it and the rules block it; it can be deleted.

## Security rules summary (`firestore.rules`)

- **Admin:** can do anything to expenses, and can update or delete `users/*`.
- **Approved member:**
  - Can read all expenses.
  - Can create an expense only with `paid == false` and `createdBy == self`.
  - Can edit their own unpaid expenses (only `name`, `qty`, `amount`, `date`).
  - Can mark **any** unpaid expense paid (only the paid fields, with `paidBy == own email`).
  - Can delete their own unpaid expenses.
  - Cannot undo payments or touch paid expenses.
- **Any signed-in user:** can create **their own** `users/{uid}` doc, but only as `pending`.
- Deploy with `firebase deploy --only firestore:rules`.

## Features (all implemented)

- **Login:**
  - Gradient welcome screen.
  - "Remember me" saves email and password **encrypted on the device** (`flutter_secure_storage`). Saved accounts appear as one-tap cards in each user's colors, with ✕ to forget.
  - Works with the Google / Samsung Pass autofill flow.
  - Show/hide password toggle.
- **Home (Unpaid):**
  - Gradient header with greeting ("Good evening / Hi, Faria 🌸"), total remaining and count.
  - Expense cards grouped by day (Today / Yesterday / date) with day totals.
  - Tap the avatar circle or long-press to select. A selection bar shows "Select all" and **Pay ৳X**.
  - Tapping your own expense (or any expense, for the admin) opens the edit sheet.
- **Add/Edit sheet:**
  - Big amount field first, gets the focus.
  - Name field with one-tap chips of recent names.
  - +/− qty stepper.
  - Today / Yesterday / Pick date chips.
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
- **Per-user look** (`lib/theme.dart`, `AppStyle` ThemeExtension):
  - Admin: navy→teal gradient, Manrope font, 💼.
  - User 1: blush pink→lavender gradient, Quicksand font, Dancing Script greeting, flower/heart motifs, 🌸.
  - Login screen: violet→pink "welcome" style.

## Code map

```
lib/
  main.dart                 auth stream → MaterialApp themed by signed-in user
  config.dart               adminEmail + isAdminEmail()
  theme.dart                AppStyle (admin / blossom / welcome), ThemeData builder
  format.dart               taka(), qty(), shortName(), friendlyName(), timeGreeting(), dayLabel()
  models/expense.dart       Expense + totalOf()
  models/app_user.dart      AppUser + UserStatus
  services/auth_service.dart
  services/expense_repository.dart   watchUnpaid/Paid/All, add/update/delete, markPaid/markUnpaid, deleteAll, recentNames
  services/user_repository.dart      access requests and approvals
  services/saved_accounts.dart       encrypted "remember me" storage
  services/csv_export.dart           CSV building + share sheet
  screens/login_screen.dart, access_gate.dart, home_screen.dart,
          expense_form.dart, history_screen.dart, admin_screen.dart
  widgets/ui.dart           GradientBackground, GradientHeader, PageHeader, SoftCard,
                            GradientButton, HeaderIconButton, InitialAvatar
firestore.rules, firebase.json, .firebaserc
test/widget_test.dart       formatting, totals, admin check, CSV, names/day labels
```

## Current status / where we left off

1. ✅ Core flow, permissions (11 rule checks), admin panel features and user 1 flow were all **tested on a real Android phone** (Galaxy S23 Ultra) over USB with `adb`.
2. ✅ The premium UI redesign is built and installed on the Android phone. `flutter analyze` is clean and all 5 tests pass.
3. ⏳ **Next:** visually check the redesigned screens on the phone:
   - admin: home, add sheet, history, admin panel
   - user 1: pink theme, waiting screen, then approve
   - saved-account cards on the login screen

   Then polish anything that looks off.
4. ⏳ The redesign changes are **not committed yet**. Commit and push them from the Linux machine before pulling on the Mac.
5. ⏳ Once user 1 is set up, optionally turn off new sign-ups in the Firebase console (Authentication → Settings → User actions). With the approval gate this is now optional, but it's an extra layer.
6. ⏳ The iOS build for user 1 hasn't been done yet. That's what the Mac is for (see below).

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
- Owner-level Firestore access for test setup/cleanup is possible with the Firebase CLI login token (`~/.config/configstore/firebase-tools.json`) against the Firestore REST API. Owner requests bypass the rules.
- Prefix test data with `TEST` so it's easy to clean up. Delete temporary test accounts afterwards.
- The first Gradle build after adding plugins sometimes fails once. Re-running it works.
