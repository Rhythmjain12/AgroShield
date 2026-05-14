# AgroShield — Project Master Reference

**Last updated:** 2026-05-15 (Chat 10.5 — COMPLETE, Kheto rebrand + icon + splash + recenter + brighter background)
**Status:** Chat 11 ready — Play Store submission

---

## Accounts & Credentials

| Service | Account | Notes |
|---|---|---|
| Firebase / Google Cloud | rhythmjain0212@gmail.com | Firebase project owner |
| Tomorrow.io | agroshield2025@gmail.com | Weather API account |
| Google Play Store | TBD | Needed for Chat 11 (submission) |

---

## API Keys & Secrets

| Key | Location in codebase | Current status |
|---|---|---|
| Tomorrow.io API key | `lib/config/api_keys.dart` → `kTomorrowApiKey` | ✅ Live key added (Chat 5) |
| Google Maps Android key | `android/app/src/main/AndroidManifest.xml` | ✅ Migrated to main GCP account + SHA-1 restricted (Chat 10) |
| Gemini API key | `lib/config/api_keys.dart` → `kGeminiApiKey` | ✅ Added (Chat 7) — model: `gemini-2.5-flash-lite` |

---

## Firebase Project

| Field | Value |
|---|---|
| Project name | agrokavach-34bf1 |
| Project ID | agrokavach-34bf1 |
| Android package name | com.agroshield.app |
| Firebase console | https://console.firebase.google.com/project/agrokavach-34bf1 |
| `google-services.json` | `android/app/google-services.json` (gitignored) |
| `firebase_options.dart` | `lib/firebase_options.dart` (committed — key is restricted by package name) |

### Firebase services in use
| Service | Status |
|---|---|
| Firestore | ✅ Active |
| Firebase Auth | ✅ Active (Google Sign-In + anonymous guest) |
| Firebase Analytics | ✅ Active |
| Firebase Cloud Messaging (FCM) | ✅ Active (token registration + `notifyDevicesOnNewFire` deployed Chat 8) |

### Firestore collections
| Collection | Status | Populated by |
|---|---|---|
| `users/{uid}` | ✅ Written on Google Sign-In | `auth_service.dart` |
| `users/{uid}/farmData` | ✅ Written after onboarding | `farm_profile_service.dart` |
| `devices/{deviceId}` | ✅ Written after FCM token registration | `ob6_notifications.dart` |
| `fires/{fireId}` | ✅ Live — deployed + seeded (Chat 6) | NASA FIRMS Cloud Function |
| `fires/{fireId}/notifiedDevices/{deviceId}` | ✅ Written by `notifyDevicesOnNewFire` (Chat 8) | FCM deduplication |
| `scoringLogs/{logId}` | ✅ Written by `scoreFireRelevance` every 6h (Chat 9) | Fire relevance scoring engine |

---

## Flutter Project

| Field | Value |
|---|---|
| Project path | `AgroShield/agroshield/` |
| Flutter SDK | 3.41.8 at `~/development/flutter` |
| Dart SDK | ≥3.2.0 |
| Android package | com.agroshield.app |
| Min SDK | Android 5.0 (API 21) — default Flutter |
| Target SDK | Android 14 (API 34) |

### Key packages (installed)
| Package | Version | Purpose |
|---|---|---|
| `flutter_riverpod` | ^2.5.1 | State management |
| `firebase_core` | ^2.27.1 | Firebase init |
| `firebase_auth` | ^4.19.1 | Authentication |
| `cloud_firestore` | ^4.17.1 | Database |
| `firebase_analytics` | ^10.10.1 | Analytics |
| `firebase_messaging` | ^14.9.1 | Push notifications |
| `google_sign_in` | ^6.2.1 | OAuth |
| `google_maps_flutter` | ^2.6.0 | Maps (Fire Map tab) |
| `geolocator` | ^11.0.0 | GPS location |
| `shared_preferences` | ^2.2.3 | Local storage |
| `permission_handler` | ^11.3.1 | Notification / location permissions |
| `http` | ^1.2.0 | Tomorrow.io API calls |
| `connectivity_plus` | ^5.0.0 | Offline detection |
| `uuid` | ^4.3.3 | Guest device ID generation |
| `intl` | ^0.19.0 | Date formatting |
| `google_fonts` | ^6.2.1 | Fraunces + DM Sans fonts |
| `google_generative_ai` | ^0.4.7 | Gemini AI chatbot (Chat 7) |

---

## SharedPreferences Keys

**All keys are defined as constants in `lib/config/prefs_keys.dart` → `PrefsKeys` class.**
Never use raw string literals — use `PrefsKeys.*` constants.

| Constant | Raw key | Type | Set by | Used by |
|---|---|---|---|---|
| `PrefsKeys.language` | `language` | String (`'en'` / `'hi'`) | ob1_language.dart, settings_screen.dart | All screens, main.dart (provider init) |
| `PrefsKeys.farmLat` | `farm_lat` | double | ob3_farm_location.dart, settings_screen.dart | Home, Weather, Fire Map |
| `PrefsKeys.farmLng` | `farm_lng` | double | ob3_farm_location.dart, settings_screen.dart | Home, Weather, Fire Map |
| `PrefsKeys.alertRadiusKm` | `alert_radius_km` | double | ob5_farm_size.dart, settings_screen.dart | Home, Fire Map, push notifications |
| `PrefsKeys.farmProfile` | `farm_profile` | String (JSON) | `farm_profile_service.dart` | Advisor, Settings |
| `PrefsKeys.notificationGranted` | `notification_granted` | bool | onboarding_flow.dart, settings_screen.dart | Home banner |
| `PrefsKeys.deviceId` | `device_id` | String (UUID) | auth_service.dart | Analytics, FCM |
| `PrefsKeys.authType` | `auth_type` | String | auth_service.dart | Settings (guest check) |
| `PrefsKeys.settingsTooltipShown` | `settings_tooltip_shown` | bool | home_screen.dart | home_screen.dart |
| `PrefsKeys.homeFireCount` | `home_fire_count` | int | home_screen.dart | Home offline cache |
| `PrefsKeys.homeNearestDistance` | `home_nearest_distance` | double | home_screen.dart | Home offline cache |
| `PrefsKeys.homeNearestDirection` | `home_nearest_direction` | String | home_screen.dart | Home offline cache |
| `PrefsKeys.homeFireTimestamp` | `home_fire_timestamp` | int (ms epoch) | home_screen.dart | Home offline cache |

| `PrefsKeys.notificationOpenCount` | `notification_open_count` | int | `main.dart` `_handleNotificationTap` | In-app review gate (Chat 12) |
| `PrefsKeys.lastReviewRequestedTs` | `last_review_requested_ts` | int (ms epoch) | in-app review logic | In-app review gate (Chat 12) |

✅ All raw string literals migrated to `PrefsKeys.*` constants in Chat 10.
⚠️ Two keys above are reserved for Chat 12 — not yet added to `prefs_keys.dart`.

---

## Riverpod Providers

| Provider | Type | File | Set by | Read by |
|---|---|---|---|---|
| `activeTabProvider` | `StateProvider<int>` | `app_shell.dart` | BottomNav / any screen | All screens (tab switching) |
| `fireContextProvider` | `StateNotifierProvider<FireContextNotifier, FireContext?>` | `providers/fire_context_provider.dart` | Fire Map (Chat 6) | Advisor (Chat 7) |
| `weatherContextProvider` | `StateNotifierProvider<WeatherContextNotifier, WeatherContext?>` | `providers/weather_context_provider.dart` | WeatherScreen | HomeScreen, Advisor (Chat 7) |
| `fireMapTargetProvider` | `StateProvider<LatLng?>` | `screens/fire_map/fire_map_screen.dart` | `main.dart` `_FcmWrapper` on notification tap; `home_screen.dart` fire row tap | `fire_map_screen.dart` (`ref.listen` → zoom camera) |
| `fireMapAutoSelectIdProvider` | `StateProvider<String?>` | `screens/fire_map/fire_map_screen.dart` | `home_screen.dart` fire row tap | `fire_map_screen.dart` (`ref.listen` → auto-show info sheet) |
| `languageProvider` | `StateProvider<String>` | `providers/language_provider.dart` | `main.dart` (override from SharedPrefs on cold start), `settings_screen.dart` | Future: any screen needing live language switch |
| `alertRadiusProvider` | `StateProvider<double>` | `providers/alert_radius_provider.dart` | `main.dart` (override from SharedPrefs on cold start), `settings_screen.dart` | `fire_map_screen.dart` (radius circle + filter), `home_screen.dart` (re-subscribes Firestore on change) |

---

## Firestore `fires` Document Schema

```
fires/{fireId}
├── lat: number          // fire latitude
├── lng: number          // fire longitude
├── frp: number          // Fire Radiative Power in MW
├── detectedAt: timestamp
└── source: string       // "NASA_FIRMS"
```

## Firestore `scoringLogs` Document Schema

```
scoringLogs/{autoId}
├── fireId: string           // fires/{fireId} document ID
├── deviceId: string         // devices/{deviceId} document ID
├── distKm: number           // haversine distance farm → fire
├── frp: number              // Fire Radiative Power in MW
├── customFireIndex: number  // Fosberg-derived index (0–100)
├── vegetationScore: number  // static state-level score (50–100)
├── score: number            // weighted final score (0–100)
└── scoredAt: timestamp
```

---

## Cloud Functions deployed

| Function | Trigger | Purpose | Timeout |
|---|---|---|---|
| `scheduledFetchFires` | Cloud Scheduler every 6h | NASA FIRMS → `fires/` | Default |
| `scheduledCleanupFires` | Cloud Scheduler every 6h | Delete fires >3 days old | Default |
| `fetchFiresManual` | HTTP GET | Manual re-seed | 540s |
| `registerUser` | HTTP POST | Write user to Firestore | Default |
| `notifyDevicesOnNewFire` | `onDocumentCreated("fires/{fireId}")` | FCM push to nearby devices (parallel dedup) | Default |
| `scoreFireRelevance` | Cloud Scheduler every 6h | Compute fire relevance scores → `scoringLogs/` | 540s |
| `scheduledCleanupScoringLogs` | Cloud Scheduler every 6h | Delete `scoringLogs` entries >7 days old | Default |

Manual fetch URL: `https://fetchfiresmanual-3o5ditkc5q-uc.a.run.app`
Requires header: `x-admin-secret: <value from functions/.env ADMIN_SECRET>`

---

## Build Order Progress

| # | Feature | Chat | Status |
|---|---|---|---|
| 1 | Flutter setup + navigation shell | 4 | ✅ Done |
| 2 | Firebase Analytics | 4 | ✅ Done |
| 3 | Riverpod shared state store | 4 | ✅ Done |
| 4 | Auth (Google + guest) | 4 | ✅ Done |
| 5 | Onboarding (all 6 screens) | 4 | ✅ Done |
| 6 | Home screen | 5 | ✅ Done |
| 7 | Weather tab | 5 | ✅ Done |
| — | Full visual redesign (all screens) | 5b | ✅ Done |
| 8 | Fire Map tab | 6 | ✅ Done |
| 9 | Push notifications | 8 | ✅ Done |
| 10 | Advisor tab (Gemini) | 7 | ✅ Done |
| 11 | Settings screen | 9 | ✅ Done |
| 12 | Fire relevance scoring engine | 9 | ✅ Done |
| 13 | Testing + QA | 10 | ✅ Done |
| 14 | UI polish + bug fixes (autocomplete, nearby fires, forecast, intensity pins, live radius) | 10.2 | ✅ Done |
| 15 | Additional bug fixes from manual device testing | 10.3 | ✅ Done |
| 16 | Fire row tap fix + info sheet auto-open + forecast nav + pulsing removed | 10.4 | ✅ Done |
| 17 | Kheto rebrand (name, icon, splash, topbar logo) + recenter button + brighter background | 10.5 | ✅ Done |

---

## Android Build Configuration (confirmed working)

| Component | Version | Source |
|---|---|---|
| Gradle wrapper | 8.14 | `gradle-wrapper.properties` |
| Android Gradle Plugin (AGP) | 8.11.1 | `settings.gradle` |
| Kotlin Gradle Plugin (KGP) | 2.3.10 | `settings.gradle` |
| google-services plugin | 4.4.2 | `settings.gradle` |
| Java / JVM target | 17 | `app/build.gradle` |
| `buildscript` block in `android/build.gradle` | **Removed** | Conflicts with `settings.gradle` plugins block |
| `shrinkResources` | `false` (both debug + release) | Required when `minifyEnabled false` |
| Mipmap launcher icons | Added (5 densities) | Copied from Flutter hello_world example |

**Emulator debug SHA-1:** `F1:1C:61:97:9D:34:04:3A:2B:47:A1:81:DB:24:58:1B:EF:F8:63:F8`
- Maps shows "Authorization failure" in emulator logs — not blocking MVP
- Add this SHA-1 to Maps API key restrictions + enable billing before production (Chat 11)

---

## Pre-Chat 10 Checklist (completed)

- [x] Settings screen — all four sections fully implemented
- [x] `scoreFireRelevance` Cloud Function — deployed, runs every 6h
- [x] `notifyDevicesOnNewFire` — dedup parallelised, redeployed
- [x] `FireRiskEngine.js` — static vegetation lookup, `logger.error` (structured logs)
- [x] `languageProvider` — moved to `providers/language_provider.dart`, initialised in `main.dart` from SharedPrefs before `runApp`
- [x] `PrefsKeys` constants class — created at `lib/config/prefs_keys.dart`
- [x] `FarmProfileService` — offline fallback + write-through SharedPrefs cache for signed-in users
- [x] Migrate raw string literals in `home_screen.dart`, `auth_service.dart`, onboarding screens → `PrefsKeys.*` (Chat 10)
- [x] Add `scoringLogs` cleanup Cloud Function (Chat 10)
- [x] Wire `HomeScreen` to watch `languageProvider` for live language switching (Chat 10)
- [x] Code-level QA pass — `flutter analyze` clean, all defects fixed (Chat 10)
- [ ] Live emulator QA pass — run each flow on Android emulator (Chat 11 prerequisite)
- [ ] Firebase console verification — Cloud Function logs, Firestore data integrity (Chat 11 prerequisite)

## Pre-Chat 11 Checklist

### Completed programmatically (Chat 10 extended session)
- [x] Deploy `scheduledCleanupScoringLogs` ✅ Deployed 2026-04-30
- [x] Fix `FireRiskEngine.js` — Tomorrow.io API breaking change: `timesteps=current` removed; migrated to `/v4/weather/realtime` + m/s→km/h conversion ✅ Redeployed
- [x] Clean up 376 stale old-schema fire documents from `fires/` collection ✅ Done
- [x] Firebase QA script — `fires/` schema ✅, `fetchFiresManual` ✅, test fire write/delete ✅
- [x] Scoring engine QA — 117 real fires scored locally, `scoringLogs` schema verified, 9/9 checks pass ✅
- [x] Flutter analyze — 0 issues ✅
- [x] Flutter test — 1/1 pass ✅
- [x] Debug APK built ✅ `build/app/outputs/flutter-apk/app-debug.apk` (176MB)
- [x] Release APK built ✅ `build/app/outputs/flutter-apk/app-release.apk` (59MB, debug-signed)
- [x] Release AAB built ✅ `build/app/outputs/bundle/release/app-release.aab` (48MB, debug-signed)

### Must do manually before Chat 11
- [ ] **Live emulator QA pass** — install `app-debug.apk` on emulator/device, run all Part 2 flows
- [ ] **Firebase console** — verify `scoreFireRelevance` logs after a device registers + function runs
- [ ] **Create production keystore** — see command below; configure in `android/app/build.gradle`
- [ ] **Add SHA-1 to Maps API key** — Google Cloud Console → Credentials → Maps Android key
  - Emulator debug SHA-1: `F1:1C:61:97:9D:34:04:3A:2B:47:A1:81:DB:24:58:1B:EF:F8:63:F8`
  - Add production keystore SHA-1 once created
- [ ] **Enable billing on GCP** — required for Maps Platform production use
- [ ] **Create Google Play Store developer account** — https://play.google.com/console, one-time $25 fee
- [ ] **Re-sign AAB with production keystore** — then submit to Play Store

### Keystore creation command (run once)
```bash
keytool -genkey -v \
  -keystore ~/agroshield-release.keystore \
  -alias agroshield \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname "CN=AgroShield, OU=Dev, O=AgroShield, L=Mumbai, S=Maharashtra, C=IN"
```

Then add to `android/app/build.gradle` before `buildTypes {}`:
```groovy
signingConfigs {
    release {
        keyAlias 'agroshield'
        keyPassword 'YOUR_KEY_PASSWORD'
        storeFile file('/path/to/agroshield-release.keystore')
        storePassword 'YOUR_STORE_PASSWORD'
    }
}
```
And change `signingConfig signingConfigs.debug` → `signingConfig signingConfigs.release` in the release buildType.

---

## Known Decisions & Rationale

| Decision | Rationale |
|---|---|
| Flutter (not Google Stitch HTML) | Build from scratch — Stitch HTML used as visual reference only |
| Direct Tomorrow.io call (no Cloud Function) | MVP simplicity — ≤10 users, no rate limit risk |
| Riverpod over Provider/Bloc | Modern, type-safe, no boilerplate |
| IndexedStack for bottom tabs | Preserves tab state; Weather tab loads in background immediately |
| Haversine client-side filter (not Firestore geoqueries) | MVP dataset tiny; no GeoFlutterFire complexity needed |
| Guest path with UUID | Removes Google account barrier for Ramesh; data lost on reinstall (acceptable) |
| `withValues(alpha:)` not `withOpacity()` | Flutter 3.41.8 deprecation |
| `connectivity_plus 5.0.2` single-result API | Installed version uses `ConnectivityResult` not `List<ConnectivityResult>` |
| Wind speed `_kWindFactor = 3.6` | Assumes Tomorrow.io returns m/s in metric |
| Maps API key unrestricted during dev | Add SHA-1 restrictions at Play Store submission (Chat 11) |
| Kotlin 2.3.10 instead of Flutter-prescribed 2.2.20 | google_maps_flutter_android 2.19.8 pulls kotlin-stdlib 2.3.10 |
| Removed `buildscript` block from `android/build.gradle` | Having both causes AGP version conflict |
| Dark theme only (no light mode) | MVP targets Ramesh on outdoor Android |
| Gemini model: `gemini-2.5-flash-lite` | `gemini-2.0-flash` has `limit: 0` on Agroshield GCP project |
| Advisor reads farm profile via `FarmProfileService` | crops and farmSizeAcres live in `farm_profile` JSON blob, not individual prefs |
| Advisor uses full 5-day forecast | Full `forecast` list already fetched |
| AppShell has no AppBar | Each tab screen manages its own topbar |
| `BackdropFilter` blur flagged with `// PERF:` comments | Expensive on budget Android; sigmaX/Y can be set to 0 |
| `google_fonts` at runtime (not bundled) | MVP acceptable — cached after first load |
| `firebase_options.dart` committed | API key restricted by package name + SHA cert |
| `google-services.json` gitignored | Standard practice |
| Vegetation score: static state-level lookup table | Deferred API decision resolved in Chat 9 — no viable free vegetation API exists for India |
| `FarmProfileService.saveProfile` write-through to SharedPrefs | Offline fallback — signed-in users see real data even if Firestore unreachable on first open |
| `languageProvider` initialised in `main()` before `runApp` | Prevents Hindi flash on cold start when screens watch the provider |
| `PrefsKeys` constants class | Single source of truth for SharedPrefs keys — typo = compile error, not silent null |
| `scoreFireRelevance` lazy-caches `computeFireRisk` per fire | One Tomorrow.io call per fire, reused across all devices in radius |
| `scoreFireRelevance` timeoutSeconds: 540 | Default 60s too short if fire dataset is large |
| `notifyDevicesOnNewFire` dedup reads parallelised | Sequential reads O(n) → parallel O(1) round-trips |
| `scoringLogs` backend-only in MVP | Score not surfaced in Flutter UI until v1.1 validation |
| In-app review: trigger after 3rd notification open, not every open | Avoids spamming user; Google also throttles independently. Gate: `notificationOpenCount >= 3 && daysSinceLastRequest > 60`. Track via `PrefsKeys.lastReviewRequestedTs`. Scheduled for Chat 12. |
| Chatbot `chatbot_message_sent` analytics event deferred to Chat 12 | Needed for tertiary metric (≥1 message/user/week) but not blocking launch |
| SoilGrids (ISRIC) replaces static vegetation lookup | Free, 250m resolution, covers India; clay/sand/SOC → fire-spread score; static state-level lookup retained as fallback on timeout |
| `soilSource` field logged to `scoringLogs` | Tracks whether live SoilGrids data or static fallback was used — feeds v1.1 validation analysis |
| Fire map display filtered to last 36h | Fires not re-detected in 36h likely extinguished; Firestore cleanup window is 48h (safety buffer) |
| `dayRange` reduced from 3 to 2 in FIRMS fetch | Aligns with 48h cleanup window; reduces redundant idempotent writes |
| Release APK signing reverts to debug key | Production keystore not yet created — Chat 11 task. `build.gradle` TODO comment left in place. |
| `onboardingComplete` added to `PrefsKeys` in Chat 10 | Key was missing from constants class; `app.dart` and `onboarding_flow.dart` used raw string |
| `HomeScreen._language` set from `languageProvider` in `build()` | Minimal change — sets existing field at top of `build()`, all helper methods pick it up without signature changes |
| `scheduledCleanupScoringLogs` uses module-level `BATCH_SIZE = 400` | Consistent with `scheduledFetchFires`; `cleanupOldFires` defined its own local — not fixed to avoid unrelated change |
| `FireRiskEngine.js` migrated to `/v4/weather/realtime` endpoint | Tomorrow.io removed `timesteps=current` from forecast endpoint. Realtime returns `response.data.data.values`. Also fixed: windSpeed returned in m/s now correctly multiplied by 3.6 to get km/h |
| Old-format fire documents deleted (Chat 10 extended) | 376 documents written by a pre-Chat 6 dev version used raw CSV field names (`latitude`/`longitude`). `cleanupOldFires` wouldn't delete them (no `detectedAt` field). One-time cleanup via `cleanup_old_fires.js` |
| Release build uses `signingConfig signingConfigs.debug` | Intentional for dev/QA. Must switch to production keystore before Play Store submission |
| `HitTestBehavior.opaque` on fire row GestureDetector | Default `deferToChild` only registers taps on visible child pixels — transparent Padding areas are missed on real devices. `opaque` makes the full bounding box tappable. |
| `fireMapAutoSelectIdProvider` reset to null inside `ref.listen` callback | Prevents the provider from re-triggering the sheet on subsequent rebuilds. Safe to call `ref.read` inside a `ref.listen` callback — only `ref.watch` and `ref.listen` itself require `build()`. |
| `addPostFrameCallback` for auto-show fire sheet | `showModalBottomSheet` called synchronously inside `ref.listen` races with the tab-switch animation. Deferring to the next frame lets the route transition complete first. |

---

## Personas (reference)

**Ramesh** — Primary user. Male, 44, Vidarbha Maharashtra. Cotton + soybean, 4 acres. Android user, WhatsApp-comfortable, limited English literacy. Checks Home screen daily in fire season.

**Priya** — Secondary user. Female, 24, Ramesh's daughter. Smartphone-confident. Discovers and installs apps for family.

---

## Success Metrics (MVP target)

| Metric | Target |
|---|---|
| % users opening app within 2h of fire notification | >50% |
| % users opening app within 24h of fire notification | >70% |
| Chatbot questions per active user per week | ≥1 |
| False positive notification rate | <20% |
| Real downloads with qualitative feedback | 10 downloads, 5 feedback responses |
