# Phase 1.8.5: Voice Input (Whisper STT)

**Parent Goal:** Phase 1.8 The AI Brain (Reasoning Engine)
**Checklist:**
- [x] 1.8.1 LLM Client Setup
- [x] 1.8.2 Agent System Prompt
- [x] 1.8.3 Tool Selection Logic
- [x] 1.8.4 Cross-App Reasoning Engine
- [ ] 1.8.5 Voice Input
- [ ] 1.8.6 User Profile & Preferences
- [ ] 1.8.7 Test Harness: AI Chat
- [ ] 1.8.8 Kimi Integration Document
- [ ] 1.8.9 Rate Limiter Service
- [ ] 1.8.10 Usage Tracker Service
- [ ] 1.8.11 Rate Limiter Middleware

---

## What
Add a backend endpoint to accept audio blobs, transcribe them using OpenAI Whisper (or similar STT service), and return the text.

## Why
Voice is the most natural way to log ("I ate a banana") or ask complex questions while walking.

## How
Use `FastAPI`'s `UploadFile` to receive the audio. Use `openai` python library or a local Whisper instance to transcribe.

## Features
- **Format Support:** Accepts `.webm`, `.m4a`, `.wav`.
- **Speed:** Optimized for short command-style utterances (3-10 seconds).

## Files
- Create: `cloud-brain/app/api/v1/transcribe.py`
- Modify: `cloud-brain/app/main.py`

## Steps

1. **Add transcription endpoint (`cloud-brain/app/api/v1/transcribe.py`)**

```python
from fastapi import APIRouter, UploadFile, HTTPException
import tempfile
import os
# from cloudbrain.services.stt import transcribe_audio_file

router = APIRouter(tags=["transcribe"])

@router.post("/transcribe")
async def transcribe_audio(file: UploadFile):
    """Transcribe audio file to text."""
    
    # Validation
    if not file.filename.endswith(('.webm', '.m4a', '.wav', '.mp3')):
         raise HTTPException(400, "Invalid file format")
         
    with tempfile.NamedTemporaryFile(delete=False, suffix=f".{file.filename.split('.')[-1]}") as tmp:
        content = await file.read()
        tmp.write(content)
        tmp_path = tmp.name
    
    try:
        # Call actual STT service here
        # text = await transcribe_audio_file(tmp_path)
        text = "Mock transcription: I just ran 5km in 25 minutes."
    finally:
        os.unlink(tmp_path)
    
    return {"text": text}
```

## Exit Criteria
- Endpoint accepts file upload.
- Returns JSON with `text` field.
