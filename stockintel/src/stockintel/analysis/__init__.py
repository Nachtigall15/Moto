"""Analyse-Schicht.

Phase 2:
- ``entity``  – regelbasierte Entity-Resolution: RawItem -> Company (-> Signal).
- ``triage``  – KI-Bewertung der Signals via Anthropic-SDK (günstiges Modell).

Phase 3:
- ``themes``  – Hype-Erkennung und Beneficiary-Linking.
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
from stockintel.analysis.themes import (
    extract_themes_from_text,
    link_themes_to_signals,
    sync_themes,
)
from stockintel.analysis.ipo import (
    extract_ipo_from_s1,
    find_ipo_events,
    link_ipo_investors,
)
from stockintel.analysis.thirteenf import (
    Holding,
    fetch_13f_holdings,
    issuer_matches,
    normalize_issuer,
    parse_13f_infotable,
)
from stockintel.analysis.eventstudy import (
    backfill_event_snapshots,
    build_events_from_signals,
    classify_event_type,
    classify_hickup,
    compute_event_outcome,
    persist_event_outcome,
    run_event_study,
    signal_to_event,
)
from stockintel.analysis.scoring import (
    generate_recommendations,
    score_company,
)

__all__ = [
    "RULE_BASED_MODEL",
    "CompanyMatcher",
    "Match",
    "analyze_signals",
    "backfill_event_snapshots",
    "build_events_from_signals",
    "build_triage_tool",
    "build_user_content",
    "classify_event_type",
    "classify_hickup",
    "compute_event_outcome",
    "extract_tool_input",
    "extract_themes_from_text",
    "extract_ipo_from_s1",
    "fetch_13f_holdings",
    "find_matches",
    "find_ipo_events",
    "generate_recommendations",
    "Holding",
    "issuer_matches",
    "normalize_issuer",
    "parse_13f_infotable",
    "link_items",
    "link_themes_to_signals",
    "link_ipo_investors",
    "matcher_from_company",
    "parse_triage_response",
    "persist_event_outcome",
    "run_event_study",
    "score_company",
    "score_relevance",
    "signal_to_event",
    "sync_companies",
    "sync_themes",
]
