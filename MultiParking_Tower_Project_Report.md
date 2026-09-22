---
title: "MultiParking Tower — Smart Automated Multi-Level Car Parking System"
subtitle: "Project Report"
version: "1.0.0"
---

<div align="center">

# MultiParking Tower — Smart Automated Multi-Level Car Parking System

### Project Report

**Flutter · FastAPI · Firebase · Razorpay · PostgreSQL**

| Document | Detail |
|:---------|:-------|
| Version | 1.0.0 |
| Document type | Project Report |
| System | Smart Automated Multi-Level Car Parking System |
| Application ID | `com.multiparking.multiparking_tower` |

</div>

---

## 1. Abstract

MultiParking Tower is a full-stack mobile application for managing an automated multi-level car parking tower with 1,100 bays across 11 floors. The system supports member authentication via Firebase Phone OTP, automated slot allocation, encrypted QR-based gate access, Razorpay payment integration, and a staff console for real-time operations. The backend is built with FastAPI and PostgreSQL (Supabase), deployed on Render. The app supports both online and offline (demo) modes.

---

## 2. Table of Contents

1. [Abstract](#1-abstract)
2. [Table of Contents](#2-table-of-contents)
3. [Introduction](#3-introduction)
4. [Objectives](#4-objectives)
5. [Technology Stack](#5-technology-stack)
6. [System Architecture](#6-system-architecture)
7. [Features](#7-features)
8. [Database Design](#8-database-design)
9. [Tower Inventory](#9-tower-inventory)
10. [API Endpoints](#10-api-endpoints)
11. [Security Implementation](#11-security-implementation)
12. [Deployment](#12-deployment)
13. [Testing & Demo](#13-testing--demo)
14. [Project Structure](#14-project-structure)
15. [Screenshots](#15-screenshots)
16. [Future Enhancements](#16-future-enhancements)
17. [Conclusion](#17-conclusion)
18. [References](#18-references)

---

## 3. Introduction

Urban parking is constrained by limited land, growing vehicle density, and slow manual processes at the gate. Drivers waste time searching for bays, operators lack a live occupancy picture, and billing is often inconsistent.

MultiParking Tower addresses this with an automated smart parking tower operated through a mobile application. Members authenticate, register vehicles, receive an allocated bay, and enter or exit with an encrypted QR pass. Staff operate a console for scanning, walk-in registration, session control, and cash collection.

**Problem:** Urban parking shortage, manual systems, inefficiency.

**Solution:** Automated smart parking tower with mobile app.

**Scope:** Member app + Staff console + REST API + Cloud deployment.

---

## 4. Objectives

- Phone OTP authentication using Firebase
- Automated slot allocation across 11 floors (1100 bays)
- Encrypted QR-based tower access
- Razorpay payment integration (hourly + subscription)
- Staff console with QR scanner and walk-in management
- Real-time occupancy monitoring
- Cloud deployment (Render + Supabase)

---

## 5. Technology Stack

### 5.1 Frontend

| Component | Technology |
|:----------|:-----------|
| Framework | Flutter 3 / Dart 3 |
| UI | Material 3 |
| State management | Riverpod (state) |
| Navigation | GoRouter (navigation) |
| HTTP client | Dio (HTTP) |
| Authentication | Firebase Auth (OTP) |
| Payments | Razorpay Flutter SDK (payments) |
| QR scanning | mobile_scanner (QR scanning) |
| QR generation | qr_flutter (QR generation) |
| Token storage | Flutter Secure Storage (JWT) |

### 5.2 Backend

| Component | Technology |
|:----------|:-----------|
| API framework | FastAPI (Python) |
| ORM | SQLAlchemy 2.0 async (ORM) |
| Database | PostgreSQL / Supabase (database) |
| Migrations | Alembic (migrations) |
| Access tokens | python-jose (JWT) |
| QR protection | cryptography (QR encryption) |
| Payment verification | Razorpay Python SDK (payment verification) |
| Identity verification | google-auth (Firebase token verification) |

### 5.3 Infrastructure

| Layer | Platform |
|:------|:---------|
| Backend hosting | Render (backend hosting) |
| Database | Supabase (PostgreSQL) |
| Authentication | Firebase (auth) |
| Payments | Razorpay (payments) |
| Source control | GitHub (source code) |

---

## 6. System Architecture

### 6.1 High-level data flow

```
Flutter App → HTTPS → FastAPI (Render) → Supabase PostgreSQL / Firebase Auth / Razorpay
```

| Client | Transport | API | Downstream services |
|:-------|:----------|:----|:--------------------|
| Flutter App | HTTPS | FastAPI (Render) | Supabase PostgreSQL / Firebase Auth / Razorpay |

### 6.2 Application architecture

App architecture: Clean Architecture with Repository pattern.

| Layer | Location | Responsibility |
|:------|:---------|:---------------|
| Core | `lib/core` (theme, config, networking) | Theme, configuration, and HTTP |
| Domain models | `lib/models` (13 entities) | Shared data entities |
| Data | `lib/repositories` (interfaces + demo + API) | Repository contracts, demo store, live API |
| State | `lib/providers` (Riverpod) | Application state |
| Presentation | `lib/features` (feature-first UI) | Screens and feature UI |
| Routing | `lib/routes` (GoRouter) | Navigation |

**Total:** 113 Dart files + 46 Python files.

---

## 7. Features

### 7.1 Member application

| Feature | Description |
|:--------|:------------|
| Phone OTP login | Member sign-in with Firebase Phone OTP |
| Vehicle management | Register and manage vehicles |
| Slot booking | Automated bay allocation |
| QR access pass | Encrypted QR for tower entry and exit |
| Subscription plans (monthly/annual) | Recurring access plans |
| Hourly billing (Rs.50/hr) | Pay-as-you-park tariff |
| Razorpay payments | In-app checkout |
| Parking history | Past sessions and charges |
| Notifications | In-app operational alerts |
| Profile / settings | Account and app preferences |
| Demo mode | Offline demonstration without the live API |

### 7.2 Staff console

| Feature | Description |
|:--------|:------------|
| Dashboard (occupancy/revenue) | Live occupancy and revenue snapshot |
| QR scanner | Validate member access passes |
| Walk-in registration | Register drivers without the member app |
| Session management | Track active parking sessions |
| Checkout | Close a session at exit |
| Cash collection | Collect outstanding hourly charges |

---

## 8. Database Design

The PostgreSQL schema comprises **11 tables**.

| # | Table | Purpose |
|:--|:------|:--------|
| 1 | `users` | Members, staff, and admin accounts |
| 2 | `vehicles` | Registered vehicles per member |
| 3 | `parking_slots` (1100 rows) | Tower A inventory — 11 floors × 100 bays |
| 4 | `parking_history` | Entry, exit, billing, and walk-in sessions |
| 5 | `subscriptions` | Active and historical member plans |
| 6 | `plans` | Monthly and annual plan catalogue |
| 7 | `qr_accesses` | Encrypted QR access tokens |
| 8 | `payments` | Razorpay orders and settlement records |
| 9 | `notifications` | In-app notification inbox |
| 10 | `otp_challenges` | OTP challenge records |
| 11 | `fcm_tokens` | Device tokens for push delivery |

---

## 9. Tower Inventory

| Attribute | Value |
|:----------|:------|
| Tower | Tower A |
| Floors | 11 floors |
| Slots per floor | 100 slots/floor |
| Total bays | 1100 total |

### 9.1 Zone mix

| Class | Zones | Inventory |
|:------|:------|:----------|
| Premium | Zone A | 20/floor × 11 = 220 |
| Standard | Zones B–E | 80/floor × 11 = 880 |
| **Total** | Zones A–E | **1100** |

Subscribers get preferential premium bays, freed on exit.

---

## 10. API Endpoints

Base URL: `https://multiparking-api.onrender.com`

| Method | Endpoint | Description |
|:-------|:---------|:------------|
| GET | `/health` | Service health check |
| GET | `/v1/config` | Public client configuration |
| POST | `/v1/auth/firebase` | Member login with Firebase ID token |
| POST | `/v1/auth/staff/login` | Staff / admin username–password login |
| POST | `/v1/auth/refresh` | Refresh JWT session |
| GET | `/v1/users/me` | Current user profile |
| GET / POST | `/v1/vehicles` | List or register vehicles |
| GET | `/v1/plans` | Subscription plan catalogue |
| POST | `/v1/payments/create-order` | Create Razorpay order (subscription) |
| POST | `/v1/payments/verify` | Verify Razorpay signature and activate plan |
| POST | `/v1/parking/allocate` | Allocate a parking slot |
| GET | `/v1/parking/history` | Member parking history |
| GET | `/v1/qr/current` | Current encrypted QR access pass |
| GET | `/v1/staff/overview` | Occupancy and revenue dashboard |
| GET | `/v1/staff/sessions` | Active and recent parking sessions |
| POST | `/v1/staff/scan` | Validate a scanned QR token |
| POST | `/v1/staff/walk-in` | Register a walk-in driver |
| POST | `/v1/staff/sessions/{id}/checkout` | Close a session at exit |
| POST | `/v1/staff/sessions/{id}/collect` | Record cash collection |

---

## 11. Security Implementation

- JWT in Secure Storage
- Encrypted opaque QR tokens (server-side decryption only)
- Server-side Razorpay signature verification
- Firebase ID token verification on backend
- Role-based access control (user/staff/admin)
- ProGuard keep rules for release builds

---

## 12. Deployment

| Layer | Detail |
|:------|:-------|
| Backend | Render (Docker), URL: https://multiparking-api.onrender.com |
| Database | Supabase PostgreSQL (ap-south-1) |
| App | Android APK (`com.multiparking.multiparking_tower`), Firebase project: `multiparking-tower` |
| CI / CD | Auto-deploy from GitHub main branch, 18 environment variables configured |

---

## 13. Testing & Demo

### 13.1 Demo credentials

| Role | Username | Password / OTP |
|:-----|:---------|:---------------|
| Staff | `staff` | `Parking@123` |
| Admin | `admin` | `Admin@123` |
| Member (demo OTP) | — | `123456` |

### 13.2 Demo flow

Member login → Add vehicle → Book slot → Get QR → Staff scans QR → Entry → Exit → Payment

### 13.3 Release build

| Item | Value |
|:-----|:------|
| Command | `flutter build apk --release` with production dart-defines |
| APK size | ~72.9 MB |

---

## 14. Project Structure

```
Smart-Parking-Tower-main/
├── lib/                          # Flutter application (113 Dart files)
│   ├── core/                     # theme, config, networking
│   │   ├── config/
│   │   ├── constants/
│   │   ├── errors/
│   │   ├── providers/
│   │   ├── services/
│   │   ├── theme/
│   │   ├── utils/
│   │   └── widgets/
│   ├── models/                   # 13 entities
│   ├── repositories/             # interfaces + demo + API
│   │   ├── api/
│   │   └── demo/
│   ├── providers/                # Riverpod
│   ├── features/                 # feature-first UI
│   │   ├── authentication/
│   │   ├── history/
│   │   ├── home/
│   │   ├── notifications/
│   │   ├── parking/
│   │   ├── payment/
│   │   ├── profile/
│   │   ├── qr/
│   │   ├── settings/
│   │   ├── staff/
│   │   ├── subscription/
│   │   ├── support/
│   │   └── vehicle/
│   ├── routes/                   # GoRouter
│   ├── app.dart
│   ├── firebase_options.dart
│   └── main.dart
├── backend/                      # FastAPI service (46 Python files)
│   ├── alembic/
│   ├── app/
│   │   ├── api/v1/
│   │   ├── core/
│   │   ├── db/
│   │   ├── schemas/
│   │   ├── services/
│   │   └── main.py
│   ├── scripts/
│   ├── tests/
│   ├── Dockerfile
│   ├── alembic.ini
│   └── requirements.txt
└── android/                      # Android host (com.multiparking.multiparking_tower)
    ├── app/
    │   ├── src/main/
    │   ├── build.gradle.kts
    │   ├── google-services.json
    │   └── proguard-rules.pro
    ├── gradle/wrapper/
    ├── build.gradle.kts
    └── settings.gradle.kts
```

---

## 15. Screenshots

| Figure | Screen | Image |
|:-------|:-------|:------|
| 15.1 | Member Login Screen | [Insert Screenshot] |
| 15.2 | Home Dashboard | [Insert Screenshot] |
| 15.3 | Vehicle Registration | [Insert Screenshot] |
| 15.4 | Slot Booking | [Insert Screenshot] |
| 15.5 | QR Access Pass | [Insert Screenshot] |
| 15.6 | Staff Console | [Insert Screenshot] |
| 15.7 | Staff QR Scanner | [Insert Screenshot] |
| 15.8 | Parking Sessions | [Insert Screenshot] |
| 15.9 | Payment Screen | [Insert Screenshot] |

**Member Login Screen**

[Insert Screenshot]

**Home Dashboard**

[Insert Screenshot]

**Vehicle Registration**

[Insert Screenshot]

**Slot Booking**

[Insert Screenshot]

**QR Access Pass**

[Insert Screenshot]

**Staff Console**

[Insert Screenshot]

**Staff QR Scanner**

[Insert Screenshot]

**Parking Sessions**

[Insert Screenshot]

**Payment Screen**

[Insert Screenshot]

---

## 16. Future Enhancements

- iOS deployment
- WebSocket real-time updates
- ANPR license plate recognition
- Multi-tower support
- Admin web dashboard
- FCM push notifications
- Google Pay / UPI
- Play Store submission

---

## 17. Conclusion

MultiParking Tower is a production-ready smart parking system automating the complete lifecycle from registration to payment. Deployed live on Render with 1,100 bays, it handles app-based and walk-in drivers through a unified platform. The clean architecture ensures maintainability and the demo mode enables offline demonstration.

---

## 18. References

1. Flutter documentation — https://docs.flutter.dev
2. FastAPI documentation — https://fastapi.tiangolo.com
3. Firebase Auth documentation — https://firebase.google.com/docs/auth
4. Razorpay documentation — https://razorpay.com/docs
5. Supabase documentation — https://supabase.com/docs
6. SQLAlchemy documentation — https://docs.sqlalchemy.org

---

*End of Report — MultiParking Tower v1.0.0*
