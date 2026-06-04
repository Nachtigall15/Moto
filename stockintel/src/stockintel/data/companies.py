"""Unternehmens-Katalog mit deutschen Standard-Kennungen (WKN + ISIN).

Dieser Katalog ist die *einzige* Quelle der Wahrheit fuer die Company-Suche und
fuer die Entitaeten-Aufloesung (Dedup). Jeder Eintrag traegt:

* ``ticker``    – sauberes Anzeige-/Kanon-Kuerzel (z.B. ``"SAP"``, ``"TCEHY"``)
* ``yf``        – Symbol fuer yfinance-Kursabruf (z.B. ``"SAP.DE"``)
* ``name``      – offizieller Name
* ``wkn``       – deutsche Wertpapierkennnummer (6-stellig) oder ``None``
* ``isin``      – internationale Wertpapierkennung (12-stellig) oder ``None``
* ``sector``    – Branche
* ``currency``  – Notierungs-Waehrung des ``yf``-Symbols (USD/EUR/CHF/GBP/KRW…)
* ``aliases``   – informelle Namen fuer das News-Matching ("Google", "Facebook")
* ``pre_ipo``   – ``True`` fuer noch nicht boersennotierte Firmen (News via Name)

Die Kennungen sind kuratiert und auf gaengige, in Deutschland handelbare Werte
ausgelegt — keine USD-zentrierte Mini-Liste, sondern US-Tech, DAX/MDAX,
europaeische und asiatische Standardwerte (inkl. Tencent, Alibaba, Samsung).
"""

from __future__ import annotations

# fmt: off
# Jede Zeile = ein handelbarer Standardwert. Reihenfolge ~ nach Region/Branche.
COMPANIES: list[dict] = [
    # ----------------------------------------------------------------- US Big Tech
    {"ticker": "AAPL",  "yf": "AAPL",  "name": "Apple Inc.",                 "wkn": "865985", "isin": "US0378331005", "sector": "Technology",              "currency": "USD", "aliases": ["Apple"]},
    {"ticker": "MSFT",  "yf": "MSFT",  "name": "Microsoft Corporation",      "wkn": "870747", "isin": "US5949181045", "sector": "Technology",              "currency": "USD", "aliases": ["Microsoft"]},
    {"ticker": "GOOGL", "yf": "GOOGL", "name": "Alphabet Inc. (A)",          "wkn": "A14Y6F", "isin": "US02079K3059", "sector": "Technology",              "currency": "USD", "aliases": ["Google", "Alphabet"]},
    {"ticker": "GOOG",  "yf": "GOOG",  "name": "Alphabet Inc. (C)",          "wkn": "A14Y6H", "isin": "US02079K1079", "sector": "Technology",              "currency": "USD", "aliases": ["Google", "Alphabet"]},
    {"ticker": "AMZN",  "yf": "AMZN",  "name": "Amazon.com Inc.",            "wkn": "906866", "isin": "US0231351067", "sector": "Consumer Cyclical",       "currency": "USD", "aliases": ["Amazon"]},
    {"ticker": "META",  "yf": "META",  "name": "Meta Platforms Inc.",        "wkn": "A1JWVX", "isin": "US30303M1027", "sector": "Technology",              "currency": "USD", "aliases": ["Meta", "Facebook", "Instagram"]},
    {"ticker": "NVDA",  "yf": "NVDA",  "name": "NVIDIA Corporation",         "wkn": "918422", "isin": "US67066G1040", "sector": "Semiconductors",          "currency": "USD", "aliases": ["Nvidia"]},
    {"ticker": "TSLA",  "yf": "TSLA",  "name": "Tesla Inc.",                 "wkn": "A1CX3T", "isin": "US88160R1014", "sector": "Automotive",              "currency": "USD", "aliases": ["Tesla"]},
    {"ticker": "NFLX",  "yf": "NFLX",  "name": "Netflix Inc.",               "wkn": "552484", "isin": "US64110L1061", "sector": "Communication Services",  "currency": "USD", "aliases": ["Netflix"]},
    {"ticker": "ORCL",  "yf": "ORCL",  "name": "Oracle Corporation",         "wkn": "871460", "isin": "US68389X1054", "sector": "Technology",              "currency": "USD", "aliases": ["Oracle"]},
    {"ticker": "ADBE",  "yf": "ADBE",  "name": "Adobe Inc.",                 "wkn": "871981", "isin": "US00724F1012", "sector": "Technology",              "currency": "USD", "aliases": ["Adobe"]},
    {"ticker": "CRM",   "yf": "CRM",   "name": "Salesforce Inc.",            "wkn": "A0B87V", "isin": "US79466L3024", "sector": "Technology",              "currency": "USD", "aliases": ["Salesforce"]},
    {"ticker": "IBM",   "yf": "IBM",   "name": "IBM",                        "wkn": "851399", "isin": "US4592001014", "sector": "Technology",              "currency": "USD", "aliases": ["International Business Machines"]},
    {"ticker": "CSCO",  "yf": "CSCO",  "name": "Cisco Systems Inc.",         "wkn": "878841", "isin": "US17275R1023", "sector": "Technology",              "currency": "USD", "aliases": ["Cisco"]},
    {"ticker": "PLTR",  "yf": "PLTR",  "name": "Palantir Technologies Inc.", "wkn": "A2QA4J", "isin": "US69608A1088", "sector": "Technology",              "currency": "USD", "aliases": ["Palantir"]},
    {"ticker": "UBER",  "yf": "UBER",  "name": "Uber Technologies Inc.",     "wkn": "A2PHHG", "isin": "US90353T1007", "sector": "Transportation",          "currency": "USD", "aliases": ["Uber"]},
    {"ticker": "SHOP",  "yf": "SHOP",  "name": "Shopify Inc.",               "wkn": "A14TJP", "isin": "CA82509L1076", "sector": "Technology",              "currency": "USD", "aliases": ["Shopify"]},
    {"ticker": "SPOT",  "yf": "SPOT",  "name": "Spotify Technology S.A.",    "wkn": "A2JEGN", "isin": "LU1778762911", "sector": "Communication Services",  "currency": "USD", "aliases": ["Spotify"]},
    {"ticker": "PYPL",  "yf": "PYPL",  "name": "PayPal Holdings Inc.",       "wkn": "A14R7U", "isin": "US70450Y1038", "sector": "Financial",               "currency": "USD", "aliases": ["PayPal"]},
    {"ticker": "COIN",  "yf": "COIN",  "name": "Coinbase Global Inc.",       "wkn": "A2QP7J", "isin": "US19260Q1076", "sector": "Financial",               "currency": "USD", "aliases": ["Coinbase"]},

    # ------------------------------------------------------------- US Semiconductors
    {"ticker": "AMD",   "yf": "AMD",   "name": "Advanced Micro Devices",     "wkn": "863186", "isin": "US0079031078", "sector": "Semiconductors",          "currency": "USD", "aliases": ["AMD"]},
    {"ticker": "INTC",  "yf": "INTC",  "name": "Intel Corporation",          "wkn": "855681", "isin": "US4581401001", "sector": "Semiconductors",          "currency": "USD", "aliases": ["Intel"]},
    {"ticker": "QCOM",  "yf": "QCOM",  "name": "Qualcomm Inc.",              "wkn": "883121", "isin": "US7475251036", "sector": "Semiconductors",          "currency": "USD", "aliases": ["Qualcomm"]},
    {"ticker": "AVGO",  "yf": "AVGO",  "name": "Broadcom Inc.",              "wkn": "A2JG9Z", "isin": "US11135F1012", "sector": "Semiconductors",          "currency": "USD", "aliases": ["Broadcom"]},
    {"ticker": "MU",    "yf": "MU",    "name": "Micron Technology Inc.",     "wkn": "869020", "isin": "US5951121038", "sector": "Semiconductors",          "currency": "USD", "aliases": ["Micron"]},
    {"ticker": "TXN",   "yf": "TXN",   "name": "Texas Instruments Inc.",     "wkn": "852654", "isin": "US8825081040", "sector": "Semiconductors",          "currency": "USD", "aliases": ["Texas Instruments"]},
    {"ticker": "MRVL",  "yf": "MRVL",  "name": "Marvell Technology Inc.",    "wkn": "A2QGD4", "isin": "US5738741041", "sector": "Semiconductors",          "currency": "USD", "aliases": ["Marvell"]},
    {"ticker": "ARM",   "yf": "ARM",   "name": "Arm Holdings plc",           "wkn": "A40JBT", "isin": "US0420682058", "sector": "Semiconductors",          "currency": "USD", "aliases": ["Arm"]},
    {"ticker": "SMCI",  "yf": "SMCI",  "name": "Super Micro Computer Inc.",  "wkn": "A1C0SX", "isin": "US86800U3023", "sector": "Technology",              "currency": "USD", "aliases": ["Supermicro", "Super Micro"]},

    # -------------------------------------------------------------- US Other / Blue Chip
    {"ticker": "BRK.B", "yf": "BRK-B", "name": "Berkshire Hathaway (B)",     "wkn": "A0YJQ2", "isin": "US0846707026", "sector": "Financial",               "currency": "USD", "aliases": ["Berkshire", "Berkshire Hathaway"]},
    {"ticker": "JPM",   "yf": "JPM",   "name": "JPMorgan Chase & Co.",       "wkn": "850628", "isin": "US46625H1005", "sector": "Financial",               "currency": "USD", "aliases": ["JPMorgan", "JP Morgan"]},
    {"ticker": "V",     "yf": "V",     "name": "Visa Inc.",                  "wkn": "A0NC7B", "isin": "US92826C8394", "sector": "Financial",               "currency": "USD", "aliases": ["Visa"]},
    {"ticker": "MA",    "yf": "MA",    "name": "Mastercard Inc.",            "wkn": "A0F602", "isin": "US57636Q1040", "sector": "Financial",               "currency": "USD", "aliases": ["Mastercard"]},
    {"ticker": "WMT",   "yf": "WMT",   "name": "Walmart Inc.",               "wkn": "860853", "isin": "US9311421039", "sector": "Consumer Defensive",      "currency": "USD", "aliases": ["Walmart"]},
    {"ticker": "JNJ",   "yf": "JNJ",   "name": "Johnson & Johnson",          "wkn": "853260", "isin": "US4781601046", "sector": "Healthcare",              "currency": "USD", "aliases": ["Johnson & Johnson"]},
    {"ticker": "PG",    "yf": "PG",    "name": "Procter & Gamble Co.",       "wkn": "852062", "isin": "US7427181091", "sector": "Consumer Defensive",      "currency": "USD", "aliases": ["Procter & Gamble"]},
    {"ticker": "KO",    "yf": "KO",    "name": "The Coca-Cola Company",      "wkn": "850663", "isin": "US1912161007", "sector": "Consumer Defensive",      "currency": "USD", "aliases": ["Coca-Cola", "Coca Cola"]},
    {"ticker": "PEP",   "yf": "PEP",   "name": "PepsiCo Inc.",               "wkn": "851995", "isin": "US7134481081", "sector": "Consumer Defensive",      "currency": "USD", "aliases": ["Pepsi", "PepsiCo"]},
    {"ticker": "DIS",   "yf": "DIS",   "name": "The Walt Disney Company",    "wkn": "855686", "isin": "US2546871060", "sector": "Communication Services",  "currency": "USD", "aliases": ["Disney"]},
    {"ticker": "MCD",   "yf": "MCD",   "name": "McDonald's Corporation",     "wkn": "856958", "isin": "US5801351017", "sector": "Consumer Cyclical",       "currency": "USD", "aliases": ["McDonald's", "McDonalds"]},
    {"ticker": "NKE",   "yf": "NKE",   "name": "Nike Inc.",                  "wkn": "866993", "isin": "US6541061031", "sector": "Consumer Cyclical",       "currency": "USD", "aliases": ["Nike"]},
    {"ticker": "BA",    "yf": "BA",    "name": "The Boeing Company",         "wkn": "850471", "isin": "US0970231058", "sector": "Industrials",             "currency": "USD", "aliases": ["Boeing"]},
    {"ticker": "XOM",   "yf": "XOM",   "name": "Exxon Mobil Corporation",    "wkn": "852549", "isin": "US30231G1022", "sector": "Energy",                  "currency": "USD", "aliases": ["Exxon", "ExxonMobil"]},
    {"ticker": "PFE",   "yf": "PFE",   "name": "Pfizer Inc.",                "wkn": "852009", "isin": "US7170811035", "sector": "Healthcare",              "currency": "USD", "aliases": ["Pfizer"]},

    # ---------------------------------------------------------------------- DAX 40
    {"ticker": "SAP",   "yf": "SAP.DE",  "name": "SAP SE",                   "wkn": "716460", "isin": "DE0007164600", "sector": "Technology",              "currency": "EUR", "aliases": ["SAP"]},
    {"ticker": "SIE",   "yf": "SIE.DE",  "name": "Siemens AG",              "wkn": "723610", "isin": "DE0007236101", "sector": "Industrials",             "currency": "EUR", "aliases": ["Siemens"]},
    {"ticker": "ALV",   "yf": "ALV.DE",  "name": "Allianz SE",             "wkn": "840400", "isin": "DE0008404005", "sector": "Financial",               "currency": "EUR", "aliases": ["Allianz"]},
    {"ticker": "DTE",   "yf": "DTE.DE",  "name": "Deutsche Telekom AG",    "wkn": "555750", "isin": "DE0005557508", "sector": "Communication Services",  "currency": "EUR", "aliases": ["Deutsche Telekom", "Telekom"]},
    {"ticker": "MBG",   "yf": "MBG.DE",  "name": "Mercedes-Benz Group AG", "wkn": "710000", "isin": "DE0007100000", "sector": "Automotive",              "currency": "EUR", "aliases": ["Mercedes", "Mercedes-Benz", "Daimler"]},
    {"ticker": "BMW",   "yf": "BMW.DE",  "name": "Bayerische Motoren Werke AG", "wkn": "519000", "isin": "DE0005190003", "sector": "Automotive",         "currency": "EUR", "aliases": ["BMW"]},
    {"ticker": "VOW3",  "yf": "VOW3.DE", "name": "Volkswagen AG (Vz)",     "wkn": "766403", "isin": "DE0007664039", "sector": "Automotive",              "currency": "EUR", "aliases": ["Volkswagen", "VW"]},
    {"ticker": "BAS",   "yf": "BAS.DE",  "name": "BASF SE",               "wkn": "BASF11", "isin": "DE000BASF111", "sector": "Materials",               "currency": "EUR", "aliases": ["BASF"]},
    {"ticker": "BAYN",  "yf": "BAYN.DE", "name": "Bayer AG",              "wkn": "BAY001", "isin": "DE000BAY0017", "sector": "Healthcare",              "currency": "EUR", "aliases": ["Bayer"]},
    {"ticker": "DBK",   "yf": "DBK.DE",  "name": "Deutsche Bank AG",      "wkn": "514000", "isin": "DE0005140008", "sector": "Financial",               "currency": "EUR", "aliases": ["Deutsche Bank"]},
    {"ticker": "ADS",   "yf": "ADS.DE",  "name": "adidas AG",             "wkn": "A1EWWW", "isin": "DE000A1EWWW0", "sector": "Consumer Cyclical",       "currency": "EUR", "aliases": ["Adidas"]},
    {"ticker": "IFX",   "yf": "IFX.DE",  "name": "Infineon Technologies AG", "wkn": "623100", "isin": "DE0006231004", "sector": "Semiconductors",       "currency": "EUR", "aliases": ["Infineon"]},
    {"ticker": "MUV2",  "yf": "MUV2.DE", "name": "Münchener Rück AG",     "wkn": "843002", "isin": "DE0008430026", "sector": "Financial",               "currency": "EUR", "aliases": ["Munich Re", "Münchener Rück", "Munich RE"]},
    {"ticker": "DHL",   "yf": "DHL.DE",  "name": "DHL Group",             "wkn": "555200", "isin": "DE0005552004", "sector": "Industrials",             "currency": "EUR", "aliases": ["DHL", "Deutsche Post"]},
    {"ticker": "RWE",   "yf": "RWE.DE",  "name": "RWE AG",                "wkn": "703712", "isin": "DE0007037129", "sector": "Utilities",               "currency": "EUR", "aliases": ["RWE"]},
    {"ticker": "EOAN",  "yf": "EOAN.DE", "name": "E.ON SE",               "wkn": "ENAG99", "isin": "DE000ENAG999", "sector": "Utilities",               "currency": "EUR", "aliases": ["E.ON", "EON"]},
    {"ticker": "DB1",   "yf": "DB1.DE",  "name": "Deutsche Börse AG",     "wkn": "581005", "isin": "DE0005810055", "sector": "Financial",               "currency": "EUR", "aliases": ["Deutsche Börse"]},
    {"ticker": "MRK",   "yf": "MRK.DE",  "name": "Merck KGaA",            "wkn": "659990", "isin": "DE0006599905", "sector": "Healthcare",              "currency": "EUR", "aliases": ["Merck KGaA"]},
    {"ticker": "RHM",   "yf": "RHM.DE",  "name": "Rheinmetall AG",        "wkn": "703000", "isin": "DE0007030009", "sector": "Industrials",             "currency": "EUR", "aliases": ["Rheinmetall"]},
    {"ticker": "P911",  "yf": "P911.DE", "name": "Porsche AG",            "wkn": "PAG911", "isin": "DE000PAG9113", "sector": "Automotive",              "currency": "EUR", "aliases": ["Porsche"]},

    # ---------------------------------------------------------- Europa (ohne DAX)
    {"ticker": "ASML",  "yf": "ASML.AS", "name": "ASML Holding N.V.",     "wkn": "A1J4U4", "isin": "NL0010273215", "sector": "Semiconductors",          "currency": "EUR", "aliases": ["ASML"]},
    {"ticker": "AIR",   "yf": "AIR.DE",  "name": "Airbus SE",            "wkn": "938914", "isin": "NL0000235190", "sector": "Industrials",             "currency": "EUR", "aliases": ["Airbus"]},
    {"ticker": "MC",    "yf": "MC.PA",   "name": "LVMH",                 "wkn": "853292", "isin": "FR0000121014", "sector": "Consumer Cyclical",       "currency": "EUR", "aliases": ["LVMH", "Louis Vuitton"]},
    {"ticker": "OR",    "yf": "OR.PA",   "name": "L'Oréal S.A.",         "wkn": "853888", "isin": "FR0000120321", "sector": "Consumer Defensive",      "currency": "EUR", "aliases": ["L'Oréal", "LOreal", "Loreal"]},
    {"ticker": "NESN",  "yf": "NESN.SW", "name": "Nestlé S.A.",          "wkn": "A0Q4DC", "isin": "CH0038863350", "sector": "Consumer Defensive",      "currency": "CHF", "aliases": ["Nestlé", "Nestle"]},
    {"ticker": "NOVN",  "yf": "NOVN.SW", "name": "Novartis AG",          "wkn": "904278", "isin": "CH0012005267", "sector": "Healthcare",              "currency": "CHF", "aliases": ["Novartis"]},
    {"ticker": "ROG",   "yf": "ROG.SW",  "name": "Roche Holding AG",     "wkn": "855167", "isin": "CH0012032048", "sector": "Healthcare",              "currency": "CHF", "aliases": ["Roche"]},
    {"ticker": "AZN",   "yf": "AZN",     "name": "AstraZeneca plc",      "wkn": "886455", "isin": "US0463531089", "sector": "Healthcare",              "currency": "USD", "aliases": ["AstraZeneca"]},
    {"ticker": "TTE",   "yf": "TTE",     "name": "TotalEnergies SE",     "wkn": "A3DTBB", "isin": "US89151E1091", "sector": "Energy",                  "currency": "USD", "aliases": ["TotalEnergies", "Total"]},
    {"ticker": "SHEL",  "yf": "SHEL",    "name": "Shell plc",            "wkn": "A3C99G", "isin": "US7802593050", "sector": "Energy",                  "currency": "USD", "aliases": ["Shell"]},
    {"ticker": "NOVOB", "yf": "NVO",     "name": "Novo Nordisk A/S",     "wkn": "A3EU6F", "isin": "US6701002056", "sector": "Healthcare",              "currency": "USD", "aliases": ["Novo Nordisk", "Novo"]},

    # ----------------------------------------------------------------------- Asien
    {"ticker": "TSM",   "yf": "TSM",     "name": "Taiwan Semiconductor (TSMC)", "wkn": "909800", "isin": "US8740391003", "sector": "Semiconductors",     "currency": "USD", "aliases": ["TSMC", "Taiwan Semiconductor"]},
    {"ticker": "TCEHY", "yf": "TCEHY",   "name": "Tencent Holdings Ltd.", "wkn": "A1138D", "isin": "US88032Q1094", "sector": "Communication Services",  "currency": "USD", "aliases": ["Tencent"]},
    {"ticker": "BABA",  "yf": "BABA",    "name": "Alibaba Group Holding", "wkn": "A117ME", "isin": "US01609W1027", "sector": "Consumer Cyclical",       "currency": "USD", "aliases": ["Alibaba"]},
    {"ticker": "BIDU",  "yf": "BIDU",    "name": "Baidu Inc.",           "wkn": "A0F5DE", "isin": "US0567521085", "sector": "Communication Services",  "currency": "USD", "aliases": ["Baidu"]},
    {"ticker": "PDD",   "yf": "PDD",     "name": "PDD Holdings Inc.",    "wkn": "A2JRK6", "isin": "US7223041028", "sector": "Consumer Cyclical",       "currency": "USD", "aliases": ["PDD", "Pinduoduo", "Temu"]},
    {"ticker": "NIO",   "yf": "NIO",     "name": "NIO Inc.",             "wkn": "A2N4PB", "isin": "US62914V1061", "sector": "Automotive",              "currency": "USD", "aliases": ["Nio"]},
    {"ticker": "SONY",  "yf": "SONY",    "name": "Sony Group Corporation", "wkn": "A2PR5X", "isin": "US8356993076", "sector": "Technology",            "currency": "USD", "aliases": ["Sony"]},
    {"ticker": "TM",    "yf": "TM",      "name": "Toyota Motor Corp.",   "wkn": "853510", "isin": "US8923313071", "sector": "Automotive",              "currency": "USD", "aliases": ["Toyota"]},
    {"ticker": "005930","yf": "005930.KS","name": "Samsung Electronics Co.", "wkn": "896360", "isin": "KR7005930003", "sector": "Technology",          "currency": "KRW", "aliases": ["Samsung"]},

    # ------------------------------------------------------ Wachstum / Mid Cap (US)
    {"ticker": "SNOW",  "yf": "SNOW",    "name": "Snowflake Inc.",       "wkn": "A2QB38", "isin": "US8334451098", "sector": "Technology",              "currency": "USD", "aliases": ["Snowflake"]},
    {"ticker": "CRWD",  "yf": "CRWD",    "name": "CrowdStrike Holdings", "wkn": "A2PK2R", "isin": "US22788C1053", "sector": "Technology",              "currency": "USD", "aliases": ["CrowdStrike"]},
    {"ticker": "MSTR",  "yf": "MSTR",    "name": "MicroStrategy Inc.",   "wkn": "A0WMPJ", "isin": "US5949724083", "sector": "Technology",              "currency": "USD", "aliases": ["MicroStrategy", "Strategy"]},
    {"ticker": "RIVN",  "yf": "RIVN",    "name": "Rivian Automotive",    "wkn": "A3C47B", "isin": "US76954A1034", "sector": "Automotive",              "currency": "USD", "aliases": ["Rivian"]},
    {"ticker": "LCID",  "yf": "LCID",    "name": "Lucid Group Inc.",     "wkn": "A3CVXG", "isin": "US5494981039", "sector": "Automotive",              "currency": "USD", "aliases": ["Lucid"]},
    {"ticker": "ABNB",  "yf": "ABNB",    "name": "Airbnb Inc.",          "wkn": "A2QG35", "isin": "US0090661010", "sector": "Consumer Cyclical",       "currency": "USD", "aliases": ["Airbnb"]},
    {"ticker": "DASH",  "yf": "DASH",    "name": "DoorDash Inc.",        "wkn": "A2QTU5", "isin": "US25809K1051", "sector": "Consumer Cyclical",       "currency": "USD", "aliases": ["DoorDash"]},

    # ---------------------------------------- Pre-IPO / nicht boersennotiert (News via Name)
    {"ticker": "ANTHROPIC",  "yf": None, "name": "Anthropic",   "wkn": None, "isin": None, "sector": "Artificial Intelligence", "currency": "USD", "aliases": ["Claude"], "pre_ipo": True},
    {"ticker": "OPENAI",     "yf": None, "name": "OpenAI",      "wkn": None, "isin": None, "sector": "Artificial Intelligence", "currency": "USD", "aliases": ["ChatGPT"], "pre_ipo": True},
    {"ticker": "SPACEX",     "yf": None, "name": "SpaceX",      "wkn": None, "isin": None, "sector": "Aerospace",               "currency": "USD", "aliases": ["Starlink"], "pre_ipo": True},
    {"ticker": "STRIPE",     "yf": None, "name": "Stripe",      "wkn": None, "isin": None, "sector": "FinTech",                 "currency": "USD", "aliases": [], "pre_ipo": True},
    {"ticker": "DATABRICKS", "yf": None, "name": "Databricks",  "wkn": None, "isin": None, "sector": "Technology",              "currency": "USD", "aliases": [], "pre_ipo": True},
    {"ticker": "XAI",        "yf": None, "name": "xAI",         "wkn": None, "isin": None, "sector": "Artificial Intelligence", "currency": "USD", "aliases": ["Grok"], "pre_ipo": True},
    {"ticker": "BYTEDANCE",  "yf": None, "name": "ByteDance",   "wkn": None, "isin": None, "sector": "Technology",              "currency": "USD", "aliases": ["TikTok"], "pre_ipo": True},
    {"ticker": "EPICGAMES",  "yf": None, "name": "Epic Games",  "wkn": None, "isin": None, "sector": "Gaming",                  "currency": "USD", "aliases": ["Fortnite"], "pre_ipo": True},
]
# fmt: on


def _normalize(entry: dict) -> dict:
    """Fuellt optionale Felder mit Defaults auf (einheitliche Struktur)."""
    return {
        "ticker": entry["ticker"],
        "yf": entry.get("yf"),
        "name": entry["name"],
        "wkn": entry.get("wkn"),
        "isin": entry.get("isin"),
        "sector": entry.get("sector"),
        "currency": entry.get("currency", "USD"),
        "aliases": list(entry.get("aliases", [])),
        "pre_ipo": entry.get("pre_ipo", False),
    }


# Kanonische, normalisierte Eintraege (ticker -> entry).
CATALOG: dict[str, dict] = {e["ticker"]: _normalize(e) for e in COMPANIES}

# Lookup-Indizes fuer schnelle/robuste Aufloesung.
_BY_WKN: dict[str, str] = {}
_BY_ISIN: dict[str, str] = {}
_BY_NAME_OR_ALIAS: dict[str, str] = {}

for _ticker, _e in CATALOG.items():
    if _e["wkn"]:
        _BY_WKN[_e["wkn"].upper()] = _ticker
    if _e["isin"]:
        _BY_ISIN[_e["isin"].upper()] = _ticker
    _BY_NAME_OR_ALIAS[_e["name"].upper()] = _ticker
    for _alias in _e["aliases"]:
        _BY_NAME_OR_ALIAS.setdefault(_alias.upper(), _ticker)


def get(ticker: str) -> dict | None:
    """Katalog-Eintrag fuer einen kanonischen Ticker (oder ``None``)."""
    return CATALOG.get(ticker.upper().strip())


def resolve_ticker(value: str) -> str | None:
    """Loest eine freie Eingabe auf einen kanonischen Ticker auf.

    Reihenfolge: exakter Ticker -> WKN -> ISIN -> Name/Alias. Liefert ``None``,
    wenn nichts Eindeutiges im Katalog gefunden wird (dann kein Anlegen!).
    """
    if not value:
        return None
    key = value.upper().strip()
    if key in CATALOG:
        return key
    if key in _BY_WKN:
        return _BY_WKN[key]
    if key in _BY_ISIN:
        return _BY_ISIN[key]
    if key in _BY_NAME_OR_ALIAS:
        return _BY_NAME_OR_ALIAS[key]
    return None


def search(query: str, limit: int = 25) -> list[dict]:
    """Sucht im Katalog ueber Ticker, Name, Alias, WKN und ISIN.

    Liefert normalisierte Eintraege, exakte Treffer zuerst, dann Prefix-/
    Teilstring-Treffer.
    """
    q = (query or "").upper().strip()
    if not q:
        return []

    exact: list[dict] = []
    prefix: list[dict] = []
    contains: list[dict] = []

    for ticker, e in CATALOG.items():
        wkn = (e["wkn"] or "").upper()
        isin = (e["isin"] or "").upper()
        name_u = e["name"].upper()
        aliases_u = [a.upper() for a in e["aliases"]]

        if q == ticker or q == wkn or q == isin or q == name_u or q in aliases_u:
            exact.append(e)
        elif ticker.startswith(q) or name_u.startswith(q) or any(a.startswith(q) for a in aliases_u):
            prefix.append(e)
        elif (
            q in name_u
            or q in ticker
            or (wkn and q in wkn)
            or (isin and q in isin)
            or any(q in a for a in aliases_u)
        ):
            contains.append(e)

    ordered = exact + prefix + contains
    return ordered[:limit]
