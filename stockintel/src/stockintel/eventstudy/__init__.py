"""Event-Study / Hickup-Modul (Phase 4).

Misst die Kursreaktion auf Ereignisse über feste Horizonte, berechnet abnormale
Renditen gegen einen Benchmark, erkennt Strohfeuer ("Hickups") und aggregiert
Basisraten je Ereignistyp (ReactionProfile).
"""

from stockintel.eventstudy.tracker import HORIZON_OFFSETS, classify_hickup, horizon_to_timedelta

__all__ = ["HORIZON_OFFSETS", "classify_hickup", "horizon_to_timedelta"]
