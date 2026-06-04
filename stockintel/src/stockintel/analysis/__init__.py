"""Analyse-Schicht.

Phase 2 (in Arbeit):
- ``entity``  – regelbasierte Entity-Resolution: RawItem -> Company (-> Signal).
- KI-Triage und Tiefenanalyse folgen (Anthropic-SDK).
"""

from stockintel.analysis.entity import (
    CompanyMatcher,
    Match,
    find_matches,
    link_items,
    matcher_from_company,
    score_relevance,
    sync_companies,
)

__all__ = [
    "CompanyMatcher",
    "Match",
    "find_matches",
    "link_items",
    "matcher_from_company",
    "score_relevance",
    "sync_companies",
]
