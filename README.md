# Nexa Staffside
## Auth setup (Google + Apple)

Backend env (.env):

```
PORT=4000
MONGODB_URI=mongodb://localhost:27017/nexa
BACKEND_JWT_SECRET=change_me
GOOGLE_CLIENT_ID_IOS=your_ios_client_id.apps.googleusercontent.com
GOOGLE_CLIENT_ID_ANDROID=your_android_client_id.apps.googleusercontent.com
GOOGLE_CLIENT_ID_WEB=your_web_client_id.apps.googleusercontent.com
APPLE_BUNDLE_ID=com.example.frontend
```

Frontend iOS (`ios/Runner/Info.plist`):
- Replace `REVERSED_GOOGLE_CLIENT_ID_PLACEHOLDER` with your reversed iOS client ID (reverse of `GOOGLE_CLIENT_ID_IOS`).
- Ensure bundle ID matches `APPLE_BUNDLE_ID`.

Flutter env (`frontend/.env`):

```
API_BASE_URL=http://127.0.0.1:4000
```

Run backend: `cd backend && npm run dev`

Run iOS app: `cd frontend && flutter run -d ios`

Monorepo with:
- `backend`: Node.js + TypeScript + Express + MongoDB Atlas
- `frontend`: Flutter (iOS only)

## Prerequisites
- Node.js 20+
- npm 10+
- Flutter 3.22+
- Xcode for iOS builds
- MongoDB Atlas connection string

## Backend

1. Create env file
```
cp backend/.env.example backend/.env
# Edit backend/.env
MONGODB_URI=your_atlas_uri
PORT=4000
```

2. Install deps
```
cd backend
npm install
```

3. Build & run
```
npm run build
npm run start
# or dev mode
npm run dev
```

4. Health check
```
curl http://localhost:4000/health
```

## Frontend (iOS)

1. Env
```
cd frontend
cp .env.example .env
# Edit .env if needed
API_BASE_URL=http://127.0.0.1:4000
```

2. Get packages
```
flutter pub get
```

3. Run on iOS
```
flutter run -d ios
```

Notes:
- `Info.plist` allows arbitrary loads for local dev HTTP.
- Only iOS platform is included; other platforms were removed.
