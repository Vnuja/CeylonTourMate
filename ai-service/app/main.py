# CeylonTourMate — AI Service Entry Point (Placeholder with stub endpoints)
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

app = FastAPI(
    title="CeylonTourMate AI Service",
    description="AI/ML microservice for recommendations, food recognition, content safety, and place identification",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─── Health Check ───
@app.get("/health")
async def health_check():
    return {
        "status": "ok",
        "service": "CeylonTourMate AI Service",
        "timestamp": datetime.utcnow().isoformat(),
        "modules": {
            "recommendation": "placeholder",
            "food_recognition": "placeholder",
            "content_safety": "placeholder",
            "place_recognition": "placeholder",
        },
    }


# ─── Module 1: Recommendation Engine (Placeholder) ───

class RecommendRequest(BaseModel):
    userId: str
    lat: float
    lng: float


class RecommendResponse(BaseModel):
    packageId: str
    matchScore: float
    matchReasons: List[str]


@app.post("/ai/recommend", response_model=List[RecommendResponse])
async def recommend_packages(request: RecommendRequest):
    """Smart package recommendation — PLACEHOLDER
    
    Future implementation will use:
    - Content-based filtering (TF-IDF + cosine similarity)
    - Weather-adjusted scoring
    - Collaborative filtering
    - Health gate filtering
    """
    # Return demo recommendations
    return [
        RecommendResponse(
            packageId="pkg-sigiriya",
            matchScore=0.94,
            matchReasons=["Matches your interest in heritage sites", "Perfect weather today for outdoor exploration"],
        ),
        RecommendResponse(
            packageId="pkg-kandy",
            matchScore=0.87,
            matchReasons=["Cultural experiences you enjoy", "Close to your location"],
        ),
        RecommendResponse(
            packageId="pkg-ella",
            matchScore=0.82,
            matchReasons=["Nature & adventure match", "Highly rated by similar travelers"],
        ),
    ]


# ─── Module 3: Food Recognition (Placeholder) ───

class FoodRecognitionRequest(BaseModel):
    image_base64: str
    userAllergens: Optional[List[str]] = []


class FoodPrediction(BaseModel):
    label: str
    confidence: float


class FoodInfo(BaseModel):
    name: str
    localName: str
    description: str
    ingredients: List[str]
    spiceLevel: int
    isVegetarian: bool
    commonAllergens: List[str]
    calories: int


class FoodRecognitionResponse(BaseModel):
    topPredictions: List[FoodPrediction]
    foodInfo: Optional[FoodInfo] = None
    allergenAlerts: List[str] = []


@app.post("/ai/food-recognition", response_model=FoodRecognitionResponse)
async def recognize_food(request: FoodRecognitionRequest):
    """Sri Lankan food recognition — PLACEHOLDER
    
    Future implementation will use:
    - Fine-tuned MobileNetV3 on 30+ Sri Lankan dish classes
    - Allergen cross-reference with user profile
    """
    return FoodRecognitionResponse(
        topPredictions=[
            FoodPrediction(label="rice_curry", confidence=0.92),
            FoodPrediction(label="dhal_curry", confidence=0.78),
            FoodPrediction(label="pol_sambol", confidence=0.65),
        ],
        foodInfo=FoodInfo(
            name="Rice & Curry",
            localName="බත් හා ව්‍යංජන",
            description="Traditional Sri Lankan rice and curry plate with multiple side dishes",
            ingredients=["rice", "coconut milk", "curry leaves", "turmeric", "chili", "garlic"],
            spiceLevel=3,
            isVegetarian=False,
            commonAllergens=["coconut", "mustard"],
            calories=650,
        ),
        allergenAlerts=[],
    )


# ─── Module 3: Content Safety (Placeholder) ───

class ContentSafetyRequest(BaseModel):
    image_base64: str
    tripId: Optional[str] = None
    reportedBy: Optional[str] = None


class ContentSafetyResponse(BaseModel):
    isSafe: bool
    safetyScore: int
    categories: List[dict]
    extractedText: Optional[str] = None
    action: str


@app.post("/ai/content-safety", response_model=ContentSafetyResponse)
async def check_content_safety(request: ContentSafetyRequest):
    """Content safety analysis — PLACEHOLDER
    
    Future implementation will use:
    - PaddleOCR for text extraction
    - Multilingual BERT for hate speech detection (Sinhala/Tamil/English)
    - CLIP embeddings for visual content classification
    """
    return ContentSafetyResponse(
        isSafe=True,
        safetyScore=95,
        categories=[
            {"name": "violence", "score": 2, "flagged": False},
            {"name": "hate_speech", "score": 0, "flagged": False},
            {"name": "nudity", "score": 1, "flagged": False},
        ],
        extractedText=None,
        action="allow",
    )


# ─── Module 4: Place Recognition (Placeholder) ───

class PlaceIdentifyRequest(BaseModel):
    image_base64: str
    lat: Optional[float] = None
    lng: Optional[float] = None


class PlacePrediction(BaseModel):
    placeId: str
    name: str
    confidence: float
    category: str


class PlaceIdentifyResponse(BaseModel):
    predictions: List[PlacePrediction]
    placeInfo: Optional[dict] = None
    nearbyPlaces: List[dict] = []


@app.post("/ai/identify-place", response_model=PlaceIdentifyResponse)
async def identify_place(request: PlaceIdentifyRequest):
    """Sri Lankan landmark identification — PLACEHOLDER
    
    Future implementation will use:
    - Fine-tuned EfficientNetB4 on 200+ Sri Lankan locations
    - Google Vision API fallback
    - Multi-label classification
    """
    return PlaceIdentifyResponse(
        predictions=[
            PlacePrediction(placeId="sigiriya", name="Sigiriya Rock Fortress", confidence=0.91, category="heritage"),
        ],
        placeInfo={
            "name": "Sigiriya Rock Fortress",
            "sinhalaName": "සීගිරිය",
            "category": "heritage",
            "description": "Ancient rock fortress and palace ruin, UNESCO World Heritage Site",
            "province": "Central",
            "unescoListed": True,
        },
        nearbyPlaces=[
            {"name": "Pidurangala Rock", "distance": "1.2 km"},
            {"name": "Dambulla Cave Temple", "distance": "15 km"},
        ],
    )


@app.get("/ai/places/search")
async def search_places(q: str = ""):
    """Full-text place search — PLACEHOLDER"""
    return {
        "query": q,
        "results": [
            {"name": "Sigiriya Rock Fortress", "category": "heritage", "province": "Central"},
            {"name": "Temple of the Tooth", "category": "heritage", "province": "Central"},
        ],
    }


@app.get("/ai/places/nearby")
async def nearby_places(lat: float = 7.87, lng: float = 80.77, radius: float = 10):
    """Find places within radius — PLACEHOLDER"""
    return {
        "center": {"lat": lat, "lng": lng},
        "radius_km": radius,
        "results": [
            {"name": "Sigiriya", "distance_km": 2.3},
            {"name": "Pidurangala", "distance_km": 3.5},
        ],
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
