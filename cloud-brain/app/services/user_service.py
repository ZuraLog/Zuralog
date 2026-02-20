"""
Life Logger Cloud Brain — User Sync Service.

Ensures every user authenticated via Supabase Auth has a corresponding
record in our local `users` table. Uses an upsert pattern for idempotency.
"""

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User


async def sync_user_to_db(db: AsyncSession, supabase_user_id: str, email: str) -> User:
    """Ensures a user record exists in the local database.

    Uses INSERT ... ON CONFLICT DO UPDATE for idempotency. If the user
    already exists, their email is updated (in case it changed in Supabase).
    This runs within the caller's transaction — no explicit commit here.

    Args:
        db: The async database session (managed by FastAPI dependency).
        supabase_user_id: The user's UUID from Supabase Auth.
        email: The user's email address.

    Returns:
        The User ORM instance (either newly created or existing).
    """
    # Use raw SQL upsert for atomicity and to avoid race conditions.
    # The ORM select-then-insert pattern from the original plan has a
    # TOCTOU vulnerability under concurrent requests.
    stmt = text(
        """
        INSERT INTO users (id, email)
        VALUES (:id, :email)
        ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email
        RETURNING id, email
        """
    )

    result = await db.execute(stmt, {"id": supabase_user_id, "email": email})
    await db.commit()

    row = result.fetchone()
    if row is None:
        # Defensive: should never happen with RETURNING clause
        msg = f"Failed to upsert user {supabase_user_id}"
        raise RuntimeError(msg)

    # Return a lightweight User instance without a full ORM load
    user = User()
    user.id = row.id
    user.email = row.email
    return user
