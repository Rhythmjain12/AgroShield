# AgroShield

A real-time fire alert and farm safety app for Indian smallholder farmers, built with Flutter and Firebase.

AgroShield monitors NASA satellite fire data, delivers hyperlocal weather intelligence, and provides an AI-powered advisor — all tailored to a farmer's exact location and crops.

---

## What it does

- **Fire alerts** — streams live NASA FIRMS VIIRS hotspots from Firestore; colour-coded map markers by distance (<25 km, 25–50 km, 50–200 km); alert radius circle centred on the farm
- **Weather tab** — hyperlocal current conditions + 5-day forecast via Tomorrow.io; fire-risk advisory derived from temperature, humidity, and wind
- **AI Advisor** — Gemini 1.5 Flash chatbot with full farm context injected (location, crops, weather, nearest fire); bilingual English / Hindi
- **Home dashboard** — live fire status banner, offline cache, weather snapshot, push notification status
- **Push notifications** — FCM device registration; `notifyDevicesOnNewFire` Cloud Function triggers on new fire within user's alert radius; dedup via `fires/{fireId}/notifiedDevices/`; deep-link tap zooms Fire Map to hotspot

---

## Tech stack

| Layer | Technology |
|---|---|
| Mobile app | Flutter 3.41.8 (Android-first) |
| State management | Riverpod 2.x |
| Backend | Firebase Cloud Functions Gen 2 (Node.js) |
| Database | Cloud Firestore |
| Auth | Firebase Auth — Google Sign-In + anonymous guest |
| Maps | Google Maps Flutter |
| Fire data | NASA FIRMS VIIRS_SNPP_NRT (via scheduled Cloud Function) |
| Weather | Tomorrow.io Realtime + Forecast API |
| AI | Google Gemini 1.5 Flash (`google_generative_ai`) |
| Fonts | Fraunces + DM Sans via `google_fonts` |

---

## Project structure

```
AgroShield/
├── agroshield/                  # Flutter app
│   ├── lib/
│   │   ├── screens/
│   │   │   ├── home/            # Fire status dashboard
│   │   │   ├── fire_map/        # Google Maps + FIRMS hotspots
│   │   │   ├── weather/         # Tomorrow.io forecast
│   │   │   ├── advisor/         # Gemini AI chatbot
│   │   │   ├── settings/        # Language, crops, location, account
│   │   │   └── onboarding/      # 6-screen onboarding flow
│   │   ├── models/              # FireContext, WeatherContext, etc.
│   │   ├── providers/           # Riverpod state providers (languageProvider, etc.)
│   │   ├── services/            # Auth, farm profile
│   │   ├── utils/               # Haversine, bearing helpers
│   │   ├── theme/               # AppTheme, FrostedCard
│   │   └── config/
│   │       ├── prefs_keys.dart         # SharedPreferences key constants
│   │       ├── api_keys.dart.example   ← copy to api_keys.dart and fill in keys
│   │       └── api_keys.dart           ← gitignored, contains real keys
└── functions/                   # Firebase Cloud Functions
    ├── index.js                 # All Cloud Functions (fetch, cleanup, notify, score, register)
    ├── FireRiskEngine.js        # Fosberg fire index + vegetation scoring
    └── .env                     # gitignored — API keys + ADMIN_SECRET go here
```

---

## Setup

### Prerequisites
- Flutter SDK ≥ 3.2.0
- Firebase CLI
- A Firebase project (Firestore + Auth + FCM enabled)
- Node.js 18+

### 1. Clone
```bash
git clone https://github.com/Rhythmjain12/AgroShield.git
cd AgroShield
```

### 2. API keys
```bash
cp agroshield/lib/config/api_keys.dart.example agroshield/lib/config/api_keys.dart
```
Open `api_keys.dart` and fill in:
- `kTomorrowApiKey` — from [app.tomorrow.io](https://app.tomorrow.io/development/keys)
- `kGeminiApiKey` — from [aistudio.google.com](https://aistudio.google.com/app/apikey) (free tier)

Create `functions/.env`:
```
NASA_FIRMS_API_KEY=your_key_here
ADMIN_SECRET=generate_a_random_64_char_hex_string
```
- NASA FIRMS key: [firms.modaps.eosdis.nasa.gov](https://firms.modaps.eosdis.nasa.gov/api/area/)
- `ADMIN_SECRET`: required to call the `fetchFiresManual` HTTP endpoint — pass as `x-admin-secret` header.

### 3. Firebase
```bash
# Add your google-services.json to agroshield/android/app/
firebase use --add
```

### 4. Run the app
```bash
cd agroshield
flutter pub get
flutter run
```

### 5. Deploy Cloud Functions
```bash
cd functions
npm install
firebase deploy --only functions
```

---

## Build status

| Feature | Status |
|---|---|
| Onboarding (6 screens) | ✅ Complete |
| Home dashboard | ✅ Complete |
| Weather tab | ✅ Complete |
| Fire Map tab | ✅ Complete |
| NASA FIRMS Cloud Function | ✅ Deployed |
| AI Advisor (Gemini) | ✅ Complete |
| Push notifications | ✅ Complete |
| Settings screen | ✅ Complete |
| Fire relevance scoring engine | ✅ Silent (logs to `scoringLogs/`) |
| Security hardening | ✅ Complete (Firestore rules, auth on HTTP endpoints) |
| Testing & QA | ✅ Complete (Chat 10) |
| Play Store submission | 🔲 Next (Chat 11) |

---

## Design

Dark-first UI built for outdoor readability on budget Android devices. Fraunces 800 for display headings, DM Sans for body text. Green-on-dark colour scheme (`#0B1A0D` base, `#6FCF80` accent). Frosted glass cards throughout using `BackdropFilter`.

---

## License

Personal project — all rights reserved.

© 2025 Rhythm Jain. Source code, design, and features may not be copied, redistributed, or used commercially without explicit written permission.
