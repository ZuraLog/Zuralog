"""
Zuralog Cloud Brain — Attachment Processor Service.

Validates and processes files uploaded via the chat attachment endpoint.
Extracts text content from documents, detects food images by filename
heuristics, and identifies health-relevant facts from text content.

No ML/AI calls are made here — LLM-based analysis happens downstream
when the extracted context is injected into the conversation.
"""

from __future__ import annotations

import asyncio
import concurrent.futures
import logging
import re
from typing import Any

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Food-related filename keywords used for image heuristic detection
# ---------------------------------------------------------------------------
_FOOD_KEYWORDS: frozenset[str] = frozenset(
    {
        "lunch",
        "dinner",
        "breakfast",
        "food",
        "meal",
        "snack",
        "eat",
        "eating",
        "recipe",
        "dish",
        "drink",
        "beverage",
        "fruit",
        "vegetable",
        "salad",
        "burger",
        "pizza",
        "sandwich",
        "soup",
        "dessert",
        "coffee",
        "smoothie",
        "protein",
        "plate",
    }
)

# ---------------------------------------------------------------------------
# Health keyword patterns for fact extraction from text content
# ---------------------------------------------------------------------------
_HEALTH_PATTERNS: list[tuple[str, str]] = [
    # Medication
    (
        r"\b(?:medication|medicine|drug|prescription|pill|tablet|capsule|dose|dosage)"
        r"(?:\s*:\s*|\s+is\s+|\s+)([^\.\n,;]{1,80})",
        "medication",
    ),
    # Allergy
    (
        r"\b(?:allerg(?:y|ic|ies)|intoleran(?:ce|t))(?:\s*:\s*|\s+to\s+|\s+)([^\.\n,;]{1,80})",
        "allergy",
    ),
    # Diagnosis / condition
    (
        r"\b(?:diagnos(?:ed|is)|condition|disorder|syndrome|disease)"
        r"(?:\s*:\s*|\s+with\s+|\s+of\s+|\s+)([^\.\n,;]{1,80})",
        "diagnosis",
    ),
    # Calories
    (
        r"\b(\d[\d,\.]*)\s*(?:kcal|calories?|cal\b)",
        "calories",
    ),
    # Weight / body weight
    (
        r"\b(?:weight|bodyweight|bw)\s*(?::\s*|is\s*|=\s*)?(\d[\d,\.]*)\s*(?:kg|lbs?|pounds?|kilograms?)",
        "weight",
    ),
    # Blood pressure
    (
        r"\b(?:blood\s*pressure|bp)\s*(?::\s*|is\s*|=\s*)?(\d{2,3}\s*/\s*\d{2,3})\s*(?:mmhg)?",
        "blood_pressure",
    ),
    # Heart rate
    (
        r"\b(?:heart\s*rate|pulse|resting\s+hr|rhr)\s*(?::\s*|is\s*|=\s*|of\s*)?(\d{2,3})\s*(?:bpm|beats\s+per\s+minute)?",
        "heart_rate",
    ),
    # Blood glucose / sugar
    (
        r"\b(?:blood\s*(?:glucose|sugar)|glucose)\s*(?::\s*|is\s*|=\s*)?(\d[\d,\.]*)\s*(?:mg/dl|mmol/l)?",
        "blood_glucose",
    ),
    # HRV
    (
        r"\b(?:hrv|heart\s+rate\s+variability)\s*(?::\s*|is\s*|=\s*)?(\d[\d,\.]*)\s*(?:ms)?",
        "hrv",
    ),
    # Sleep duration
    (
        r"\b(?:slept?|sleep\s+duration|sleep\s+time)\s*(?::\s*|for\s*|=\s*)?(\d[\d,\.]*)\s*(?:hours?|hrs?)",
        "sleep",
    ),
    # Steps
    (
        r"\b(\d[\d,\.]*)\s*steps?\b",
        "steps",
    ),
    # VO2 max
    (
        r"\b(?:vo2\s*max|cardio\s+fitness)\s*(?::\s*|is\s*|=\s*)?(\d[\d,\.]*)",
        "vo2_max",
    ),
    # Body fat
    (
        r"\b(?:body\s*fat|bf\s*%|fat\s*percentage)\s*(?::\s*|is\s*|=\s*)?(\d[\d,\.]*)\s*%?",
        "body_fat",
    ),
]

# Pre-compile all patterns for performance
_COMPILED_PATTERNS: list[tuple[re.Pattern[str], str]] = [
    (re.compile(pat, re.IGNORECASE), label) for pat, label in _HEALTH_PATTERNS
]

# ---------------------------------------------------------------------------
# Prompt injection guard
# ---------------------------------------------------------------------------

_DANGEROUS_PATTERN = re.compile(
    r'(ignore\s+(?:previous|above|all|everything)|system\s*:|assistant\s*:|forget\s+(?:all|everything|previous)|<\|im_start\|>|<\|im_end\|>|<\|endoftext\|>)',
    re.IGNORECASE,
)


def sanitize_for_llm(text: str) -> str:
    """Remove prompt injection patterns from user-supplied text.

    Strips multi-word instruction override phrases and special tokens
    (e.g. ``<|im_start|>``) that could manipulate LLM behaviour.

    Args:
        text: Raw text from an uploaded file or user input.

    Returns:
        Sanitized text with dangerous patterns replaced by ``[removed]``.
    """
    return _DANGEROUS_PATTERN.sub("[removed]", text)


# ---------------------------------------------------------------------------
# Thread pool for CPU-bound health fact extraction
# ---------------------------------------------------------------------------

_executor: concurrent.futures.ThreadPoolExecutor = concurrent.futures.ThreadPoolExecutor(max_workers=2)


async def _safe_extract_health_facts(text: str) -> list[str]:
    """Extract health facts asynchronously with a 2-second timeout.

    Runs the CPU-bound ``_extract_health_facts`` method in a thread pool
    executor so it does not block the event loop. Uses
    ``asyncio.get_running_loop()`` (the non-deprecated replacement for
    ``asyncio.get_event_loop()`` inside async functions).

    Args:
        text: Decoded text content to scan.

    Returns:
        A list of health fact strings, or an empty list on timeout/error.
    """
    try:
        loop = asyncio.get_running_loop()
        return await asyncio.wait_for(
            loop.run_in_executor(_executor, AttachmentProcessor._extract_health_facts, text),
            timeout=2.0,
        )
    except asyncio.TimeoutError:
        logger.warning("_safe_extract_health_facts: timed out extracting health facts")
        return []
    except Exception as exc:
        logger.warning("_safe_extract_health_facts: error extracting health facts: %s", exc)
        return []


class AttachmentProcessor:
    """Service for validating and processing user-uploaded files.

    Validates file type and size, extracts text content from documents,
    detects food images by filename heuristics, and identifies
    health-relevant facts for injection into the LLM conversation context.

    All operations are synchronous (no async I/O or ML calls).

    Class Attributes:
        ALLOWED_TYPES: Mapping of allowed MIME types to canonical extensions.
        MAX_SIZE_BYTES: Maximum file size accepted (10 MB).
        MAX_PER_MESSAGE: Maximum number of attachments allowed per message.
    """

    ALLOWED_TYPES: dict[str, str] = {
        "image/jpeg": ".jpg",
        "image/png": ".png",
        "image/heic": ".heic",
        "application/pdf": ".pdf",
        "text/plain": ".txt",
        "text/csv": ".csv",
    }

    MAX_SIZE_BYTES: int = 10 * 1024 * 1024  # 10 MB
    MAX_PER_MESSAGE: int = 3

    # -----------------------------------------------------------------------
    # Public API
    # -----------------------------------------------------------------------

    @staticmethod
    def process(
        file_bytes: bytes,
        filename: str,
        content_type: str,
        user_id: str,
    ) -> dict[str, Any]:
        """Process an uploaded file and return structured metadata.

        Steps:
        1. Validate content type and size (raises ``ValueError`` on failure).
        2. Detect whether the file is a food image via filename heuristics.
        3. Extract text content: decode text/CSV files; note that PDF
           extraction is not yet available.
        4. Extract health-relevant facts from any text content.
        5. Build a context message suitable for injection into the LLM prompt.

        Args:
            file_bytes: Raw file content in memory.
            filename: Original filename as provided by the client.
            content_type: MIME type declared by the client.
            user_id: ID of the uploading user (used for logging).

        Returns:
            A structured result dict with keys:
                - ``type``: ``"image"`` or ``"document"``.
                - ``filename``: The original filename.
                - ``content_type``: The validated MIME type.
                - ``size_bytes``: File size in bytes.
                - ``extracted_text``: Decoded text for text/CSV; ``None``
                  for images and PDFs.
                - ``is_food_image``: ``True`` if the image filename contains
                  food-related keywords.
                - ``health_facts``: List of extracted health-relevant fact
                  strings from the text content.
                - ``context_message``: A plain-English summary ready to
                  inject into the LLM context window.

        Raises:
            ValueError: If the content type is not allowed or the file
                exceeds ``MAX_SIZE_BYTES``.
        """
        # Step 1 — validate
        AttachmentProcessor.validate(file_bytes, content_type)

        logger.info(
            "AttachmentProcessor.process: user=%s filename=%r content_type=%s size=%d",
            user_id,
            filename,
            content_type,
            len(file_bytes),
        )

        size_bytes: int = len(file_bytes)
        is_image: bool = content_type.startswith("image/")
        file_type: str = "image" if is_image else "document"

        # Step 2 — food image detection
        is_food_image: bool = False
        if is_image:
            is_food_image = AttachmentProcessor._detect_food_image(filename)
            logger.debug(
                "AttachmentProcessor.process: is_food_image=%s for filename=%r",
                is_food_image,
                filename,
            )

        # Step 3 — extract text content
        extracted_text: str | None = AttachmentProcessor._extract_text(file_bytes, content_type)

        # Step 4 — identify health facts from any text
        health_facts: list[str] = []
        if extracted_text:
            health_facts = AttachmentProcessor._extract_health_facts(extracted_text)
            logger.debug(
                "AttachmentProcessor.process: found %d health fact(s) in %r",
                len(health_facts),
                filename,
            )

        # Step 5 — build context message for LLM injection
        context_message: str = AttachmentProcessor._build_context_message(
            filename=filename,
            content_type=content_type,
            file_type=file_type,
            size_bytes=size_bytes,
            extracted_text=extracted_text,
            is_food_image=is_food_image,
            health_facts=health_facts,
        )

        return {
            "type": file_type,
            "filename": filename,
            "content_type": content_type,
            "size_bytes": size_bytes,
            "extracted_text": extracted_text,
            "is_food_image": is_food_image,
            "health_facts": health_facts,
            "context_message": context_message,
        }

    # Magic byte signatures for server-side MIME verification.
    # Mapping: normalised MIME type -> list of valid magic-byte prefixes.
    _MAGIC_BYTES: dict[str, list[bytes]] = {
        "image/jpeg": [b"\xff\xd8\xff"],
        "image/png": [b"\x89PNG\r\n\x1a\n"],
        "image/heic": [],  # HEIC containers vary; skip magic-byte check
        "application/pdf": [b"%PDF"],
        "text/plain": [],  # No reliable magic bytes for plain text
        "text/csv": [],  # No reliable magic bytes for CSV
    }

    @staticmethod
    def validate(file_bytes: bytes, content_type: str) -> None:
        """Validate file content type and size.

        Checks the declared MIME type against the allowlist, verifies the
        payload does not exceed ``MAX_SIZE_BYTES``, and performs magic-byte
        verification for JPEG, PNG, and PDF files.

        Args:
            file_bytes: Raw file bytes to validate.
            content_type: MIME type declared by the client.

        Raises:
            ValueError: If the MIME type is not in ``ALLOWED_TYPES``.
            ValueError: If the file size exceeds ``MAX_SIZE_BYTES``.
            ValueError: If the magic bytes do not match the declared type.
        """
        # Normalise MIME type (strip parameters such as "; charset=utf-8")
        normalised_type = content_type.split(";")[0].strip().lower()

        if normalised_type not in AttachmentProcessor.ALLOWED_TYPES:
            allowed = ", ".join(sorted(AttachmentProcessor.ALLOWED_TYPES.keys()))
            raise ValueError(f"Unsupported file type '{normalised_type}'. Allowed types: {allowed}.")

        size = len(file_bytes)
        if size > AttachmentProcessor.MAX_SIZE_BYTES:
            max_mb = AttachmentProcessor.MAX_SIZE_BYTES / (1024 * 1024)
            raise ValueError(f"File size {size / (1024 * 1024):.1f} MB exceeds the {max_mb:.0f} MB limit.")

        # Magic-byte verification for types with known signatures
        magic_prefixes = AttachmentProcessor._MAGIC_BYTES.get(normalised_type, [])
        if magic_prefixes:
            if not any(file_bytes.startswith(prefix) for prefix in magic_prefixes):
                raise ValueError(
                    f"File content does not match declared type '{normalised_type}'. "
                    "The file may be corrupt or mislabelled."
                )

    # -----------------------------------------------------------------------
    # Private helpers
    # -----------------------------------------------------------------------

    @staticmethod
    def _detect_food_image(filename: str) -> bool:
        """Return True if the filename suggests the image depicts food.

        Checks whether any of the food-related keywords appear as a
        whole word (case-insensitive) in the filename stem.

        Args:
            filename: The original upload filename.

        Returns:
            ``True`` if a food keyword is found in the filename.
        """
        # Strip extension and lower-case for comparison
        stem = filename.rsplit(".", 1)[0].lower()
        # Tokenise on non-word characters so "lunch2" still matches "lunch"
        tokens = set(re.split(r"\W+|_", stem))
        return bool(tokens & _FOOD_KEYWORDS)

    @staticmethod
    def _extract_text(file_bytes: bytes, content_type: str) -> str | None:
        """Attempt to extract plain text from the file.

        - ``text/plain`` and ``text/csv``: decoded as UTF-8 (with
          latin-1 fallback).
        - ``application/pdf``: extraction is not yet available; a note
          string is returned so callers can communicate this to users.
        - Images: always returns ``None`` (no text extraction).

        Args:
            file_bytes: Raw file bytes.
            content_type: Normalised MIME type of the file.

        Returns:
            Extracted or explanatory text string, or ``None`` for images.
        """
        normalised = content_type.split(";")[0].strip().lower()

        if normalised in ("text/plain", "text/csv"):
            try:
                return file_bytes.decode("utf-8")
            except UnicodeDecodeError:
                try:
                    return file_bytes.decode("latin-1")
                except Exception:
                    logger.warning("_extract_text: could not decode text file — returning None")
                    return None

        if normalised == "application/pdf":
            return "PDF content extraction not yet available."

        # Images — no text extraction
        return None

    @staticmethod
    def _extract_health_facts(text: str) -> list[str]:
        """Scan text for health-relevant facts using regex patterns.

        Checks all compiled patterns in ``_COMPILED_PATTERNS`` and
        returns a deduplicated list of human-readable fact strings for
        each match found.

        Args:
            text: Decoded text content to scan.

        Returns:
            A list of fact strings, e.g. ``["calories: 450"]``.
            Empty list if no health keywords are detected.
        """
        facts: list[str] = []
        seen: set[str] = set()

        for pattern, label in _COMPILED_PATTERNS:
            for match in pattern.finditer(text):
                # Use the first capture group as the value when present
                if match.lastindex and match.lastindex >= 1:
                    value = match.group(1).strip()
                else:
                    value = match.group(0).strip()

                fact = f"{label}: {value}"
                if fact not in seen:
                    seen.add(fact)
                    facts.append(fact)

        return facts

    @staticmethod
    def _build_context_message(
        filename: str,
        content_type: str,
        file_type: str,
        size_bytes: int,
        extracted_text: str | None,
        is_food_image: bool,
        health_facts: list[str],
    ) -> str:
        """Build a plain-English context message for LLM injection.

        Summarises the attachment so the language model understands what
        was shared without requiring access to the raw bytes.

        Args:
            filename: Original upload filename.
            content_type: File MIME type.
            file_type: ``"image"`` or ``"document"``.
            size_bytes: File size in bytes.
            extracted_text: Decoded text content, or ``None``.
            is_food_image: Whether the image was identified as food.
            health_facts: List of extracted health fact strings.

        Returns:
            A formatted context message string.
        """
        size_kb = size_bytes / 1024
        size_label = f"{size_kb:.1f} KB" if size_kb < 1024 else f"{size_kb / 1024:.1f} MB"

        # Sanitise filename before embedding in LLM prompt to prevent prompt injection.
        # Strip newlines, control characters, and truncate to 255 chars.
        safe_filename = re.sub(r'[\r\n\x00-\x1f"\'`]', "", filename)[:255]

        lines: list[str] = [
            f"[Attachment] The user has shared a {file_type}: '{safe_filename}' ({content_type}, {size_label}).",
        ]

        if file_type == "image":
            if is_food_image:
                lines.append(
                    "The image appears to depict a meal or food item. "
                    "Consider providing nutritional context or asking about the meal."
                )
            else:
                lines.append("The image has been received. Describe or reference it as needed in your response.")

        if extracted_text:
            # Sanitize for prompt injection before embedding in LLM context.
            safe_text = sanitize_for_llm(extracted_text)
            # Truncate very long texts for the context summary
            preview = safe_text[:2000]
            if len(safe_text) > 2000:
                preview += f"\n... [truncated — {len(safe_text)} chars total]"
            lines.append(f"Extracted content:\n{preview}")

        if health_facts:
            facts_formatted = "\n".join(f"  - {f}" for f in health_facts)
            lines.append(f"Health-relevant information detected in the document:\n{facts_formatted}")

        return "\n\n".join(lines)
