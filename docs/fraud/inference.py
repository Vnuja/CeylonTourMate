
import json
import re
import joblib
import torch
import torch.nn as nn

class FraudReviewClassifier(nn.Module):
    def __init__(self, input_dim, hidden_dim=256, dropout=0.4):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(input_dim, hidden_dim),
            nn.BatchNorm1d(hidden_dim),
            nn.ReLU(),
            nn.Dropout(dropout),
            nn.Linear(hidden_dim, hidden_dim // 2),
            nn.BatchNorm1d(hidden_dim // 2),
            nn.ReLU(),
            nn.Dropout(dropout),
            nn.Linear(hidden_dim // 2, 1)
        )

    def forward(self, x):
        return self.net(x).squeeze(1)


def clean_text(text):
    text = text.lower()
    text = re.sub(r"[^a-z0-9\s]", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def load_model(metadata_path="model_metadata.json",
                vectorizer_path="tfidf_vectorizer.pkl",
                weights_path="fraud_model.pth"):
    with open(metadata_path) as f:
        metadata = json.load(f)

    vectorizer = joblib.load(vectorizer_path)

    model = FraudReviewClassifier(
        input_dim=metadata["architecture"]["input_dim"],
        hidden_dim=metadata["architecture"]["hidden_dim"],
        dropout=metadata["architecture"]["dropout"]
    )
    model.load_state_dict(torch.load(weights_path, map_location="cpu"))
    model.eval()

    return model, vectorizer, metadata


def predict(review_text, model, vectorizer, metadata):
    cleaned = clean_text(review_text)
    features = vectorizer.transform([cleaned]).toarray()
    features_tensor = torch.tensor(features, dtype=torch.float32)

    with torch.no_grad():
        logit = model(features_tensor)
        prob = torch.sigmoid(logit).item()

    threshold = metadata["prediction_threshold"]
    label = "deceptive" if prob > threshold else "truthful"
    confidence = prob if label == "deceptive" else 1 - prob

    return {"label": label, "confidence": confidence, "raw_probability": prob}


if __name__ == "__main__":
    model, vectorizer, metadata = load_model()
    sample = "This hotel is amazing amazing amazing, best ever, 5 stars!!!"
    result = predict(sample, model, vectorizer, metadata)
    print(result)
