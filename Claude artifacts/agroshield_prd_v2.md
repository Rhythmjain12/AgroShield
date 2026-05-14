# AgroShield — Product Requirements Document
**Version:** 1.4 (MVP — updated post Chat 10.4 delivery)
**Status:** Bug fixes complete — Play Store submission next (Chat 11)
**Author:** Rhythm Jain

---

## Changelog
- v1.1: Updated onboarding (guest path added, crop picker revised, farm size range corrected), nav structure finalised (4 bottom tabs + top-right settings), home screen content defined.
- v1.2: Tech stack updated to reflect final delivered implementation. Section 7 corrected (was placeholder from Chat 2, now reflects actual build).
- v1.3: Home screen updated (nearby fires list + 2-day forecast). Fire Map updated (intensity-based pin colours, refresh button, radius toggle, clarified timestamp).
- v1.4: Bug fixes — fire row full-area tap (HitTestBehavior.opaque), fire info sheet auto-opens from home screen tap, forecast cards navigate to weather tab, pulsing banner animation removed.

---

## 1. Problem Statement

Indian smallholder farmers in fire-prone regions receive state-level fire alerts that are too broad to act on. A fire 80km away in the same state triggers the same government alert as one 3km away upwind. Farmers either panic unnecessarily or — more dangerously — learn to ignore all alerts entirely.

No existing tool answers the question a farmer actually needs answered: **"Is this fire a real threat to my specific farm, right now?"**

---

## 2. Target Users

### Primary — Ramesh (The Farmer)
Male, 44, Vidarbha region Maharashtra. Grows cotton and soybean on 4 acres. Android smartphone user, comfortable with WhatsApp and visual apps. Does not read English confidently. Has no reliable source of fire information today. Makes field safety decisions based on word of mouth or visible smoke.

**Job-to-be-done:** "When fire season starts, tell me if my field is actually in danger today so I can decide whether to stay and protect it or send my family away."

### Secondary — Priya (The Installer)
Female, 24, Ramesh's daughter. Smartphone-confident. Discovers, evaluates, and installs apps for the family. Controls whether AgroShield enters the household. Not the daily user.

**Job-to-be-done:** "Find something reliable that keeps my father informed about fire risk so I don't have to worry about him during season when I'm not home."

### Onboarding design principle
The onboarding must be completable by Ramesh without assistance. If Ramesh cannot complete onboarding independently, the onboarding is broken — not the user. This means: icon-led UI, visual crop picker (images not text), GPS auto-collection, zero typed input required.

---

## 3. MVP Feature Scope

### 3.1 Onboarding (6 screens, runs once)

**Screen 1 — Language selection**
First screen after install. Two large buttons: English, हिंदी. Language stored locally and changeable in Settings.

**Screen 2 — Sign-in**
Two options: Google Sign-In (primary, prominent) and "Continue without account" (secondary, smaller).
- Google path: auto-collects name and profile photo via OAuth. No additional data extracted from Google profile.
- Guest path: anonymous device ID generated and stored locally. All farm data stored on-device. If user uninstalls and reinstalls, onboarding repeats. No sync across devices.
- Analytics: both paths fire anonymous event data via Firebase Analytics using device ID. Core MVP metrics (notification response, chatbot usage, map engagement) are trackable on both paths.
- No phone number OTP, no manual email/password in MVP.

**Screen 3 — Farm location**
GPS auto-detects current location, centres map. Instructional prompt (icon + one line): "Drag the pin to your farm." User confirms with large button. Both current location and farm location stored separately — farmer may check app from town; fire risk must reflect farm location, not current location.

**Screen 4 — Crop picker**
Visual grid of crop icons (cotton, wheat, soybean, rice, sugarcane, maize, other). Crop name below each icon in selected language. Multi-select. Selection framed as recommended, not required — user can proceed with no crop selected.
- If no crop selected: chatbot advises using weather and fire data only, and states "Add your crop in Settings for crop-specific advice."
- Search bar above grid for discoverability (typed input — intended for Priya or literate users; grid remains primary for Ramesh).
- Framing: "What are you growing this season?" — supports seasonal rotation behaviour. User updates in Settings when crop changes.
- Soil type auto-fetched silently from coordinates (India NBSS data). Not shown to user.

**Screen 5 — Farm size + alert radius**
Two sliders on one screen.
- Farm size: 0.5–200 acres, default 3 acres.
- Alert radius: 10–150km, default 50km. Controls both map view and push notification trigger.
- Both sliders have large touch targets. Visual indicator next to radius shows what the radius means in practice.

**Screen 6 — Notification permission**
FCM system permission prompt. Brief context before prompt: "[icon] We'll alert you when a fire appears near your farm." If denied: app proceeds fully, but persistent soft banner shown on home screen ("Enable notifications to get fire alerts") until granted or dismissed. First-open tooltip highlights settings icon location (top-right) — one-time only.

### 3.2 Navigation structure

**Bottom navigation bar — 4 tabs:**
- Home (flame icon)
- Fire Map (location pin icon)
- Weather (cloud icon)
- Advisor (speech bubble icon)

**Top-right corner:** Settings gear icon. Not a bottom tab. One-time tooltip on first open points to this icon so Ramesh knows where it lives.

**Home as launch state:** App opens to Home tab after onboarding. Home is a persistent bottom tab, not a separate "dashboard" destination.

### 3.3 Home screen

Shows at a glance — Ramesh should be able to read essential information without tapping anything:

- **Fire status banner** (largest, most prominent): "No fires within 50km" (green) / "1 fire — 23km northeast" (amber) / "Multiple fires nearby" (red). Tappable — navigates to Fire Map.
- **Nearby fires list** (shown when live fires exist, above forecast): filters to fires detected in the last 24 hours only. Shows up to 3 closest fires. Each row: coloured dot (red/amber/yellow) + distance & direction + FRP intensity label (Small/Moderate/Large/Extreme) + time ago. Tapping a row navigates to Fire Map zoomed to that pin. Stat cards (temp/humidity) tap → Weather tab.
- **2-day forecast** (always shown when weather data available): tomorrow and day-after cards, each showing day label, min–max temp range, rain mm or "No rain", wind speed. Labels localised (Tomorrow/Yesterday in English; कल/परसों in Hindi).
- **Weather summary line**: one sentence, farming language. "Dry and windy today — fire risk conditions." Tappable — navigates to Weather tab.
- **Chatbot entry prompt**: "Ask about your farm →". Tappable — navigates to Advisor tab.
- **Last updated timestamp**: "Fire data updated 2h ago." Bottom of screen.
- Screen is fully vertically scrollable to accommodate all sections.

### 3.4 Fire Map tab

Full-screen map centred on farm pin. Farm location marked with purple pin (distinct from fire pins).

**Fire markers colour-coded by intensity (FRP):**
| Colour | FRP Range | Label |
|--------|-----------|-------|
| Yellow | < 10 MW | Small |
| Orange | 10–50 MW | Moderate |
| Red | 50–200 MW | Large |
| Magenta | 200+ MW | Extreme |

Tapping a hotspot opens a bottom sheet: distance from farm, intensity badge (coloured pill — Small/Moderate/Large/Extreme), detection time, and "Ask advisor about this fire" button (pre-loads Advisor with fire context).

**Topbar controls:**
- **Radius toggle** (centre-right): switches between "My radius" (filters to user's alert radius) and "All fires" (shows all fires within 200km). Icon turns green when My Radius is active. Fire count badge updates live.
- **Refresh button** (right): re-subscribes to Firestore listener, shows progress indicator while loading.

**Fire age filter:** Only fires detected in the **last 36 hours** are displayed. Older detections are not shown — a fire not re-detected by the satellite in 36h is very likely extinguished. Firestore retains fires for 48h as a buffer; the display window is the conservative inner bound.

**Timestamp:** "Last fire detected · [date, time]" when fires exist; "No fires within 200 km" when none. Clarifies what the timestamp refers to (last detection, not last app refresh).

**Legend:** shows all four FRP tiers + Your farm — clean labels, no MW brackets.

### 3.5 Weather tab

Full forecast view in farming language. Today's conditions at top (expanded), followed by 5/7-day forecast cards. Each day card: temperature range, wind speed + direction (arrow), humidity %, one farming advisory line. Meteorological data translated to plain language — no mbar, no dew point shown.

Advisory examples:
- "Wind from the northeast, 18 km/h — fire could spread toward farms from forest areas."
- "Humidity rising tomorrow — lower fire risk, safer to burn crop waste."

### 3.6 Advisor tab (AI chatbot)

Powered by Gemini API. Context injected automatically before every conversation — brief context summary shown at top of chat: "I know you're growing cotton near Amravati, with a fire 23km to the northeast and dry winds forecast."

Context object injected into system prompt per session:
- Farm location
- Crop type(s) — or note if not set
- Current fire proximity data (nearest fire, distance, intensity)
- Current weather and 48hr forecast
- Current fire danger level (low/medium/high based on proximity)

Conversation history maintained within session. Between sessions, context re-injected fresh from Firestore — no persistent chat history in MVP.

Responds in selected language (English or Hindi). Out-of-scope questions (livestock disease, legal advice, financial advice): acknowledges limitation, provides Krishi Vigyan Kendra helpline as fallback.

"Ask advisor about this fire" button from Fire Map: navigates to Advisor tab with fire-specific context pre-loaded in the input or as a prompt stub.

### 3.7 Fire Relevance Scoring Engine (Silent — Background Only)

Runs on every FIRMS data refresh. Inputs: fire location, FRP, euclidean distance to farm, live soil composition (clay/sand/SOC from SoilGrids ISRIC API at 250m resolution), wind direction and speed, temperature, humidity. Score formula: `customFireIndex×0.5 + soilScore×0.3 + frpNorm×0.2`. SoilGrids call falls back to static state-level lookup if API is unavailable. Outputs a relevance score per hotspot per farm. Logs `soilSource` field ('soilgrids'/'static') for validation tracking. Not surfaced to user in MVP. Promoted to live alerts in v1.1 after validation.

### 3.8 Push Notifications

Triggered when new FIRMS data shows a fire hotspot within user's set alert radius. One push per new hotspot event — no repeat for same hotspot. Firebase Cloud Messaging.

Notification tap behaviour:
- App closed: opens directly to Fire Map, zoomed to triggered hotspot.
- App open: in-app banner; tap navigates to Fire Map and zooms to hotspot.

---

## 4. Explicitly Out of Scope for MVP

- Validated fire risk scoring surfaced to users (v1.1)
- Languages beyond English and Hindi (v1.1 target: 6–10 Indian languages)
- Voice input in chatbot (v1.1 — high priority for low-literacy users)
- Persistent chat history across sessions
- Account deletion / data export
- Crop price monitor (v2.0)
- Online marketplace (future)
- Offline mode (partial — see Known Limitations)
- Flood, drought, or non-fire disaster types
- Community / social features

---

## 5. Known Limitations

**Language barrier:** MVP ships in English and Hindi. Icon-led UI minimises text dependency. Full vernacular support is highest-priority post-MVP improvement.

**Scoring engine not live:** Personalised fire relevance scoring not surfaced in MVP. Deliberate sequencing decision. Raw proximity data delivers real value in interim.

**6-hour data latency:** NASA FIRMS updates every 6 hours. AgroShield is a risk awareness tool, not an emergency response system.

**Offline / low connectivity:** Farm location stored locally after onboarding. Fire and weather data cached locally; last known state shown with "last updated [timestamp]" banner when offline. Full offline mode is post-MVP.

**Guest path data loss:** Users who proceed without an account and uninstall will lose farm data and repeat onboarding on reinstall. Mitigated by framing Google Sign-In as a backup/sync benefit, not a requirement.

**Gemini API limits:** Free tier rate limits may constrain scale. Alternatives at scale: OpenAI GPT-4o, Anthropic Claude API, Groq. To be assessed in Chat 6 before launch.

---

## 6. Success Metrics

| Type | Metric | MVP Target |
|---|---|---|
| Primary | % of users who open app within 2 hours of a fire proximity push notification | >50% |
| Secondary | % of users who open app within 24 hours of a fire proximity push notification | >70% |
| Tertiary | Chatbot questions per active user per week | ≥1 |
| Guardrail | False positive notification rate | <20% |
| Launch goal | Real downloads with qualitative feedback collected | 10 downloads, 5 feedback responses |

**Why these metrics, not D7 retention:** AgroShield is a situational app — Ramesh does not need to open it daily, he needs to open it when a fire appears nearby. Notification response metrics directly measure the job-to-be-done.

---

## 7. Technical Stack

| Component | Technology |
|---|---|
| Mobile app | Flutter 3.41.8 (Android-first, Dart) |
| State management | Riverpod 2.x (`StateProvider`, `StateNotifierProvider`) |
| Backend | Firebase Cloud Functions Gen 2 (Node.js 22) |
| Database | Cloud Firestore |
| Auth | Firebase Auth — Google Sign-In + anonymous guest |
| Maps | Google Maps Flutter (`google_maps_flutter`) |
| Fire data | NASA FIRMS VIIRS_SNPP_NRT (scheduled Cloud Function every 6h) |
| Weather | Tomorrow.io Realtime + Forecast API |
| AI chatbot | Google Gemini (`google_generative_ai`, multi-turn, context-injected) |
| Push notifications | Firebase Cloud Messaging (FCM) |
| Analytics | Firebase Analytics (works on both auth + guest paths via device ID) |
| Local storage | SharedPreferences (typed keys via `PrefsKeys` constants class) |
| Deployment | Android (Google Play Store, $25 one-time fee) |

---

## 8. Post-MVP Roadmap

| Version | Key addition |
|---|---|
| v1.1 | Scoring engine live as personalised alerts; 6–10 Indian languages; voice input in chatbot |
| v2.0 | Crop price monitor (mandi rates reference) |
| Future | Online crop marketplace |
