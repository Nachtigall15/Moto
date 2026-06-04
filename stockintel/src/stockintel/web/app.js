// StockIntel Dashboard — Frontend-Logik (Vanilla JS, kein Build-Step).

const API = ""; // Same-Origin

// --- Helpers -------------------------------------------------------------

async function fetchJSON(path, options = {}) {
    const res = await fetch(API + path, options);
    if (!res.ok) {
        throw new Error(`HTTP ${res.status}: ${path}`);
    }
    return res.json();
}

function escapeHtml(str) {
    if (str == null) return "";
    return String(str)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;");
}

function badge(value, type) {
    const cls = `badge badge-${type}`;
    return `<span class="${cls}">${escapeHtml(value)}</span>`;
}

function relevanceBar(value) {
    const pct = Math.max(0, Math.min(100, value || 0));
    return `<span class="relevance-bar"><span class="relevance-fill" style="width:${pct}%"></span></span>${pct}`;
}

// --- Loaders -------------------------------------------------------------

async function loadStats() {
    try {
        const stats = await fetchJSON("/stats");
        document.getElementById("stat-items").textContent = stats.items ?? "–";
        document.getElementById("stat-signals").textContent = stats.signals ?? "–";
        document.getElementById("stat-companies").textContent = stats.companies ?? "–";
        document.getElementById("stat-recommendations").textContent = stats.recommendations ?? "–";
        if (stats.timestamp) {
            const d = new Date(stats.timestamp);
            document.getElementById("last-updated").textContent =
                "Stand: " + d.toLocaleString("de-DE");
        }
    } catch (e) {
        console.error("Stats laden fehlgeschlagen:", e);
    }
}

async function loadRecommendations() {
    const body = document.getElementById("recommendations-body");
    try {
        const recs = await fetchJSON("/recommendations?limit=50");
        if (!recs.length) {
            body.innerHTML = `<tr><td colspan="4" class="loading">Keine Recommendations. "Neu berechnen" klicken.</td></tr>`;
            return;
        }
        body.innerHTML = recs.map(r => `
            <tr>
                <td class="ticker">${escapeHtml(r.ticker)}</td>
                <td>${badge(r.action, r.action.toLowerCase())}</td>
                <td>${(r.confidence * 100).toFixed(0)}%</td>
                <td>${escapeHtml(r.rationale || "")}</td>
            </tr>
        `).join("");
    } catch (e) {
        body.innerHTML = `<tr><td colspan="4" class="loading">Fehler: ${escapeHtml(e.message)}</td></tr>`;
    }
}

async function loadSignals() {
    const body = document.getElementById("signals-body");
    const ticker = document.getElementById("ticker-filter").value.trim();
    const analyzedOnly = document.getElementById("analyzed-only").checked;

    let path = "/signals?limit=50";
    if (ticker) path += `&ticker=${encodeURIComponent(ticker)}`;
    if (analyzedOnly) path += `&analyzed_only=true`;

    try {
        const signals = await fetchJSON(path);
        if (!signals.length) {
            body.innerHTML = `<tr><td colspan="5" class="loading">Keine Signals.</td></tr>`;
            return;
        }
        body.innerHTML = signals.map(s => `
            <tr>
                <td class="ticker">${escapeHtml(s.ticker)}</td>
                <td>${badge(s.direction, s.direction)}</td>
                <td>${relevanceBar(s.relevance)}</td>
                <td>${(s.confidence * 100).toFixed(0)}%</td>
                <td>${escapeHtml(s.title || "")}</td>
            </tr>
        `).join("");
    } catch (e) {
        body.innerHTML = `<tr><td colspan="5" class="loading">Fehler: ${escapeHtml(e.message)}</td></tr>`;
    }
}

async function loadCompanies() {
    const body = document.getElementById("companies-body");
    try {
        const companies = await fetchJSON("/companies?limit=100");
        if (!companies.length) {
            body.innerHTML = `<tr><td colspan="4" class="loading">Keine Companies.</td></tr>`;
            return;
        }
        body.innerHTML = companies.map(c => `
            <tr>
                <td class="ticker">${escapeHtml(c.ticker)}</td>
                <td>${escapeHtml(c.name)}</td>
                <td>${escapeHtml(c.sector || "–")}</td>
                <td>${c.signal_count}</td>
            </tr>
        `).join("");
    } catch (e) {
        body.innerHTML = `<tr><td colspan="4" class="loading">Fehler: ${escapeHtml(e.message)}</td></tr>`;
    }
}

async function loadAll() {
    await Promise.all([
        loadStats(),
        loadRecommendations(),
        loadSignals(),
        loadCompanies(),
    ]);
}

// --- Actions -------------------------------------------------------------

async function triggerScore() {
    const btn = document.getElementById("score-btn");
    const orig = btn.textContent;
    btn.textContent = "Berechne…";
    btn.disabled = true;
    try {
        await fetchJSON("/score", { method: "POST" });
        await loadRecommendations();
        await loadStats();
    } catch (e) {
        alert("Scoring fehlgeschlagen: " + e.message);
    } finally {
        btn.textContent = orig;
        btn.disabled = false;
    }
}

// --- Event Listeners -----------------------------------------------------

document.addEventListener("DOMContentLoaded", () => {
    loadAll();

    document.getElementById("refresh-btn").addEventListener("click", loadAll);
    document.getElementById("score-btn").addEventListener("click", triggerScore);

    // Signal-Filter mit Debounce
    let debounce;
    document.getElementById("ticker-filter").addEventListener("input", () => {
        clearTimeout(debounce);
        debounce = setTimeout(loadSignals, 400);
    });
    document.getElementById("analyzed-only").addEventListener("change", loadSignals);
});
