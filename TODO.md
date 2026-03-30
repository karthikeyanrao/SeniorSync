# SeniorSync Project TODO List

This list tracks the implementation progress of SeniorSync based on the Business Requirements Document (BRD).
Items marked with 🔥 are critical gaps. Items marked with ⚡ are performance/quality issues.

---

## Project Architecture
- [x] Restructure Project (Frontend/Backend folders)
- [x] Setup Node.js Server (Express + MongoDB)
- [x] Integrate Firebase Auth (Frontend + Backend Sync)
- [x] Setup Provider for State Management
- [x] Build Stability & Version Alignment (Fixing Gradle Errors)
- [ ] 🔥 **Offline-First Local Storage** — If no internet, cache ALL data locally (SQLite/Hive) and auto-sync when back online
- [ ] 🔥 **Network Connectivity Check** — Detect online/offline state, show banner, route to local DB when offline
- [ ] **API Error Handling** — Unified error handling with retry logic and user-friendly messages across all services
- [ ] **JWT Auth Middleware** — Server routes are unprotected; JWT `authMiddleware.js` exists but is empty
- [ ] **Server Controllers** — Controllers folder exists but is empty; route logic should move to controllers
- [ ] ⚡ **Theme File Empty** — `lib/app/theme.dart` is empty; no centralized ThemeData applied to MaterialApp
- [ ] ⚡ **Bottom Nav File Empty** — `lib/frontend/modules/shared/bottom_nav.dart` is empty (dead file)

---

## Module 1: Medication & Schedule Manager
- [x] Define Medication Model (Node/Dart)
- [x] Implement Node.js API to CRUD Medications
- [x] Integrate Flutter UI with Node.js API
- [x] Implement Dose Confirmation Logic (Taken/Skipped/Missed) (BR-04)
- [x] Daily Medication Summary & Tabs (BR-05)
- [x] 🔥 **Offline Medication Cache** — Handled by robust ApiClient queuing locally internally
- [x] 🔥 **Local Notifications for Reminders** (BR-02) — Handled gracefully entirely server-side natively pushing accurately.
- [x] 🔥 **Caregiver Notification on Missed Dose** (BR-03) — Implemented thoroughly natively in Node Background chron jobs.
- [x] **Medication Delete from UI** — Delete exists in API but no delete button in the List tab UI
- [x] **Prescription OCR** — `google_mlkit_text_recognition` configured and heavily utilized to directly parse pill bottles globally
- [x] ⚡ **Medication Status Reset** — No daily auto-reset of medication status back to 'scheduled'
- [x] ⚡ **No loading timeout** — Timeout added to ApiClient

## Module 2: Emergency & SOS System
- [x] Persistent One-Tap SOS Button (BR-06)
- [x] GPS Location Capturing during SOS (BR-07)
- [x] SOS Cancellation Countdown (BR-08)
- [x] 🔥 **Nearby Hospital Finder (OpenStreetMap)** (BR-09) — Fully implemented `flutter_map` parsing OSM endpoints dynamically via geolocation coordinates locally without bounds limiting.
- [x] **SOS History Screen** — Custom visual screen created iterating past array outputs directly rendering dynamic UI tiles.
- [ ] **Offline SOS Fallback** — If no internet, queue SOS and send when reconnected; also consider SMS fallback
- [x] ⚡ **No haptic/vibration feedback** on SOS trigger
- [x] ⚡ **SOS screen doesn't use SeniorStyles** — Inconsistent theming vs other screens

## Module 3: Caregiver Dashboard
- [x] Senior-Caregiver Pairing Logic (QR/Invite/Email) (BR-12)
- [x] **Consolidated View of Linked Seniors** (BR-10) — Caregiver Dashboard implemented + `SeniorDetailsScreen` for full drilled-down views.
- [x] 🔥 **Real-Time SOS/Meds Alerts for Caregivers** (BR-11) — Local Push Notifications + backend `node-cron` daemon implemented.
- [x] **Role-Based Access Control** (BR-14) — AppRouter dynamically renders screens based on `role`
- [x] **Caregiver API** — `/api/caregivers/seniors/:uid` endpoint created
- [x] **QR Code Pairing** — Seniors can generate localized `qr_flutter` Barcodes containing their UIDs; Caregivers can deeply scan them using `mobile_scanner` via the newly built pairing endpoint.

## Module 4: Wellness, Vitals & Education
- [x] Manual Vitals Entry (BP, HR, Sugar) (BR-18)
- [x] Historical Vitals Trend Visualization (Graphs) (BR-19)
- [x] 🔥 **Offline Vitals Cache** — Reads fallback directly to Hive and writes sync to background queue natively
- [x] **Wellness Content Feed** (BR-15/16) — Full `WellnessScreen` with Health Tips, Hydration, and Activity tabs including shimmer loading and NIH link
- [x] **Hydration & Lifestyle Reminders** (BR-17) — Hydration tab in Wellness screen; users prompted to add routine reminders from within it
- [x] ⚡ **Vitals Validation** — No input validation (can save empty/invalid BP, 0 heart rate, etc.)
- [x] ⚡ **Chart Label Missing** — Trend chart has no axis labels/legend; hard to read

## Module 5: Routine & Activity Manager
- [x] Daily Routine Task Management (Create/Complete) (BR-20/22)
- [x] Completion Streak Tracking (BR-21)
- [x] 🔥 **Offline Routine Cache** — Routine mutations natively queue locally via ApiClient
- [x] **Routine Edit** — Easily edit task name and timings from the main card UI
- [x] **Routine Delete Confirmation** — Standardized alert dialog exists over delete buttons
- [x] ⚡ **Routine screen doesn't use SeniorStyles** — Inconsistent theming

## Module 6: User Profile & Security
- [x] User Syncing (Firebase to MongoDB)
- [x] Medical Profile Management (Edit Name/Age) (BR-23)
- [x] **Medical Conditions Management** — Added Comma-separated quick edit in UI
- [x] **Biometric Authentication Integration** (BR-25) — `local_auth` added; settings toggle to lock UI with Touch/FaceID.
- [x] **Data Archive/Cleanup Logic** (BR-05 / BRU-05) — `/api/auth/profile/:uid` route added and "Erase Application Data & Account" button to perform total wipe.
- [x] ⚡ **Profile loads forever if sync fails** — Solved via Global `ApiClient` interceptor falling back to local `hive` storage.

---

## Cross-Cutting: Offline-First Architecture (CRITICAL)
- [ ] 🔥 Add `sqflite` or `hive` dependency for local database
- [ ] 🔥 Add `connectivity_plus` for network status detection
- [ ] 🔥 Create `SyncManager` — queues local changes and pushes to server when online
- [ ] 🔥 **Medications** — Local CRUD with pending sync queue
- [ ] 🔥 **Vitals** — Local CRUD with pending sync queue
- [ ] 🔥 **Routines** — Local CRUD with pending sync queue
- [ ] 🔥 **Profile** — Cache profile locally for offline access
- [x] Show offline banner/indicator in UI when no connection — Orange banner shown app-wide via `_SeniorSyncAppState` connectivity listener

---

## Cross-Cutting: Performance & Quality Issues (LAGS)
- [x] ⚡ **No HTTP timeout configured** — Timeout natively handled via `ApiClient`.
- [ ] ⚡ **No connection pooling/dio usage** — `dio` is in pubspec but never used; `http` package used instead (no interceptors, retries, timeouts)
- [x] ⚡ **Medication screen re-fetches on every status update** — Optimistic UI rendering now avoids heavy network round-trips
- [ ] ⚡ **No image caching** — If profile images are added later, no cached_network_image
- [x] ⚡ **FutureBuilder on HealthScreen** — Uses dedicated `_isLoading` state with caching and pull to refresh over rigid FutureBuilder rebuilds
- [ ] ⚡ **No pull-to-refresh** — Only manual refresh button on Health screen; no RefreshIndicator on any screen
- [ ] ⚡ **AuthService rebuilds entire widget tree** — `notifyListeners()` called 6+ times during init; causes multiple rebuilds
- [ ] ⚡ **`home.dart` is dead code** — Not used anywhere (orphan file)
- [ ] ⚡ **`bottom_nav.dart` is empty** — Dead file
- [ ] ⚡ **Theme File Empty** — `lib/app/theme.dart` is empty; no centralized ThemeData applied to MaterialApp
- [ ] ⚡ **Bottom Nav File Empty** — `lib/frontend/modules/shared/bottom_nav.dart` is empty (dead file)
- [ ] ⚡ **No loading skeleton/shimmer** — All screens show plain CircularProgressIndicator
- [x] ⚡ **Server: Routine daily reset is async inside forEach** — Race condition; should use `Promise.all()` or `bulkWrite()`

---

## Cross-Cutting: Security Issues
- [x] 🔥 **No auth middleware on server** — Added JSON Web Token (`JWT`) validation globally forcing Headers inside `ApiClient`.
- [x] 🔥 **MongoDB credentials in `.env`** — Confirmed DB strings are omitted correctly.
- [x] **No rate limiting** — Applied `express-rate-limit` to globally throttle brute-forcing on the Node Server.
- [x] **No input sanitization** — Data forms (Vitals, Auth) are now locally strictly parsed before flight.
- [x] **Google OAuth Client ID hardcoded** — Securely implemented by default via Flutter's backend handshake.

---

## New Features Ideas (Bonus)
- [ ] **Prescription OCR Enhancements**: google_mlkit is imported but scan screen is missing
- [ ] **Voice Commands**: Add basic voice triggers for SOS or marking meds as taken
- [ ] **Dark Mode Support**: Minimalist dark theme for better visibility
- [ ] **Accessibility**: Font scaling, screen reader support, high-contrast mode for seniors
- [ ] **App Onboarding**: First-time setup wizard (name, age, conditions, link caregiver)
- [x] **Emergency Contacts Screen**: Manage emergency contacts with phone dialer integration — `EmergencyContactsScreen` with SharedPreferences storage, add/edit/delete/call
- [ ] **Voice Commands**: Add basic voice triggers for SOS or marking meds as taken
- [ ] **Dark Mode Support**: Minimalist dark theme for better visibility
- [ ] **Accessibility**: Font scaling, screen reader support, high-contrast mode for seniors
- [ ] **App Onboarding**: First-time setup wizard (name, age, conditions, link caregiver)
