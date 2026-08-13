# MultiParking Tower

Premium Flutter mobile app for an automated multi-level car parking tower.

Users authenticate with phone OTP (MSG91 via FastAPI), optionally purchase Monthly or Annual subscriptions via Razorpay (or pay ₹50/hour on exit), register vehicles, receive automatic slot allocation, and access the tower with a secure opaque QR token.

## Features

- Phone OTP authentication via **MSG91** (backend `/auth/send-otp` · `/auth/verify-otp`); demo OTP supported
- Optional Monthly and Annual subscription plans with feature comparison
- Pay-as-you-go hourly billing (₹50/hour) for users without a plan
- Razorpay checkout with **backend payment verification only** (native Android SDK)
- Multi-vehicle management (Indian registration validation)
- Automatic slot allocation (preferential premium Zone A for subscribers — not a permanent reserved bay)
- Encrypted/opaque QR access codes (`qr_flutter` display)
- Parking history, notifications, profile, settings, support
- Light / Dark Material 3 theme inspired by the supplied brand template
- Clean Architecture + Riverpod + GoRouter + Dio
- Demo mode for full offline walkthrough without backend credentials

## Tech stack

Flutter 3 / Dart 3 · Material 3 · Riverpod · GoRouter · Dio · Secure Storage · Shared Preferences · Razorpay · qr_flutter · mobile_scanner · **FastAPI + PostgreSQL + MSG91** (Firebase/FCM optional later)

## Tower inventory

Local API seeds **Tower A · 11 floors × 100 slots = 1100**:

| Tier | Layout | Count |
|------|--------|-------|
| Premium (subscriber preference) | Zone A on every floor · A-01…A-20 | **220** |
| Standard (hourly) | Zones B–E · 80 per floor | **880** |

Subscribers get preferential premium bays on floors 1–3 (then any premium), freed on exit — **not** a permanently reserved bay for the plan duration.

## Backend API

See [`backend/README.md`](backend/README.md).

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
# Fill DATABASE_URL, JWT_SECRET, QR_SECRET, MSG91_*, RAZORPAY_* as needed
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

On startup, if the slot count ≠ 1100 the API reseeds inventory automatically (SQLite locally, or Supabase when `DATABASE_URL` is a real Postgres URI).

With `OTP_DEV_MODE=true` (local default), OTP is `123456`. Hosted production: MSG91 keys + `OTP_DEV_MODE=false`.

## Getting started

### Prerequisites

- Flutter stable (`flutter doctor` should be clean)
- Android Studio for device / APK builds
- (Production) MSG91 account, Razorpay test/live keys, reachable FastAPI URL

### Install & run (demo mode — offline)

```bash
flutter pub get
flutter run --dart-define=APP_MODE=demo
```

Demo credentials:

- Any valid Indian mobile number (e.g. `9876543210`)
- OTP: `123456`
- Staff console: username `staff` / password `Parking@123`
  (also `admin` / `Admin@123`) — **change these before any shared/production deploy**

### Production mode — hosted HTTPS API (required for a shareable APK)

Flutter talks only to FastAPI. FastAPI talks to Supabase. The phone never uses `DATABASE_URL`.

```bat
cd c:\Users\THARUN\Downloads\Smart-Parking-Tower-main\Smart-Parking-Tower-main
flutter pub get
flutter run --dart-define=APP_MODE=production --dart-define=API_BASE_URL=https://YOUR-API.onrender.com/v1
```

### Build a release APK (HTTPS only — not localhost / LAN)

```bat
cd c:\Users\THARUN\Downloads\Smart-Parking-Tower-main\Smart-Parking-Tower-main
flutter build apk --release --dart-define=APP_MODE=production --dart-define=API_BASE_URL=https://YOUR-API.onrender.com/v1
```

APK: `build\app\outputs\flutter-apk\app-release.apk`

Replace `YOUR-API.onrender.com` with your Render/Railway hostname. Do **not** bake `localhost`, `127.0.0.1`, or a `192.168.*` LAN IP into a release APK.

### Laptop-only: phone on same Wi‑Fi as PC

Use this only while the API runs on your PC. It will not work for anyone off your network.

```bat
flutter run --dart-define=APP_MODE=production --dart-define=API_BASE_URL=http://192.168.1.42:8000/v1
```

Android emulator → `http://10.0.2.2:8000/v1`. Chrome on the same PC → `http://localhost:8000/v1` (Razorpay is simulated on web).

Debug APK against LAN (not for sharing):

```bat
flutter build apk --debug --dart-define=APP_MODE=production --dart-define=API_BASE_URL=http://192.168.1.42:8000/v1
```

The Razorpay Key ID is served by the backend (create-order + `GET /v1/config`); `--dart-define=RAZORPAY_KEY_ID=...` is only an optional override. **Never** put the Razorpay secret in the app.

For **live SMS OTP + Razorpay test checkout**, see [docs/INTEGRATION.md](docs/INTEGRATION.md#live-otp--razorpay).

See [`.env.example`](.env.example) for dart-define flags. Backend secrets live in `backend/.env` (from `backend/.env.example`).

## Architecture

```
lib/
  core/           # theme, config, networking, storage, shared widgets
  models/         # immutable domain entities
  repositories/   # interfaces + demo + Dio implementations
  providers/      # cross-feature Riverpod notifiers
  features/       # feature-first UI (auth, subscription, payment, ...)
  routes/         # GoRouter + guards
```

Repositories switch automatically:

- `APP_MODE=demo` → in-memory demo repositories
- `APP_MODE=production` → Dio REST repositories (`ApiAuthRepository` → MSG91 OTP)

## Assumed backend API contract

Base URL: `{API_BASE_URL}`

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/config` | Public bootstrap (`otpDevMode`, `msg91Enabled`, slot counts, Razorpay key id) |
| POST | `/auth/send-otp` | Send phone OTP (MSG91 / dev) |
| POST | `/auth/verify-otp` | Verify OTP → JWT + user |
| POST | `/auth/staff/login` | Staff username/password → JWT |
| POST | `/auth/refresh` | Refresh access token |
| GET | `/users/me` | Current user profile |
| GET/POST/PATCH/DELETE | `/vehicles` | Vehicle CRUD |
| GET | `/plans` | Subscription plans |
| GET | `/subscriptions/current` | Active subscription |
| GET | `/payments/history` | Payment history |
| POST | `/payments/create-order` | Create Razorpay order |
| POST | `/payments/verify` | Verify payment signature (authoritative) |
| POST | `/payments/parking/create-order` | Hourly exit order |
| POST | `/payments/parking/verify` | Hourly payment verify |
| POST | `/payments/razorpay/webhook` | Server-to-server settlement |
| GET/POST | `/parking/slot` / `/parking/allocate` | Slot status / allocate |
| GET | `/parking/history` | Parking sessions |
| GET/POST | `/qr/current` / `/qr/refresh` | Opaque QR token |
| GET | `/notifications` | In-app notifications |
| POST | `/fcm/register` | Register FCM device token (optional) |

### Security rules enforced by the app

- JWT stored in Flutter Secure Storage
- QR payload contains **only** an opaque backend-issued token
- Client-side Razorpay “success” never activates a subscription alone
- Production builds should use an **HTTPS** `API_BASE_URL` for release APKs

## Branding

- Logo: `assets/images/logo.png`
- Palette: deep teal/slate `#2C4A56` / `#3A505D`, peach accents `#F2C299` / `#F1A27B`, cream surfaces `#F5E9D6`

## Tests

```bash
flutter test
flutter analyze
cd backend && pytest -q
```

## Platform notes

### Android

- Internet, camera, and notification permissions are declared in `AndroidManifest.xml`
- Debug cleartext HTTP is allowed for LAN testing; **release APKs should target HTTPS**
- Use a physical device or emulator for native Razorpay (not Chrome as the main path)

### iOS (requires macOS)

- Camera usage string is set in `Info.plist`

## License

Private project — all rights reserved.
