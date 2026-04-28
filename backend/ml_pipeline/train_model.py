"""
SafePass — Multi-Location ML Training Pipeline
================================================
Trains a separate RandomForestRegressor for each corridor waypoint
using 5 years of historical hourly weather data from Meteostat.

Outputs:
  safepass_model_mumbai.joblib
  safepass_model_khopoli.joblib
  safepass_model_lonavala.joblib
  safepass_model_pune.joblib
"""

import os
import pandas as pd
from datetime import datetime, timedelta
from meteostat import Hourly, Point
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error, r2_score
import joblib

# ── Corridor Locations ──────────────────────────────────────────────────────
LOCATIONS = {
    "mumbai":   {"lat": 19.0760, "lon": 72.8777, "alt": 14,  "name": "Mumbai"},
    "khopoli":  {"lat": 18.7861, "lon": 73.2660, "alt": 60,  "name": "Khopoli"},
    "lonavala": {"lat": 18.7517, "lon": 73.4067, "alt": 625, "name": "Lonavala"},
    "pune":     {"lat": 18.5204, "lon": 73.8567, "alt": 560, "name": "Pune"},
}

# ── Severity Calculator ─────────────────────────────────────────────────────
def compute_historical_severity(row):
    """
    Derive a synthetic severity target (0–100) from raw weather measurements.
    This gives the ML model a meaningful target variable to learn from.
    """
    rain_mm = row.get("prcp", 0.0)
    if pd.isna(rain_mm):
        rain_mm = 0.0

    wind_kmh = row.get("wspd", 0.0)
    if pd.isna(wind_kmh):
        wind_kmh = 0.0

    def rain_score(r):
        if r == 0:     return 0
        if r <= 2.5:   return 20
        if r <= 10:    return 40
        if r <= 30:    return 75
        return 95

    def wind_score(w):
        if w < 20:   return 0
        if w <= 40:  return 15
        if w <= 65:  return 45
        return 80

    return float(max(rain_score(rain_mm), wind_score(wind_kmh)))


# ── Train One Model ─────────────────────────────────────────────────────────
def train_for_location(loc_id: str, config: dict, end: datetime, start: datetime) -> bool:
    print(f"\n{'='*60}")
    print(f"  Training model for: {config['name']} ({loc_id})")
    print(f"{'='*60}")

    point = Point(config["lat"], config["lon"], config["alt"])
    data = Hourly(point, start, end).fetch()

    if data.empty:
        print(f"  [SKIP] No data returned for {config['name']}.")
        return False

    print(f"  [OK] Fetched {len(data):,} hourly records.")

    data.reset_index(inplace=True)
    data["hour"]  = data["time"].dt.hour
    data["month"] = data["time"].dt.month

    # Interpolate temperature, humidity, and pressure
    for col in ["temp", "rhum", "pres"]:
        if col in data.columns:
            data[col] = data[col].interpolate(method="linear")
            data[col] = data[col].bfill()
            data[col] = data[col].ffill()
        else:
            data[col] = 0.0

    # Generate synthetic target severity
    data["target_severity"] = data.apply(compute_historical_severity, axis=1)

    # Features: temporal + weather params
    X = data[["month", "hour", "temp", "rhum", "pres"]].copy()
    y = data["target_severity"]

    # Drop any remaining NaN rows
    mask = X.notna().all(axis=1)
    X, y = X[mask], y[mask]

    if len(X) < 100:
        print(f"  [SKIP] Not enough clean data for {config['name']} ({len(X)} rows).")
        return False

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    model = RandomForestRegressor(
        n_estimators=150,
        max_depth=12,
        min_samples_leaf=4,
        random_state=42,
        n_jobs=-1,  # use all CPU cores
    )
    model.fit(X_train, y_train)
    y_pred = model.predict(X_test)

    from sklearn.metrics import root_mean_squared_error
    rmse = root_mean_squared_error(y_test, y_pred)
    r2   = r2_score(y_test, y_pred)
    print(f"  RMSE: {rmse:.2f}  |  R2: {r2:.4f}")

    # Save model next to this script file
    out_path = os.path.join(os.path.dirname(__file__), f"safepass_model_{loc_id}.joblib")
    joblib.dump(model, out_path)
    print(f"  [SAVED] {out_path}")
    return True


# ── Main ────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    end   = datetime.today()
    start = end - timedelta(days=5 * 365)

    print(f"\nSafePass Multi-Location ML Training")
    print(f"Period : {start.strftime('%Y-%m-%d')} to {end.strftime('%Y-%m-%d')}")
    print(f"Locations: {list(LOCATIONS.keys())}\n")

    results = {}
    for loc_id, config in LOCATIONS.items():
        ok = train_for_location(loc_id, config, end, start)
        results[loc_id] = "[OK]" if ok else "[FAILED]"

    print(f"\n{'='*60}")
    print("  Training Summary")
    print(f"{'='*60}")
    for loc_id, status in results.items():
        print(f"  {status}  {LOCATIONS[loc_id]['name']}")
    print()
