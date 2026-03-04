"""
Local conftest for services tests.

Overrides the root conftest to avoid importing app.main (which fails in
Python 3.14 due to a type-annotation incompatibility in journal_routes.py).
Service-layer tests do not need the full FastAPI application.
"""
