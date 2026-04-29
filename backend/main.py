"""
SafePass — FastAPI Backend (Full Corridor Edition)
====================================================
Hybrid Intelligence Engine covering 4 waypoints on the Mumbai–Pune Expressway.

Endpoints:
  GET  /api/v1/corridor            — All 4 location scores (parallel)
  GET  /api/v1/safeness?city=XXX   — Single location score
  POST /api/v1/report              — Submit detailed condition report

Run locally:
  pip install -r requirements.txt
  uvicorn main:app --reload --port 8000
"""

import os
import asyncio
import httpx
import uuid
from datetime import datetime, timezone, timedelta
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from supabase import create_client, Client
from typing import Literal, Optional
import joblib
import pandas as pd

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────
OPENWEATHERMAP_API_KEY = os.getenv("OPENWEATHERMAP_API_KEY", "")
SUPABASE_URL           = os.getenv("SUPABASE_URL", "")
SUPABASE_SERVICE_KEY   = os.getenv("SUPABASE_KEY", "")

# ─────────────────────────────────────────────────────────────────────────────
# CORRIDOR LOCATION REGISTRY
# ─────────────────────────────────────────────────────────────────────────────
CORRIDOR_LOCATIONS = {
    "mumbai":   {"name": "Mumbai",   "emoji": "🏙️", "lat": 19.0760, "lon": 72.8777, "km": 0},
    "khopoli":  {"name": "Khopoli",  "emoji": "🏭", "lat": 18.7861, "lon": 73.2660, "km": 83},
    "lonavala": {"name": "Lonavala", "emoji": "⛰️", "lat": 18.7517, "lon": 73.4067, "km": 96},
    "pune":     {"name": "Pune",     "emoji": "🌆", "lat": 18.5204, "lon": 73.8567, "km": 149},
}

LocationId = Literal["mumbai", "khopoli", "lonavala", "pune"]

# ─────────────────────────────────────────────────────────────────────────────
# ML MODELS — Load all 4 at startup
# ─────────────────────────────────────────────────────────────────────────────
ml_models: dict = {}
_ml_dir = os.path.join(os.path.dirname(__file__), "ml_pipeline")

for loc_id in CORRIDOR_LOCATIONS:
    model_path = os.path.join(_ml_dir, f"safepass_model_{loc_id}.joblib")
    try:
        ml_models[loc_id] = joblib.load(model_path)
        print(f"[OK] Loaded ML model: {loc_id}")
    except Exception as e:
        ml_models[loc_id] = None
        print(f"[WARN] No model for {loc_id}: {e}")

# ─────────────────────────────────────────────────────────────────────────────
# SUPABASE CLIENT
# ─────────────────────────────────────────────────────────────────────────────
supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

# ─────────────────────────────────────────────────────────────────────────────
# FASTAPI APP
# ─────────────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="SafePass API — Corridor Edition",
    description="AI-driven real-time weather advisory for the Mumbai–Pune Expressway",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─────────────────────────────────────────────────────────────────────────────
# PYDANTIC MODELS
# ─────────────────────────────────────────────────────────────────────────────
class ReportRequest(BaseModel):
    user_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    rainfall:    Literal["No Rainfall", "Low Rainfall", "Medium", "High", "Very High"]
    visibility:  Literal["Clear", "Low"]
    temperature: Literal["Low", "High", "Very High"]
    location: LocationId = "mumbai"

class SafenessResponse(BaseModel):
    score: int
    status_text: str
    is_overridden_by_crowd: bool
    api_severity_score: float
    ml_severity_score: float
    base_safeness: float
    hazard_count: int
    clear_count: int

class WaypointSummary(BaseModel):
    id: str
    name: str
    emoji: str
    km: int
    score: int
    status_label: str
    color: str   # "green" | "amber" | "red"
    detailed_status: str
    is_overridden: bool

class CorridorResponse(BaseModel):
    overall_status: str
    danger_zones: int
    waypoints: list[WaypointSummary]

# ─────────────────────────────────────────────────────────────────────────────
# SEVERITY PRE-PROCESSING MATRIX
# ─────────────────────────────────────────────────────────────────────────────
def rain_score(rain_mm: float) -> float:
    if rain_mm == 0:      return 0
    elif rain_mm <= 2.5:  return 20
    elif rain_mm <= 10:   return 40
    elif rain_mm <= 30:   return 75
    else:                 return 95

def visibility_score(vis_m: float) -> float:
    if vis_m > 5000:    return 0
    elif vis_m >= 2000: return 20
    elif vis_m >= 500:  return 50
    elif vis_m >= 100:  return 85
    else:               return 100

def wind_score(wind_kmh: float) -> float:
    if wind_kmh < 20:    return 0
    elif wind_kmh <= 40: return 15
    elif wind_kmh <= 65: return 45
    else:                return 80

def compute_api_severity(rain_mm: float, vis_m: float, wind_kmh: float) -> float:
    return max(rain_score(rain_mm), visibility_score(vis_m), wind_score(wind_kmh))

# ─────────────────────────────────────────────────────────────────────────────
# ML PREDICTION
# ─────────────────────────────────────────────────────────────────────────────
def get_ml_prediction(loc_id: str, current_temp: float, current_rhum: float, current_pres: float) -> float:
    model = ml_models.get(loc_id)
    if model is None:
        return 30.0   # Fallback
    now = datetime.now()
    input_df = pd.DataFrame([{"month": now.month, "hour": now.hour, "temp": current_temp, "rhum": current_rhum, "pres": current_pres}])
    try:
        return float(model.predict(input_df)[0])
    except Exception as e:
        print(f"ML prediction error ({loc_id}): {e}")
        return 30.0

# ─────────────────────────────────────────────────────────────────────────────
# STATUS HELPERS
# ─────────────────────────────────────────────────────────────────────────────
def score_label(score: int) -> tuple[str, str]:
    """Returns (status_label, color_key)"""
    if score >= 80: return ("Safe", "green")
    if score >= 40: return ("Caution", "amber")
    return ("Danger", "red")

def build_status_text(score: int, is_overridden: bool, hazard_count: int, clear_count: int) -> str:
    if is_overridden:
        if score <= 20: return "⚠️ Override: Heavy Hazards Reported by Users"
        return "✅ Override: Conditions Cleared by Community"
    if score >= 80:  return "Safe to Travel — Conditions Look Good"
    elif score >= 40: return "Caution Advised — Moderate Weather Risk"
    return "Do Not Travel — Severe Conditions Detected"

# ─────────────────────────────────────────────────────────────────────────────
# CORE SCORE ENGINE (shared by both endpoints)
# ─────────────────────────────────────────────────────────────────────────────
async def _compute_score_for_location(client: httpx.AsyncClient, loc_id: str) -> dict:
    loc = CORRIDOR_LOCATIONS[loc_id]

    # Fetch OWM data
    owm_url = (
        f"https://api.openweathermap.org/data/2.5/weather"
        f"?lat={loc['lat']}&lon={loc['lon']}"
        f"&appid={OPENWEATHERMAP_API_KEY}&units=metric"
    )
    try:
        response = await client.get(owm_url)
        response.raise_for_status()
        weather_data = response.json()
    except Exception:
        weather_data = {}

    rain_mm      = weather_data.get("rain", {}).get("1h", 0.0)
    vis_m        = float(weather_data.get("visibility", 10000))
    wind_ms      = weather_data.get("wind", {}).get("speed", 0.0)
    wind_kmh     = wind_ms * 3.6
    current_temp = weather_data.get("main", {}).get("temp", 30.0)
    current_rhum = float(weather_data.get("main", {}).get("humidity", 50.0))
    current_pres = float(weather_data.get("main", {}).get("pressure", 1010.0))

    api_severity = compute_api_severity(rain_mm, vis_m, wind_kmh)
    ml_severity  = get_ml_prediction(loc_id, current_temp, current_rhum, current_pres)
    base_score   = (api_severity * 0.65) + (ml_severity * 0.35)
    base_safeness = 100.0 - base_score

    # Trust Engine — crowd override
    cutoff_time = (datetime.now(timezone.utc) - timedelta(minutes=45)).isoformat()
    try:
        crowd_result = (
            supabase.table("user_reports")
            .select("rainfall, visibility, temperature")
            .eq("location", loc_id)
            .gte("created_at", cutoff_time)
            .execute()
        )
        reports = crowd_result.data
    except Exception:
        reports = []

    is_overridden = False
    final_score = base_safeness
    status_text = build_status_text(int(final_score), False, 0, 0)
    
    hazard_count = 0
    clear_count = 0
    
    # Severity-based scoring
    if len(reports) >= 2:
        total_penalty = 0
        severe_conditions = set()
        
        for r in reports:
            penalty = 0
            # Rainfall severity weights
            rain = r.get("rainfall", "No Rainfall")
            if rain == "Low Rainfall": penalty += 10
            elif rain == "Medium": penalty += 25
            elif rain == "High": 
                penalty += 50
                severe_conditions.add("High Rainfall")
            elif rain == "Very High": 
                penalty += 75
                severe_conditions.add("Very High Rainfall")
            
            # Visibility severity weights
            if r.get("visibility") == "Low": 
                penalty += 40
                severe_conditions.add("Low Visibility")
            
            # Temperature severity weights
            if r.get("temperature") == "Very High": 
                penalty += 15
                severe_conditions.add("Extreme Heat")
            
            total_penalty += penalty
            
        average_penalty = total_penalty / len(reports)
        
        # Apply the exact crowd severity penalty to the score
        final_score = base_safeness - average_penalty
        
        # Build dynamic reason string
        reason_str = " and ".join(list(severe_conditions)) if severe_conditions else "Hazards"
        
        # Update the status text based on how severe the crowd penalty was
        if average_penalty >= 50:
            status_text = f"⚠️ Override: {reason_str} reported by community"
            is_overridden = True
        elif average_penalty >= 20:
            status_text = f"⚠️ Caution: {reason_str} reported by community"
            is_overridden = True
        elif average_penalty == 0 and len(reports) >= 3:
            # If multiple users confirm perfectly clear conditions
            final_score = max(final_score, 95)
            status_text = "✅ Override: Conditions Cleared by Community"
            is_overridden = True

    final_score = max(0, min(100, int(round(final_score))))

    return {
        "score": final_score,
        "status_text": status_text,
        "is_overridden_by_crowd": is_overridden,
        "api_severity_score": round(api_severity, 2),
        "ml_severity_score": round(ml_severity, 2),
        "base_safeness": round(base_safeness, 2),
        "hazard_count": hazard_count,
        "clear_count": clear_count,
    }

# ─────────────────────────────────────────────────────────────────────────────
# ROUTE A: GET /api/v1/corridor — All 4 locations in parallel
# ─────────────────────────────────────────────────────────────────────────────
@app.get("/api/v1/corridor", response_model=CorridorResponse,
         summary="Get Safeness Scores for all 4 corridor waypoints")
async def get_corridor():
    async with httpx.AsyncClient(timeout=12.0) as client:
        tasks = [_compute_score_for_location(client, loc_id) for loc_id in CORRIDOR_LOCATIONS]
        results = await asyncio.gather(*tasks)

    waypoints: list[WaypointSummary] = []
    danger_zones = 0

    for loc_id, result in zip(CORRIDOR_LOCATIONS.keys(), results):
        loc = CORRIDOR_LOCATIONS[loc_id]
        label, color = score_label(result["score"])
        if color == "red":
            danger_zones += 1
        waypoints.append(WaypointSummary(
            id=loc_id,
            name=loc["name"],
            emoji=loc["emoji"],
            km=loc["km"],
            score=result["score"],
            status_label=label,
            color=color,
            detailed_status=result["status_text"],
            is_overridden=result["is_overridden_by_crowd"],
        ))

    if danger_zones == 0:
        overall = "✅ Route Clear — Safe to Travel"
    elif danger_zones == 1:
        overall = f"⚠️ Caution — {danger_zones} Danger Zone on Route"
    else:
        overall = f"🛑 Hazardous — {danger_zones} Danger Zones Detected"

    return CorridorResponse(
        overall_status=overall,
        danger_zones=danger_zones,
        waypoints=waypoints,
    )

# ─────────────────────────────────────────────────────────────────────────────
# ROUTE B: GET /api/v1/safeness — Single location detail
# ─────────────────────────────────────────────────────────────────────────────
@app.get("/api/v1/safeness", response_model=SafenessResponse,
         summary="Get detailed Safeness Score for a single waypoint")
async def get_safeness(city: LocationId = "mumbai"):
    if city not in CORRIDOR_LOCATIONS:
        raise HTTPException(status_code=400, detail=f"Unknown location: {city}")

    async with httpx.AsyncClient(timeout=12.0) as client:
        result = await _compute_score_for_location(client, city)

    return SafenessResponse(**result)

# ─────────────────────────────────────────────────────────────────────────────
# ROUTE C: POST /api/v1/report — Submit detailed report
# ─────────────────────────────────────────────────────────────────────────────
@app.post("/api/v1/report", summary="Submit a detailed live hazard report")
async def submit_report(report: ReportRequest):
    try:
        data = {
            "user_id":     report.user_id,
            "rainfall":    report.rainfall,
            "visibility":  report.visibility,
            "temperature": report.temperature,
            "location":    report.location,
        }
        result = supabase.table("user_reports").insert(data).execute()
        return {"success": True, "message": "Detailed report received. Thank you!", "data": result.data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to save report: {str(e)}")

# ─────────────────────────────────────────────────────────────────────────────
# HEALTH CHECK
# ─────────────────────────────────────────────────────────────────────────────
@app.get("/", summary="Health check")
async def root():
    loaded = [k for k, v in ml_models.items() if v is not None]
    return {
        "status": "SafePass Corridor API is running",
        "version": "2.0.0",
        "locations": list(CORRIDOR_LOCATIONS.keys()),
        "ml_models_loaded": loaded,
    }
