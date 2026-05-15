# Kheto — Play Store Launch Tasks
**Last updated:** Chat 11 (2026-05-15)

---

## 🐛 Bugs Fixed in Chat 11
- [x] BUG-1: Onboarding language — selecting Hindi did not carry through to screens 2–6 (fixed: `setState` wrapping language assignment in `OnboardingFlow`)
- [x] BUG-2: Home screen showed "No fires" while Fire Map showed fires — stale Firestore cache snapshot was clearing `_isLoading` too early (fixed: `isFromCache` guard)
- [x] BUG-3: Home/Fire Map fire count mismatch after radius change — home screen restarted subscription on radius change causing race; fire map used getter pattern (fixed: `_allFires` + `_fires` getter, no subscription restart)
- [x] BUG-4: Nearby fires list not showing even when banner said "3 fires nearby" — list gated on `!_isLoading` which blocked cache data (fixed: removed gate, updated `_fireStatus` to prefer live data)
- [x] BUG-5: No logout button for guest users in Settings (fixed: `_SignOutRow` now always visible; clears `onboardingComplete` pref)

## 🏗 Architectural Issues Fixed (Chat 11 Audit)
- [x] Raw string literals in fire_map, weather, advisor screens bypassing `PrefsKeys` (6 strings)
- [x] Empty `deviceId` silently writing to Firestore `doc('')` — FCM never registered for any user
- [x] Guest `FarmProfileService.saveProfile` replaced entire blob — crops-only save erased farmLat/farmLng
- [x] `languageProvider` / `alertRadiusProvider` not updated after onboarding — Hindi users saw English on first open
- [x] Fire map false "no fires" flash — `_loading = false` on cache snapshot before server data
- [x] Farm location change in Settings not propagated to live screens — added `farmLocationProvider`

---

## Phase 1 — Screenshots & Assets
- [ ] 1. Capture 8 raw screenshots from Pixel 3 XL via ADB (Play Store allows up to 8 — use all slots)
- [ ] 2. Edit screenshots — add device frame, clean background, optional caption overlay
- [ ] 3. Feature graphic — 1024×500px banner (required, shown at top of Play Store listing)
- [ ] 4. App icon — 512×512px high-res PNG (separate from in-app icon, for Play Store listing)

## Phase 2 — Store Listing Copy
- [ ] 5. Finalise app title — "Kheto - Fire Risk Alert" (30 char max)
- [ ] 6. Short description — 80 chars max
- [ ] 7. Full description — update draft from Chat 11 (replace "AgroShield" → "Kheto", 4000 char max)
- [ ] 8. What's New — v1.0 first release notes (brief)

## Phase 3 — Legal & Policy
- [ ] 9. Write Privacy Policy — must cover: location data, crops data, Firebase, FCM, Gemini API, Tomorrow.io
- [ ] 10. Host Privacy Policy at a public URL (Google Doc, GitHub Pages, or Notion)
- [ ] 11. Fill Data Safety form in Play Console — what data is collected, shared, encrypted

## Phase 4 — Play Console Setup
- [ ] 12. Create Google Play Developer account — $25 one-time at play.google.com/console
- [ ] 13. Create app listing — package name: com.agroshield.app
- [ ] 14. Fill all metadata (title, description, category: Tools or Weather, target country: India)
- [ ] 15. Complete content rating questionnaire (answers prepared in Chat 11)
- [ ] 16. Set target audience + age group

## Phase 5 — Testing & Upload
- [ ] 17. Upload AAB to internal testing track (file: build/app/outputs/bundle/release/app-release.aab)
- [ ] 18. Add yourself as internal tester (your Gmail)
- [ ] 19. Install via Play Store link and verify production build works end-to-end on device
- [ ] 20. Promote to closed testing once internal test passes
- [ ] 21. Promote to open testing / production when ready for public

---

## Completed (Chat 11)
- [x] Production keystore created (agroshield-release.keystore, valid to 2053)
- [x] build.gradle configured with production signing
- [x] Signed release AAB built and verified (52.5MB, Delhi keystore)
- [x] Production SHA-1 added to Maps API key in GCP
- [x] GCP billing confirmed active
- [x] Firestore cost fix deployed (dayRange 2→1, scoreFireRelevance scoped to new fires only)
- [x] Play Store listing copy drafted (needs Kheto rename — Task 7)

---

## Key Files & Info
- AAB location: `agroshield/build/app/outputs/bundle/release/app-release.aab`
- Package name: `com.agroshield.app`
- Version: 1.0.1+2 (pubspec.yaml)
- Keystore: `android/app/agroshield-release.keystore`
- Key alias: `agroshield`
- Keystore passwords: saved in Locked Notes
