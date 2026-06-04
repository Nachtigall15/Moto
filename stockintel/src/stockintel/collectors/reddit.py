"""Reddit-Collector (Phase 1).

Liest die neuesten Beiträge ausgewählter Subreddits via ``praw``. Frühindikator
für Social-Hype — schnell, aber unzuverlässig; die Bewertung übernimmt die KI.

Benötigt Reddit-API-Credentials (https://www.reddit.com/prefs/apps):
``REDDIT_CLIENT_ID``, ``REDDIT_CLIENT_SECRET`` (in der .env).
"""

from __future__ import annotations

import datetime as dt
import os
from typing import Iterable

from stockintel.collectors.base import BaseCollector, CollectedItem

DEFAULT_SUBREDDITS = ["wallstreetbets", "stocks", "investing"]
DEFAULT_USER_AGENT = "stockintel/0.0.1"


def submission_to_item(submission) -> CollectedItem:
    """Wandelt ein Reddit-Submission-Objekt in ein CollectedItem (rein, testbar).

    Erwartet ein Objekt mit den Attributen ``id``, ``title``, ``selftext``,
    ``permalink`` und ``created_utc`` (wie es ``praw`` liefert).
    """
    created = getattr(submission, "created_utc", None)
    published = (
        dt.datetime.fromtimestamp(created, tz=dt.timezone.utc) if created else None
    )
    permalink = getattr(submission, "permalink", "") or ""
    return CollectedItem(
        source_key="reddit",
        external_id=f"t3_{submission.id}",
        title=getattr(submission, "title", None),
        body=getattr(submission, "selftext", "") or None,
        url=f"https://www.reddit.com{permalink}" if permalink else None,
        published_at=published,
    )


class RedditCollector(BaseCollector):
    source_key = "reddit"
    name = "Reddit"
    kind = "social"

    def __init__(self, config: dict | None = None) -> None:
        super().__init__(config)
        self.subreddits = self.config.get("subreddits") or DEFAULT_SUBREDDITS
        self.limit = int(self.config.get("limit", 25))
        self.user_agent = (
            self.config.get("user_agent")
            or os.environ.get("REDDIT_USER_AGENT")
            or DEFAULT_USER_AGENT
        )

    def _client(self):
        client_id = os.environ.get("REDDIT_CLIENT_ID")
        client_secret = os.environ.get("REDDIT_CLIENT_SECRET")
        if not (client_id and client_secret):
            raise RuntimeError(
                "Reddit-Credentials fehlen: REDDIT_CLIENT_ID / REDDIT_CLIENT_SECRET "
                "in der .env setzen (https://www.reddit.com/prefs/apps)."
            )
        import praw  # lokaler Import: nur nötig, wenn Reddit aktiv ist

        return praw.Reddit(
            client_id=client_id,
            client_secret=client_secret,
            user_agent=self.user_agent,
            check_for_async=False,
        )

    def fetch(self) -> Iterable[CollectedItem]:
        reddit = self._client()
        for name in self.subreddits:
            for submission in reddit.subreddit(name).new(limit=self.limit):
                yield submission_to_item(submission)
