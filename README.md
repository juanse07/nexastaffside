# Nexa Staffside

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
