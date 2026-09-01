/**
 * Drowsiness Detection Module for CeylonTourMate Vehicle Monitor
 * 
 * Uses the device front camera + converted Keras model (via TensorFlow.js)
 * to detect driver drowsiness in real-time.
 * 
 * Detection pipeline:
 *   1. Capture video frames from front camera
 *   2. Extract face region using lightweight face detection
 *   3. Preprocess frame → model input tensor
 *   4. Run inference → drowsy / alert classification
 *   5. Fire alerts via the notification system
 */

import { showSnackbar } from './notifications.js';
import { db, auth } from './firebase-config.js';
import { doc, setDoc, serverTimestamp } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore.js";
import { getCurrentPosition, getCurrentSpeed } from './map.js';

// ── Configuration ──────────────────────────────────────────────
const CONFIG = {
    MODEL_URL: './tfjs_model/model.json',
    DETECTION_INTERVAL_MS: 150,        // Run inference every 0.15s for smoother detection
    DROWSY_THRESHOLD: 0.7,             // Probability threshold for "drowsy" (hit 70%)
    EAR_THRESHOLD: 0.22,               // Threshold for Eye Aspect Ratio (EAR)
    DROWSY_DURATION_MS: 1000,          // 1 second duration for alert trigger
    ALERT_COOLDOWN_MS: 15000,          // Min time between alerts (15s)
    INPUT_SIZE: 64,                    // Default model input size (updated after load)
    CAMERA_CONSTRAINTS: {
        video: {
            facingMode: 'user',        // Front camera
            width: { ideal: 320 },
            height: { ideal: 240 },
            frameRate: { ideal: 15 },
            powerPreference: "low-power" // Helps iPhone battery
        },
        audio: false
    },
    SMOOTHING_FACTOR: 0.7,             // Reduced slightly for faster response (User: 1s trigger)
    MICROSLEEP_DURATION_MS: 1500,      // 1.5s for microsleep detection
    DISTRACTION_YAW_THRESHOLD: 0.3,    // Looking left/right
    DISTRACTION_PITCH_THRESHOLD: 0.25  // Looking up/down
};

// ── State ──────────────────────────────────────────────────────
let model = null;
let faceDetector = null;
let videoStream = null;
let detectionLoop = null;
let isRunning = false;
let drowsyCount = 0;
let noFaceCount = 0;
let lastAlertTime = 0;
let lastNoFaceAlertTime = 0;
let alertAudio = null;

// New state for improvements
let smoothedConfidence = 0;
let eyesClosedStartTime = null;
let headPose = { pitch: 0, yaw: 0, roll: 0 };
let isDistracted = false;
let drowsinessStartTime = null;        // Track duration of high drowsiness (User Request: 1s)

const NO_FACE_FRAMES_THRESHOLD = 5;   // Consecutive no-face frames before warning
const NO_FACE_COOLDOWN_MS = 10000;    // 10s between "focus on road" alerts

// DOM Elements (populated on init)
let videoEl = null;
let canvasEl = null;
let canvasCtx = null;
let statusIndicator = null;
let statusText = null;
let confidenceBar = null;
let confidenceValue = null;
let toggleBtn = null;

// ── Firebase Telemetry ─────────────────────────────────────────
let lastSyncTime = 0;
const SYNC_INTERVAL_MS = 5000; // Sync every 5s during normal operation

/**
 * Send current telemetry and driver status to Firebase
 */
async function syncTelemetryToFirebase(status, confidence, eyeState = 'OPEN', ear = 0.30) {
    if (!db || !auth.currentUser) return;

    const now = Date.now();
    const isAlert = status === 'Drowsy' || status === 'Warning' || eyeState === 'CLOSED';
    
    // Sync if interval passed (3s) OR it's a critical alert
    if (!isAlert && (now - lastSyncTime < 3000)) return;
    lastSyncTime = now;

    try {
        const driverId = auth.currentUser.uid;
        const gps = getCurrentPosition();
        const speed = getCurrentSpeed();

        const telemetryData = {
            driverId: driverId,
            driverName: auth.currentUser.displayName || auth.currentUser.email?.split('@')[0] || 'Driver',
            driverEmail: auth.currentUser.email || '',
            status: status,
            eyeState: eyeState,
            ear: typeof ear === 'number' ? parseFloat(ear.toFixed(3)) : 0.30,
            confidence: Math.round(confidence * 100),
            gps: gps ? {
                lat: gps.lat,
                lng: gps.lng
            } : { lat: 6.9271, lng: 79.8612 }, // Fallback to Colombo if GPS not enabled in browser
            speed: Math.round(speed || 0),
            timestamp: serverTimestamp(),
            lastUpdated: new Date().toISOString()
        };

        // Update the driver's current status document
        await setDoc(doc(db, "active_trips", driverId), telemetryData, { merge: true });
        
        // If it's a critical alert, also log to an alert history collection
        if (isAlert) {
            const alertId = `${driverId}_${now}`;
            await setDoc(doc(db, "alerts", alertId), {
                ...telemetryData,
                type: eyeState === 'CLOSED' ? 'eye_closure_alert' : 'drowsiness_alert'
            });
        }

    } catch (err) {
        console.error('[Firebase] Sync failed:', err);
        if (err.code === 'permission-denied' || err.message?.includes('API has not been used')) {
            if (now - lastAlertTime > 60000) { 
                showSnackbar("Telemetry Sync: Firestore API not enabled. Monitoring continues locally.", "error", 5000);
                lastAlertTime = now;
            }
        }
    }
}

// ── Public API ─────────────────────────────────────────────────

/**
 * Initialize the drowsiness detection module
 * Called once when the dashboard loads
 */
export async function initDrowsinessDetection() {
    console.log('[Drowsiness] Initializing module...');

    // Cache DOM references
    videoEl = document.getElementById('drowsy-video');
    canvasEl = document.getElementById('drowsy-canvas');
    statusIndicator = document.getElementById('drowsy-status-indicator');
    statusText = document.getElementById('drowsy-status-text');
    confidenceBar = document.getElementById('drowsy-confidence-bar');
    confidenceValue = document.getElementById('drowsy-confidence-value');
    toggleBtn = document.getElementById('drowsy-toggle-btn');

    if (!videoEl || !canvasEl) {
        console.warn('[Drowsiness] DOM elements not found. Skipping init.');
        return;
    }

    canvasCtx = canvasEl.getContext('2d');

    // Set up toggle button
    if (toggleBtn) {
        toggleBtn.addEventListener('click', toggleDetection);
    }

    // Create alert sound (oscillator-based, no external file needed)
    createAlertSound();

    // Try to load the model
    await loadModel();
}

/**
 * Toggle detection on/off
 */
export async function toggleDetection() {
    if (isRunning) {
        stopDetection();
    } else {
        await startDetection();
    }
}

/**
 * Start camera and detection loop
 */
export async function startDetection() {
    if (isRunning) return;

    try {
        updateStatus('starting', 'Starting camera...');

        // Request front camera
        videoStream = await navigator.mediaDevices.getUserMedia(CONFIG.CAMERA_CONSTRAINTS);
        videoEl.srcObject = videoStream;
        await videoEl.play();

        // Update canvas size to match video
        canvasEl.width = videoEl.videoWidth || 320;
        canvasEl.height = videoEl.videoHeight || 240;

        isRunning = true;
        drowsyCount = 0;

        updateToggleBtn(true);
        updateStatus('active', 'Monitoring...');

        // Start detection loop with recursive setTimeout to avoid overlapping
        isRunning = true;
        detectionLoop = setTimeout(runDetection, CONFIG.DETECTION_INTERVAL_MS);

        console.log('[Drowsiness] Detection started.');
        showSnackbar('Drowsiness monitoring activated', 'info', 3000);

    } catch (err) {
        console.error('[Drowsiness] Camera access failed:', err);
        updateStatus('error', 'Camera access denied');
        showSnackbar('Camera access denied. Please allow camera permissions.', 'error');
    }
}

/**
 * Stop camera and detection
 */
export function stopDetection() {
    isRunning = false;

    if (detectionLoop) {
        clearTimeout(detectionLoop);
        detectionLoop = null;
    }

    if (videoStream) {
        videoStream.getTracks().forEach(track => track.stop());
        videoStream = null;
    }

    if (videoEl) {
        videoEl.srcObject = null;
    }

    // Clear canvas
    if (canvasCtx && canvasEl) {
        canvasCtx.clearRect(0, 0, canvasEl.width, canvasEl.height);
    }

    drowsyCount = 0;
    updateToggleBtn(false);
    updateStatus('inactive', 'Detection paused');
    updateConfidence(0);

    console.log('[Drowsiness] Detection stopped.');
}

// ── Model Loading ──────────────────────────────────────────────

async function loadModel() {
    // Check if TensorFlow.js is loaded
    if (typeof tf === 'undefined') {
        console.warn('[Drowsiness] TensorFlow.js not loaded yet. Model loading deferred.');
        updateEngineLabel('No TF.js');
        return false;
    }

    try {
        updateStatus('loading', 'Loading AI model...');

        // 1. Load the drowsiness classification model
        model = await tf.loadLayersModel(CONFIG.MODEL_URL);
        const inputShape = model.inputs[0].shape;
        console.log('[Drowsiness] Drowsiness model loaded. Input shape:', inputShape);

        if (inputShape.length === 4) {
            CONFIG.INPUT_SIZE = inputShape[1] || 64;
        }

        // Warm up
        const dummyInput = tf.zeros([1, CONFIG.INPUT_SIZE, CONFIG.INPUT_SIZE, inputShape[3] || 3]);
        const warmup = model.predict(dummyInput);
        const warmupData = await warmup.data();
        console.log('[Drowsiness] Warmup prediction (zeros):', warmupData[0]);
        dummyInput.dispose();
        warmup.dispose();

        // 2. Load MediaPipe Face Mesh for eye landmarks (EAR)
        if (typeof faceLandmarksDetection !== 'undefined') {
            updateStatus('loading', 'Loading Face Mesh...');
            const detectorModel = faceLandmarksDetection.SupportedModels.MediaPipeFaceMesh;
            const detectorConfig = {
                runtime: 'mediapipe',
                solutionPath: `https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh`,
                refineLandmarks: true
            };
            faceDetector = await faceLandmarksDetection.createDetector(detectorModel, detectorConfig);
            console.log('[Drowsiness] MediaPipe Face Mesh loaded for EAR + Cropping.');
        } else {
            console.warn('[Drowsiness] faceLandmarksDetection not available. Using center-crop fallback.');
        }

        updateStatus('ready', 'Ready to start');
        updateEngineLabel('Hybrid AI');
        console.log(`[Drowsiness] Model ready. Input: ${CONFIG.INPUT_SIZE}x${CONFIG.INPUT_SIZE}`);
        return true;

    } catch (err) {
        console.error('[Drowsiness] Failed to load model:', err);
        updateStatus('error', 'Model load failed');
        updateEngineLabel('Error');
        model = null;
        return false;
    }
}

// ── Detection Pipeline ─────────────────────────────────────────

async function runDetection() {
    if (!isRunning || !videoEl || videoEl.readyState < 2) return;

    try {
        // Draw current frame to canvas
        canvasCtx.drawImage(videoEl, 0, 0, canvasEl.width, canvasEl.height);

        let isDrowsy = false;
        let confidence = 0;
        let isNoFace = false;
        let result = null;

        if (model && typeof tf !== 'undefined') {
            result = await runModelInference();
            isDrowsy = result.isDrowsy;
            confidence = result.confidence;
            isNoFace = result.noFace || false;
        } else {
            // No model — can't detect
            confidence = 0;
            isDrowsy = false;
        }

        // Update confidence bar
        updateConfidence(smoothedConfidence);

        // Draw overlay on canvas
        drawDetectionOverlay(isDrowsy, smoothedConfidence, isNoFace);

        // --- IMPROVEMENT: Duration-based Alert (User Request: 50% for 1 sec) ---
        if (smoothedConfidence >= CONFIG.DROWSY_THRESHOLD) {
            if (!drowsinessStartTime) drowsinessStartTime = Date.now();
            const duration = Date.now() - drowsinessStartTime;
            
            if (duration >= CONFIG.DROWSY_DURATION_MS) {
                triggerDrowsyAlert(smoothedConfidence);
                drowsinessStartTime = null; // Reset to respect cooldown
            }
        } else {
            drowsinessStartTime = null;
        }

        // --- IMPROVEMENT: Microsleep Detection (Critical Alert for 1.5s+ closure) ---
        if (isDrowsy && result && (result.isDrowsy || result.ear < CONFIG.EAR_THRESHOLD)) {
            if (!eyesClosedStartTime) eyesClosedStartTime = Date.now();
            const closedDuration = Date.now() - eyesClosedStartTime;
            
            if (closedDuration > CONFIG.MICROSLEEP_DURATION_MS) {
                triggerCriticalAlert('MICROSLEEP DETECTED!');
                eyesClosedStartTime = null; // Reset after critical alert
            }
        } else {
            eyesClosedStartTime = null;
        }

        let currentStatus = 'Active';
        const isEyesClosed = result?.eyeState === 'CLOSED' || (result?.ear && result.ear < CONFIG.EAR_THRESHOLD);
        const eyeStateStr = isEyesClosed ? 'CLOSED' : 'OPEN';

        // Update driver UI eye state chip if present
        const eyeChipEl = document.getElementById('drowsy-eye-state');
        if (eyeChipEl) {
            eyeChipEl.innerText = eyeStateStr === 'CLOSED' ? 'Closed' : 'Open';
            eyeChipEl.style.color = eyeStateStr === 'CLOSED' ? '#F85149' : '#3FB950';
        }

        if (isNoFace) {
            if (noFaceCount >= NO_FACE_FRAMES_THRESHOLD) {
                updateStatus('warning', 'Face not detected!');
                currentStatus = 'Warning';
            } else {
                updateStatus('active', 'Looking for face...');
                currentStatus = 'Searching';
            }
        } else if (isDistracted) {
            updateStatus('warning', 'Please focus on the road!');
            currentStatus = 'Distracted';
        } else if (isDrowsy || isEyesClosed) {
            updateStatus('warning', isEyesClosed ? 'Eyes Closed Detected!' : 'Drowsiness detected!');
            currentStatus = isEyesClosed ? 'Drowsy' : 'Warning';
        } else {
            updateStatus('active', 'Monitoring...');
            currentStatus = 'Safe';
        }

        // Firebase Sync with eyeState and EAR
        syncTelemetryToFirebase(currentStatus, smoothedConfidence, eyeStateStr, result?.ear || 0.30);

        // --- IMPROVEMENT: GPU Memory Cleanup (especially for iPhone) ---
        if (typeof tf !== 'undefined') {
            await tf.nextFrame();
        }

        // Schedule next detection
        if (isRunning) {
            detectionLoop = setTimeout(runDetection, CONFIG.DETECTION_INTERVAL_MS);
        }

    } catch (err) {
        console.error('[Drowsiness] Detection error:', err);
        // Retry anyway after error
        if (isRunning) {
            detectionLoop = setTimeout(runDetection, CONFIG.DETECTION_INTERVAL_MS);
        }
    }
}

/**
 * Run the Keras model on eye crops extracted via BlazeFace.
 *
 * Pipeline:
 *   1. BlazeFace detects face → gives eye landmark positions
 *   2. Crop a region around each eye from the video frame
 *   3. Resize crop to 64×64, normalize, feed to drowsiness CNN
 *   4. Average both eyes' predictions
 *
 * Model convention (standard for drowsiness CNNs):
 *   sigmoid ≈ 1.0 → eyes OPEN (alert)
 *   sigmoid ≈ 0.0 → eyes CLOSED (drowsy)
 */
async function runModelInference() {
    const w = canvasEl.width;
    const h = canvasEl.height;

    // ── Step 1: Detect face and locate eyes ──
    let eyeRegions = null;
    let currentEAR = 0;

    if (faceDetector) {
        try {
            const predictions = await faceDetector.estimateFaces(videoEl, { flipHorizontal: false });

            if (predictions.length > 0) {
                const face = predictions[0];
                const landmarks = face.keypoints; // 478 points with refineLandmarks: true

                // --- IMPROVEMENT: Head Pose Estimation ---
                headPose = estimateHeadPose(landmarks);

                // Calculate EAR (Eye Aspect Ratio)
                currentEAR = calculateFaceEAR(landmarks);
                
                // Distraction Detection: Check if looking away
                isDistracted = Math.abs(headPose.yaw) > CONFIG.DISTRACTION_YAW_THRESHOLD || 
                               Math.abs(headPose.pitch) > CONFIG.DISTRACTION_PITCH_THRESHOLD;

                // Extract eye regions for CNN classifier
                // Landmarks indices for center of eyes (MediaPipe standard)
                const rightEyeCenter = landmarks[468]; // Right eye pupil
                const leftEyeCenter = landmarks[473];  // Left eye pupil

                // --- BUG FIX: Safer eye crop size calculation ---
                const faceWidth = face.box.width || (face.box.xMax - face.box.xMin) || 200;
                const eyeCropSize = Math.max(40, Math.round(faceWidth * 0.25));

                eyeRegions = [
                    {
                        x: Math.round(rightEyeCenter.x - eyeCropSize / 2),
                        y: Math.round(rightEyeCenter.y - eyeCropSize / 2),
                        size: eyeCropSize,
                        label: 'R'
                    },
                    {
                        x: Math.round(leftEyeCenter.x - eyeCropSize / 2),
                        y: Math.round(leftEyeCenter.y - eyeCropSize / 2),
                        size: eyeCropSize,
                        label: 'L'
                    }
                ];

                // Face found — reset no-face counter
                noFaceCount = 0;

                // Draw face box and eye markers on canvas
                drawFaceLandmarks(face, eyeRegions, currentEAR, headPose);
            } else {
                // No face found — track and warn
                noFaceCount++;
                isDistracted = false;
                if (noFaceCount >= NO_FACE_FRAMES_THRESHOLD) {
                    const now = Date.now();
                    if (now - lastNoFaceAlertTime >= NO_FACE_COOLDOWN_MS) {
                        lastNoFaceAlertTime = now;
                        showSnackbar('⚠️ Face not detected — Please focus on the road!', 'warning', 6000);
                        playAlertSound();
                        if (navigator.vibrate) navigator.vibrate([150, 80, 150]);
                    }
                }
                return { isDrowsy: false, confidence: 0, noFace: true };
            }
        } catch (e) {
            console.warn('[Drowsiness] Face Mesh error:', e);
        }
    }

    // ── Step 2: If no face detector or it failed, use center crop ──
    if (!eyeRegions) {
        // Fallback: crop the upper-center of frame (rough eye area)
        const cropSize = Math.round(Math.min(w, h) * 0.35);
        eyeRegions = [{
            x: Math.round(w / 2 - cropSize / 2),
            y: Math.round(h * 0.25),
            size: cropSize,
            label: 'C'
        }];
    }

    // ── Step 3: Run model on each eye crop ──
    let totalDrowsy = 0;
    let validCrops = 0;

    for (const eye of eyeRegions) {
        // Clamp to canvas bounds
        const sx = Math.max(0, Math.min(eye.x, w - 1));
        const sy = Math.max(0, Math.min(eye.y, h - 1));
        const sw = Math.min(eye.size, w - sx);
        const sh = Math.min(eye.size, h - sy);

        if (sw < 10 || sh < 10) continue;

        const tensor = tf.tidy(() => {
            const imageData = canvasCtx.getImageData(sx, sy, sw, sh);
            let img = tf.browser.fromPixels(imageData);

            // Resize to model input
            img = tf.image.resizeBilinear(img, [CONFIG.INPUT_SIZE, CONFIG.INPUT_SIZE]);

            // Grayscale if needed
            const inputChannels = model.inputs[0].shape[3];
            if (inputChannels === 1) {
                img = img.mean(2, true);
            }

            // Normalize to [0, 1]
            img = img.div(255.0);

            return img.expandDims(0);
        });

        const prediction = model.predict(tensor);
        const data = await prediction.data();
        tensor.dispose();
        prediction.dispose();

        const rawOutput = data[0];
        // Invert: 1=open(alert) → 0=drowsy, 0=closed(drowsy) → 1=drowsy
        const drowsyProb = 1.0 - rawOutput;

        console.log(`[Drowsiness] Eye ${eye.label}: raw=${rawOutput.toFixed(4)} drowsy=${(drowsyProb * 100).toFixed(1)}%`);

        totalDrowsy += drowsyProb;
        validCrops++;
    }

    const avgDrowsy = totalDrowsy / validCrops;
    
    // --- IMPROVEMENT: Better Drowsiness Logic (Weighted Scoring) ---
    // EAR is more sensitive to momentary blinks, CNN is better for sustained fatigue look
    // Weighted scoring: 60% CNN + 40% EAR
    const earScore = Math.min(1.0, Math.max(0, (CONFIG.EAR_THRESHOLD * 1.5 - currentEAR) / CONFIG.EAR_THRESHOLD));
    
    // --- BUG FIX: Use the higher of the two signals (CNN vs EAR) ---
    // Previously, a low CNN score would drag down a high EAR score (closed eyes).
    // Using Math.max ensures that if eyes are clearly closed (high EAR score), 
    // the confidence reflects that even if the CNN model is uncertain.
    const combinedConfidence = Math.max(avgDrowsy, earScore);

    // Head tilt adjustment: If head is tilted down (high pitch), increase confidence
    let adjustedConfidence = combinedConfidence;
    if (headPose.pitch > 0.15) { // Tilted down
        adjustedConfidence += 0.1;
    }

    // --- IMPROVEMENT: Temporal Smoothing ---
    smoothedConfidence = (smoothedConfidence * CONFIG.SMOOTHING_FACTOR) + (adjustedConfidence * (1 - CONFIG.SMOOTHING_FACTOR));
    smoothedConfidence = Math.max(0, Math.min(1.0, smoothedConfidence)); // Clamp between 0 and 1 (100%)

    const isHybridDrowsy = smoothedConfidence >= CONFIG.DROWSY_THRESHOLD;

    console.log(`[Drowsiness] EAR: ${currentEAR.toFixed(3)}, CNN: ${avgDrowsy.toFixed(2)}, Pose P: ${headPose.pitch.toFixed(2)}, Smoothed: ${smoothedConfidence.toFixed(2)}`);

    const isClosed = currentEAR < CONFIG.EAR_THRESHOLD || avgDrowsy > 0.65;

    return {
        isDrowsy: isHybridDrowsy,
        confidence: smoothedConfidence,
        ear: currentEAR,
        eyeState: isClosed ? 'CLOSED' : 'OPEN'
    };
}

/**
 * Calculate Eye Aspect Ratio (EAR) for both eyes and return the average.
 */
function calculateFaceEAR(landmarks) {
    // Indices for MediaPipe Face Mesh
    // Left eye
    const leftEAR = getEAR(landmarks, 362, 385, 387, 263, 373, 380);
    // Right eye
    const rightEAR = getEAR(landmarks, 33, 160, 158, 133, 153, 144);
    
    return (leftEAR + rightEAR) / 2;
}

function getEAR(landmarks, p1, p2, p3, p4, p5, p6) {
    const v1 = dist(landmarks[p2], landmarks[p6]);
    const v2 = dist(landmarks[p3], landmarks[p5]);
    const h = dist(landmarks[p1], landmarks[p4]);
    return (v1 + v2) / (2 * h);
}

function dist(p1, p2) {
    return Math.sqrt(Math.pow(p1.x - p2.x, 2) + Math.pow(p1.y - p2.y, 2));
}

/**
 * Estimate head pose (pitch, yaw, roll) based on landmarks.
 */
function estimateHeadPose(landmarks) {
    // Points for pose estimation (MediaPipe indices)
    const nose = landmarks[1];
    const chin = landmarks[152];
    const leftEye = landmarks[33];
    const rightEye = landmarks[263];
    const leftMouth = landmarks[61];
    const rightMouth = landmarks[291];

    // Pitch: vertical tilt (up/down)
    // Distance from nose to eyes vs nose to chin
    const eyeMidY = (leftEye.y + rightEye.y) / 2;
    const noseToEye = nose.y - eyeMidY;
    const noseToChin = chin.y - nose.y;
    const pitch = (noseToChin / (noseToEye + 0.001)) - 1.5; // Baseline approx 1.5

    // Yaw: horizontal tilt (left/right)
    const noseToLeftEye = nose.x - leftEye.x;
    const rightEyeToNose = rightEye.x - nose.x;
    const yaw = (noseToLeftEye / (rightEyeToNose + 0.001)) - 1.0;

    // Roll: rotation (tilt to shoulder)
    const roll = Math.atan2(rightEye.y - leftEye.y, rightEye.x - leftEye.x);

    return { pitch, yaw, roll };
}

/**
 * Draw face detection landmarks on the canvas overlay
 */
function drawFaceLandmarks(face, eyeRegions, ear, pose) {
    canvasCtx.save();

    // Face bounding box
    const box = face.box;
    const bx = box.xMin;
    const by = box.yMin;
    const bw = box.width || (box.xMax - box.xMin);
    const bh = box.height || (box.yMax - box.yMin);

    canvasCtx.strokeStyle = 'rgba(47, 129, 247, 0.6)';
    canvasCtx.lineWidth = 2;
    canvasCtx.setLineDash([6, 4]);
    canvasCtx.strokeRect(bx, by, bw, bh);
    canvasCtx.setLineDash([]);

    // EAR display
    canvasCtx.fillStyle = ear < CONFIG.EAR_THRESHOLD ? '#F85149' : '#3FB950';
    canvasCtx.font = 'bold 12px Outfit, sans-serif';
    canvasCtx.fillText(`EAR: ${ear.toFixed(3)}`, bx, by - 10);

    // Pose display (Pitch/Yaw)
    canvasCtx.fillStyle = isDistracted ? '#F85149' : 'rgba(255, 255, 255, 0.7)';
    canvasCtx.font = '10px Outfit, sans-serif';
    canvasCtx.fillText(`P: ${pose.pitch.toFixed(2)} Y: ${pose.yaw.toFixed(2)}`, bx + bw - 70, by - 10);

    // Eye crop regions
    for (const eye of eyeRegions) {
        canvasCtx.strokeStyle = 'rgba(63, 185, 80, 0.8)';
        canvasCtx.lineWidth = 2;
        canvasCtx.strokeRect(eye.x, eye.y, eye.size, eye.size);

        // Label
        canvasCtx.fillStyle = 'rgba(63, 185, 80, 0.9)';
        canvasCtx.font = 'bold 10px Outfit, sans-serif';
        canvasCtx.fillText(eye.label, eye.x + 3, eye.y + 12);
    }

    canvasCtx.restore();
}

function triggerDrowsyAlert(confidence) {
    const now = Date.now();

    // Enforce cooldown between alerts
    if (now - lastAlertTime < CONFIG.ALERT_COOLDOWN_MS) return;
    lastAlertTime = now;

    const pct = Math.round(confidence * 100);

    // Visual alert
    showSnackbar(
        `⚠️ Driver drowsiness detected! (${pct}% confidence) Please take a break.`,
        'error',
        8000
    );

    // Audio alert
    playAlertSound();

    // Vibrate device
    if (navigator.vibrate) {
        navigator.vibrate([200, 100, 200, 100, 400]);
    }

    // Flash the drowsiness card border
    const card = document.getElementById('drowsy-card');
    if (card) {
        card.classList.add('alert-flash');
        setTimeout(() => card.classList.remove('alert-flash'), 3000);
    }

    console.log(`[Drowsiness] 🚨 ALERT! Confidence: ${pct}%`);
}

function triggerCriticalAlert(message) {
    const now = Date.now();
    // Critical alerts have shorter cooldown (5s) but are more intense
    if (now - lastAlertTime < 5000) return;
    lastAlertTime = now;

    showSnackbar(`🚨 CRITICAL: ${message}`, 'error', 10000);
    
    // Intense audio alert
    playCriticalSound();

    // Long vibration
    if (navigator.vibrate) {
        navigator.vibrate([500, 200, 500, 200, 500]);
    }

    // Flash UI
    const card = document.getElementById('drowsy-card');
    if (card) {
        card.classList.add('critical-flash');
        setTimeout(() => card.classList.remove('critical-flash'), 5000);
    }
}

function createAlertSound() {
    // We'll create the AudioContext on first use (browser autoplay policy)
    alertAudio = {
        play: () => {
            try {
                const ctx = new (window.AudioContext || window.webkitAudioContext)();
                const oscillator = ctx.createOscillator();
                const gainNode = ctx.createGain();

                oscillator.connect(gainNode);
                gainNode.connect(ctx.destination);

                // Alarm-like tone pattern
                oscillator.type = 'square';
                oscillator.frequency.setValueAtTime(800, ctx.currentTime);
                oscillator.frequency.setValueAtTime(600, ctx.currentTime + 0.2);
                oscillator.frequency.setValueAtTime(800, ctx.currentTime + 0.4);

                gainNode.gain.setValueAtTime(0.3, ctx.currentTime);
                gainNode.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.8);

                oscillator.start(ctx.currentTime);
                oscillator.stop(ctx.currentTime + 0.8);
            } catch (e) {
                console.warn('[Drowsiness] Audio alert failed:', e);
            }
        },
        playCritical: () => {
            try {
                const ctx = new (window.AudioContext || window.webkitAudioContext)();
                const oscillator = ctx.createOscillator();
                const gainNode = ctx.createGain();

                oscillator.connect(gainNode);
                gainNode.connect(ctx.destination);

                oscillator.type = 'sawtooth';
                oscillator.frequency.setValueAtTime(1000, ctx.currentTime);
                
                // Rapid pulsing
                for(let i=0; i<10; i++) {
                    gainNode.gain.setValueAtTime(0.5, ctx.currentTime + i*0.2);
                    gainNode.gain.setValueAtTime(0.01, ctx.currentTime + i*0.2 + 0.1);
                }

                oscillator.start(ctx.currentTime);
                oscillator.stop(ctx.currentTime + 2.0);
            } catch (e) {
                console.warn('[Drowsiness] Critical audio alert failed:', e);
            }
        }
    };
}

function playAlertSound() {
    if (alertAudio) alertAudio.play();
}

function playCriticalSound() {
    if (alertAudio) alertAudio.playCritical();
}

// ── UI Updates ─────────────────────────────────────────────────

function updateStatus(state, text) {
    console.log(`[Drowsiness] Status Update: ${state} - ${text}`);
    if (statusIndicator) {
        statusIndicator.className = `drowsy-status-dot ${state}`;
    }
    if (statusText) {
        statusText.textContent = text;
    }

    // Also update the shield badge
    const shield = document.getElementById('drowsy-shield');
    if (shield) {
        if (state === 'warning') {
            shield.className = 'drowsy-shield danger';
            shield.innerHTML = '<span class="material-symbols-rounded">gpp_maybe</span> Drowsy';
        } else {
            shield.className = 'drowsy-shield safe';
            shield.innerHTML = '<span class="material-symbols-rounded">verified_user</span> Safe';
        }
    }
}

function updateEngineLabel(label) {
    const el = document.getElementById('drowsy-engine');
    if (el) el.textContent = label;
}

function updateConfidence(value) {
    const pct = Math.round(value * 100);
    if (confidenceBar) {
        confidenceBar.style.width = `${pct}%`;

        // Color transitions
        if (pct >= 60) {
            confidenceBar.style.background = 'linear-gradient(90deg, var(--warning), var(--error))';
        } else if (pct >= 30) {
            confidenceBar.style.background = 'linear-gradient(90deg, var(--secondary), var(--warning))';
        } else {
            confidenceBar.style.background = 'linear-gradient(90deg, var(--primary), var(--secondary))';
        }
    }
    if (confidenceValue) {
        confidenceValue.textContent = `${pct}%`;
    }
}

function updateToggleBtn(active) {
    if (!toggleBtn) return;
    const icon = toggleBtn.querySelector('.material-symbols-rounded');
    const label = toggleBtn.querySelector('.toggle-label');

    if (active) {
        toggleBtn.classList.add('active');
        if (icon) icon.textContent = 'stop_circle';
        if (label) label.textContent = 'Stop';
    } else {
        toggleBtn.classList.remove('active');
        if (icon) icon.textContent = 'play_circle';
        if (label) label.textContent = 'Start';
    }
}

function drawDetectionOverlay(isDrowsy, confidence, isNoFace) {
    const w = canvasEl.width;
    const h = canvasEl.height;
    const pct = Math.round(confidence * 100);

    // Semi-transparent overlay on edges
    if (isDrowsy) {
        canvasCtx.save();
        // Red vignette effect
        const gradient = canvasCtx.createRadialGradient(
            w / 2, h / 2, Math.min(w, h) * 0.3,
            w / 2, h / 2, Math.max(w, h) * 0.7
        );
        gradient.addColorStop(0, 'rgba(248, 81, 73, 0)');
        gradient.addColorStop(1, 'rgba(248, 81, 73, 0.4)');
        canvasCtx.fillStyle = gradient;
        canvasCtx.fillRect(0, 0, w, h);

        // Status text
        canvasCtx.fillStyle = '#F85149';
        canvasCtx.font = 'bold 14px Outfit, sans-serif';
        canvasCtx.textAlign = 'center';
        canvasCtx.fillText(`⚠ DROWSY (${pct}%)`, w / 2, h - 12);
        canvasCtx.restore();
    } else if (isNoFace && noFaceCount >= NO_FACE_FRAMES_THRESHOLD) {
        canvasCtx.save();
        // Yellow/Orange vignette for warning
        const gradient = canvasCtx.createRadialGradient(
            w / 2, h / 2, Math.min(w, h) * 0.3,
            w / 2, h / 2, Math.max(w, h) * 0.7
        );
        gradient.addColorStop(0, 'rgba(255, 165, 0, 0)');
        gradient.addColorStop(1, 'rgba(255, 165, 0, 0.3)');
        canvasCtx.fillStyle = gradient;
        canvasCtx.fillRect(0, 0, w, h);

        // Warning text
        canvasCtx.fillStyle = '#FFA500';
        canvasCtx.font = 'bold 14px Outfit, sans-serif';
        canvasCtx.textAlign = 'center';
        canvasCtx.fillText(`⚠ FACE NOT DETECTED`, w / 2, h - 12);
        canvasCtx.restore();
    } else {
        // Subtle green border
        canvasCtx.save();
        canvasCtx.strokeStyle = 'rgba(63, 185, 80, 0.5)';
        canvasCtx.lineWidth = 2;
        canvasCtx.strokeRect(2, 2, w - 4, h - 4);

        canvasCtx.fillStyle = '#3FB950';
        canvasCtx.font = '12px Outfit, sans-serif';
        canvasCtx.textAlign = 'center';
        canvasCtx.fillText(`Alert (${pct}%)`, w / 2, h - 10);
        canvasCtx.restore();
    }
}
