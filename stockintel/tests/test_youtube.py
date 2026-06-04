"""Tests für den YouTube-Collector (ohne Netzwerk)."""

from stockintel.collectors.youtube import (
    YouTubeCollector,
    parse_channel_feed,
    transcript_to_text,
)

SAMPLE_FEED = """<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns:yt="http://www.youtube.com/xml/schemas/2015"
      xmlns:media="http://search.yahoo.com/mrss/"
      xmlns="http://www.w3.org/2005/Atom">
  <title>Some Finance Channel</title>
  <entry>
    <id>yt:video:VID123</id>
    <yt:videoId>VID123</yt:videoId>
    <yt:channelId>UCabc</yt:channelId>
    <title>CEO Interview: NVIDIA Earnings Outlook</title>
    <link rel="alternate" href="https://www.youtube.com/watch?v=VID123"/>
    <published>2024-01-15T10:00:00+00:00</published>
  </entry>
  <entry>
    <id>yt:video:VID456</id>
    <yt:videoId>VID456</yt:videoId>
    <title>Analyst Call: Semiconductors</title>
    <link rel="alternate" href="https://www.youtube.com/watch?v=VID456"/>
    <published>2024-01-10T08:00:00+00:00</published>
  </entry>
</feed>"""


def test_parse_channel_feed():
    refs = parse_channel_feed(SAMPLE_FEED)
    assert len(refs) == 2
    assert refs[0].video_id == "VID123"
    assert refs[0].title == "CEO Interview: NVIDIA Earnings Outlook"
    assert refs[0].url == "https://www.youtube.com/watch?v=VID123"
    assert refs[0].published_at is not None


def test_parse_channel_feed_empty():
    assert parse_channel_feed("<feed></feed>") == []
    assert parse_channel_feed("not xml") == []


def test_transcript_to_text_dicts():
    segments = [
        {"text": "Hello", "start": 0.0, "duration": 1.0},
        {"text": "world", "start": 1.0, "duration": 1.0},
        {"text": "", "start": 2.0},  # leer -> übersprungen
    ]
    assert transcript_to_text(segments) == "Hello world"


def test_transcript_to_text_objects():
    class Seg:
        def __init__(self, text):
            self.text = text

    assert transcript_to_text([Seg("foo"), Seg("bar")]) == "foo bar"
    assert transcript_to_text([]) == ""
    assert transcript_to_text(None) == ""


def test_collector_no_config_yields_nothing():
    collector = YouTubeCollector({})
    assert list(collector.fetch()) == []


def test_collector_explicit_video_no_transcripts():
    """Explizite Video-IDs ohne Transkript-Abruf -> kein Netzwerk nötig."""
    collector = YouTubeCollector({"video_ids": ["ABC123"], "transcripts": False})
    items = list(collector.fetch())
    assert len(items) == 1
    item = items[0]
    assert item.external_id == "yt_ABC123"
    assert item.url == "https://www.youtube.com/watch?v=ABC123"
    assert item.body is None
    assert item.source_key == "youtube"


def test_collector_discover_dedupes(monkeypatch):
    """Discovery dedupliziert Videos, die in Feed und video_ids vorkommen."""
    collector = YouTubeCollector(
        {"channels": ["UCabc"], "video_ids": ["VID123"], "transcripts": False}
    )

    class _FakeResp:
        status_code = 200
        text = SAMPLE_FEED

    class _FakeClient:
        def get(self, url):
            return _FakeResp()

    refs = collector._discover(_FakeClient())
    ids = [r.video_id for r in refs]
    assert ids.count("VID123") == 1          # nicht doppelt (Feed + explizit)
    assert set(ids) == {"VID123", "VID456"}
