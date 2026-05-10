from flask import Flask, request, jsonify, render_template
from flask_cors import CORS
import requests
import json
import torch
import torchvision.transforms as transforms
from torchvision import models
from PIL import Image
import base64
import io
import torch.nn as nn
import os

app = Flask(__name__)
CORS(app)

# Load food database
with open("food_database.json", "r") as f:
    food_db = json.load(f)

# Load class names
with open("class_names.json", "r") as f:
    class_names = json.load(f)

# Load CNN model
print("Loading CNN model...")
num_classes = len(class_names)
cnn_model = models.mobilenet_v2(pretrained=False)
cnn_model.classifier[1] = nn.Linear(cnn_model.last_channel, num_classes)
cnn_model.load_state_dict(torch.load("food_model.pth", map_location="cpu"))
cnn_model.eval()
print(f"CNN model loaded! Classes: {class_names}")

# Image transform
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406],
                        [0.229, 0.224, 0.225])
])

def get_food_image(food_name):
    """Get reference image from training_data folder"""
    folder_name = food_name.lower().replace(" ", "_")
    folder_path = os.path.join("training_data", folder_name)

    if os.path.exists(folder_path):
        images = [f for f in os.listdir(folder_path)
                 if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
        if images:
            img_path = os.path.join(folder_path, images[0])
            with open(img_path, "rb") as f:
                img_data = f.read()
            return base64.b64encode(img_data).decode('utf-8')
    return None

def classify_with_cnn(image_base64):
    """Try CNN model first"""
    print("CNN analyzing image...")
    try:
        image_data = base64.b64decode(image_base64)
        image = Image.open(io.BytesIO(image_data)).convert("RGB")
        input_tensor = transform(image).unsqueeze(0)

        with torch.no_grad():
            outputs = cnn_model(input_tensor)
            probabilities = torch.nn.functional.softmax(outputs[0], dim=0)
            confidence, predicted_idx = torch.max(probabilities, 0)

        confidence_score = confidence.item() * 100
        predicted_class = class_names[predicted_idx.item()]
        print(f"CNN: {predicted_class} ({confidence_score:.1f}%)")
        return predicted_class, confidence_score

    except Exception as e:
        print(f"CNN error: {e}")
        return None, 0

def detect_multiple_foods(image_base64):
    """Ask LLaVA to detect ALL foods in image"""
    print("LLaVA detecting multiple foods...")

    food_list = list(food_db.keys())
    food_options = ", ".join(food_list)

    try:
        response = requests.post(
            "http://localhost:11434/api/generate",
            json={
                "model": "llava",
                "prompt": f"""Look at this food image very carefully.

ONLY list foods that you can CLEARLY and OBVIOUSLY see.
Do NOT guess or assume foods that might be there.
Do NOT list foods just because they are commonly eaten together.

Available foods to identify from:
{food_options}

Rules:
- Only list foods you are 100% sure you can see
- If you only see ONE food, list only that one
- Maximum 3 foods
- If unsure about a food do NOT include it
- Separate with commas

What foods can you CLEARLY see in this image?""",
                "images": [image_base64],
                "stream": False
            },
            timeout=120
        )

        result = response.json()
        raw = result.get("response", "").strip()
        print(f"LLaVA detected: {raw}")

        # Split into list
        foods = [f.strip() for f in raw.split(",")]
        foods = [f for f in foods if f]
        return foods

    except Exception as e:
        print(f"LLaVA error: {e}")
        return []

def find_best_match(name):
    """Find closest food name in database"""
    name_lower = name.lower()

    for key in food_db:
        if key.lower() == name_lower:
            return key

    for key in food_db:
        if key.lower() in name_lower or name_lower in key.lower():
            return key

    for key in food_db:
        for word in key.lower().split():
            if word in name_lower and len(word) > 3:
                return key

    for class_name in class_names:
        class_formatted = class_name.replace("_", " ").title()
        if class_formatted.lower() in name_lower:
            return class_formatted

    return name

def generate_combined_description(detected_foods_info):
    """Generate ONE friendly description for all detected foods"""
    print("Generating combined tourist description...")

    foods_context = ""
    for food_name, food_info in detected_foods_info.items():
        if food_info:
            allergens = ", ".join(food_info['allergens']) if food_info['allergens'] else "None"
            foods_context += f"""
{food_name}:
- Description: {food_info['description']}
- Ingredients: {', '.join(food_info['ingredients'])}
- Allergens: {allergens}
- Dietary: {food_info['dietary']}
- How to eat: {food_info.get('how_to_eat', 'Not available')}
"""

    try:
        response = requests.post(
            "http://localhost:11434/api/generate",
            json={
                "model": "llama3.2",
                "prompt": f"""You are a friendly Sri Lankan food tour guide helping tourists.

The tourist's plate contains these foods:
{foods_context}

Write a friendly, natural description that:
1. Introduces each food naturally like a tour guide
2. Explains what each food tastes like
3. Explains how to eat them together
4. Clearly warns about any allergens

Important rules:
- Do NOT use ** or ## or any markdown
- Write in natural friendly sentences
- Keep it under 150 words
- Sound like a friendly local guide""",
                "stream": False
            },
            timeout=120
        )

        result = response.json()
        description = result.get("response", "").strip()
        description = description.replace("**", "")
        description = description.replace("##", "")
        description = description.replace("*", "")
        description = description.replace("#", "")
        return description

    except Exception as e:
        print(f"Description error: {e}")
        return "Could not generate description."

@app.route("/")
def home():
    return render_template("index.html")

@app.route("/analyze", methods=["POST"])
def analyze():
    try:
        data = request.json
        image_base64 = data.get("image")

        if not image_base64:
            return jsonify({"error": "No image provided"}), 400

        # Step 1: CNN classifies main food
        cnn_prediction, confidence = classify_with_cnn(image_base64)
        method_used = ""

        if confidence >= 75:
            print(f"CNN confident ({confidence:.1f}%)")
            main_food = cnn_prediction.replace("_", " ").title()
            method_used = f"CNN Model ({confidence:.1f}% confident)"
            detected_food_names = [main_food]
        else:
            print(f"CNN not confident - using LLaVA")
            detected_food_names = detect_multiple_foods(image_base64)
            method_used = "LLaVA Vision Detection"

       
        # Step 2: Only check for additional foods if CNN is not very confident
        if confidence >= 75 and confidence < 90:
            additional = detect_multiple_foods(image_base64)
            for food in additional:
                matched = find_best_match(food)
                if matched not in detected_food_names and matched != "Unknown Food":
                    detected_food_names.append(matched)

        # Step 3: Match each detected food to database
        matched_foods = []
        for food_name in detected_food_names:
            matched = find_best_match(food_name)
            if matched not in matched_foods:
                matched_foods.append(matched)

        print(f"Final detected foods: {matched_foods}")

        # Step 4: Get info for each food from RAG database
        foods_info = {}
        foods_result = []

        for food_name in matched_foods:
            # Search database
            food_info = food_db.get(food_name)
            if not food_info:
                for key in food_db:
                    if key.lower() == food_name.lower():
                        food_info = food_db[key]
                        food_name = key
                        break

            foods_info[food_name] = food_info

            # Get reference image from training_data
            food_image = get_food_image(food_name)

            foods_result.append({
                "food_name": food_name,
                "image": food_image,
                "ingredients": food_info["ingredients"] if food_info else ["Unknown"],
                "allergens": food_info["allergens"] if food_info else [],
                "dietary": food_info["dietary"] if food_info else "Unknown",
                "how_to_eat": food_info.get("how_to_eat", "") if food_info else "",
                "how_to_make": food_info.get("how_to_make", "") if food_info else "",
                "in_database": food_info is not None
            })

        # Step 5: Generate combined friendly description
        combined_description = generate_combined_description(foods_info)

        result = {
            "foods": foods_result,
            "combined_description": combined_description,
            "total_foods": len(foods_result),
            "method_used": method_used,
            "confidence": f"{confidence:.1f}%"
        }

        return jsonify(result)

    except Exception as e:
        print(f"Error: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    print("Starting CeylonTourMate - Food Scanner...")
    print("Open your browser and go to: http://localhost:5000")
    app.run(debug=True, port=5000)