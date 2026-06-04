"""Tests für 13F-Parsing und Investor-Linking (reine Funktionen + DI)."""

from stockintel.analysis.ipo import link_ipo_investors
from stockintel.analysis.thirteenf import (
    Holding,
    issuer_matches,
    normalize_issuer,
    parse_13f_infotable,
)
from stockintel.db.database import Database
from stockintel.db.models import IpoEvent

# Beispiel mit Standard-Namespace (wie EDGAR es liefert).
SAMPLE_NS = """<?xml version="1.0" encoding="UTF-8"?>
<informationTable xmlns="http://www.sec.gov/edgar/document/thirteenf/informationtable">
  <infoTable>
    <nameOfIssuer>ACME CORP</nameOfIssuer>
    <titleOfClass>COM</titleOfClass>
    <cusip>00123X100</cusip>
    <value>1500000</value>
    <shrsOrPrnAmt>
      <sshPrnamt>42000</sshPrnamt>
      <sshPrnamtType>SH</sshPrnamtType>
    </shrsOrPrnAmt>
  </infoTable>
  <infoTable>
    <nameOfIssuer>NVIDIA CORP</nameOfIssuer>
    <titleOfClass>COM</titleOfClass>
    <cusip>67066G104</cusip>
    <value>9000000</value>
    <shrsOrPrnAmt>
      <sshPrnamt>5000</sshPrnamt>
      <sshPrnamtType>SH</sshPrnamtType>
    </shrsOrPrnAmt>
  </infoTable>
</informationTable>
"""

# Variante mit Namespace-Präfix (ebenfalls valide, kommt vor).
SAMPLE_PREFIX = """<?xml version="1.0"?>
<ns1:informationTable xmlns:ns1="http://www.sec.gov/edgar/document/thirteenf/informationtable">
  <ns1:infoTable>
    <ns1:nameOfIssuer>Beta Holdings</ns1:nameOfIssuer>
    <ns1:cusip>11122Z101</ns1:cusip>
    <ns1:value>250000</ns1:value>
    <ns1:shrsOrPrnAmt><ns1:sshPrnamt>1,000</ns1:sshPrnamt></ns1:shrsOrPrnAmt>
  </ns1:infoTable>
</ns1:informationTable>
"""


def test_parse_13f_with_namespace():
    holdings = parse_13f_infotable(SAMPLE_NS)
    assert len(holdings) == 2
    acme = holdings[0]
    assert acme.issuer == "ACME CORP"
    assert acme.cusip == "00123X100"
    assert acme.value == 1500000.0
    assert acme.shares == 42000.0


def test_parse_13f_with_prefix_and_comma_number():
    holdings = parse_13f_infotable(SAMPLE_PREFIX)
    assert len(holdings) == 1
    assert holdings[0].issuer == "Beta Holdings"
    assert holdings[0].shares == 1000.0  # "1,000" korrekt geparst


def test_parse_13f_invalid_xml():
    assert parse_13f_infotable("not xml") == []
    assert parse_13f_infotable("") == []


def test_normalize_issuer_strips_noise():
    assert normalize_issuer("ACME CORP COM") == {"acme"}
    assert normalize_issuer("Acme Inc.") == {"acme"}


def test_issuer_matches():
    assert issuer_matches("ACME CORP COM", "Acme Inc.") is True
    assert issuer_matches("NVIDIA CORP", "NVIDIA Corporation") is True
    assert issuer_matches("ACME CORP", "Globex Inc.") is False
    assert issuer_matches("", "Acme") is False


def test_link_ipo_investors_with_injected_provider(tmp_path):
    """End-to-End mit injiziertem Holdings-Provider (kein Netzwerk)."""
    db = Database(f"sqlite:///{tmp_path/'t.db'}")
    db.create_all()
    with db.session() as session:
        session.add(IpoEvent(company_name="Acme Corp.", ticker="ACME"))
        session.add(IpoEvent(company_name="Globex Inc.", ticker="GLBX"))
        session.commit()

    def provider(cik):
        return [
            Holding(issuer="ACME CORP COM", cusip="00123X100", value=1500000.0, shares=42000.0),
        ]

    managers = [{"cik": "0001067983", "name": "Berkshire Test"}]
    stats = link_ipo_investors(db, managers=managers, holdings_provider=provider)
    assert stats["investors_found"] == 1
    assert stats["investors_linked"] == 1

    # Idempotenz: zweiter Lauf legt keinen Doppel-Link an.
    stats2 = link_ipo_investors(db, managers=managers, holdings_provider=provider)
    assert stats2["investors_linked"] == 0

    with db.session() as session:
        acme = session.query(IpoEvent).filter_by(ticker="ACME").one()
        assert len(acme.investors) == 1
        assert acme.investors[0].investor_name == "Berkshire Test"
        globex = session.query(IpoEvent).filter_by(ticker="GLBX").one()
        assert len(globex.investors) == 0


def test_link_ipo_investors_no_managers(tmp_path):
    """Ohne konfigurierte Manager passiert nichts (kein Crash)."""
    db = Database(f"sqlite:///{tmp_path/'t.db'}")
    db.create_all()
    stats = link_ipo_investors(db, managers=[])
    assert stats == {"investors_found": 0, "investors_linked": 0}
