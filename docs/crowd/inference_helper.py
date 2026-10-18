"""
Standalone Inference Pipeline for Sri Lanka Tourist Arrival Model

Usage:
    from inference_helper import load_inference_pipeline, predict_arrivals
    pipe = load_inference_pipeline(".")
    result = predict_arrivals(pipe, "Galle", 2026, 12, current_inflation=2.0,
                              as_of_year=2026, as_of_month=10)
    print(result)

Pipeline: (district, month) -> climate model -> temperature, rainfall
          current inflation -> damped AR forecast -> inflation for travel month
          all of the above   -> tourism model -> expected tourist arrivals
"""
import joblib
import torch
import torch.nn as nn
import numpy as np
import pandas as pd


class TourismDemandNet(nn.Module):
    def __init__(self, num_districts=25, emb_dim=8, num_cont=7, num_shocks=3):
        super(TourismDemandNet, self).__init__()
        self.district_embedding = nn.Embedding(num_districts, emb_dim)
        in_dim = emb_dim + num_cont + num_shocks
        self.mlp = nn.Sequential(
            nn.Linear(in_dim, 64),
            nn.SiLU(),
            nn.BatchNorm1d(64),
            nn.Dropout(0.10),
            nn.Linear(64, 32),
            nn.SiLU(),
            nn.BatchNorm1d(32),
            nn.Linear(32, 1)
        )

    def forward(self, district_idx, cont_x, shock_x):
        emb = self.district_embedding(district_idx)
        x = torch.cat([emb, cont_x, shock_x], dim=1)
        return self.mlp(x)


class ClimateNet(nn.Module):
    def __init__(self, num_districts=25, emb_dim=8, num_feats=5):
        super().__init__()
        self.emb = nn.Embedding(num_districts, emb_dim)
        self.mlp = nn.Sequential(
            nn.Linear(emb_dim + num_feats, 64),
            nn.SiLU(),
            nn.Dropout(0.10),
            nn.Linear(64, 32),
            nn.SiLU(),
            nn.Linear(32, 2)
        )

    def forward(self, d, x):
        return self.mlp(torch.cat([self.emb(d), x], dim=1))


def load_inference_pipeline(artifacts_dir="."):
    prep = joblib.load(f"{artifacts_dir}/preprocessor_bundle.joblib")
    n_dist = len(prep["all_districts"])

    tourism = TourismDemandNet(num_districts=n_dist, num_cont=len(prep["continuous_cols"]))
    tourism.load_state_dict(torch.load(f"{artifacts_dir}/tourism_model_state_dict.pth", map_location="cpu"))
    tourism.eval()

    climate = ClimateNet(num_districts=n_dist, num_feats=len(prep["climate_feat_cols"]))
    climate.load_state_dict(torch.load(f"{artifacts_dir}/climate_model_state_dict.pth", map_location="cpu"))
    climate.eval()

    return {"tourism": tourism, "climate": climate, "prep": prep}


def predict_climate(pipe, district, month):
    """Returns (temperature_C, rainfall_mm) for a district and calendar month."""
    prep = pipe["prep"]
    feats = np.array([[
        np.sin(2 * np.pi * month / 12.0),
        np.cos(2 * np.pi * month / 12.0),
        np.sin(4 * np.pi * month / 12.0),
        np.cos(4 * np.pi * month / 12.0),
        1.0 if district in prep["wet_zone_districts"] else 0.0
    ]], dtype=np.float32)
    with torch.no_grad():
        out = pipe["climate"](
            torch.tensor([prep["district_to_idx"][district]], dtype=torch.long),
            torch.tensor(feats)
        ).numpy()
    temp, rain_log = prep["clim_scaler"].inverse_transform(out)[0]
    return float(temp), float(max(0.0, np.expm1(rain_log)))


def predict_inflation(pipe, current_rate, as_of_year, as_of_month, target_year, target_month):
    """Damped AR forecast from the real current inflation rate to the target month."""
    cfg = pipe["prep"]["inflation_config"]
    steps = (target_year - as_of_year) * 12 + (target_month - as_of_month)
    if steps <= 0:
        return float(current_rate)

    n_lags = cfg["n_lags"]
    coef = np.array(cfg["ar_coef"])
    hist = [float(current_rate)] * n_lags      # single input -> flat seed

    nxt = float(current_rate)
    for k in range(1, steps + 1):
        x = np.array(hist[-n_lags:][::-1])
        ar_pred = float(coef @ x + cfg["ar_intercept"])
        w = cfg["persistence"] ** k
        nxt = w * ar_pred + (1 - w) * cfg["target"]
        nxt = float(np.clip(nxt, cfg["clip_min"], cfg["clip_max"]))
        hist.append(nxt)
    return nxt


def predict_arrivals(pipe, district, target_year, target_month, current_inflation,
                     as_of_year, as_of_month):
    """Full pipeline. Returns a dict with predicted climate, inflation and tourist arrivals."""
    prep = pipe["prep"]
    district = district.strip().title()
    if district not in prep["district_to_idx"]:
        raise ValueError(f"Unknown district: {district}")

    temp, rain = predict_climate(pipe, district, target_month)
    infl = predict_inflation(pipe, current_inflation, as_of_year, as_of_month,
                             target_year, target_month)

    is_wz = 1.0 if district in prep["wet_zone_districts"] else 0.0
    cont_df = pd.DataFrame([{
        "inflation for the month of the year": infl,
        "average temperature within the month": temp,
        "average rainfall within the month": rain,
        "month_sin": float(np.sin(2 * np.pi * target_month / 12.0)),
        "month_cos": float(np.cos(2 * np.pi * target_month / 12.0)),
        "is_wet_zone": is_wz,
        "district_base_weight": float(prep["district_weight_map"].get(district, 0.01))
    }])[prep["continuous_cols"]]

    cont_scaled = prep["scaler"].transform(cont_df)
    with torch.no_grad():
        log_pred = pipe["tourism"](
            torch.tensor([prep["district_to_idx"][district]], dtype=torch.long),
            torch.tensor(cont_scaled, dtype=torch.float32),
            torch.zeros((1, 3), dtype=torch.float32)       # no shock flags for future travel
        ).item()

    return {
        "district": district,
        "period": f"{target_year}-{target_month:02d}",
        "temperature_c": round(temp, 1),
        "rainfall_mm": round(rain, 1),
        "inflation_pct": round(infl, 2),
        "predicted_arrivals": max(0, int(round(np.expm1(log_pred))))
    }
