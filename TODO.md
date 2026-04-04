# SeniorSync Project TODO List

This list tracks the implementation progress of SeniorSync based on the Business Requirements Document (BRD).
Items marked with 🔥 are critical gaps. Items marked with ⚡ are performance/quality issues. Items marked with 🆕 are recently added requirements from the BRD.

---

## Project Architecture
- [x] Restructure Project (Frontend/Backend folders)
- [x] Setup Node.js Server (Express + MongoDB)
- [x] Integrate Firebase Auth (Frontend + Backend Sync)
- [x] Setup Provider for State Management
- [x] Build Stability & Version Alignment (Fixing Gradle Errors)
- [x] 🔥 **Offline-First Local Storage** — Local cache and sync (SQLite/Hive)
- [x] 🔥 **Network Connectivity Check** — Online/offline banner and routing
- [x] **API Error Handling** — Unified error handling
- [x] **JWT Auth Middleware**
- [x] **Server Controllers**
- [x] ⚡ **Theme File Empty**
- [x] ⚡ **Bottom Nav File Empty**

---

## Module 1: Medication & Schedule Manager
- [x] Define Medication Model (Node/Dart)
- [x] Implement Node.js API to CRUD Medications
- [x] Integrate Flutter UI with Node.js API
- [x] Implement Dose Confirmation Logic (Taken/Skipped/Missed) (BR-04)
- [x] Daily Medication Summary & Tabs (BR-05)
- [x] 🔥 **Offline Medication Cache** & local syncing
- [x] 🔥 **Local Notifications for Reminders** (BR-02)
- [x] 🔥 **Caregiver Notification on Missed Dose** (BR-03)
- [x] **Medication Delete from UI**
- [x] **Prescription OCR**
- [x] ⚡ **Medication Status Reset**
- [x] ⚡ **No loading timeout**
- [x] 🆕 **Medication Snooze Option (MED-11)** — Add 10-minute snooze without pausing the 30-min missed timer.
- [x] 🆕 **Custom Alerts (MED-10)** — Allow users to select unique tones for different medications.
- [x] 🆕 **Skipped Reason Prompt (MED-09)** — Ask for reason (e.g. "Feeling Nauseous") when skipping a dose.
- [x] 🆕 **Detailed Caregiver Alerts (MED-07)** — Ensure missed dose push notification includes exact medicine name and senior's name.

## Module 2: Emergency & SOS System
- [x] Persistent One-Tap SOS Button (BR-06)
- [x] GPS Location Capturing during SOS (BR-07)
- [x] SOS Cancellation Countdown (BR-08)
- [x] 🔥 **Nearby Hospital Finder (OpenStreetMap)** (BR-09)
- [x] **SOS History Screen**
- [x] **Offline SOS Fallback**
- [x] ⚡ **No haptic/vibration feedback**
- [x] ⚡ **SOS screen doesn't use SeniorStyles**
- [x] 🆕 **Caregiver Alert Map Link (SOS-03)** — Caregiver's SOS alert must include a clickable OpenStreetMaps link based on captured GPS.

## Module 3: Caregiver Dashboard
- [x] Senior-Caregiver Pairing Logic (QR/Invite/Email) (BR-12)
- [x] **Consolidated View of Linked Seniors** (BR-10)
- [x] 🔥 **Real-Time SOS/Meds Alerts for Caregivers** (BR-11)
- [x] **Role-Based Access Control** (BR-14)
- [x] **Caregiver API**
- [x] **QR Code Pairing**
- [x] 🆕 **Multiple Caregiver Association (BRU-04)** — Support linking multiple caregivers with configurable permission levels.
- [x] 🆕 **Secure Invite Links (DASH-03)** — Generate unique linking invites that expire after 24 hours.
- [x] 🆕 **Unlink Caregiver with Confirmation (SEC-04)** — UI to view and unlink caregivers (revoke token) instantly.

## Module 4: Wellness, Vitals & Education
- [x] Manual Vitals Entry (BP, HR, Sugar) (BR-18)
- [x] Historical Vitals Trend Visualization (Graphs) (BR-19)
- [x] 🔥 **Offline Vitals Cache**
- [x] **Wellness Content Feed** (BR-15/16)
- [x] **Hydration & Lifestyle Reminders** (BR-17)
- [x] ⚡ **Vitals Validation**
- [x] ⚡ **Chart Label Missing**
- [x] 🆕 **Vitals Chart Zooming (VIT-05)** — Ensure historical lines charts for BP/HR support zooming for daily/weekly trends.

## Module 5: Routine & Activity Manager
- [x] Daily Routine Task Management (Create/Complete) (BR-20/22)
- [x] Completion Streak Tracking (BR-21)
- [x] 🔥 **Offline Routine Cache**
- [x] **Routine Edit & Delete Confirmation**
- [x] ⚡ **Routine screen doesn't use SeniorStyles**
- [x] 🆕 **Streak Reset Enforce (ROUT-02)** — Verify that daily streak counters strictly reset if a task is not marked complete by end of day.

## Module 6: User Profile & Security
- [x] User Syncing (Firebase to MongoDB)
- [x] Medical Profile Management (Edit Name/Age) (BR-23)
- [x] **Medical Conditions Management**
- [x] **Biometric Authentication Integration** (BR-25)
- [x] **Data Archive/Cleanup Logic Manual**
- [x] ⚡ **Profile loads forever if sync fails**
- [x] 🆕 **Automated Data Archival (BRU-05)** — Archive and locally remove user health records older than 2 years automatically.

---

## Cross-Cutting & Previously Completed Tasks
- [x] Cross-Cutting: Offline-First Architecture (SQLite/Hive Setup, Connectivity checks, caches on all models)
- [x] Cross-Cutting: Performance & Quality Issues (HTTP timeouts, optimistic UI rendering, shimmer skeletons, code cleanup)
- [x] Cross-Cutting: Security Issues (JWT auth middleware, Express-rate-limit, Input Sanitization)
- [x] Extra Features (Dark mode, accessibility text-scaling, quick dialer contacts, voice triggers)
