"""
Zuralog Cloud Brain — Global Limiter Configuration.

Provides a shared slowapi Limiter used to protect endpoints
from abuse and brute-force attacks.
"""

from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
