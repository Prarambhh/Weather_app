# 🛡️ SafePass — Real-Time AI Travel Advisory for Mumbai

> A full-stack MVP combining **OpenWeatherMap**, **ML prediction**, and **crowdsourced reports** into a single Safeness Score (0–100) displayed in a Flutter mobile app.

---

## 📁 Project Structure

```
WEATHER_APP_new/
├── backend/
│   ├── main.py            # FastAPI Hybrid Intelligence Engine
│   └── requirements.txt   # Python dependencies
├── flutter_app/
│   ├── lib/
│   │   └── main.dart      # Complete Flutter UI
│   └── pubspec.yaml       # Flutter dependencies
├── supabase/
│   └── schema.sql         # Database schema + RLS policies
└── README.md
```

---

## 🔑 Step 0 — Get Your API Keys

| Service | Where to get it | Free tier? |
|---|---|---|
| OpenWeatherMap | https://openweathermap.org/api → Current Weather API | ✅ Yes |
| Supabase | https://supabase.com → New Project → Settings → API | ✅ Yes |

---

## 🗄️ Step 1 — Set Up Supabase Database

1. Create a new Supabase project at https://supabase.com
2. Go to **SQL Editor → New Query**
3. Paste the contents of `supabase/schema.sql` and click **Run**
4. Verify the `user_reports` table exists under **Table Editor**

---

## ⚙️ Step 2 — Configure & Run the Backend

### Insert your credentials

Open `backend/main.py` and replace these three lines:

```python
OPENWEATHERMAP_API_KEY = "YOUR_OPENWEATHERMAP_API_KEY_HERE"   # ← line ~25
SUPABASE_URL           = "YOUR_SUPABASE_PROJECT_URL_HERE"      # ← line ~26
SUPABASE_SERVICE_KEY   = "YOUR_SUPABASE_SERVICE_ROLE_KEY_HERE" # ← line ~27
```

### Install dependencies & run

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

The API will be live at **http://localhost:8000**

### Test the endpoints

```bash
# Health check
curl http://localhost:8000/

# Get safeness score
curl "http://localhost:8000/api/v1/safeness?city=mumbai"

# Submit a test report
curl -X POST http://localhost:8000/api/v1/report \
  -H "Content-Type: application/json" \
  -d '{"user_id":"test-001","hazard_type":"waterlogging","location":"mumbai"}'
```

Interactive Swagger UI: **http://localhost:8000/docs**

---

## 📱 Step 3 — Configure & Run the Flutter App

### Set the backend URL

Open `flutter_app/lib/main.dart` and update line ~46:

```dart
// Android emulator (talking to your PC's localhost):
const String kApiBaseUrl = "http://10.0.2.2:8000";

// iOS simulator or Web:
const String kApiBaseUrl = "http://localhost:8000";

// Physical device on same Wi-Fi (replace with your PC's local IP):
const String kApiBaseUrl = "http://192.168.1.X:8000";
```

### Install Flutter packages & run

```bash
cd flutter_app
flutter pub get
flutter run
```

---

## 🧠 How the Safeness Score Works

```
┌─────────────────────────────────────────────────────────────┐
│                  HYBRID INTELLIGENCE ENGINE                  │
├───────────────────────┬─────────────────────────────────────┤
│  OpenWeatherMap API   │  Rain (mm), Visibility (m), Wind    │
│  (65% weight)         │  → Pre-processing Matrix            │
│                       │  → API Severity Score (0–100)       │
├───────────────────────┼─────────────────────────────────────┤
│  ML Prediction        │  get_ml_prediction() → 30 (mock)    │
│  (35% weight)         │  Replace with trained model in prod │
├───────────────────────┼─────────────────────────────────────┤
│  Base Safeness        │  100 − (API×0.65 + ML×0.35)         │
├───────────────────────┼─────────────────────────────────────┤
│  Trust Engine         │  Query last 45 min crowd reports     │
│  (Crowd Override)     │  ≥3 hazards  → Override to 15       │
│                       │  ≥3 clears   → Override to 95       │
└───────────────────────┴─────────────────────────────────────┘
```

### Score → Color Mapping

| Score | Color | Meaning |
|---|---|---|
| 80–100 | 🟢 Green | Safe to Travel |
| 40–79 | 🟠 Orange | Caution |
| 0–39 | 🔴 Red | Do Not Travel |

---

## 🚀 Production Deployment Notes

- **Backend:** Deploy `backend/` to Railway, Render, or Fly.io. Set your secrets as environment variables.
- **Flutter:** Build APK with `flutter build apk --release` and update `kApiBaseUrl` to your production URL.
- **Supabase RLS:** Tighten Row Level Security policies to reject unauthenticated writes in production.
- **ML Model:** Replace `get_ml_prediction()` in `main.py` with a call to a trained scikit-learn or TensorFlow model that uses hour-of-day, day-of-week, and monsoon season features.
