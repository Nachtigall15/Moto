"""YouTube-Collector (Phase 1+).

Sammelt CEO-/Analysten-Aussagen aus YouTube — schlüssellos über zwei Bausteine:

1. **Video-Discovery** über den öffentlichen Channel-RSS-Feed
   (``https://www.youtube.com/feeds/videos.xml?channel_id=...``) — kein API-Key.
2. **Transkripte** über ``youtube-transcript-api`` (sofern verfügbar). Schlägt
   ein Transkript fehl (deaktiviert/keins/Netz), wird das Video dennoch mit Titel
   gespeichert — der Body bleibt leer.

Konfiguration (``collectors.youtube`` in settings.yaml):
- ``channels``: Liste von YouTube-Channel-IDs (UC…), deren neueste Videos.
- ``video_ids``: optionale Liste expliziter Video-IDs.
- ``limit``: max. Videos je Channel (Standard 5).
- ``languages``: bevorzugte Transkriptsprachen (Standard ["en"]).
- ``transcripts``: Transkripte laden? (Standard true).
"""

from __future__ import annotations

import datetime as dt
import logging
from dataclasses import dataclass
from typing import Iterable

import httpx

from stockintel.collectors.base import BaseCollector, CollectedItem

logger = logging.getLogger(__name__)

CHANNEL_FEED_URL = "https://www.youtube.com/feeds/videos.xml?channel_id={channel_id}"
WATCH_URL = "https://www.youtube.com/watch?v={video_id}"
DEFAULT_USER_AGENT = "stockintel/0.0.1"


@dataclass(frozen=True, slots=True)
class VideoRef:
    """Ein entdecktes Video (vor dem Transkript-Abruf)."""

    video_id: str
    title: str | None
    url: str | None
    published_at: dt.datetime | None


def parse_channel_feed(xml_text: str) -> list[VideoRef]:
    """Parst einen YouTube-Channel-Atom-Feed in ``VideoRef``-Objekte (rein, testbar)."""
    import feedparser

    parsed = feedparser.parse(xml_text)
    refs: list[VideoRef] = []
    for entry in parsed.entries:
        video_id = getattr(entry, "yt_videoid", None)
        if not video_id:
            continue
        published = None
        if getattr(entry, "published_parsed", None):
            published = dt.datetime(*entry.published_parsed[:6], tzinfo=dt.timezone.utc)
        refs.append(
            VideoRef(
                video_id=video_id,
                title=getattr(entry, "title", None),
                url=getattr(entry, "link", None),
                published_at=published,
            )
        )
    return refs


def transcript_to_text(segments) -> str:
    """Fügt Transkript-Segmente (dicts mit ``text`` oder Objekte mit ``.text``) zusammen."""
    parts: list[str] = []
    for seg in segments or []:
        text = seg.get("text") if isinstance(seg, dict) else getattr(seg, "text", None)
        if text:
            parts.append(text.strip())
    return " ".join(parts).strip()


class YouTubeCollector(BaseCollector):
    source_key = "youtube"
    name = "YouTube"
    kind = "video"

    def __init__(self, config: dict | None = None) -> None:
        super().__init__(config)
        self.channels = [str(c) for c in self.config.get("channels", []) if c]
        self.video_ids = [str(v) for v in self.config.get("video_ids", []) if v]
        self.limit = int(self.config.get("limit", 5))
        self.languages = self.config.get("languages") or ["en"]
        self.with_transcripts = bool(self.config.get("transcripts", True))
        self.user_agent = self.config.get("user_agent") or DEFAULT_USER_AGENT

    def _discover(self, client: httpx.Client) -> list[VideoRef]:
        """Sammelt Videos aus Channel-Feeds + expliziten Video-IDs."""
        refs: list[VideoRef] = []
        seen: set[str] = set()
        for channel_id in self.channels:
            resp = client.get(CHANNEL_FEED_URL.format(channel_id=channel_id))
            if resp.status_code != 200:
                logger.info("YouTube-Feed %s: HTTP %s", channel_id, resp.status_code)
                continue
            for ref in parse_channel_feed(resp.text)[: self.limit]:
                if ref.video_id not in seen:
                    seen.add(ref.video_id)
                    refs.append(ref)
        for video_id in self.video_ids:
            if video_id not in seen:
                seen.add(video_id)
                refs.append(
                    VideoRef(
                        video_id=video_id,
                        title=None,
                        url=WATCH_URL.format(video_id=video_id),
                        published_at=None,
                    )
                )
        return refs

    def _fetch_transcript(self, video_id: str) -> str | None:
        """Holt das Transkript eines Videos (oder None, wenn nicht verfügbar)."""
        if not self.with_transcripts:
            return None
        try:
            from youtube_transcript_api import YouTubeTranscriptApi
        except ImportError:
            logger.warning("youtube-transcript-api fehlt — keine Transkripte (.[collectors]).")
            return None
        try:
            fetched = YouTubeTranscriptApi().fetch(video_id, languages=self.languages)
            return transcript_to_text(fetched.to_raw_data()) or None
        except Exception as exc:  # noqa: BLE001 - pro Video robust (disabled/none/Netz)
            logger.info("Kein Transkript für %s: %s", video_id, exc)
            return None

    def fetch(self) -> Iterable[CollectedItem]:
        if not self.channels and not self.video_ids:
            return
        headers = {"User-Agent": self.user_agent}
        with httpx.Client(headers=headers, timeout=30.0) as client:
            refs = self._discover(client)

        for ref in refs:
            body = self._fetch_transcript(ref.video_id)
            yield CollectedItem(
                source_key="youtube",
                external_id=f"yt_{ref.video_id}",
                title=ref.title or f"YouTube {ref.video_id}",
                body=body,
                url=ref.url or WATCH_URL.format(video_id=ref.video_id),
                published_at=ref.published_at,
            )
