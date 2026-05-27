"""
DataCharge - All-in-One Offline Shorts/Reels Hub
Backend Server: FastAPI + yt-dlp

Folder: backend/
File:   main.py

Run with:
    pip install fastapi uvicorn yt-dlp httpx
    python main.py
"""

import os
import re
import logging
import asyncio
from typing import Optional
from contextlib import asynccontextmanager

import uvicorn
import yt_dlp
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, HttpUrl, field_validator

# ── Logging ──────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
log = logging.getLogger("datacharge")


# ── Models ────────────────────────────────────────────────────────────────────
class VideoRequest(BaseModel):
    url: str

    @field_validator("url")
    @classmethod
    def validate_url(cls, v: str) -> str:
        v = v.strip()
        tiktok_pattern = r"(https?://)?(www\.|vm\.|vt\.)?tiktok\.com/.+"
        yt_shorts_pattern = r"(https?://)?(www\.)?youtube\.com/shorts/[A-Za-z0-9_-]+"
        yt_youtu_be = r"(https?://)?youtu\.be/[A-Za-z0-9_-]+"

        if not (
            re.match(tiktok_pattern, v)
            or re.match(yt_shorts_pattern, v)
            or re.match(yt_youtu_be, v)
        ):
            raise ValueError(
                "URL must be a TikTok or YouTube Shorts link."
            )
        return v


class VideoInfo(BaseModel):
    id: str
    title: str
    platform: str          # "youtube" | "tiktok"
    duration: Optional[float]
    thumbnail: Optional[str]
    direct_url: str        # No-watermark MP4 URL
    width: Optional[int]
    height: Optional[int]
    filesize: Optional[int]


class ErrorResponse(BaseModel):
    error: str
    detail: Optional[str] = None


# ── yt-dlp helpers ────────────────────────────────────────────────────────────
# Common options shared by both platforms
_BASE_OPTS: dict = {
    "quiet": True,
    "no_warnings": True,
    "skip_download": True,           # We only want metadata / URL
    "nocheckcertificate": True,
    "extractor_retries": 3,
    "socket_timeout": 30,
}

# TikTok: pick the best MP4 without watermark
_TIKTOK_OPTS: dict = {
    **_BASE_OPTS,
    "format": "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best",
}

# YouTube: pick best mp4 ≤1080p (Shorts are portrait, so 1080p is plenty)
_YOUTUBE_OPTS: dict = {
    **_BASE_OPTS,
    "format": "bestvideo[ext=mp4][height<=1080]+bestaudio[ext=m4a]/best[ext=mp4][height<=1080]/best",
}


def _detect_platform(url: str) -> str:
    if "tiktok.com" in url:
        return "tiktok"
    return "youtube"


def _extract_info(url: str) -> dict:
    """
    Runs yt-dlp extraction in a blocking manner.
    Called inside asyncio.to_thread() to avoid blocking the event loop.
    """
    platform = _detect_platform(url)
    opts = _TIKTOK_OPTS if platform == "tiktok" else _YOUTUBE_OPTS

    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(url, download=False)

    if info is None:
        raise RuntimeError("yt-dlp returned no info for this URL.")

    # Resolve the actual playable URL
    # For merged formats, yt-dlp stores the final URL under "url"
    # or we can pick the best format from "requested_formats"
    direct_url = info.get("url") or ""

    if not direct_url:
        # Try requested_formats (merged video+audio)
        formats = info.get("requested_formats") or info.get("formats") or []
        if formats:
            # Prefer video stream for streaming purposes
            video_formats = [f for f in formats if f.get("vcodec") != "none"]
            if video_formats:
                direct_url = video_formats[-1].get("url", "")
            else:
                direct_url = formats[-1].get("url", "")

    if not direct_url:
        raise RuntimeError("Could not resolve a direct video URL.")

    # TikTok watermark removal: yt-dlp uses the no-watermark API endpoint
    # when available. We don't need extra work here.

    return {
        "id": info.get("id", "unknown"),
        "title": info.get("title") or info.get("description") or "Untitled",
        "platform": platform,
        "duration": info.get("duration"),
        "thumbnail": info.get("thumbnail"),
        "direct_url": direct_url,
        "width": info.get("width"),
        "height": info.get("height"),
        "filesize": info.get("filesize") or info.get("filesize_approx"),
    }


# ── App lifecycle ─────────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    log.info("DataCharge backend starting up…")
    yield
    log.info("DataCharge backend shutting down.")


# ── FastAPI app ───────────────────────────────────────────────────────────────
app = FastAPI(
    title="DataCharge – Video Hub API",
    version="1.0.0",
    description=(
        "Extracts no-watermark direct MP4 URLs from TikTok and YouTube Shorts."
    ),
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # Tighten in production
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


# ── Routes ────────────────────────────────────────────────────────────────────
@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "DataCharge"}


@app.post("/extract", response_model=VideoInfo)
async def extract_video(request: VideoRequest):
    """
    POST /extract
    Body: { "url": "<TikTok or YouTube Shorts URL>" }
    Returns: VideoInfo with a direct, no-watermark MP4 URL.
    """
    log.info("Extracting: %s", request.url)
    try:
        info = await asyncio.to_thread(_extract_info, request.url)
        log.info("Extracted OK: id=%s platform=%s", info["id"], info["platform"])
        return VideoInfo(**info)
    except yt_dlp.utils.DownloadError as exc:
        log.error("yt-dlp DownloadError: %s", exc)
        raise HTTPException(
            status_code=422,
            detail=f"yt-dlp could not process this URL: {exc}",
        )
    except RuntimeError as exc:
        log.error("RuntimeError: %s", exc)
        raise HTTPException(status_code=422, detail=str(exc))
    except Exception as exc:
        log.exception("Unexpected error during extraction")
        raise HTTPException(status_code=500, detail=str(exc))


@app.get("/extract", response_model=VideoInfo)
async def extract_video_get(url: str = Query(..., description="TikTok or YouTube Shorts URL")):
    """
    GET /extract?url=<URL>
    Convenience GET endpoint – same behaviour as POST.
    """
    req = VideoRequest(url=url)
    return await extract_video(req)


# ── Entry point ───────────────────────────────────────────────────────────────
if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        reload=False,
        log_level="info",
    )
