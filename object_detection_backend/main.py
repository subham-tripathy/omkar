from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import numpy as np
import cv2
import base64
import io
from PIL import Image
import json
import httpx
import os
from typing import Optional
import uvicorn

app = FastAPI(title="Object Detection API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Load YOLO Model ──────────────────────────────────────────────────────────
from ultralytics import YOLO
model = YOLO("yolov8n.pt")  # Downloads automatically on first run

# ─── Config ───────────────────────────────────────────────────────────────────
GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "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")
GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions"

# ─── Request/Response Models ──────────────────────────────────────────────────
class DetectionRequest(BaseModel):
    image_base64: str  # base64 encoded image

class ExplanationRequest(BaseModel):
    object_name: str
    level: str  # "simple", "medium", "advanced"

class BoundingBox(BaseModel):
    x: float
    y: float
    width: float
    height: float
    label: str
    confidence: float
    index: int

class DetectionResponse(BaseModel):
    objects: list[BoundingBox]
    image_width: int
    image_height: int

class ExplanationResponse(BaseModel):
    explanation: str
    object_name: str
    level: str

# ─── Detect Objects ────────────────────────────────────────────────────────────
@app.post("/detect", response_model=DetectionResponse)
async def detect_objects(request: DetectionRequest):
    try:
        # Decode base64 image
        img_bytes = base64.b64decode(request.image_base64)
        img_array = np.frombuffer(img_bytes, dtype=np.uint8)
        img = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
        
        if img is None:
            raise HTTPException(status_code=400, detail="Invalid image data")
        
        h, w = img.shape[:2]
        
        # Run YOLO detection
        results = model(img, conf=0.4, iou=0.5)[0]
        
        objects = []
        for i, box in enumerate(results.boxes):
            x1, y1, x2, y2 = box.xyxy[0].tolist()
            conf = float(box.conf[0])
            cls_id = int(box.cls[0])
            label = model.names[cls_id]
            
            objects.append(BoundingBox(
                x=x1 / w,
                y=y1 / h,
                width=(x2 - x1) / w,
                height=(y2 - y1) / h,
                label=label,
                confidence=round(conf, 2),
                index=i
            ))
        
        # Image is NOT stored — processed only in memory
        return DetectionResponse(objects=objects, image_width=w, image_height=h)
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ─── Explain Object ────────────────────────────────────────────────────────────
@app.post("/explain", response_model=ExplanationResponse)
async def explain_object(request: ExplanationRequest):
    level_prompts = {
        "simple": f"Explain what a '{request.object_name}' is in 2-3 simple sentences for a 10-year-old child. Use very easy words.",
        "medium": f"Explain what a '{request.object_name}' is in 3-4 sentences for a high school student. Include basic facts and uses.",
        "advanced": f"Provide a detailed explanation of '{request.object_name}' in 4-5 sentences for a college student or adult. Include scientific or technical aspects, history, and interesting facts.",
    }
    
    prompt = level_prompts.get(request.level, level_prompts["medium"])
    
    headers = {
        "Authorization": f"Bearer {GROQ_API_KEY}",
        "Content-Type": "application/json"
    }
    
    payload = {
        "model": "llama-3.1-8b-instant",
        "messages": [
            {"role": "system", "content": "You are a helpful educational assistant. Give clear, accurate, engaging explanations."},
            {"role": "user", "content": prompt}
        ],
        "max_tokens": 200,
        "temperature": 0.7
    }
    
    async with httpx.AsyncClient(timeout=15) as client:
        resp = await client.post(GROQ_API_URL, headers=headers, json=payload)
        if resp.status_code != 200:
            print("Groq error:", resp.status_code)
            print("Groq response:", resp.text)
            raise HTTPException(status_code=resp.status_code, detail=resp.text)
        
        data = resp.json()
        explanation = data["choices"][0]["message"]["content"].strip()
    
    return ExplanationResponse(
        explanation=explanation,
        object_name=request.object_name,
        level=request.level
    )


@app.get("/")
def home():
    return "hello"

@app.get("/health")
async def health():
    return {"status": "ok", "model": "yolov8n"}


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000)
