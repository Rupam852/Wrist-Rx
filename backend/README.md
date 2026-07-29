# Wrist Rx — Backend API

Node.js + Express backend for the **Wrist Rx** health monitoring app.

## Stack
- **Runtime**: Node.js 18+
- **Framework**: Express.js
- **Database**: MongoDB Atlas (Mongoose)
- **Auth**: Firebase Admin SDK (Google Sign-In verification)
- **Real-time**: WebSocket (ws library)
- **Hosting**: Render

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Server health check |
| GET | `/health` | Uptime info |
| POST | `/api/auth/register` | Register/login Google user |
| GET | `/api/auth/user/:uid` | Get user profile |
| PUT | `/api/auth/user/:uid` | Update profile |
| PUT | `/api/auth/user/:uid/onboarding` | Save AI onboarding |
| POST | `/api/health/reading` | Save health reading |
| GET | `/api/health/:uid/today` | Today's data |
| GET | `/api/health/:uid/history` | Historical data |
| POST | `/api/watch/connect-token` | Connect via WiFi token |
| POST | `/api/watch/connect-bluetooth` | Register BT MAC |
| GET | `/api/watch/:uid/status` | Watch status |
| POST | `/api/watch/data` | Watch pushes data |
| POST | `/api/ai/chat` | Chat with AI |
| GET | `/api/ai/conversation/:uid` | Chat history |
| POST | `/api/sos/trigger` | Trigger SOS |
| GET | `/api/sos/:uid/history` | SOS history |
| WS | `/ws?userId=UID` | Real-time data stream |

## Setup

### 1. Clone & Install
```bash
cd backend
npm install
```

### 2. Environment Variables
```bash
cp .env.example .env
# Edit .env with your values
```

Required env vars:
- `MONGODB_URI` — MongoDB Atlas connection string
- `FIREBASE_PROJECT_ID` — `wrist-rx`
- `FIREBASE_PRIVATE_KEY` — From Firebase service account JSON
- `FIREBASE_CLIENT_EMAIL` — From Firebase service account JSON

### 3. Run locally
```bash
npm run dev
```

## Deploy to Render

1. Push this repo to GitHub
2. Go to [render.com](https://render.com) → New Web Service
3. Connect your GitHub repo
4. Set:
   - **Root Directory**: `backend`
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
5. Add all environment variables in Render dashboard
6. Deploy!

## Firebase Service Account

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Project Settings → Service Accounts
3. Click **Generate new private key**
4. Copy `project_id`, `private_key`, `client_email` into your Render env vars
