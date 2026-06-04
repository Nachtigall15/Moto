// StockIntel Dashboard — Frontend-Logik (Vanilla JS, kein Build-Step).

const API = ""; // Same-Origin

// Chart instances (global for updates)
let _chartRecommendations = null;
let _chartCompanies = null;
let _chartRelevance = null;
let _chartReactionProfiles = null;
let _chartHickupRate = null;

// Auto-refresh state
let autoRefreshInterval = null;
let autoRefreshEnabled = false;
const AUTO_REFRESH_INTERVAL = 30000; // 30 Sekunden

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

// --- Charts ---------------------------------------------------------------

async function loadCharts() {
    try {
        const recs = await fetchJSON("/recommendations?limit=50");
        const companies = await fetchJSON("/companies?limit=100");
        const signals = await fetchJSON("/signals?limit=1000");
        const profiles = await fetchJSON("/reaction-profiles").catch(() => []);

        // Recommendations Distribution (Pie)
        const recCounts = {};
        recs.forEach(r => {
            const action = r.action.toLowerCase();
            recCounts[action] = (recCounts[action] || 0) + 1;
        });
        updateChart("_chartRecommendations", "recommendations-canvas", {
            type: "doughnut",
            labels: Object.keys(recCounts),
            data: Object.values(recCounts),
            colors: ["#3fb950", "#d29922", "#f85149"],
        });

        // Signals per Company (Bar)
        updateChart("_chartCompanies", "companies-canvas", {
            type: "bar",
            labels: companies.map(c => c.ticker),
            data: companies.map(c => c.signal_count),
            color: "#58a6ff",
        });

        // Relevance Distribution (Histogram)
        const relevanceBuckets = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        signals.forEach(s => {
            const bucket = Math.min(9, Math.floor(s.relevance / 10));
            relevanceBuckets[bucket]++;
        });
        updateChart("_chartRelevance", "relevance-canvas", {
            type: "bar",
            labels: relevanceBuckets.map((_, i) => `${i * 10}-${(i + 1) * 10}`),
            data: relevanceBuckets,
            color: "#58a6ff",
        });

        // Reaction Profiles: Peak vs Final Returns (if data exists)
        if (profiles.length > 0) {
            updateChart("_chartReactionProfiles", "reaction-profiles-canvas", {
                type: "bar",
                labels: profiles.map(p => p.event_type.substring(0, 15)),
                datasets: [
                    {
                        label: "Avg Peak Return",
                        data: profiles.map(p => (p.avg_peak_return * 100).toFixed(2)),
                        backgroundColor: "#58a6ff",
                    },
                    {
                        label: "Avg Final Return",
                        data: profiles.map(p => (p.avg_final_return * 100).toFixed(2)),
                        backgroundColor: "#3fb950",
                    },
                ],
            });

            // Hickup-Quote Tracking
            updateChart("_chartHickupRate", "hickup-rate-canvas", {
                type: "bar",
                labels: profiles.map(p => p.event_type.substring(0, 15)),
                data: profiles.map(p => (p.hickup_rate * 100).toFixed(1)),
                color: "#f85149",
                label: "Strohfeuer-Quote (%)",
            });
        }
    } catch (e) {
        console.error("Charts loading failed:", e);
    }
}

function updateChart(instanceName, canvasId, config) {
    const ctx = document.getElementById(canvasId);
    if (!ctx) return;

    const globalInstance = window[instanceName];
    if (globalInstance) {
        globalInstance.destroy();
    }

    // Handle multiple datasets or single dataset
    let datasets;
    if (config.datasets) {
        // Multi-dataset case
        datasets = config.datasets.map((ds, i) => ({
            label: ds.label,
            data: ds.data,
            backgroundColor: ds.backgroundColor,
            borderColor: "#58a6ff",
            borderWidth: 1,
        }));
    } else {
        // Single dataset case
        datasets = [
            config.type === "doughnut"
                ? {
                    data: config.data,
                    backgroundColor: config.colors,
                    borderColor: "#161b22",
                    borderWidth: 2,
                  }
                : {
                    label: config.label || "Count",
                    data: config.data,
                    backgroundColor: config.color,
                    borderColor: "#58a6ff",
                    borderWidth: 1,
                  },
        ];
    }

    const chartConfig = {
        type: config.type,
        data: {
            labels: config.labels,
            datasets: datasets,
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                legend: {
                    labels: { color: "#e6edf3", font: { size: 12 } },
                },
            },
            scales: config.type !== "doughnut" ? {
                x: { ticks: { color: "#8b949e" }, grid: { color: "#30363d" } },
                y: { ticks: { color: "#8b949e" }, grid: { color: "#30363d" } },
            } : {},
        },
    };

    window[instanceName] = new Chart(ctx, chartConfig);
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
        body.innerHTML = signals.map((s, i) => `
            <tr data-signal-index="${i}" data-signal='${JSON.stringify(s)}'>
                <td class="ticker">${escapeHtml(s.ticker)}</td>
                <td>${badge(s.direction, s.direction)}</td>
                <td>${relevanceBar(s.relevance)}</td>
                <td>${(s.confidence * 100).toFixed(0)}%</td>
                <td>${escapeHtml(s.title || "")}</td>
            </tr>
        `).join("");
        attachSignalListeners();
    } catch (e) {
        body.innerHTML = `<tr><td colspan="5" class="loading">Fehler: ${escapeHtml(e.message)}</td></tr>`;
    }
}

function attachSignalListeners() {
    document.querySelectorAll("#signals-body tr[data-signal]").forEach(row => {
        row.addEventListener("click", () => {
            const signal = JSON.parse(row.dataset.signal);
            const html = `
                ${modalField("Ticker", signal.ticker)}
                ${modalField("Richtung", signal.direction)}
                ${modalField("Relevanz", signal.relevance + "%")}
                ${modalField("Konfidenz", (signal.confidence * 100).toFixed(1) + "%")}
                ${modalField("Titel", signal.title)}
            `;
            showModal(`Signal: ${signal.ticker}`, html);
        });
    });
}

async function loadCompanies() {
    const body = document.getElementById("companies-body");
    try {
        const companies = await fetchJSON("/companies?limit=100");
        if (!companies.length) {
            body.innerHTML = `<tr><td colspan="4" class="loading">Keine Companies.</td></tr>`;
            return;
        }
        body.innerHTML = companies.map((c, i) => `
            <tr data-company-index="${i}" data-company='${JSON.stringify(c)}'>
                <td class="ticker">${escapeHtml(c.ticker)}</td>
                <td>${escapeHtml(c.name)}</td>
                <td>${escapeHtml(c.sector || "–")}</td>
                <td>${c.signal_count}</td>
            </tr>
        `).join("");
        attachCompanyListeners();
    } catch (e) {
        body.innerHTML = `<tr><td colspan="4" class="loading">Fehler: ${escapeHtml(e.message)}</td></tr>`;
    }
}

function attachCompanyListeners() {
    document.querySelectorAll("#companies-body tr[data-company]").forEach(row => {
        row.addEventListener("click", () => {
            const company = JSON.parse(row.dataset.company);
            const html = `
                ${modalField("Ticker", company.ticker)}
                ${modalField("Name", company.name)}
                ${modalField("Sektor", company.sector)}
                ${modalField("Signal Count", company.signal_count)}
            `;
            showModal(`Company: ${company.ticker}`, html);
        });
    });
}

async function loadEvents() {
    const body = document.getElementById("events-body");
    const ticker = document.getElementById("event-ticker-filter").value.trim();

    let path = "/events?limit=50";
    if (ticker) path += `&ticker=${encodeURIComponent(ticker)}`;

    try {
        const events = await fetchJSON(path);
        if (!events.length) {
            body.innerHTML = `<tr><td colspan="7" class="loading">Keine Events.</td></tr>`;
            return;
        }
        body.innerHTML = events.map((e, i) => `
            <tr data-event-index="${i}" data-event='${JSON.stringify(e)}'>
                <td class="ticker">${escapeHtml(e.ticker)}</td>
                <td>${escapeHtml(e.event_type)}</td>
                <td>${escapeHtml(e.created_at.substring(0, 10))}</td>
                <td>${e.peak_return !== null ? (e.peak_return * 100).toFixed(2) + '%' : '–'}</td>
                <td>${e.final_return !== null ? (e.final_return * 100).toFixed(2) + '%' : '–'}</td>
                <td>${e.abnormal_return !== null ? (e.abnormal_return * 100).toFixed(2) + '%' : '–'}</td>
                <td>${e.is_hickup ? '✓ Hickup' : '–'}</td>
            </tr>
        `).join("");
        attachEventListeners();
    } catch (e) {
        body.innerHTML = `<tr><td colspan="7" class="loading">Fehler: ${escapeHtml(e.message)}</td></tr>`;
    }
}

function attachEventListeners() {
    document.querySelectorAll("#events-body tr[data-event]").forEach(row => {
        row.addEventListener("click", async () => {
            const event = JSON.parse(row.dataset.event);
            showModal(`Event: ${event.ticker} (${event.event_type})`,
                `<div class="loading">Lade Event-Details…</div>`);

            try {
                // TODO: Load event detail with snapshots for price chart
                // For now, show basic info
                const abnormalClass = event.abnormal_return > 0 ? "green" : "red";
                const html = `
                    ${modalField("Ticker", event.ticker)}
                    ${modalField("Event-Typ", event.event_type)}
                    ${modalField("Erstellt", event.created_at)}
                    <hr style="border: none; border-top: 1px solid var(--border); margin: 1rem 0;">
                    ${modalField("Peak Return", event.peak_return !== null ? (event.peak_return * 100).toFixed(2) + '%' : '–')}
                    ${modalField("Final Return", event.final_return !== null ? (event.final_return * 100).toFixed(2) + '%' : '–')}
                    <div class="modal-field">
                        <div class="modal-label">Abnormal Return (vs. Benchmark)</div>
                        <div class="modal-value" style="color: ${event.abnormal_return > 0 ? '#3fb950' : '#f85149'}; font-weight: bold;">
                            ${event.abnormal_return !== null ? (event.abnormal_return * 100).toFixed(2) + '%' : '–'}
                        </div>
                    </div>
                    ${modalField("Hickup", event.is_hickup ? "✓ Strohfeuer erkannt" : "–")}
                `;
                showModal(`Event: ${event.ticker} (${event.event_type})`, html);
            } catch (e) {
                showModal(`Event: ${event.ticker}`, `<p style="color: red;">Fehler: ${escapeHtml(e.message)}</p>`);
            }
        });
    });
}

async function loadProfiles() {
    const body = document.getElementById("profiles-body");
    try {
        const profiles = await fetchJSON("/reaction-profiles");
        if (!profiles.length) {
            body.innerHTML = `<tr><td colspan="5" class="loading">Keine Profiles.</td></tr>`;
            return;
        }
        body.innerHTML = profiles.map(p => `
            <tr>
                <td>${escapeHtml(p.event_type)}</td>
                <td>${p.sample_size}</td>
                <td>${(p.avg_peak_return * 100).toFixed(2)}%</td>
                <td>${(p.avg_final_return * 100).toFixed(2)}%</td>
                <td>${(p.hickup_rate * 100).toFixed(1)}%</td>
            </tr>
        `).join("");
    } catch (e) {
        body.innerHTML = `<tr><td colspan="5" class="loading">Fehler: ${escapeHtml(e.message)}</td></tr>`;
    }
}

async function loadAbnormalReturns() {
    const body = document.getElementById("abnormal-returns-body");
    try {
        const events = await fetchJSON("/abnormal-returns-ranking?limit=30");
        if (!events.length) {
            body.innerHTML = `<tr><td colspan="5" class="loading">Keine Events mit Abnormal-Returns.</td></tr>`;
            return;
        }
        body.innerHTML = events.map((e, i) => {
            const abnormalClass = e.abnormal_return > 0 ? "green" : "red";
            const statusEmoji = e.is_hickup ? "⚠️" : (e.abnormal_return > 0.05 ? "📈" : "📉");
            return `
                <tr data-abnormal-index="${i}" data-abnormal='${JSON.stringify(e)}'>
                    <td class="ticker">${escapeHtml(e.ticker)}</td>
                    <td>${escapeHtml(e.event_type)}</td>
                    <td>${e.peak_return !== null ? (e.peak_return * 100).toFixed(2) + '%' : '–'}</td>
                    <td style="color: ${e.abnormal_return > 0 ? '#3fb950' : '#f85149'}; font-weight: bold;">
                        ${e.abnormal_return !== null ? (e.abnormal_return * 100).toFixed(2) + '%' : '–'}
                    </td>
                    <td>${statusEmoji} ${e.is_hickup ? 'Hickup' : ''}</td>
                </tr>
            `;
        }).join("");
        attachAbnormalListeners();
    } catch (e) {
        body.innerHTML = `<tr><td colspan="5" class="loading">Fehler: ${escapeHtml(e.message)}</td></tr>`;
    }
}

function attachAbnormalListeners() {
    document.querySelectorAll("#abnormal-returns-body tr[data-abnormal]").forEach(row => {
        row.addEventListener("click", () => {
            const event = JSON.parse(row.dataset.abnormal);
            const abnormalColor = event.abnormal_return > 0 ? '#3fb950' : '#f85149';
            const html = `
                ${modalField("Ticker", event.ticker)}
                ${modalField("Event-Typ", event.event_type)}
                ${modalField("Erstellt", event.created_at)}
                <hr style="border: none; border-top: 1px solid var(--border); margin: 1rem 0;">
                ${modalField("Peak Return", event.peak_return !== null ? (event.peak_return * 100).toFixed(2) + '%' : '–')}
                <div class="modal-field">
                    <div class="modal-label">Abnormal Return (vs. Benchmark)</div>
                    <div class="modal-value" style="color: ${abnormalColor}; font-weight: bold; font-size: 1.2rem;">
                        ${event.abnormal_return !== null ? (event.abnormal_return * 100).toFixed(2) + '%' : '–'}
                    </div>
                </div>
                ${modalField("Status", event.is_hickup ? "⚠️ Strohfeuer (Spike + Reversal)" : "✓ Nachhaltige Bewegung")}
            `;
            showModal(`Event Impact: ${event.ticker}`, html);
        });
    });
}

async function loadTrackingStatus() {
    const body = document.getElementById("tracking-body");
    try {
        const tracking = await fetchJSON("/tracking-status?limit=20");
        if (!tracking.length) {
            body.innerHTML = `<tr><td colspan="5" class="loading">Keine laufenden Events.</td></tr>`;
            return;
        }
        body.innerHTML = tracking.map(t => `
            <tr>
                <td class="ticker">${escapeHtml(t.ticker)}</td>
                <td>${escapeHtml(t.event_type)}</td>
                <td>${escapeHtml(t.event_created_at.substring(0, 16))}</td>
                <td><span class="badge badge-yellow" style="background: rgba(210, 153, 34, 0.3); color: #d29922; padding: 0.3rem 0.6rem; border-radius: 4px;">${t.pending_horizons.length} ausstehend</span></td>
                <td>${t.recent_snapshots.length > 0 ? t.recent_snapshots.join(", ") : "–"}</td>
            </tr>
        `).join("");
    } catch (e) {
        body.innerHTML = `<tr><td colspan="5" class="loading">Fehler: ${escapeHtml(e.message)}</td></tr>`;
    }
}

async function loadAll() {
    await Promise.all([
        loadStats(),
        loadCharts(),
        loadRecommendations(),
        loadSignals(),
        loadCompanies(),
        loadTrackingStatus(),
        loadAbnormalReturns(),
        loadEvents(),
        loadProfiles(),
    ]);
}

// --- Modal ---------------------------------------------------------------

function showModal(title, html) {
    document.getElementById("modal-title").textContent = title;
    document.getElementById("modal-body").innerHTML = html;
    document.getElementById("detail-modal").style.display = "flex";
}

function closeModal() {
    document.getElementById("detail-modal").style.display = "none";
}

function modalField(label, value) {
    if (!value) return "";
    return `
        <div class="modal-field">
            <div class="modal-label">${escapeHtml(label)}</div>
            <div class="modal-value">${escapeHtml(String(value))}</div>
        </div>
    `;
}

// --- Auto-Refresh -------------------------------------------------------

function toggleAutoRefresh() {
    const btn = document.getElementById("autorefresh-btn");
    if (autoRefreshEnabled) {
        stopAutoRefresh();
        btn.classList.remove("active");
    } else {
        startAutoRefresh();
        btn.classList.add("active");
    }
}

function startAutoRefresh() {
    if (autoRefreshInterval) return;
    autoRefreshEnabled = true;
    autoRefreshInterval = setInterval(loadAll, AUTO_REFRESH_INTERVAL);
    console.log("Auto-refresh started (30s interval)");
}

function stopAutoRefresh() {
    if (autoRefreshInterval) {
        clearInterval(autoRefreshInterval);
        autoRefreshInterval = null;
    }
    autoRefreshEnabled = false;
    console.log("Auto-refresh stopped");
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
    document.getElementById("autorefresh-btn").addEventListener("click", toggleAutoRefresh);

    // Modal listeners
    document.getElementById("detail-modal").addEventListener("click", (e) => {
        if (e.target.id === "detail-modal") closeModal();
    });
    document.querySelector(".modal-close").addEventListener("click", closeModal);
    document.addEventListener("keydown", (e) => {
        if (e.key === "Escape") closeModal();
    });

    // Signal-Filter mit Debounce
    let debounce;
    document.getElementById("ticker-filter").addEventListener("input", () => {
        clearTimeout(debounce);
        debounce = setTimeout(loadSignals, 400);
    });
    document.getElementById("analyzed-only").addEventListener("change", loadSignals);

    // Event-Filter
    let debounceEvent;
    document.getElementById("event-ticker-filter").addEventListener("input", () => {
        clearTimeout(debounceEvent);
        debounceEvent = setTimeout(loadEvents, 400);
    });
});
