"""Unsplash API integration for fetching evocative background images."""
import hashlib
import os
from pathlib import Path

import requests

UNSPLASH_ACCESS_KEY = os.environ.get("UNSPLASH_ACCESS_KEY")
UNSPLASH_API = "https://api.unsplash.com/search/photos"

# Cache downloaded images under the tiles dir so we don't re-fetch.
CACHE_DIR = Path(os.environ.get("TILES_DIR", Path(__file__).resolve().parent.parent / "tiles")) / "unsplash_cache"


def _cache_key(query: str) -> str:
    return hashlib.sha1(query.encode()).hexdigest()[:16]


def fetch_photo(query: str) -> Path | None:
    """Search Unsplash for *query* and return a local path to the first result.

    Returns None if no key is configured, the API errors, or no results.
    The downloaded image is cached on disk.
    """
    if not UNSPLASH_ACCESS_KEY:
        return None

    cache_key = _cache_key(query)
    cached = CACHE_DIR / f"{cache_key}.jpg"
    if cached.exists():
        return cached

    try:
        resp = requests.get(
            UNSPLASH_API,
            params={"query": query, "per_page": 1, "orientation": "portrait"},
            headers={"Authorization": f"Client-ID {UNSPLASH_ACCESS_KEY}"},
            timeout=10,
        )
        resp.raise_for_status()
        data = resp.json()
        results = data.get("results", [])
        if not results:
            return None

        img_url = results[0]["urls"]["regular"]
        img_resp = requests.get(img_url, timeout=15)
        img_resp.raise_for_status()

        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        cached.write_bytes(img_resp.content)
        return cached
    except Exception:
        # Fail silently — caller should fall back to plain text.
        return None
