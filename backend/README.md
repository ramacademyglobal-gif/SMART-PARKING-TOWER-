# MultiParking Tower API

FastAPI backend for the MultiParking Tower Flutter app.

- PostgreSQL via `DATABASE_URL` (Supabase or local)
- **MSG91 SMS OTP** (primary member auth path)
- JWT access/refresh tokens
- Razorpay order create + server-side verification + webhook
- Automatic slot allocation + opaque Fernet QR tokens
- Gate validate endpoint for tower entry/exit

## Security placeholders (rotate before any shared deploy)

| Variable | Notes |
|----------|--------|
| `JWT_SECRET` | Must be a long random string — never ship the example value |
| `QR_SECRET` | Fernet key material — rotate independently of JWT |
| `GATE_API_KEY` | Header for hardware/gate scanners |
| `STAFF_PASSWORD` / `ADMIN_PASSWORD` | Defaults are for local demo only |

## Tower inventory

Seed creates **Tower A** with **1100** car slots (11 floors × 100):

| Tier | Layout | Count |
|------|--------|-------|
| Premium (~20%, subscriber preference) | Zone A · A-01…A-20 on floors 1–11 | **220** |
| Standard (~80%, hourly) | Zones B–E · 80 per floor | **880** |

IDs: `slot_a{floor:02d}{zone}{nn}` e.g. `slot_a01a01`, `slot_a11e20`.

On startup the API reseeds when `slot_count != 1100` (or `force_slots=True`). Subscribers get preferential Zone A on floors 1–3 (then any premium) — **not** a permanent reserved bay.

```bash
cd backend
python -m venv .venv
# Windows
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
# .env defaults to SQLite (sqlite+aiosqlite:///./multiparking.db) for laptop-only runs.
# For a shared cloud DB, set a real Supabase DATABASE_URL (YOUR_PROJECT placeholders stay SQLite).
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Open Swagger: http://localhost:8000/docs

Bind `--host 0.0.0.0` so a phone on the same LAN can reach the API (use the PC’s LAN IP in Flutter `API_BASE_URL`).

With `OTP_DEV_MODE=true`, use OTP `123456` for any valid Indian mobile. Live SMS requires MSG91 keys + `OTP_DEV_MODE=false`.

## Staff console

On every startup the API upserts gate accounts from `.env`:

| Role | Username | Password (default — change me) |
|------|----------|--------------------------------|
| Staff | `staff` | `Parking@123` |
| Admin | `admin` | `Admin@123` |

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/v1/auth/staff/login` | Username + password → JWT |
| GET | `/v1/staff/overview` | Tower snapshot (counts, not 1100 cards) |
| GET | `/v1/staff/slots?floor=1` | **One floor** of inventory (100 bays) |
| POST | `/v1/staff/scan` | QR scan → entry/exit details |
| POST | `/v1/staff/walk-in` | Book a bay by car number (no app) |
| GET | `/v1/staff/sessions` | Parked / completed (`floor` filter optional, limit 100) |
| POST | `/v1/staff/sessions/{id}/checkout` | Close a session + amount due |
| POST | `/v1/staff/sessions/{id}/collect` | Mark cash as collected |

## Supabase / Postgres setup

Flutter never connects to Supabase. Only FastAPI does.

1. Create a Supabase project.
2. **Project Settings → Database → Connection string → URI**.
3. Put it in `backend/.env` as `DATABASE_URL`. The API rewrites `postgresql://` to `postgresql+asyncpg://` and forces SSL. URL-encode special characters in the password (`@` → `%40`).

Direct (session) — port **5432**:

```
postgresql+asyncpg://postgres:YOUR_URL_ENCODED_PASSWORD@db.YOUR_PROJECT_REF.supabase.co:5432/postgres
```

Pooler (pgbouncer) — port **6543** (good for Render/Railway):

```
postgresql+asyncpg://postgres.YOUR_PROJECT_REF:YOUR_URL_ENCODED_PASSWORD@aws-0-YOUR_REGION.pooler.supabase.com:6543/postgres
```

Blank values and the `YOUR_PROJECT` / `YOUR_PASSWORD` placeholders fall back to local SQLite. A **real** host is never replaced with SQLite; a bad password/SSL/host fails startup with a clear error.

4. Start the API — `create_all` + seed **1100** slots into that database.
5. Confirm: `GET /v1/config` → `totalSlots: 1100`, and in Supabase **Table Editor** open `parking_slots` (row count 1100).

## Deploy (Render or Railway)

The image is `backend/Dockerfile`. Start command (already the Docker `CMD`):

```
uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}
```

Health check: `GET /health` (port 8000, or the platform `PORT`).

### Render

1. New Web Service → this repo → **Root Directory** `backend` → Docker.
2. Or use the repo-root [`render.yaml`](../render.yaml) blueprint (`sync: false` secrets must be filled in the dashboard).
3. Set env vars (see list below). `APP_ENV=production`.
4. After deploy, open `https://YOUR-SERVICE.onrender.com/health` then `/v1/config`.

### Railway

1. New project → Deploy from GitHub → set **Root Directory** to `backend`.
2. Railway detects the Dockerfile. Set the same env vars. Health: `/health`.

### Host env vars

| Name | Production value |
|------|------------------|
| `DATABASE_URL` | Real Supabase URI (asyncpg, encoded password) |
| `APP_ENV` | `production` |
| `CORS_ORIGINS` | `*` or your web origins |
| `JWT_SECRET` | long random string |
| `QR_SECRET` | long random string (32+ chars) |
| `GATE_API_KEY` | random; used by hardware scanners |
| `OTP_DEV_MODE` | `false` |
| `MSG91_AUTH_KEY` / `MSG91_TEMPLATE_ID` / `MSG91_SENDER_ID` | live SMS |
| `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` / `RAZORPAY_WEBHOOK_SECRET` | test or live keys |
| `STAFF_PASSWORD` / `ADMIN_PASSWORD` | not the local defaults |

If `APP_ENV=production` still has `OTP_DEV_MODE=true` or empty Razorpay keys, the API **logs a warning** and does not pretend stub mode is live checkout.

Point Flutter at `https://YOUR-SERVICE.onrender.com/v1` (note `/v1`). Webhook URL: `https://YOUR-SERVICE.onrender.com/v1/payments/razorpay/webhook`.

## MSG91 (primary member OTP)

Set in `.env`:

- `MSG91_AUTH_KEY`
- `MSG91_TEMPLATE_ID` (OTP / SendOTP template with OTP variable)
- `MSG91_SENDER_ID`
- `OTP_DEV_MODE=false`

Failures from MSG91 return a clear API error. Check server logs for the MSG91 response body.

Flutter production uses `ApiAuthRepository` → these endpoints (not Firebase Phone Auth).

## Razorpay

Leave `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` **empty** for **stub/dev-only** mode (fake orders; verify accepts any signature). That is **not** production.

For test or live checkout:

```env
RAZORPAY_KEY_ID=rzp_test_xxxxxxxx
RAZORPAY_KEY_SECRET=your_test_secret
RAZORPAY_WEBHOOK_SECRET=pick_a_strong_secret
```

The Key ID is served to the app two ways (secret never leaves the server):

- every `create-order` response carries the `key` to open checkout with;
- `GET /v1/config` returns `{ otpDevMode, razorpayKeyId, razorpayEnabled, msg91Enabled, totalSlots, … }`.

### Payment flow

1. App calls `POST /v1/payments/create-order` (or `/payments/parking/create-order`).
2. Native Razorpay SDK opens on Android/iOS and returns order/payment/signature.
3. App calls `POST /v1/payments/verify` (or `/payments/parking/verify`); the server recomputes the HMAC and only then activates the subscription or marks the session paid.

### Webhook (recommended)

`POST /v1/payments/razorpay/webhook` settles payments if the app is killed mid-flow.

- **URL** — `https://<your-public-api>/v1/payments/razorpay/webhook`
- **Secret** — same as `RAZORPAY_WEBHOOK_SECRET`
- **Events** — `payment.captured`, `order.paid`

Leaving `RAZORPAY_WEBHOOK_SECRET` empty disables the endpoint.

### Self-checks

```bash
python scripts/check_razorpay.py      # keys can create + sign a real order
python scripts/check_payment_flow.py  # full flow against a running local API
```

### Phone testing notes

- Use a **physical Android device** or emulator with the native Razorpay SDK.
- Chrome simulates gateway success only — not the main payment path.
- Point `API_BASE_URL` at `http://<LAN-IP>:8000/v1` for local API, or HTTPS for hosted.

## Flutter connection

```bash
# Phone on LAN
flutter run -d <device> \
  --dart-define=APP_MODE=production \
  --dart-define=API_BASE_URL=http://192.168.1.42:8000/v1

# Emulator
flutter run -d emulator-5554 \
  --dart-define=APP_MODE=production \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/v1

# APK
flutter build apk --release \
  --dart-define=APP_MODE=production \
  --dart-define=API_BASE_URL=https://your-api.example.com/v1
```

## Key endpoints (`/v1`)

| Method | Path | Notes |
|--------|------|-------|
| GET | `/config` | Public bootstrap (OTP flags, slot counts, Razorpay key id) |
| POST | `/auth/send-otp` | MSG91 / dev OTP |
| POST | `/auth/verify-otp` | Returns JWT session |
| POST | `/auth/staff/login` | Staff username/password |
| POST | `/auth/refresh` | Rotate tokens |
| GET | `/users/me` | Profile |
| CRUD | `/vehicles` | Plate validation |
| GET | `/plans` | Monthly / Annual |
| GET | `/subscriptions` | Current active sub |
| POST | `/payments/create-order` | Razorpay order |
| POST | `/payments/verify` | HMAC verify → subscription |
| POST | `/payments/parking/create-order` | Hourly exit order |
| POST | `/payments/parking/verify` | Hourly verify |
| POST | `/payments/razorpay/webhook` | Header `X-Razorpay-Signature` |
| POST | `/parking/allocate` | Auto slot |
| GET/POST | `/qr/current`, `/qr/refresh` | Opaque token |
| POST | `/gate/validate` | Header `X-Gate-Key` |

## Tests

```bash
cd backend
pytest -q
```

## Docker

```bash
cd backend
docker build -t multiparking-api .
docker run -p 8000:8000 --env-file .env -e PORT=8000 multiparking-api
```

Hosted platforms set `PORT` automatically. Health check: `GET /health`.
