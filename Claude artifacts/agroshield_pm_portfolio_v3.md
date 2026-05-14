# AgroShield — PM Portfolio Document
*Living document. Updated as product decisions are made.*

---

## For Resume

**Project line:**
> AgroShield — Agricultural Fire Risk Intelligence App | Product Manager
> Built and launched an Android MVP applying the Double Diamond framework — from problem discovery and competitive research through to App Store deployment. Integrated NASA FIRMS satellite data, real-time weather, and a context-aware AI chatbot (Gemini API) to deliver personalised fire risk intelligence to smallholder farmers in fire-prone India.

**Skills demonstrated (for skills section):**
- Product management (Double Diamond framework)
- Market research and competitive analysis
- User persona development
- Problem definition and PRD writing
- User flow design (screen-by-screen mapping before any code written)
- RICE prioritisation
- Feature sequencing and build order decisions
- AI product integration (Gemini API, context injection)
- Firebase, Flutter, Cloudflare deployment

---

## For Interviews

### The problem (30-second version)
"Indian farmers receive state-level fire alerts — one alert covers an entire state regardless of where the fire actually is. A fire 80km away triggers the same notification as one 3km away. Farmers either panic unnecessarily or start ignoring all alerts. No tool existed that told a farmer whether a specific fire was actually a threat to *their* farm."

### The solution (30-second version)
"AgroShield is a mobile app that combines NASA FIRMS satellite fire data with environmental factors — vegetation type between fire and farm, wind direction, humidity, euclidean distance, fire intensity — to produce a personalised fire relevance score for each farmer's specific location and crop. The MVP includes a fire proximity map, a farming-framed weather forecast, and an AI chatbot that uses the farmer's crop type, location, and current fire risk as automatic context before the farmer types a single word."

### Framework used
**Double Diamond** — chosen because the problem space was partially explored (hackathon origin) but not fully validated. The framework forced a proper diverge-then-converge sequence before committing to build scope.

---

## Key Product Decisions (with rationale — use in interviews)

### Decision 1: Scoring engine runs silently in MVP, not surfaced to users
**What:** The fire relevance scoring engine was built and runs in the background during MVP, logging predictions but not showing them to users. Raw NASA FIRMS proximity data is shown instead.

**Why:** A false negative in fire safety — telling a farmer "low risk" when a fire reaches his farm — destroys trust permanently and spreads via word of mouth in rural communities faster than any marketing. A disclaimer doesn't solve this. The engine needed real-world validation before becoming an alerting mechanism.

**PM thinking demonstrated:** Separated the visibility feature (show fires near me) from the alerting feature (tell me if I'm in danger). Sequenced them deliberately based on consequence of failure, not technical readiness.

**Interview answer:** "I applied a risk-weighted sequencing decision. The fire alert engine had high potential impact but unvalidated accuracy. Given that false negatives in fire safety have severe real-world consequences, I launched the raw proximity data as an MVP feature while running the scoring engine silently to build a validation dataset. Once the predictions held up against real outcomes, the engine would be promoted to the alert feature in v1.1."

### Decision 2: Weather data is infrastructure, not a standalone feature
**What:** Weather tab shows full forecast, but its primary role is feeding the AI chatbot as automatic context.

**Why:** Every competitor has weather. Alone, it adds no differentiation. Its value in AgroShield is that it makes the AI chatbot's answers situation-specific — the chatbot knows wind is forecast to shift toward the farm by evening, so it changes its advice accordingly.

**PM thinking demonstrated:** Evaluated feature value in the context of the whole product, not in isolation.

### Decision 3: Google Sign-In optional, guest path added
**What:** Sign-in screen offers Google Sign-In (primary) and "Continue without account" (secondary). Guest path stores all data locally on device. Both paths fire anonymous analytics events via Firebase device ID.

**Why:** Forcing Google Sign-In would exclude farmers without Gmail accounts and adds friction at the most critical drop-off point in any mobile app. At MVP scale (10 users), the core metrics — notification response rate, chatbot usage, map engagement — are trackable via anonymous device ID. Cross-device identity and longitudinal retention analysis can wait for v1.1.

**PM thinking demonstrated:** Distinguished between what data is actually needed to answer MVP questions vs. what seems useful in the abstract. Avoided over-engineering authentication at MVP stage.

**Interview answer:** "I decided not to gate the app behind Google Sign-In because forcing authentication at onboarding is one of the highest drop-off points in consumer apps. For MVP, I needed to know: do farmers open the app when a fire is nearby? Firebase Analytics can answer that with an anonymous device ID — no account needed. I kept Sign-In as an option framed as a backup benefit, not a requirement."

### Decision 4: Crop selection recommended, not required
**What:** Crop picker allows proceeding with no selection. If no crop selected, chatbot states it's advising without crop-specific context and prompts the user to add their crop in Settings.

**Why:** Forcing a minimum selection at onboarding creates unnecessary friction and doesn't reflect how farmers actually use land — seasonal rotation means the crop they're growing today may not be what they're growing in 3 months. A hard block also breaks the Ramesh-can-do-this-independently principle if he doesn't see his crop in the list.

**PM thinking demonstrated:** Recognised that a forced input creates a worse outcome than a graceful fallback. Addressed seasonal behaviour with "current season" framing rather than a static field.

### Decision 5: 4 bottom tabs + top-right settings
**What:** Bottom navigation: Home, Fire Map, Weather, Advisor. Settings accessed via gear icon in top-right corner, not a bottom tab. One-time tooltip on first open points Ramesh to the settings location.

**Why:** Four bottom tabs is the maximum for comfortable thumb navigation on Android without crowding. Settings is not a primary destination — a farmer doesn't need to go there regularly. Placing it top-right follows standard Android patterns. The tooltip addresses the discoverability risk for lower-literacy users without adding a permanent nav item.

**PM thinking demonstrated:** Navigation decisions are UX decisions with product consequences — putting the wrong thing in the bottom bar signals to users that it's important. Settings in the bottom bar would imply the app requires regular configuration.

### Decision 6: Flutter over React Native or PWA
**What:** Flutter chosen as the app framework. Riverpod for state management.

**Why:** Android-first deployment, deep Firebase integration (both Google products), reliable FCM push notifications (critical for primary metric), and strong google_maps_flutter support. PWA was ruled out because push notification delivery on Android is less reliable than FCM native — a direct risk to the primary success metric (notification response rate). React Native was ruled out in favour of Flutter's tighter Firebase integration and cleaner Dart codebase for a solo builder.

**PM thinking demonstrated:** Framework decision evaluated against the product's primary success metric, not developer convenience. The notification response rate metric was the deciding factor.

---

## Market Research Summary

### Competitive landscape

| Competitor | What they do | Gap / weakness |
|---|---|---|
| FireAlert (Plant-for-the-Planet) | NASA FIRMS data → smartphone alerts | Not farm-specific. No crop context. Reliability issues (Play Store reviews). No agricultural advisory. |
| Farmer.Chat (Digital Green + OpenAI) | AI agricultural advisor for extension agents | No fire risk data. Targets extension agents, not farmers directly. Government-backed, slow to iterate. |
| AgriApp | All-in-one farming platform (weather, advisory, soil, marketplace) | No fire data. Broad focus means generic experience. |
| Meghdoot (Govt. of India) | District-level weather + crop advisories twice a week | Not real-time. Too broad geographically. No fire data. |
| Farmonaut | Satellite crop health monitoring, weather | Enterprise/agribusiness focus. No fire alerts. |

### The gap AgroShield fills
No product cross-references live fire proximity data with the farmer's specific crop type, farm location, and environmental factors between them. FireAlert doesn't know what crop you grow. Farmer.Chat doesn't know there's a fire 8km northeast. The intersection — *your farm + your crop + fire relevance right now* — is unoccupied.

---

## Product Definition

### Problem statement
Indian smallholder farmers in fire-prone regions have no reliable, personalised way to assess whether a nearby fire is actually a threat to their specific farm. Existing state-level alerts are too broad to act on — either causing unnecessary panic or being ignored entirely.

### Target users
- **Primary:** Smallholder farmer in fire-prone rural India. Android smartphone user. 2–5 acres. Grows seasonal crops (cotton, wheat, soybean). Has experienced or fears crop fire loss.
- **Secondary:** Tech-literate family member (often younger) who installs and sets up the app on behalf of the primary user. Controls onboarding UX decisions.

### MVP feature scope

| Feature | Status in MVP | Rationale |
|---|---|---|
| Onboarding (language, sign-in/guest, GPS farm pin, crop picker, farm size/radius, notification permission) | Live | Zero typed input, completable by Ramesh independently |
| Home screen (fire banner, weather line, chatbot entry) | Live | Answers JTBD without requiring any navigation |
| Fire proximity map (raw NASA FIRMS) | Live | Immediate value, no accuracy risk |
| Fire relevance scoring engine | Built, runs silently | Needs validation before surfacing |
| Weather tab (full forecast, farming-framed) | Live | Table stakes + chatbot infrastructure |
| AI chatbot (Gemini, context-injected) | Live | Key differentiator — knows fire risk + weather + crop |
| Push notifications (radius-triggered) | Live | Core engagement mechanism |
| Crop type onboarding | Live (recommended, not required) | Enables chatbot context injection |

### Post-MVP roadmap
- v1.1: Scoring engine goes live as personalised alert once validated; 6–10 Indian languages; voice input in chatbot
- v2.0: Crop price monitor (mandi rates reference)
- Future: Online marketplace

---

## Metrics

| Type | Metric | Target |
|---|---|---|
| Primary | % of users who open app within 2 hours of a fire proximity push notification | >50% |
| Secondary | % of users who open app within 24 hours of a fire proximity push notification | >70% |
| Tertiary | Chatbot questions per active user per week | ≥1 |
| Guardrail | False positive notification rate | <20% |
| MVP goal | Real downloads with qualitative feedback collected | 10 downloads, 5 feedback responses |

---

## Artifacts Produced

| Phase | Artifact | Status |
|---|---|---|
| Discover | Competitive research (FireAlert, Farmer.Chat, AgriApp, Meghdoot, Farmonaut) | Complete |
| Define | User personas (Ramesh + Priya) | Complete |
| Define | PRD v1.0 | Complete |
| Define | PRD v1.1 (post Chat 2 revisions) | Complete |
| Develop | User flow diagram v2 (all screens + transitions) | Complete |
| Develop | RICE prioritisation table (12 features, Claude Code session estimates) | Complete |
| Develop | User stories (20 stories across all 12 features, with acceptance criteria) | Complete |
| Develop | Framework decision: Flutter + Riverpod | Complete |
| Develop | Build order finalised (12-feature sequence, ~21 total sessions) | Complete |
| Deliver | Testing + QA (Firebase QA scripts, scoring engine QA, security hardening) | Complete — Chat 10 |
| Deliver | UI polish + bug fixes (autocomplete, nearby fires list, 2-day forecast, intensity pins, live radius, FCM token refresh) | Complete — Chat 10.2 |
| Deliver | Additional bug fixes + fire age filter (36h display, 48h cleanup) + SoilGrids live soil API in scoring engine | Complete — Chat 10.3 |
| Deliver | Bug fixes — full-row tap on nearby fires (HitTestBehavior), fire info sheet auto-open, forecast tap nav, pulsing banner removed | Complete — Chat 10.4 |
| Deliver | Play Store listing (production keystore, screenshots, listing copy, content rating, AAB submission) | Chat 11 — Current |
| Measure | Launch + feedback analysis | Chat 12 — Pending |
