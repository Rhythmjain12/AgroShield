# AgroShield — Full Product Roadmap

---

## Frameworks
**Product:** Double Diamond (primary). JTBD used as a tool within the Discover phase.
**Engineering:** Flutter (Android-first). State management: Riverpod. Backend: Firebase.

---

## Chat Roadmap

| Chat | Phase | Focus | PM Artifact | Status |
|---|---|---|---|---|
| **Chat 1** | Discover + Define | Problem framing, market research, personas, PRD | PRD v1.0, Portfolio doc | ✅ Complete |
| **Chat 2** | Develop | User flows — all screens and transitions mapped. Nav structure finalised (4 bottom tabs + top-right settings). Auth options decided. Crop picker revised. Farm size range corrected. | User flow diagram v2, PRD v1.1 | ✅ Complete |
| **Chat 3** | Develop | RICE prioritisation + user stories for all MVP features. Framework decided (Flutter + Riverpod). Build order finalised. | RICE table, user stories doc | ✅ Complete |
| **Chat 4** | Deliver | Flutter project setup. Firebase init. Navigation shell. Firebase Analytics. Riverpod shared state. Auth (Google + guest). Full onboarding flow (6 screens). | Working onboarding, authenticated app shell | ✅ Complete |
| **Chat 5** | Deliver | Home screen (live fire banner + weather line + chatbot entry). Weather tab (Tomorrow.io, farming-language framing). Full visual redesign (dark theme, Fraunces + DM Sans). | Working home + weather screens | ✅ Complete |
| **Chat 6** | Deliver | Fire Map tab — Firestore hotspot read, google_maps_flutter, colour-coded markers, bottom sheet, "Ask advisor" Riverpod write. | Working fire map with real NASA FIRMS data | ✅ Complete |
| **Chat 7** | Deliver | AI Advisor tab — Gemini API, context injection, system prompt, multi-turn conversation, KVK fallback. | Working AI chatbot | ✅ Complete |
| **Chat 8** | Deliver | Push notifications — FCM, devices collection, `notifyDevicesOnNewFire` Cloud Function, FCM tap handler, deep-link zoom to fire. | Working push notifications | ✅ Complete |
| **Chat 9** | Deliver | Settings screen (all four sections). Fire relevance scoring engine (`scoreFireRelevance` Cloud Function, `scoringLogs` collection). Structural fixes: `PrefsKeys`, `languageProvider`, `FarmProfileService` offline fallback, parallel FCM dedup. | Working settings + silent scoring | ✅ Complete |
| **Chat 10** | Deliver | Testing + QA — PrefsKeys migration, languageProvider wiring, Firebase QA scripts, Tomorrow.io API fix, scoring engine QA (9/9 pass), security hardening (Firestore rules, HTTP endpoint auth, Maps key migration, npm audit). | QA checklist, HANDOFF_chat10.md | ✅ Complete |
| **Chat 10.2** | Deliver | UI polish + bug fixes — autocomplete dropdown, nearby fires list, 2-day forecast, intensity-based pin colours, refresh + radius toggle, alertRadiusProvider (Riverpod), FCM token refresh handler. | HANDOFF_chat10.2.md | ✅ Complete |
| **Chat 10.3** | Deliver | Bug fixes (topbar alignment, language live on all tabs, autocomplete UX, keyboard overflow, cached fire status, settings crop pre-selection) + fire map 36h age filter + SoilGrids live soil API replacing static vegetation lookup + Firestore cleanup window tightened to 48h. | HANDOFF_chat10.3.md | ✅ Complete |
| **Chat 10.4** | Deliver | Bug fixes — fire row HitTestBehavior.opaque (full row tappable), fire info sheet auto-opens via `fireMapAutoSelectIdProvider` + `ref.listen`, forecast cards navigate to weather tab, pulsing ScaleTransition removed from fire banner. | HANDOFF_chat10.4.md | ✅ Complete |
| **Chat 10.5** | Deliver | Kheto rebrand — app name, adaptive icon (75% safe zone, #47a848 bg), Android 12 splash (1024px nodpi drawable), home topbar logo, Flutter splash clarity fix. Fire map recenter button. Background brightness increase across all screens. | HANDOFF_chat10.5.md | ✅ Complete |
| **Chat 11** | Deliver | Play Store submission — production keystore, app listing copy, screenshots, description, content rating. | App Store listing copy | 🔲 Current |
| **Chat 12** | Measure | Launch strategy — WhatsApp farmer groups, KVK outreach, LinkedIn, Reddit. In-app feedback mechanism. `chatbot_message_sent` analytics event. In-app review prompt (after 3rd notification open, 60-day cooldown). | Launch plan | 🔲 Pending |
| **Chat 13** | Measure | Feedback analysis — what users said, metrics, what to build next. | "What I learned" doc | 🔲 Pending |

---

## Build Order (by RICE score, with dependency overrides)

| Order | Feature | Sessions | Complexity | Chat | Status |
|---|---|---|---|---|---|
| 1 | Flutter setup + navigation shell | 1.5 | Med | 4 | ✅ |
| 2 | Firebase Analytics | 0.5 | Low | 4 | ✅ |
| 3 | Riverpod shared state store | 0.5 | Low | 4 | ✅ |
| 4 | Auth: Google Sign-In + guest path | 1.5 | Med | 4 | ✅ |
| 5 | Onboarding flow (all 6 screens) | 3.0 | High | 4 | ✅ |
| 6 | Home screen | 1.0 | Low | 5 | ✅ |
| 7 | Weather tab | 1.5 | Med | 5 | ✅ |
| 8 | Fire Map tab | 2.0 | Med | 6 | ✅ |
| 9 | Push notifications | 3.0 | High | 8 | ✅ |
| 10 | Advisor tab (Gemini) | 3.0 | High | 7 | ✅ |
| 11 | Settings screen | 1.5 | Med | 9 | ✅ |
| 12 | Fire relevance scoring engine (silent) | 2.5 | High | 9 | ✅ |
| 13 | Testing + QA | 2.0 | Med | 10 | ✅ |

**Total estimated sessions: ~23**

---

## Notes
- Chat 13 is the most important portfolio piece for interviews
- Scoring engine runs silently in MVP — promoted to live personalised alerts in v1.1 after validation
- Vegetation API decision resolved in Chat 9: static state-level lookup table (no viable free API for India exists)
- Language scope: English + Hindi only for MVP; 6–10 Indian languages in v1.1

---

## Artifacts Index

| Artifact | File |
|---|---|
| PRD v1.1 | agroshield_prd_v2.md |
| PM Portfolio doc | agroshield_pm_portfolio_v2.md |
| Roadmap v3 | agroshield_roadmap_v3.md |
| User flow diagram v2 | agroshield_userflow_v2.md |
| RICE table + user stories | agroshield_rice_stories_v1.md |

---

## MVP Feature Summary

| Feature | Status |
|---|---|
| Onboarding (language → sign-in/guest → GPS farm pin → crop picker → farm size/radius → notification permission) | ✅ Live |
| Home screen (fire banner + nearby fires list + 2-day forecast + weather line + chatbot entry + offline cache) | ✅ Live |
| Fire proximity map (NASA FIRMS data, intensity-based pin colours, refresh + radius toggle, notification deep-link zoom) | ✅ Live |
| Weather tab (Today full + 5-day forecast, farming language) | ✅ Live |
| AI advisor tab (Gemini, context-injected, multi-turn) | ✅ Live |
| Push notifications (radius-triggered FCM, opens to fire map) | ✅ Live |
| Settings (crops, location, farm size/radius, language, notifications, account, about) | ✅ Live |
| Fire relevance scoring engine | ✅ Silent — logs to `scoringLogs/` only |

## Post-MVP (v1.1+)
- Scoring engine promoted to live personalised risk score shown on Home screen
- 6–10 Indian language support + voice input
- `_clockTimer` optimisation (pause when tab inactive)
- Firestore `fires/` listener with `.limit()` for scale
- v2.0: Crop price monitor
- Future: Online marketplace
