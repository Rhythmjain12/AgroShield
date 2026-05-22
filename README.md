<p align="center">
  <img src="docs/screenshots/hero.jpg" alt="Kheto — fire detected nearby" width="600"/>
</p>

<h1 align="center">Kheto</h1>

<p align="center">
  <strong>Live fire alerts for Indian farmers.</strong><br/>
  Real-time NASA satellite fire data, hyperlocal weather, and a bilingual AI advisor — built for smallholder farms.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Play_Store-Closed_Beta-6FCF80?style=flat-square&logo=googleplay&logoColor=white" alt="Play Store"/>
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?style=flat-square&logo=android&logoColor=white" alt="Android"/>
  <img src="https://img.shields.io/badge/Flutter-3.41-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Firebase-Cloud_Functions-FFCA28?style=flat-square&logo=firebase&logoColor=black" alt="Firebase"/>
</p>

---

## The problem

Indian smallholder farmers get **state-level fire alerts**. A fire 80 km away in the same state triggers the same notification as one 3 km away upwind.

So farmers either panic at every alert, or — more dangerously — learn to ignore them.

Kheto fixes that. Every alert is anchored to the user's exact farm location, with distance, direction, and intensity made explicit.

---

## Who it's for

**Primary persona — Ramesh, 44, Vidarbha, Maharashtra.** Cotton + soybean, 4 acres. Android user, WhatsApp-comfortable, limited English literacy. Checks the app daily in fire season.

**Secondary — Priya, 24,** his daughter. Smartphone-confident. Installs and configures the app for the household.

> **Honest note on research:** Personas are working hypotheses, not formally validated against a user interview cohort. They were built from secondary research and informal conversations. Validating them against real beta users is one explicit goal of closed testing.

---

## Competitive landscape

| Competitor | What they do | Where they fall short |
|---|---|---|
| FireAlert (Plant-for-the-Planet) | NASA FIRMS data → smartphone alerts | Not farm-specific. No crop context. No agricultural advisory layer. |
| Farmer.Chat (Digital Green + OpenAI) | AI agricultural advisor for extension agents | No fire risk data. Targets extension agents, not farmers directly. |
| AgriApp | All-in-one farming platform (weather, advisory, soil, marketplace) | No fire data. Broad focus → generic experience. |
| Meghdoot (Govt. of India) | District-level weather + crop advisories, twice a week | Not real-time. District-level granularity. No fire data. |
| Farmonaut | Satellite crop health monitoring, weather | Enterprise / agribusiness focus. No fire alerts. |

The unoccupied intersection: **a notification that combines a specific farm's coordinates with live fire proximity and a crop-aware advisory in one product.** FireAlert doesn't know what crop you grow; Farmer.Chat doesn't know there's a fire 8 km northeast.

---

## What it does

| Problem | Solution | Why this approach |
|---|---|---|
| Farmers can't tell if an alert means their farm | Notifications only fire within a user-configured radius (default 50 km, adjustable 10–150 km) | Replaces blanket state-level alerts with a per-farm geofence the user controls |
| State-level data hides which fire matters | Fire map with colour-coded markers by intensity (FRP), farm at the centre | Visual hierarchy makes "which one threatens me" answerable in 2 seconds |
| Weather forecasts use English meteorology jargon | Tomorrow.io data wrapped in farmer-language ("hot and dry, elevated fire risk") | Ramesh doesn't need humidity in %; he needs "should I burn stubble today" |
| Farmers want to ask follow-up questions but Hindi support in chatbots is poor | Gemini AI advisor with full farm context auto-injected, Hindi-first system prompt | Removes the cold-start ("what do I ask?") and removes the language barrier in the same step |
| Many target users are uncomfortable creating accounts | Anonymous guest path with device-UUID identity | Removes the single biggest install-funnel drop-off; trade-off: data loss on reinstall (acceptable for MVP) |

---

## Screenshots

<table>
  <tr>
    <td><img src="docs/screenshots/firemap.jpg" alt="Fire Map"/></td>
    <td><img src="docs/screenshots/advisor.jpg" alt="AI Advisor"/></td>
    <td><img src="docs/screenshots/weather.jpg" alt="Weather"/></td>
  </tr>
  <tr>
    <td align="center"><sub>Live NASA FIRMS hotspots</sub></td>
    <td align="center"><sub>Bilingual AI advisor</sub></td>
    <td align="center"><sub>Weather, no jargon</sub></td>
  </tr>
</table>

---

## Try it

Kheto is currently in **closed beta** on the Google Play Store.

📩 Email **agroshield2025@gmail.com** with the Google account you'll use on the Play Store. You'll get an opt-in link within 24 hours.

---

## Success metrics

These are the numbers Kheto's MVP is being judged against, set before launch:

| Metric | Target | Why this target |
|---|---|---|
| % testers opening app within 2h of fire notification | > 50% | Below this, the notification isn't doing its job |
| % testers opening app within 24h of fire notification | > 70% | Trust signal — users believe the alert is worth checking |
| AI advisor messages per active user per week | ≥ 1 | Indicates the advisor is solving a real question, not a novelty |
| False positive notification rate (per qualitative feedback) | < 20% | Above this, farmers learn to ignore — the same trap state-level alerts fall into |
| Real downloads + qualitative feedback responses | 10 / 5 | Minimum viable evidence to decide whether to invest in a v2 |

Metrics are wired through Firebase Analytics.

---

## Product decisions

Six decisions I made and would defend in an interview.

### 1. The fire-relevance scoring engine is built — but switched off

The engine takes raw satellite data and converts it into "this fire is/isn't a real threat to your farm." It runs silently, logs predictions to `scoringLogs/`, and surfaces nothing in the UI. Users see raw NASA FIRMS proximity instead.

**Why:** A false negative in fire safety — telling a farmer "low risk" when a fire reaches their field — destroys trust permanently. The engine needs validation against real fire events before it can become an alerting mechanism. Closed beta is where that validation dataset gets built.

### 2. Guest mode despite data loss on reinstall

Anonymous device-UUID path is offered alongside Google Sign-In, even though guest users lose their data on reinstall.

**Why:** Forcing authentication at onboarding is a well-known drop-off point in consumer apps, especially for older rural users who may not remember a Gmail password. For MVP, the metrics that matter (notification response, chatbot usage, map engagement) are all trackable via anonymous device ID through Firebase Analytics. Cross-device sync and longitudinal identity can wait for v1.1. Friction at install costs more than data loss on the rare reinstall.

### 3. Hindi + English only — not 6+ Indian languages

MVP supports only Hindi and English, despite India having 22 official languages and many farmer-targeted apps offering more.

**Why:** Adding Marathi, Punjabi, Tamil, etc. correctly requires native-speaker review for agricultural terms — auto-translation produces farming-specific errors that erode trust. Doing this badly is worse than doing it later. Hindi + English is the smallest set that covers the primary target user (Vidarbha cotton/soybean farmers) without compromising on translation quality. Full vernacular support is the top-priority post-MVP item.

### 4. Live soil data (SoilGrids) with a static state-level fallback

The fire scoring engine fetches live soil composition (clay %, sand %, soil organic carbon) for each fire location from SoilGrids (ISRIC) at 250 m resolution. A static state-level lookup is retained as a fallback when SoilGrids times out or errors.

**Why:** Soil composition meaningfully affects how fire spreads — sandy + organic soil burns differently from clay-heavy soil. Initial decision was to ship with a static lookup because no obvious free vegetation API existed. SoilGrids was discovered later and adopted because it covers India at usable resolution. Keeping the static fallback means scoring never silently breaks if the external API goes down. Each `scoringLogs` row records which source was used (`soilSource: 'soilgrids' | 'static'`) for later validation.

### 5. Dark theme only — no light mode

The app ships dark-theme only, ignoring system theme preferences.

**Why:** Ramesh uses the app outdoors in bright sunlight on a budget Android with a dim screen. Dark-on-green high-contrast text is readable in conditions where light mode washes out. The cost of a "settings → theme" toggle isn't worth the rare indoor user.

### 6. Direct Tomorrow.io API call from the app — not via a Cloud Function

Weather requests go straight from the device to Tomorrow.io, instead of being proxied through a server.

**Why:** MVP has ≤ 10 active users. A proxy Cloud Function adds latency, cost, and a deploy surface for zero benefit at this scale. Decision is documented as one to reverse when user count crosses ~500 (rate limits become real then).

---

## What's intentionally NOT in v1

Most of what gets cut signals more than what gets built.

| Cut | Why |
|---|---|
| Live in-app fire risk score | Validation dataset doesn't exist yet (see Decision #1) |
| Crop disease detection | Not the wedge problem — Kheto's promise is fire, not omnibus farm assistant |
| Crop price monitor | Different user job, different data sources — deserves its own product |
| Marketplace | Distribution-first feature, premature without trust |
| iOS app | Target user demographic is overwhelmingly Android — building for iOS first would optimise for the wrong audience |
| More than 2 languages | See Decision #3 |
| Voice input | Worth doing well in v1.1; not worth doing badly now |
| Push notifications for weather changes | Notification budget is for fires only — anything else dilutes the channel |

---

## Roadmap

| Stage | Item | Gate to next stage |
|---|---|---|
| **Now** | Closed beta, v1.0.2+3 live | 12 testers opted in + 14 days on track |
| **Next** | Apply for production access; collect 5 qualitative interviews | First interview cohort completed |
| **After validation** | Promote scoring engine from silent → visible on Home screen | Scoring predictions match observed fire spread across ≥ 1 fire season |
| **v1.1** | Marathi + Punjabi, voice input | Scoring engine live (so language work doesn't compound with feature work) |
| **v2 (maybe)** | Crop price monitor | Decision conditional on whether farmers ask for it during interviews |

---

## Tech stack

| Layer | Technology |
|---|---|
| Mobile | Flutter 3.41 (Android-first), Riverpod 2.x |
| Backend | Firebase Cloud Functions (Node.js 18, Gen 2) |
| Database | Cloud Firestore |
| Auth | Firebase Auth — Google Sign-In + anonymous guest |
| Maps | Google Maps Flutter |
| Fire data | NASA FIRMS VIIRS_SNPP_NRT |
| Weather | Tomorrow.io Realtime + Forecast |
| AI | Google Gemini 2.5 Flash Lite |
| Push | Firebase Cloud Messaging |

---

## Local development

### Prerequisites
- Flutter SDK ≥ 3.2.0
- Firebase CLI
- A Firebase project with Firestore, Auth, and FCM enabled
- Node.js 18+

### 1. Clone & install
```bash
git clone https://github.com/Rhythmjain12/Kheto.git
cd Kheto/agroshield
flutter pub get
```

### 2. Add API keys
```bash
cp lib/config/api_keys.dart.example lib/config/api_keys.dart
```
Fill in `kTomorrowApiKey` ([app.tomorrow.io](https://app.tomorrow.io/development/keys)) and `kGeminiApiKey` ([aistudio.google.com](https://aistudio.google.com/app/apikey)).

For Cloud Functions, create `functions/.env`:
```
NASA_FIRMS_API_KEY=your_key_here
ADMIN_SECRET=generate_a_random_64_char_hex_string
```

### 3. Firebase setup
Add `google-services.json` to `agroshield/android/app/`, then:
```bash
firebase use --add
cd functions && npm install
firebase deploy --only functions
```

### 4. Run
```bash
cd agroshield && flutter run
```

---

## License

© 2026 Rhythm Jain. All rights reserved. Source code, design, and features may not be copied, redistributed, or used commercially without explicit written permission.

---

<p align="center">
  <em>Built in 3 months as a solo project, with one constraint:<br/>ship the smallest version that's safe to put in front of a real farmer. The rest waits for validation.</em>
</p>
