"""
Export the OpenAPI schema from the FastAPI application.

Generates ``openapi.json`` at the repository root of the Cloud Brain
package by calling ``app.openapi()`` on the configured FastAPI instance.

Usage::

    cd cloud-brain
    python -m scripts.export_openapi
"""

from __future__ import annotations

import json
import pathlib

from app.main import app


def main() -> None:
    """Export the current OpenAPI schema to *openapi.json*.

    Reads the schema dict from the FastAPI ``app``, serialises it as
    pretty-printed JSON, and writes to ``cloud-brain/openapi.json``.
    Also prints a summary of total paths (endpoints) discovered.
    """
    schema = app.openapi()

    out_path = pathlib.Path(__file__).resolve().parent.parent / "openapi.json"
    out_path.write_text(json.dumps(schema, indent=2), encoding="utf-8")

    endpoint_count = sum(len(methods) for methods in schema.get("paths", {}).values())

    print(f"OpenAPI schema written to {out_path}")
    print(f"Title   : {schema.get('info', {}).get('title', 'N/A')}")
    print(f"Version : {schema.get('info', {}).get('version', 'N/A')}")
    print(f"Endpoints: {endpoint_count}")


if __name__ == "__main__":
    main()
