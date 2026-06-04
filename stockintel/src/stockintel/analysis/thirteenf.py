"""SEC-13F-Parsing: institutionelle Halter aus 13F-HR-Filings.

13F-HR-Filings listen die Positionen institutioneller Vermögensverwalter
(>100 Mio. USD Portfolio). Die "Information Table" ist ein XML-Dokument mit je
einem ``infoTable``-Eintrag pro Position (Emittent, CUSIP, Wert, Stückzahl).

Aufteilung:
- ``parse_13f_infotable`` — reine, namespace-robuste XML-Parserfunktion (testbar).
- ``normalize_issuer`` / ``issuer_matches`` — Namensabgleich Emittent ⇄ IPO.
- ``fetch_13f_holdings`` — EDGAR-Abruf (netzabhängig, degradiert zu []).

Kein KI-Modell beteiligt — reines regelbasiertes Parsen/Matching.
"""

from __future__ import annotations

import logging
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass

logger = logging.getLogger(__name__)

SUBMISSIONS_URL = "https://data.sec.gov/submissions/CIK{cik}.json"
ARCHIVE_INDEX_URL = "https://www.sec.gov/Archives/edgar/data/{cik}/{acc}/index.json"
ARCHIVE_FILE_URL = "https://www.sec.gov/Archives/edgar/data/{cik}/{acc}/{name}"
DEFAULT_USER_AGENT = "stockintel research example@example.com"

# Häufige Rechtsform-/Klassen-Suffixe, die beim Namensabgleich stören.
_ISSUER_NOISE = {
    "inc", "incorporated", "corp", "corporation", "co", "company", "ltd",
    "limited", "plc", "llc", "lp", "sa", "ag", "nv", "holdings", "holding",
    "group", "com", "cl", "class", "a", "b", "the", "new", "ord", "ordinary",
    "shares", "share", "adr", "ads", "spons", "sponsored",
}


@dataclass(frozen=True, slots=True)
class Holding:
    """Eine 13F-Position: Emittent, CUSIP, Wert, Stückzahl."""

    issuer: str
    cusip: str | None
    value: float | None
    shares: float | None


def _local(tag: str) -> str:
    """Lokaler Tag-Name ohne XML-Namespace (``{ns}infoTable`` -> ``infoTable``)."""
    return tag.rsplit("}", 1)[-1].lower()


def _find_child(element: ET.Element, name: str) -> ET.Element | None:
    for child in element:
        if _local(child.tag) == name.lower():
            return child
    return None


def _child_text(element: ET.Element, name: str) -> str | None:
    child = _find_child(element, name)
    if child is None or child.text is None:
        return None
    text = child.text.strip()
    return text or None


def _to_float(value: str | None) -> float | None:
    if value is None:
        return None
    cleaned = value.replace(",", "").strip()
    try:
        return float(cleaned)
    except ValueError:
        return None


def parse_13f_infotable(xml_text: str) -> list[Holding]:
    """Parst eine 13F Information Table (XML) in eine Liste von ``Holding``.

    Namespace-robust: erkennt ``infoTable``-Einträge unabhängig von Präfix/NS.
    Liefert eine leere Liste bei ungültigem XML (kein Crash).
    """
    if not xml_text or not xml_text.strip():
        return []
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError as exc:
        logger.warning("13F-XML nicht parsebar: %s", exc)
        return []

    holdings: list[Holding] = []
    # Alle infoTable-Knoten finden (egal wie tief / welcher Namespace).
    for node in root.iter():
        if _local(node.tag) != "infotable":
            continue
        issuer = _child_text(node, "nameOfIssuer")
        if not issuer:
            continue
        cusip = _child_text(node, "cusip")
        value = _to_float(_child_text(node, "value"))

        shares = None
        shrs = _find_child(node, "shrsOrPrnAmt")
        if shrs is not None:
            shares = _to_float(_child_text(shrs, "sshPrnamt"))

        holdings.append(Holding(issuer=issuer, cusip=cusip, value=value, shares=shares))
    return holdings


def normalize_issuer(name: str | None) -> set[str]:
    """Zerlegt einen Emittenten-/Firmennamen in bedeutungstragende Tokens.

    Entfernt Rechtsform-/Klassen-Rauschen ("INC", "CORP", "COM", "CL A", …) und
    Sonderzeichen, damit "Acme Corp." und "ACME CORP COM" matchen.
    """
    if not name:
        return set()
    cleaned = re.sub(r"[^a-z0-9\s]", " ", name.lower())
    tokens = {t for t in cleaned.split() if t and t not in _ISSUER_NOISE}
    return tokens


def issuer_matches(issuer: str | None, company_name: str | None) -> bool:
    """True, wenn Emittent und Firmenname sich (über Tokens) decken.

    Match-Kriterium: alle bedeutungstragenden Tokens der kürzeren Seite sind in
    der anderen enthalten (Teilmengen-Logik, robust gegen Zusätze wie "COM").
    """
    a = normalize_issuer(issuer)
    b = normalize_issuer(company_name)
    if not a or not b:
        return False
    smaller, larger = (a, b) if len(a) <= len(b) else (b, a)
    return smaller <= larger


def fetch_13f_holdings(
    cik: str,
    user_agent: str = DEFAULT_USER_AGENT,
    client=None,
) -> list[Holding]:
    """Lädt die jüngste 13F-HR-Information-Table eines Managers von EDGAR.

    Netzabhängig — liefert bei jedem Fehler (kein httpx, HTTP-Fehler, kein 13F,
    keine Infotable) eine leere Liste statt einer Exception.

    ``client`` (optional) ist ein vorhandener ``httpx.Client`` (sonst wird einer
    erzeugt). ``cik`` darf mit/ohne führende Nullen übergeben werden.
    """
    try:
        import httpx
    except ImportError:
        logger.warning("httpx fehlt — 13F-Abruf nicht möglich (pip install .[collectors])")
        return []

    cik_padded = str(cik).zfill(10)
    cik_int = int(cik_padded)
    headers = {"User-Agent": user_agent, "Accept-Encoding": "gzip, deflate"}
    own_client = client is None
    client = client or httpx.Client(headers=headers, timeout=30.0)
    try:
        sub = client.get(SUBMISSIONS_URL.format(cik=cik_padded))
        if sub.status_code != 200:
            return []
        recent = sub.json().get("filings", {}).get("recent", {})
        forms = recent.get("form", [])
        accessions = recent.get("accessionNumber", [])
        idx = next((i for i, f in enumerate(forms) if f == "13F-HR"), None)
        if idx is None:
            return []
        acc_nodash = accessions[idx].replace("-", "")

        index = client.get(ARCHIVE_INDEX_URL.format(cik=cik_int, acc=acc_nodash))
        if index.status_code != 200:
            return []
        items = index.json().get("directory", {}).get("item", [])
        infotable_name = _pick_infotable(items)
        if not infotable_name:
            return []

        doc = client.get(ARCHIVE_FILE_URL.format(cik=cik_int, acc=acc_nodash, name=infotable_name))
        if doc.status_code != 200:
            return []
        return parse_13f_infotable(doc.text)
    except Exception as exc:  # noqa: BLE001 - Netzwerk/JSON robust kapseln
        logger.warning("13F-Abruf für CIK %s fehlgeschlagen: %s", cik, exc)
        return []
    finally:
        if own_client:
            client.close()


def _pick_infotable(items: list[dict]) -> str | None:
    """Wählt aus den Filing-Dokumenten die Information-Table-XML heuristisch aus."""
    xmls = [it.get("name", "") for it in items if str(it.get("name", "")).lower().endswith(".xml")]
    # Bevorzugt Dateien mit "table"/"infotable" im Namen.
    for name in xmls:
        low = name.lower()
        if "infotable" in low or "table" in low:
            return name
    # Sonst: erste XML, die nicht die Cover-/Primary-Form ist.
    for name in xmls:
        if "primary_doc" not in name.lower() and "form13f" not in name.lower():
            return name
    return xmls[0] if xmls else None
