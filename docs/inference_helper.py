"""
Standalone Inference Loader for Sri Lanka Tourist Arrival Model
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

def load_inference_pipeline(artifacts_dir="."):
    prep = joblib.load(f"{artifacts_dir}/preprocessor_bundle.joblib")
    model = TourismDemandNet(num_districts=len(prep["all_districts"]), num_cont=len(prep["continuous_cols"]))
    model.load_state_dict(torch.load(f"{artifacts_dir}/tourism_model_state_dict.pth", map_location="cpu"))
    model.eval()
    return model, prep
