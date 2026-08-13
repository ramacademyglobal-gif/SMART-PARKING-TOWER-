# MultiParking Tower — Integration Notes

## Demo vs Production

| Concern | Demo (`APP_MODE=demo`) | Production |
|---------|------------------------|------------|
| Auth | In-app OTP `123456` | FastAPI + **MSG91** SMS OTP → JWT (`ApiAuthRepository`) |
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
  --dart-define=API_BASE_URL=http://192.168.1.42:8000/v1
```

## Live OTP + Razorpay

### 1. MSG91 (real SMS — primary member auth)

1. Create an MSG91 account and an **OTP / SendOTP** template with an OTP variable (`otp` / `VAR1`).
2. In `backend/.env` set:

```env
MSG91_AUTH_KEY=your_auth_key
MSG91_TEMPLATE_ID=your_template_id
MSG91_SENDER_ID=MPARK
OTP_DEV_MODE=false
```

3. Restart uvicorn. `GET /v1/config` should show `otpDevMode: false` and `msg91Enabled: true`.
4. App OTP screen hides the “use 123456” hint and expects the SMS code.
5. With `OTP_DEV_MODE=true` (or empty MSG91 key), OTP is always `123456` and SMS is skipped.

Firebase Phone Auth is **not** required for member login. `ENABLE_FIREBASE` remains optional for future FCM.

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
