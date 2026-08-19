# MultiParking Tower — Integration Notes

## Demo vs Production

| Concern | Demo (`APP_MODE=demo`) | Production |
|---------|------------------------|------------|
| Auth | In-app OTP `123456` | Firebase Phone Auth → `POST /auth/firebase` → JWT (`FirebaseAuthRepository`) |
| Payments | Simulated order + verify | Native Razorpay SDK + `POST /payments/verify` |
| Slots / QR | In-memory (11×100 capacity totals) | FastAPI + Postgres · Tower A 1100 bays |
| Notifications | Seeded list | API notifications (+ optional FCM later) |
| Bootstrap | Local defaults (1100 / 220 / 880) | `GET /v1/config` |

Staff login is always username/password (`/auth/staff/login`) — not OTP.

## Backend (FastAPI)

See [`backend/README.md`](../backend/README.md).

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Phone on LAN (replace IP):

```bash
flutter run \
  --dart-define=APP_MODE=production \
  --dart-define=API_BASE_URL=http://192.168.1.42:8000/v1 \
  --dart-define=ENABLE_FIREBASE=true
```

## Live OTP + Razorpay

### 1. Firebase Phone Auth (primary member login)

MSG91 is **unused** for member login. The app sends SMS via Firebase, then exchanges the ID token with FastAPI.

1. Firebase Console project **multiparking-tower**:
   - Authentication → Sign-in method → enable **Phone**
   - Project settings → Android app `com.multiparking.multiparking_tower` → add **SHA-1** (debug and/or release)
2. Keep `android/app/google-services.json` in place (gitignored).
3. Backend `.env` and Render env: `FIREBASE_PROJECT_ID=multiparking-tower` (must match the token audience).
4. Run / build with:

```bat
flutter run --dart-define=APP_MODE=production --dart-define=API_BASE_URL=https://multiparking-api.onrender.com/v1 --dart-define=ENABLE_FIREBASE=true
```

Demo mode (`APP_MODE=demo`) still uses OTP `123456` and does not call Firebase.

### 2. Razorpay (test mode)

Leave keys empty for stub/dev-only. For real phone checkout:

```env
RAZORPAY_KEY_ID=rzp_test_xxxxxxxx
RAZORPAY_KEY_SECRET=your_test_secret
RAZORPAY_WEBHOOK_SECRET=pick_a_strong_secret
```

Restart uvicorn; `GET /v1/config` should show `razorpayEnabled: true`. Confirm with `python scripts/check_razorpay.py`.

Run Flutter on **Android** — native Razorpay is the main path (Chrome only simulates):

```bash
flutter run -d <android-device> \
  --dart-define=APP_MODE=production \
  --dart-define=API_BASE_URL=http://192.168.1.42:8000/v1
```

Key ID comes from the API; never put the secret in the app.

Flows that charge:

- Optional subscription: Monthly/Annual → Razorpay → `POST /payments/verify`
- Hourly exit: QR EXIT → PAY ₹X → Razorpay → `POST /payments/parking/verify`

Test cards (test mode): `4111 1111 1111 1111`, any future expiry, any CVV, OTP `1234`. UPI: `success@razorpay`.

### 3. Razorpay webhook (recommended)

1. Expose the API publicly (hosted URL, or `ngrok http 8000` while testing).
2. Dashboard → **Settings → Webhooks → Add New Webhook**:
   - URL `https://<public-api>/v1/payments/razorpay/webhook`
   - Secret — exact value of `RAZORPAY_WEBHOOK_SECRET`
   - Events — `payment.captured`, `order.paid`
3. Verify with `python scripts/check_payment_flow.py`.

## Phone / APK

Flutter never talks to Supabase. The APK talks to the **hosted FastAPI** over HTTPS.

| Scenario | `API_BASE_URL` |
|----------|----------------|
| Shareable / release APK | `https://YOUR-API.onrender.com/v1` |
| Phone ↔ PC LAN (laptop only) | `http://<PC-LAN-IP>:8000/v1` |
| Android emulator | `http://10.0.2.2:8000/v1` |

```bat
flutter build apk --release --dart-define=APP_MODE=production --dart-define=API_BASE_URL=https://YOUR-API.onrender.com/v1
```

Debug builds may use cleartext HTTP for LAN testing; release must use HTTPS. Demo mode (`APP_MODE=demo`) is offline UI only.

## Supabase PostgreSQL

Flutter never talks to Supabase. FastAPI uses `DATABASE_URL`.

1. Create a project and copy **Project Settings → Database → URI**.
2. Set `postgresql+asyncpg://postgres:URL_ENCODED_PASSWORD@db.PROJECT_REF.supabase.co:5432/postgres` (or pooler port 6543).
3. Start/deploy the API — `create_all` + seed **1100** `parking_slots`.
4. Table Editor → `parking_slots` → confirm 1100 rows.

## Inventory notes

- **1100** slots: floors 1–11 × 100 (zones A–E × 20).
- Premium **220** (Zone A); standard **880**.
- Plan copy: preferential premium bay — **not** a permanent reserved slot for the subscription duration.

## QR tokens

- Backend issues an opaque Fernet token bound to user, vehicle, slot, subscription, and expiry.
- App renders `token` only.
- Gate scanners call `POST /v1/gate/validate` with header `X-Gate-Key`.

## FCM (optional)

1. Request notification permission.
2. Obtain FCM token (`ENABLE_FIREBASE=true` + google-services files).
3. `POST /v1/fcm/register` with token + platform.
