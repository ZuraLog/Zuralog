"""Wellness transcript parsing — extracts mood/energy/stress from free-form text."""
import json
import logging

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from app.api.deps import get_authenticated_user_id
from app.agent.llm_client import LLMClient
from app.limiter import limiter

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/wellness", tags=["wellness"])

_PRESET_TAGS = [
    "work_stress", "poor_sleep", "exercise", "good_food", "social",
    "tired", "anxious", "calm", "motivated", "under_the_weather",
]

_PARSE_SYSTEM = """You are a wellness data extractor. Given a person's free-form text about how they feel, extract:
- mood: float 1.0–10.0 (1=very bad, 10=excellent)
- energy: float 1.0–10.0 (1=completely drained, 10=full of energy)
- stress: float 1.0–10.0 (1=very calm, 10=extremely stressed)
- tags: list of matching tags from this exact set (use only tags that clearly apply, may be empty):
  work_stress, poor_sleep, exercise, good_food, social, tired, anxious, calm, motivated, under_the_weather
- summary: one warm, human sentence (max 120 chars) reflecting what you heard

Respond ONLY with valid JSON matching this schema exactly:
{"mood": <float>, "energy": <float>, "stress": <float>, "tags": [<str>], "summary": "<str>"}"""


class ParseRequest(BaseModel):
    transcript: str = Field(..., min_length=1, max_length=5000)


class ParseResponse(BaseModel):
    mood: float
    energy: float
    stress: float
    tags: list[str]
    summary: str


async def parse_transcript(transcript: str, llm_client: LLMClient) -> dict:
    """Call LLM to extract structured wellness data from transcript text."""
    messages = [
        {"role": "system", "content": _PARSE_SYSTEM},
        {"role": "user", "content": transcript},
    ]
    response = await llm_client.chat(messages=messages, response_format={"type": "json_object"})
    raw = response.choices[0].message.content
    data = json.loads(raw)
    return {
        "mood": float(max(1.0, min(10.0, data.get("mood", 5.0)))),
        "energy": float(max(1.0, min(10.0, data.get("energy", 5.0)))),
        "stress": float(max(1.0, min(10.0, data.get("stress", 5.0)))),
        "tags": [t for t in data.get("tags", []) if t in _PRESET_TAGS],
        "summary": str(data.get("summary", ""))[:240],
    }


@limiter.limit("20/minute")
@router.post("/parse", response_model=ParseResponse)
async def wellness_parse(
    request: Request,
    body: ParseRequest,
    user_id: str = Depends(get_authenticated_user_id),
) -> ParseResponse:
    """Parse a free-form wellness transcript and return structured mood/energy/stress data."""
    llm_client: LLMClient | None = request.app.state.llm_client
    if llm_client is None:
        raise HTTPException(status_code=503, detail="AI service is not configured.")
    try:
        result = await parse_transcript(body.transcript, llm_client)
    except (json.JSONDecodeError, KeyError, ValueError) as exc:
        logger.warning("wellness_parse: LLM returned unparseable JSON — %s", exc)
        raise HTTPException(status_code=502, detail="AI parsing failed, please try again.")
    return ParseResponse(**result)
