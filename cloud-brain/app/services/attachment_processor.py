"""
Zuralog Cloud Brain — Attachment Processor.

Processes uploaded files (images, PDFs, text, CSV) and extracts health-relevant
facts without permanently storing the raw file. Extracted knowledge is persisted
to the vector memory store (Pinecone) for future AI recall.

Design decisions:
- No permanent file storage — we extract knowledge and discard the bytes.
- Images are described via LLM vision, then health facts extracted.
- Food photo detection: if image contains food, return nutrition estimate.
- PDF/TXT/CSV: text extracted directly, then summarised.
- Max 10MB per file, max 3 files per message.
"""

from __future__ import annotations

import csv
import io
import logging
from typing import Any

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

_FOOD_KEYWORDS = frozenset(
    [
        "food",
        "meal",
        "dish",
        "plate",
        "bowl",
        "salad",
        "sandwich",
        "burger",
        "pizza",
        "pasta",
        "rice",
        "soup",
        "steak",
        "chicken",
        "fish",
        "fruit",
        "vegetable",
        "snack",
        "breakfast",
        "lunch",
        "dinner",
        "dessert",
        "drink",
        "coffee",
        "tea",
        "juice",
        "smoothie",
        "chocolate",
        "cake",
        "bread",
        "egg",
        "cheese",
        "yogurt",
        "oats",
        "cereal",
    ]
)


class AttachmentProcessor:
    """Processes uploaded file attachments and extracts health-relevant information.

    All processing is in-memory — no files are written to disk or persisted to
    object storage. Extracted facts are stored in the vector memory store.

    Class Constants:
        ALLOWED_TYPES: Set of accepted MIME types.
        MAX_SIZE_BYTES: Maximum file size (10 MB).
    """

    ALLOWED_TYPES: frozenset[str] = frozenset(
        [
            "image/jpeg",
            "image/png",
            "image/heic",
            "application/pdf",
            "text/plain",
            "text/csv",
        ]
    )
    MAX_SIZE_BYTES: int = 10 * 1024 * 1024  # 10MB

    async def process(
        self,
        file_content: bytes,
        content_type: str,
        filename: str,
        user_id: str,
        memory_store,
        llm_client,
    ) -> dict[str, Any]:
        """Process an uploaded file and return extracted facts.

        Args:
            file_content: Raw file bytes.
            content_type: MIME type of the file.
            filename: Original filename.
            user_id: Zuralog user ID.
            memory_store: Vector store for persisting extracted facts.
                Expected interface: ``await memory_store.add(text, metadata)``.
            llm_client: LLM client for vision description.
                Expected interface: ``await llm_client.describe_image(bytes)``.

        Returns:
            Dict with ``extracted_facts`` (list[str]), ``food_data`` (dict | None),
            ``content_type``, ``filename``, ``size_bytes``.

        Raises:
            ValueError: If file exceeds size limit or has an unsupported type.
        """
        if len(file_content) > self.MAX_SIZE_BYTES:
            raise ValueError(f"File size {len(file_content)} bytes exceeds {self.MAX_SIZE_BYTES} byte limit")

        if content_type not in self.ALLOWED_TYPES:
            raise ValueError(f"Unsupported content type: {content_type}")

        extracted_facts: list[str] = []
        food_data: dict | None = None

        if content_type in ("image/jpeg", "image/png", "image/heic"):
            description, food_data = await self._process_image(file_content, content_type, llm_client)
            if description:
                extracted_facts.append(description)

        else:
            text = await self._extract_text(file_content, content_type)
            if text.strip():
                # Summarise long text to extract health-relevant facts.
                summary = await self._summarise_health_facts(text, llm_client)
                if summary:
                    extracted_facts.append(summary)

        # Persist to vector memory store if facts were extracted.
        if extracted_facts and memory_store is not None:
            combined = "\n".join(extracted_facts)
            try:
                await memory_store.add(
                    combined,
                    metadata={
                        "user_id": user_id,
                        "source": "attachment",
                        "filename": filename,
                        "content_type": content_type,
                    },
                )
            except Exception:  # noqa: BLE001
                logger.exception(
                    "Failed to persist attachment facts to memory store for user %s",
                    user_id,
                )

        return {
            "extracted_facts": extracted_facts,
            "food_data": food_data,
            "content_type": content_type,
            "filename": filename,
            "size_bytes": len(file_content),
        }

    def _is_food_image(self, description: str) -> bool:
        """Check if an image description suggests food content.

        Args:
            description: LLM-generated image description string.

        Returns:
            True if the description contains food-related keywords.
        """
        description_lower = description.lower()
        return any(keyword in description_lower for keyword in _FOOD_KEYWORDS)

    async def _extract_text(self, content: bytes, content_type: str) -> str:
        """Extract text content from PDF, TXT, or CSV files.

        Args:
            content: Raw file bytes.
            content_type: MIME type of the file.

        Returns:
            Extracted text string (may be empty).
        """
        if content_type == "text/plain":
            try:
                return content.decode("utf-8", errors="replace")
            except Exception:  # noqa: BLE001
                return ""

        if content_type == "text/csv":
            return self._extract_csv_text(content)

        if content_type == "application/pdf":
            return self._extract_pdf_text(content)

        return ""

    @staticmethod
    def _extract_csv_text(content: bytes) -> str:
        """Convert CSV bytes to a plain-text representation.

        Args:
            content: CSV file bytes.

        Returns:
            Text representation with headers and rows.
        """
        try:
            text = content.decode("utf-8", errors="replace")
            reader = csv.DictReader(io.StringIO(text))
            lines: list[str] = []
            if reader.fieldnames:
                lines.append("Columns: " + ", ".join(reader.fieldnames))
            for i, row in enumerate(reader):
                if i >= 50:  # Cap rows for LLM context
                    lines.append(f"... and {i} more rows")
                    break
                lines.append(", ".join(f"{k}: {v}" for k, v in row.items()))
            return "\n".join(lines)
        except Exception:  # noqa: BLE001
            logger.exception("CSV extraction failed")
            return ""

    @staticmethod
    def _extract_pdf_text(content: bytes) -> str:
        """Extract text from a PDF file using pypdf if available.

        Falls back to a placeholder message if pypdf is not installed.

        Args:
            content: PDF file bytes.

        Returns:
            Extracted text string.
        """
        try:
            import pypdf  # type: ignore[import-untyped]

            reader = pypdf.PdfReader(io.BytesIO(content))
            pages: list[str] = []
            for page in reader.pages[:20]:  # Max 20 pages
                text = page.extract_text()
                if text:
                    pages.append(text)
            return "\n".join(pages)
        except ImportError:
            logger.warning("pypdf not installed — PDF text extraction unavailable")
            return "[PDF content — text extraction requires pypdf package]"
        except Exception:  # noqa: BLE001
            logger.exception("PDF extraction failed")
            return ""

    async def _process_image(
        self,
        content: bytes,
        content_type: str,
        llm_client,
    ) -> tuple[str, dict | None]:
        """Describe an image and optionally extract nutrition data.

        Args:
            content: Image bytes.
            content_type: MIME type (jpeg/png/heic).
            llm_client: LLM client with vision capability.

        Returns:
            Tuple of (description_text, food_data_dict_or_None).
        """
        description = ""
        food_data: dict | None = None

        try:
            if llm_client is None:
                return "", None

            # Describe the image via LLM vision.
            if hasattr(llm_client, "describe_image"):
                description = await llm_client.describe_image(content, content_type)
            else:
                logger.debug("llm_client has no describe_image method — skipping vision")
                return "", None

            if description and self._is_food_image(description):
                # Ask LLM to estimate nutrition.
                if hasattr(llm_client, "estimate_nutrition"):
                    food_data = await llm_client.estimate_nutrition(content, description)
                else:
                    food_data = {"detected": True, "note": "Nutrition estimation not available"}

        except Exception:  # noqa: BLE001
            logger.exception("Image processing failed")

        return description, food_data

    @staticmethod
    async def _summarise_health_facts(text: str, llm_client) -> str:
        """Use the LLM to extract health-relevant facts from document text.

        Args:
            text: Plain text content from the document.
            llm_client: LLM client for summarisation.

        Returns:
            Summary string with extracted health facts.
        """
        if llm_client is None:
            return text[:2000]  # Truncate for storage without LLM

        try:
            if hasattr(llm_client, "extract_health_facts"):
                return await llm_client.extract_health_facts(text[:8000])
            # Fallback: return truncated text
            return text[:2000]
        except Exception:  # noqa: BLE001
            logger.exception("Health fact summarisation failed")
            return text[:2000]
