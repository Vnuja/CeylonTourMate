# CeylonTourMate

**AI-Driven Smart Tour Guide and Traveller Safety Recommendation System**

Research Project **R26-IT-014** · BSc (Hons) in Information Technology · Sri Lanka Institute of Information Technology (SLIIT) · 2026

## Overview

CeylonTourMate is a mobile platform that supports tourists in Sri Lanka before and during their trip. It combines context-aware tour recommendations, grounded travel guidance, real-time situational awareness and live monitoring of tourist transport in one Flutter application, backed by a shared Flask API and Firebase.

## Research Problem

Tourists and travel agencies in Sri Lanka rely on several unconnected tools. Recommendations ignore weather, season and crowding, on-trip information is scattered, and once a tour begins, risks such as driver fatigue, route deviation or hostile encounters go unnoticed. No single, affordable platform supports the whole journey.

## Components

| Component | Description | Member |
|---|---|---|
| **Smart Monitor AI** | Tourist, vehicle and tour monitoring: GPS tracking, route geofencing, driver fatigue detection and real-time alerts | Ransith N P V (IT22199430) |
| **Smart Pack AI** | Context-aware tour package and activity recommendation using RAG, live weather and budget, with a fake-review detector | Senanayaka S.M.N.C (IT22027924) |
| **TourAware AI** | Tourist situational awareness: unsafe Sinhala language detection and Sri Lankan food recognition with allergen information | Sithara K.P.W.D.O (IT21067860) |
| **Smart_Guide AI** | Personalised travel assistance: tourism chatbot, landmark identification and district-level tourist arrival forecasting | Premathilaka D.A.P (IT22541802) |

## Technologies

- **Mobile app:** Flutter (Dart)
- **Backend:** Flask REST API, Firebase (Authentication, Realtime Database, Firestore, Cloud Messaging)
- **Machine learning:** TensorFlow / TensorFlow Lite, PyTorch, ONNX Runtime, scikit-learn
- **Generative AI and retrieval:** Pinecone, FAISS, LangChain, OpenRouter, Google Gemini, Ollama
- **External data:** Open-Meteo weather API, SLTDA tourism data

## Key Results

- Vehicle tracking: 96.4% of GPS fixes within 15 m; critical alerts delivered in 3.2 s (95th percentile)
- Driver eye-state classification: 92.7% accuracy
- Fake review detection: 89.17% accuracy
- Sinhala unsafe-language classifier: 87.2% accuracy
- District arrival forecasting: R² = 0.9129 on unseen 2023–2024 data
- All 24 integration test cases passed

## Team

| Name | Student ID |
|---|---|
| Ransith N P V | IT22199430 |
| Senanayaka S.M.N.C | IT22027924 |
| Sithara K.P.W.D.O | IT21067860 |
| Premathilaka D.A.P | IT22541802 |

**Supervisor:** Ms. Uthpala Samarakoon
**Co-supervisor:** Dr. Sanvitha Kasthuriarachchi

Department of Information Technology, Faculty of Computing, SLIIT

---

*This repository was developed for academic research purposes at SLIIT.*
