# HANDOFF — Chat 11
**Date:** 2026-05-15
**Status:** Complete — production build ready, all critical bugs fixed, Play Store screenshots next

---

## What was accomplished

### 1. Production keystore + signed release build
- Created `agroshield-release.keystore` (PKCS12, RSA 2048, valid to 2053, Delhi)
- Configured `android/key.properties` (gitignored) — passwords in user's Locked Notes
- `android/app/build.gradle` `release` buildType now uses `signingConfig signingConfigs.release`
- Production SHA-1 added to Maps Android API key in GCP
- Signed release AAB: `agroshield/build/app/outputs/bundle/release/app-release.aab` (63.7MB) ✅
- Verified with `keytool -printcert` — CN=AgroShield, Delhi ✅

### 2. Firestore cost fix
- `functions/index.js` — `dayRange` reduced `"2"` → `"1"` in `fetchAndStoreFires`
- `scoreFireRelevance` now only scores fires detected in the last 6h (was scoring all fires in collection)
- Result: ~8,500 writes/day + ~18,000 reads/day → well within Firestore free tier (was 31,563 writes, 63,632 reads)
- Deployed via `firebase deploy --only functions`

### 3. Bug fixes (5 user-reported + 6 architectural)
See PLAY_STORE_TASKS.md for complete list. Key fixes:

**BUG-1** `onboarding_flow.dart` — language selection not carrying through to screens 2–6
- Fix: `setState(() => _data.language = lang)` in Ob1 `onSelect` callback

**BUG-2** `home_screen.dart` — home banner showed "safe" while fire map showed fires
- Fix: `if (!snapshot.metadata.isFromCache) _isLoading = false` — defer loading clear until server data

**BUG-3/4** `home_screen.dart` — fire count mismatch + nearby fires list hidden
- Root cause: subscription restart on radius change caused race; list gated on `!_isLoading`
- Fix: `_allFires` stores all fires ≤200km; `_fires` is a getter (radius + 36h filter); no subscription restart on radius change; list renders whenever `_fires.isNotEmpty`

**BUG-5** `settings_screen.dart` — no logout button for guest users
- Fix: `_SignOutRow` now always shown; clears `onboardingComplete` pref on tap

**Architectural (6 fixes):**
- `fire_map_screen.dart`, `weather_screen.dart`, `advisor_screen.dart` — replaced 9 raw string literals with `PrefsKeys.*` constants
- `ob6_notifications.dart` — guard against empty `deviceId` before Firestore write (FCM silent failure)
- `farm_profile_service.dart` — guest `saveProfile` now merges instead of replacing (prevented partial saves from erasing farmLat/farmLng)
- `onboarding_flow.dart` — changed to `ConsumerStatefulWidget`; `_complete()` now syncs `languageProvider`, `alertRadiusProvider`, `farmLocationProvider`
- `fire_map_screen.dart` — added `isFromCache` guard to prevent false "no fires" flash
- Added `providers/farm_location_provider.dart` (`StateProvider<FarmLocation>`); wired in `main.dart`, `settings_screen.dart`, `onboarding_flow.dart`, `home_screen.dart`, `fire_map_screen.dart` — farm location changes now propagate to live screens immediately

---

## Current app state (as of end of Chat 11)

- App installed on Pixel 3 XL with all fixes
- All known bugs fixed
- Signed release APK/AAB ready
- `PLAY_STORE_TASKS.md` documents all remaining Play Store tasks

---

## Files changed in Chat 11

| File | Change |
|---|---|
| `android/app/build.gradle` | Release signing config |
| `android/key.properties` | Created (gitignored) |
| `functions/index.js` | dayRange fix + scoreFireRelevance time filter |
| `lib/screens/onboarding/onboarding_flow.dart` | BUG-1 fix + ConsumerStatefulWidget + provider sync in _complete() |
| `lib/screens/home/home_screen.dart` | BUG-2/3/4 fixes + _allFires/_fires getter pattern + farmLocationProvider listener |
| `lib/screens/settings/settings_screen.dart` | BUG-5 sign-out for guests + farmLocationProvider write |
| `lib/screens/fire_map/fire_map_screen.dart` | PrefsKeys fix + isFromCache guard + farmLocationProvider listener |
| `lib/screens/weather/weather_screen.dart` | PrefsKeys fix |
| `lib/screens/advisor/advisor_screen.dart` | PrefsKeys fix |
| `lib/screens/onboarding/ob6_notifications.dart` | Empty deviceId guard |
| `lib/services/farm_profile_service.dart` | Guest saveProfile merge fix |
| `lib/providers/farm_location_provider.dart` | **New file** — FarmLocation provider |
| `lib/main.dart` | farmLocationProvider override added |
| `PLAY_STORE_TASKS.md` | **New file** — full Play Store task tracking |
| `PROJECT_MASTER.md` | Updated to Chat 11 state |

---

## What's next (Chat 12)

**Goal:** Capture and edit Play Store screenshots, write store listing copy, create Privacy Policy, submit to internal testing track.

### Immediate next steps
1. **Reset app** on Pixel 3 XL (`adb shell pm clear com.agroshield.app`) and do full onboarding to reach the "ideal" state for screenshots
2. **Capture 8 screenshots** via ADB from Pixel 3 XL:
   - Home screen — warning/danger state (fires present)
   - Fire map — with fire pins visible
   - Fire map — bottom sheet open on a fire pin
   - Weather tab
   - Advisor tab — conversation in progress
   - Home screen — safe state
   - Onboarding language selection
   - Onboarding farm location
3. **Edit screenshots** — device frame, clean background, optional caption overlay
4. **Feature graphic** — 1024×500px banner for Play Store listing
5. **Store listing copy** — title (max 30 chars), short desc (80 chars), full desc (4000 chars, replace "AgroShield" → "Kheto"), What's New
6. **Privacy Policy** — write and host (Google Doc / GitHub Pages / Notion)
7. **Play Console** — create account ($25), create app listing, fill metadata
8. **Upload AAB** to internal testing track

### Key file locations
- Signed AAB: `agroshield/build/app/outputs/bundle/release/app-release.aab`
- Signed APK: `agroshield/build/app/outputs/flutter-apk/app-release.apk`
- Package: `com.agroshield.app`
- Version: `1.0.1+2` (pubspec.yaml)
- Keystore: `android/app/agroshield-release.keystore` (local only, never push)
- Play Store task list: `PLAY_STORE_TASKS.md`

### Start-of-chat-12 prompt
```
This is Chat 12 of Kheto (formerly AgroShield) development.

Read HANDOFF_chat11.md and PROJECT_MASTER.md before doing anything.

GOAL: Play Store screenshots + store listing + Privacy Policy + internal testing track submission.

Start by installing the latest signed APK on the Pixel 3 XL and resetting app data so we can capture screenshots from a clean onboarding state.

Flutter is at ~/development/flutter/bin/flutter
ADB is at ~/Library/Android/sdk/platform-tools/adb
Device serial: 8BAY0W9B1
```
