import torch
import torch.nn as nn
import torchvision
import torchvision.transforms as transforms
from torchvision import datasets, models
from torch.utils.data import DataLoader
import os
import json

# Settings
TRAINING_DIR = "training_data"
MODEL_SAVE_PATH = "food_model.pth"
EPOCHS = 10
BATCH_SIZE = 8
IMAGE_SIZE = 224

print("Starting CNN Model Training for CeylonTourMate...")
print(f"Training data folder: {TRAINING_DIR}")

# Image transformations
transform = transforms.Compose([
    transforms.Resize((IMAGE_SIZE, IMAGE_SIZE)),
    transforms.RandomHorizontalFlip(),
    transforms.RandomRotation(10),
    transforms.ColorJitter(brightness=0.2, contrast=0.2),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], 
                        [0.229, 0.224, 0.225])
])

# Load dataset
print("\nLoading images from training_data folder...")
dataset = datasets.ImageFolder(
    root=TRAINING_DIR,
    transform=transform
)

# Get class names
class_names = dataset.classes
num_classes = len(class_names)
print(f"Found {num_classes} food categories: {class_names}")
print(f"Total images: {len(dataset)}")

# Save class names for later use
with open("class_names.json", "w") as f:
    json.dump(class_names, f)
print("Saved class names to class_names.json")

# Split into train and validation
train_size = int(0.8 * len(dataset))
val_size = len(dataset) - train_size
train_dataset, val_dataset = torch.utils.data.random_split(
    dataset, [train_size, val_size]
)

print(f"Training images: {train_size}")
print(f"Validation images: {val_size}")

# Create data loaders
train_loader = DataLoader(
    train_dataset, 
    batch_size=BATCH_SIZE, 
    shuffle=True
)
val_loader = DataLoader(
    val_dataset, 
    batch_size=BATCH_SIZE, 
    shuffle=False
)

# Load pretrained MobileNetV2 model
print("\nLoading pretrained MobileNetV2 model...")
model = models.mobilenet_v2(pretrained=True)

# Modify last layer for our number of food classes
model.classifier[1] = nn.Linear(
    model.last_channel, 
    num_classes
)

# Use GPU if available, otherwise CPU
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Using device: {device}")
model = model.to(device)

# Loss function and optimizer
criterion = nn.CrossEntropyLoss()
optimizer = torch.optim.Adam(model.parameters(), lr=0.001)
scheduler = torch.optim.lr_scheduler.StepLR(
    optimizer, step_size=5, gamma=0.1
)

# Training loop
print("\nStarting training...")
best_accuracy = 0.0

for epoch in range(EPOCHS):
    # Training phase
    model.train()
    running_loss = 0.0
    correct = 0
    total = 0
    
    for images, labels in train_loader:
        images, labels = images.to(device), labels.to(device)
        
        optimizer.zero_grad()
        outputs = model(images)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()
        
        running_loss += loss.item()
        _, predicted = torch.max(outputs, 1)
        total += labels.size(0)
        correct += (predicted == labels).sum().item()
    
    train_accuracy = 100 * correct / total
    
    # Validation phase
    model.eval()
    val_correct = 0
    val_total = 0
    
    with torch.no_grad():
        for images, labels in val_loader:
            images, labels = images.to(device), labels.to(device)
            outputs = model(images)
            _, predicted = torch.max(outputs, 1)
            val_total += labels.size(0)
            val_correct += (predicted == labels).sum().item()
    
    val_accuracy = 100 * val_correct / val_total
    
    print(f"Epoch [{epoch+1}/{EPOCHS}] "
          f"Loss: {running_loss/len(train_loader):.4f} "
          f"Train Accuracy: {train_accuracy:.1f}% "
          f"Val Accuracy: {val_accuracy:.1f}%")
    
    # Save best model
    if val_accuracy > best_accuracy:
        best_accuracy = val_accuracy
        torch.save(model.state_dict(), MODEL_SAVE_PATH)
        print(f"  → Best model saved! Accuracy: {val_accuracy:.1f}%")
    
    scheduler.step()

print(f"\nTraining complete!")
print(f"Best validation accuracy: {best_accuracy:.1f}%")
print(f"Model saved to: {MODEL_SAVE_PATH}")