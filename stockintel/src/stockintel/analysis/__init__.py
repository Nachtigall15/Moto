"""Analyse-Schicht.

Phase 2:
- ``entity``  – regelbasierte Entity-Resolution: RawItem -> Company (-> Signal).
- ``triage``  – KI-Bewertung der Signals via Anthropic-SDK (günstiges Modell).
"""

from stockintel.analysis.entity import (
    RULE_BASED_MODEL,
    CompanyMatcher,
    Match,
    find_matches,
    link_items,
    matcher_from_company,
    score_relevance,
    sync_companies,
)
from stockintel.analysis.triage import (
    analyze_signals,
    build_triage_tool,
    build_user_content,
    extract_tool_input,
    parse_triage_response,
)

__all__ = [
    "RULE_BASED_MODEL",
    "CompanyMatcher",
    "Match",
    "analyze_signals",
    "build_triage_tool",
    "build_user_content",
    "extract_tool_input",
    "find_matches",
    "link_items",
    "matcher_from_company",
    "parse_triage_response",
    "score_relevance",
    "sync_companies",
]
