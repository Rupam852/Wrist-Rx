<div align="center">

<img src="app/assets/images/app_logo.png" alt="Wrist Rx Logo" width="100" height="100" style="border-radius: 20px"/>

# Wrist Rx

### Next-Gen Health Tracking & SOS Emergency Guardian

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Node.js](https://img.shields.io/badge/Node.js-Express-339933?logo=node.js&logoColor=white)](https://nodejs.org)
[![MongoDB](https://img.shields.io/badge/MongoDB-Atlas-47A248?logo=mongodb&logoColor=white)](https://mongodb.com)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%26%20Storage-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Vercel](https://img.shields.io/badge/Website-Live%20on%20Vercel-000000?logo=vercel&logoColor=white)](https://wrist-rx.vercel.app)
[![Version](https://img.shields.io/badge/Version-1.0.1-00C853?logo=android&logoColor=white)](https://github.com/Rupam852/Wrist-Rx)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Connect 50+ smartwatch brands · Track health with hybrid BLE pedometer · Protect loved ones with 1-tap SOS**

[🌐 Live Website](https://wrist-rx.vercel.app) · [📥 Download APK](https://neo-files-transfer.pages.dev/download/ad3a54a49ab4) · [🐛 Report Bug](https://github.com/Rupam852/Wrist-Rx/issues) · [✨ Request Feature](https://github.com/Rupam852/Wrist-Rx/issues)

</div>

---

## 📸 Preview

<div align="center">

| Home & Health | SOS Guardian | Watch Connect | AI Assistant |
|:---:|:---:|:---:|:---:|
| Real-time BPM & Steps | 1-Tap Emergency Dispatch | BLE Device Scan | Gemini AI Chat |

> 🌐 **Full interactive preview:** [wrist-rx.vercel.app](https://wrist-rx.vercel.app)

</div>

---

## ✨ Features

### 🏃 Health & Fitness Tracking
- **Hybrid BLE Pedometer Fusion** — Combines smartwatch + phone sensors for accurate step counting
- **Real-time Heart Rate Monitoring** — Live BPM with optimal/warning range detection
- **Health Analytics Dashboard** — fl_chart powered graphs for daily/weekly trends
- **Foreground Service** — Background step tracking even when app is closed
- **Offline-first with Hive** — All health data cached locally, syncs when online

### ⌚ Smartwatch Integration
- **50+ Smartwatch Brand Support** — Universal BLE connection via `flutter_blue_plus`
- **Custom Prototype Support** — Wrist Rx custom ESP32/Arduino-based watch device
- **Auto-reconnect** — Persistent WebSocket connection to backend for live data
- **Battery & Signal Status** — Real-time watch status monitoring

### 💊 Smart Medicine Reminders
- **5-Second Precision Ticker** — High-frequency clock ticker checks schedules every 5s for exact minute accuracy
- **Direct BLE Smartwatch Haptic Burst** — Sends 3-pulse vibration waves & text popups to your smartwatch wrist motor
- **1-Tap Test Vibration Button (🔔)** — Instantly test watch motor vibration and status bar alert for any medicine
- **Tap-to-Edit Mode (✏️)** — Tap any saved reminder card to update medicine name, time, or dosage instructions
- **Multi-Vendor Haptic Sync** — Supports Noise uRPC, Fire-Boltt DaFit, boAt, and Wrist Rx custom hardware

### 🆘 SOS Emergency Guardian
- **1-Tap Emergency Dispatch** — Instant SMS + WhatsApp to emergency contacts
- **GPS Location Sharing** — Exact coordinates sent with every SOS alert
- **Fall Detection Ready** — Accelerometer-based automatic SOS trigger (prototype)
- **Emergency Contact Management** — Add/edit multiple guardians from profile

### 🤖 Gemini AI Health Assistant
- **Conversational Health Q&A** — Ask anything about your health data
- **Personalized Insights** — AI analysis of your step count, BPM trends
- **Smart Health Tips** — Context-aware daily wellness recommendations
- **Backend-powered** — AI route via secure Node.js proxy to Google Gemini

### 🔐 Authentication & Profile
- **Google Sign-In** via Firebase Auth
- **Email/Password** registration & login
- **Firebase Storage** — Profile photo upload & management
- **Secure local storage** — Tokens stored via `flutter_secure_storage`

---

## 🏗️ Architecture

```
Wrist Rx/
├── 📱 app/                          # Flutter Mobile App
│   ├── lib/
│   │   ├── core/
│   │   │   ├── constants/           # App colors, strings, config
│   │   │   ├── router/              # GoRouter navigation
│   │   │   ├── services/            # WebSocket, API, BLE services
│   │   │   └── theme/               # AppTheme, AppColors
│   │   ├── features/
│   │   │   ├── auth/                # Login, Register screens
│   │   │   ├── home/                # Dashboard, health cards
│   │   │   ├── watch/               # BLE scan, watch details
│   │   │   ├── ai/                  # Gemini AI chat screen
│   │   │   ├── profile/             # User profile, settings
│   │   │   └── settings/            # About, Preferences
│   │   └── shared/
│   │       └── widgets/             # MainShell, reusable components
│   └── android/
│       ├── app/
│       │   ├── build.gradle.kts     # Signing config + ABI splits
│       │   ├── proguard-rules.pro   # R8 minification rules
│       │   └── wrist_rx_release.keystore  # (gitignored)
│       └── key.properties           # (gitignored)
│
├── 🖥️ backend/                      # Node.js + Express REST API
│   └── src/
│       ├── config/
│       │   └── database.js          # MongoDB Atlas connection
│       ├── models/
│       │   └── HealthData.js        # Mongoose health schema
│       ├── routes/
│       │   ├── auth.js              # JWT auth endpoints
│       │   ├── health.js            # Health data CRUD
│       │   ├── watch.js             # Watch device management
│       │   ├── sos.js               # SOS alert endpoints
│       │   └── ai.js                # Gemini AI proxy
│       ├── middleware/              # Auth middleware
│       ├── jobs/                    # Scheduled tasks
│       └── index.js                 # Express server entry
│
└── 🌐 website/                      # Landing Page (Vercel)
    ├── index.html                   # Main landing page
    ├── style.css                    # Warm Silk Alabaster theme
    └── script.js                    # Animations, mobile menu, modals
```

---

## 🛠️ Tech Stack

### Mobile App (Flutter)
| Category | Package | Purpose |
|---|---|---|
| **State** | `flutter_riverpod` | Reactive state management |
| **Navigation** | `go_router` | Declarative routing |
| **Bluetooth** | `flutter_blue_plus` | BLE smartwatch connection |
| **Auth** | `firebase_auth` + `google_sign_in` | Authentication |
| **Storage** | `firebase_storage` | Profile photo cloud storage |
| **Local DB** | `hive_flutter` | Offline health data cache |
| **Secure** | `flutter_secure_storage` | Token encryption |
| **Charts** | `fl_chart` | Health analytics graphs |
| **Animation** | `flutter_animate` | Micro-animations |
| **Location** | `geolocator` | GPS for SOS |
| **Pedometer** | `pedometer` | Step counting |
| **Background** | `flutter_foreground_task` | Background health tracking |
| **SOS Share** | `url_launcher` + `share_plus` | Emergency messaging |

### Backend (Node.js)
| Category | Tech | Purpose |
|---|---|---|
| **Framework** | Express.js | REST API server |
| **Database** | MongoDB Atlas + Mongoose | Health data persistence |
| **Auth** | JWT (jsonwebtoken) | Stateless authentication |
| **AI Proxy** | Google Gemini API | AI health assistant |
| **Real-time** | WebSocket (ws) | Live watch data streaming |
| **Scheduler** | node-cron | Background health jobs |

### Infrastructure
| Service | Usage |
|---|---|
| **Firebase** | Auth, Storage, Google Sign-In |
| **MongoDB Atlas** | Cloud NoSQL database |
| **Vercel** | Website hosting (auto-deploy from GitHub) |
| **GitHub** | Source control + secret scanning |

---

## 🚀 Getting Started

### Prerequisites

```bash
# Flutter SDK (3.x)
flutter --version

# Node.js (18+)
node --version

# MongoDB Atlas account
# Firebase project
```

### 1. Clone the Repository

```bash
git clone https://github.com/Rupam852/Wrist-Rx.git
cd Wrist-Rx
```

### 2. Backend Setup

```bash
cd backend
npm install

# Copy env template and fill in your values
cp .env.example .env
```

**Edit `.env`:**
```env
PORT=3000
MONGODB_URI=mongodb+srv://<username>:<password>@cluster.mongodb.net/wrist_rx
JWT_SECRET=your_jwt_secret_here
GEMINI_API_KEY=your_google_gemini_api_key
```

```bash
# Start the backend server
npm start

# Development with hot reload
npm run dev
```

### 3. Flutter App Setup

```bash
cd app
flutter pub get

# Add your Firebase config
# Place google-services.json in android/app/
# (Download from Firebase Console)

# Run in debug mode
flutter run

# Build release APK (requires keystore - see Release Build section)
flutter build apk --release --split-per-abi
```

### 4. Website (Local Preview)

```bash
cd website
# Open index.html in browser or use Live Server extension in VS Code
```

---

## 📦 Release Build (APK Signing)

The app uses a custom RSA-2048 keystore with APK Signature Schemes **v1 + v2 + v3** for maximum Android compatibility and to avoid Play Protect warnings.

### Generate Keystore (one-time)

```bash
keytool -genkeypair -v \
  -keystore android/app/wrist_rx_release.keystore \
  -alias wrist_rx_key \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname "CN=YourName, OU=Mobile, O=YourOrg, L=City, ST=State, C=IN" \
  -storepass YOUR_STORE_PASSWORD \
  -keypass YOUR_KEY_PASSWORD
```

### Create `android/key.properties`

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=wrist_rx_key
storeFile=wrist_rx_release.keystore
```

> ⚠️ **Never commit `key.properties` or `*.keystore` to Git — they are gitignored!**

### Build Split APKs

```bash
cd app
flutter build apk --release --split-per-abi
```

**Output:**
```
build/app/outputs/flutter-apk/
  app-arm64-v8a-release.apk    ← Modern Android phones (~21 MB)
  app-armeabi-v7a-release.apk  ← Older Android phones (~19 MB)
  app-x86_64-release.apk       ← Emulators (~23 MB)
```

---

## 🔒 Security

- ✅ **No hardcoded secrets** — All credentials via `.env` / `key.properties`
- ✅ **`.gitignore`** covers `*.keystore`, `key.properties`, `.env*`, `google-services.json`
- ✅ **JWT authentication** on all backend API routes
- ✅ **HTTPS only** — Backend deployed with TLS
- ✅ **R8 code minification** — Source obfuscation in release builds
- ✅ **GitHub secret scanning** — Auto-alerts for leaked credentials

---

## 🌐 Website

The landing page at **[wrist-rx.vercel.app](https://wrist-rx.vercel.app)** is built with:
- Pure HTML + Vanilla CSS + JavaScript (no frameworks)
- **Warm Silk Alabaster & Sage Emerald** design theme
- Glassmorphism cards with GPU-accelerated ambient glow effects
- Smooth scroll reveal animations via IntersectionObserver
- Fully responsive mobile design with hamburger navigation
- Auto-deployed to Vercel on every `git push` to `master`

---

## 👥 Contributors

<div align="center">

| | Name | Role |
|:---:|:---:|:---:|
| 🧑‍💻 | **Rupam Bairagya** | Project Lead · Flutter Dev · Backend · UI/UX |

> Want to contribute? Open an [Issue](https://github.com/Rupam852/Wrist-Rx/issues) or submit a [Pull Request](https://github.com/Rupam852/Wrist-Rx/pulls)!

</div>

---

## 📄 License

```
MIT License — Copyright (c) 2025 Rupam Bairagya

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software.
```

---

## 🔗 Links

| Resource | URL |
|---|---|
| 🌐 Live Website | [wrist-rx.vercel.app](https://wrist-rx.vercel.app) |
| 📥 Download APK | [Download Latest Release](https://neo-files-transfer.pages.dev/download/ad3a54a49ab4) |
| 🐛 Bug Reports | [GitHub Issues](https://github.com/Rupam852/Wrist-Rx/issues) |
| ⭐ Star this repo | [github.com/Rupam852/Wrist-Rx](https://github.com/Rupam852/Wrist-Rx) |

---

<div align="center">

**Made with ❤️ by [Rupam Bairagya](https://github.com/Rupam852)**

*If you found this project helpful, please consider giving it a ⭐ star!*

</div>
