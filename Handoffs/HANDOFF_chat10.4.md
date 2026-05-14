# AgroShield — Chat 10.4 Handoff

**Date:** 2026-05-14
**Session:** Chat 10.4 — Bug Fixes (Fire Row Tap, Info Sheet, Forecast Nav, Pulsing Banner)
**Next session:** Chat 11 — Play Store Submission

---

## What was fixed in Chat 10.4

### 1. Fire Row Tap — Full Row Now Tappable (HitTestBehavior.opaque)

**Problem:** Tapping a fire in the "Nearby Fires" list on the Home screen only registered when the user tapped directly on visible content (the coloured dot or text). Tapping on the transparent padding area around those elements did nothing.

**Root cause:** `GestureDetector` default hit-test behaviour is `HitTestBehavior.deferToChild` — it only passes taps to child widgets. The `Padding` widget wrapping the row content has no visual surface, so taps in those areas were silently swallowed.

**Fix:** Added `behavior: HitTestBehavior.opaque` to the `GestureDetector` in `_buildFireRow`. The entire bounding box of the row now registers taps, regardless of where within the row the user taps.

**File:** `lib/screens/home/home_screen.dart`

**Note:** This bug was present since Chat 10.2 when nearby fires were introduced. It was hard to diagnose because on emulators you click precisely on content; on a real device with a fingertip you often tap padding.

---

### 2. Fire Info Sheet — Auto-Opens When Tapping a Nearby Fire from Home Screen

**Problem:** Tapping a fire row redirected to the Fire Map tab and zoomed to the fire location, but did not open the fire's info sheet. The user had to manually tap the fire marker on the map to see details.

**Fix:**
- Added `fireMapAutoSelectIdProvider = StateProvider<String?>` in `fire_map_screen.dart`
- `_buildFireRow` in `home_screen.dart` now sets this provider with `fire.id` alongside the existing `fireMapTargetProvider` zoom
- `FireMapScreen.build()` registers a `ref.listen` on `fireMapAutoSelectIdProvider`; when a non-null ID arrives:
  1. Resets the provider to null immediately (prevents double-trigger on rebuild)
  2. Schedules `WidgetsBinding.instance.addPostFrameCallback` to call `_showFireSheet` with the matched fire

**Why addPostFrameCallback:** Allows the tab switch animation to complete before the bottom sheet presents. Calling `showModalBottomSheet` synchronously inside `ref.listen` risks presenting before the route transition settles.

**Why ref.listen in build():** Riverpod assertion — `ref.listen` MUST be called inside `build()` for `ConsumerStatefulWidget`. Calling it in `initState()` throws: *"ref.listen can only be used within the build method of a ConsumerWidget"*.

**Files changed:**
- `lib/screens/fire_map/fire_map_screen.dart` — `fireMapAutoSelectIdProvider` declaration + `ref.listen` in `build()`
- `lib/screens/home/home_screen.dart` — set provider in `_buildFireRow` onTap; import updated to named exports

---

### 3. Forecast Cards — Now Navigate to Weather Tab

**Problem:** The 2-day forecast section on the Home screen had no tap interaction. Users expected tapping it to open the full weather forecast.

**Fix:** Wrapped `_buildTwoDayForecast`'s return `Column` in a `GestureDetector(onTap: () => _switchTab(2))`.

**File:** `lib/screens/home/home_screen.dart`

---

### 4. Fire Banner Pulsing — Removed

**Problem:** The fire status banner (warning and danger states) pulsed in scale via a `ScaleTransition`, making the first widget on the home screen visually distracting — it looked like a bug rather than an intentional effect.

**Fix:** Removed `ScaleTransition`, `AnimationController _pulseCtrl`, `Animation<double> _pulse`, and `TickerProviderStateMixin` from `_HomeScreenState`. The `final bool animating` variable and its switch-case assignments were also removed.

**File:** `lib/screens/home/home_screen.dart`

**Note:** `_PulseDot` (the small animated dot inside the pill) is a separate `StatefulWidget` with its own `SingleTickerProviderStateMixin` — this was NOT removed. Only the full-banner ScaleTransition is gone.

---

## Files Changed in Chat 10.4

| File | Change |
|------|--------|
| `lib/screens/fire_map/fire_map_screen.dart` | Added `fireMapAutoSelectIdProvider`; `ref.listen` in `build()` to auto-show info sheet |
| `lib/screens/home/home_screen.dart` | `HitTestBehavior.opaque` on fire row; set `fireMapAutoSelectIdProvider` on tap; forecast GestureDetector; removed pulsing (ScaleTransition + TickerProviderStateMixin) |

---

## Git State at End of Chat 10.4

**Branch:** `main`
**Last commit:** `21dae71` — "fix: fire row tap, info sheet, forecast nav, remove pulsing banner"
**Status:** All changes committed and pushed ✅

---

## Riverpod Providers — Full List (updated)

| Provider | Type | File | Set by | Read by |
|---|---|---|---|---|
| `activeTabProvider` | `StateProvider<int>` | `app_shell.dart` | BottomNav / any screen | All screens (tab switching) |
| `fireContextProvider` | `StateNotifierProvider<FireContextNotifier, FireContext?>` | `providers/fire_context_provider.dart` | Fire Map ("Ask Advisor" tap) | Advisor |
| `weatherContextProvider` | `StateNotifierProvider<WeatherContextNotifier, WeatherContext?>` | `providers/weather_context_provider.dart` | WeatherScreen | HomeScreen, Advisor |
| `fireMapTargetProvider` | `StateProvider<LatLng?>` | `screens/fire_map/fire_map_screen.dart` | `main.dart` FCM tap handler; HomeScreen fire row tap | `fire_map_screen.dart` (`ref.listen` → zoom camera) |
| `fireMapAutoSelectIdProvider` | `StateProvider<String?>` | `screens/fire_map/fire_map_screen.dart` | HomeScreen fire row tap | `fire_map_screen.dart` (`ref.listen` → auto-show info sheet) |
| `languageProvider` | `StateProvider<String>` | `providers/language_provider.dart` | `main.dart` on cold start; `settings_screen.dart` | All screens in `build()` |
| `alertRadiusProvider` | `StateProvider<double>` | `providers/alert_radius_provider.dart` | `main.dart` on cold start; `settings_screen.dart` | `fire_map_screen.dart`; `home_screen.dart` (re-subscribes Firestore) |

---

## Known Issues / Deferred

- `BackdropFilter` blur is still active (`sigmaX: 12, sigmaY: 12`) on the weather strip and stat cards. These are expensive on budget Android — a `// PERF:` comment is in place. Can be set to `sigmaX: 0, sigmaY: 0` if performance is a concern on low-end devices. Deferred post-MVP.
- FCM end-to-end test (fire created → notification received on locked phone) still unverified on a physical device.

---

## Pre-Chat 11 Checklist

- [ ] Create Google Play Developer account — https://play.google.com/console ($25 one-time)
- [ ] Create production keystore (command in PROJECT_MASTER.md) and wire into `build.gradle`
- [ ] Add release keystore SHA-1 to Maps API key restrictions (Google Cloud Console)
- [ ] Enable billing on GCP (required for Maps Platform in production)
- [ ] Build release AAB signed with production keystore
- [ ] Prepare Play Store listing: screenshots, short/full description, content rating questionnaire

---

## Architecture State (end of Chat 10.4)

```
Flutter app (Android)
├── Riverpod providers
│   ├── languageProvider          (StateProvider<String>) — watched in build() by all tabs
│   ├── alertRadiusProvider       (StateProvider<double>) — watched by FireMap; listened by Home
│   ├── weatherContextProvider    (StateNotifierProvider)
│   ├── fireContextProvider       (StateNotifierProvider)
│   ├── activeTabProvider         (StateProvider<int>)
│   ├── fireMapTargetProvider     (StateProvider<LatLng?>) — zoom camera on notification/home tap
│   └── fireMapAutoSelectIdProvider (StateProvider<String?>) — auto-show info sheet on home fire tap
├── SharedPreferences
│   └── PrefsKeys.* constants
├── Firestore listeners
│   ├── HomeScreen — fires collection, re-subscribes on radius change; shows cache while loading
│   └── FireMapScreen — fires collection, 200km cap; filtered by _recentFires (36h) + _displayedFires (radius)
└── FCM
    ├── onTokenRefresh → updates devices/{deviceId}.fcmToken
    ├── onMessage → analytics log
    └── onMessageOpenedApp / getInitialMessage → fire map zoom (fireMapTargetProvider)
```
