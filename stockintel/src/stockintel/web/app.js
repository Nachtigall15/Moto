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

        // Recommendations Distribution (Horizontal Bar)
        const recCounts = { buy: 0, hold: 0, sell: 0 };
        recs.forEach(r => {
            const action = r.action.toLowerCase();
            if (action in recCounts) {
                recCounts[action]++;
            }
        });
        updateChart("_chartRecommendations", "recommendations-canvas", {
            type: "bar",
            labels: ["Buy", "Hold", "Sell"],
            datasets: [
                {
                    label: "Recommendations",
                    data: [recCounts.buy, recCounts.hold, recCounts.sell],
                    backgroundColor: ["#3fb950", "#d29922", "#f85149"],
                    borderColor: "#58a6ff",
                    borderWidth: 1,
                }
            ],
            indexAxis: "y",
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
            indexAxis: config.indexAxis || "x",
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

    let path = "/signals/detailed?limit=50";
    if (ticker) path += `&ticker=${encodeURIComponent(ticker)}`;
    if (analyzedOnly) path += `&analyzed_only=true`;

    try {
        const signals = await fetchJSON(path);
        if (!signals.length) {
            body.innerHTML = `<tr><td colspan="5" class="loading">Keine Signals.</td></tr>`;
            return;
        }
        body.innerHTML = signals.map((s, i) => {
            const time = s.published_at ? new Date(s.published_at).toLocaleString('de-DE', { month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' }) : '–';
            const urlBadge = s.url ? `<span style="display: inline-block; margin-left: 0.3rem; font-size: 0.8rem;"><a href="${escapeHtml(s.url)}" target="_blank" style="color: #58a6ff; text-decoration: none;">🔗</a></span>` : '';
            return `
            <tr data-signal-index="${i}" data-signal='${JSON.stringify(s)}' style="cursor: pointer;">
                <td class="ticker">${escapeHtml(s.ticker)}</td>
                <td>${badge(s.direction, s.direction)}</td>
                <td>${relevanceBar(s.relevance)}</td>
                <td>${(s.confidence * 100).toFixed(0)}%</td>
                <td>
                    <div style="font-size: 0.85rem; color: #8b949e; margin-bottom: 0.2rem;">
                        📰 ${escapeHtml(s.source_name)} | ${time}
                    </div>
                    <div>${escapeHtml(s.title || "")}${urlBadge}</div>
                </td>
            </tr>
        `}).join("");
        attachSignalListeners();
    } catch (e) {
        body.innerHTML = `<tr><td colspan="5" class="loading">Fehler: ${escapeHtml(e.message)}</td></tr>`;
    }
}

function attachSignalListeners() {
    document.querySelectorAll("#signals-body tr[data-signal]").forEach(row => {
        row.addEventListener("click", () => {
            const signal = JSON.parse(row.dataset.signal);
            const time = signal.published_at ? new Date(signal.published_at).toLocaleString('de-DE') : '–';
            let html = `
                ${modalField("Ticker", signal.ticker)}
                ${modalField("Quelle", signal.source_name)}
                ${modalField("Richtung", signal.direction)}
                ${modalField("Relevanz", signal.relevance + "%")}
                ${modalField("Konfidenz", (signal.confidence * 100).toFixed(1) + "%")}
                ${modalField("Veröffentlicht", time)}
                ${modalField("Titel", signal.title)}
                ${modalField("Rationale", signal.rationale)}
            `;
            if (signal.url) {
                html += `<div class="modal-field"><a href="${escapeHtml(signal.url)}" target="_blank" class="action-btn" style="display: inline-block;">🔗 Zur Quelle</a></div>`;
            }
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
        row.addEventListener("click", async () => {
            const company = JSON.parse(row.dataset.company);
            showModal(`Company: ${company.ticker}`, `<div class="loading">Lade Details für ${escapeHtml(company.ticker)}…</div>`);

            try {
                const detail = await fetchJSON(`/company/${encodeURIComponent(company.ticker)}`);

                // Build signals grouped by source
                let signalsHtml = `
                    <div class="modal-field">
                        <div class="modal-label">Kurs (Live)</div>
                        <div class="modal-value" style="font-size: 1.3rem; font-weight: bold;">
                            ${detail.current_price !== null ? `$${detail.current_price.toFixed(2)}` : '–'}
                        </div>
                    </div>
                `;

                if (detail.signal_count > 0) {
                    signalsHtml += '<div style="margin-top: 1.5rem; border-top: 1px solid var(--border); padding-top: 1rem;">';
                    signalsHtml += `<h4 style="margin: 0 0 1rem 0;">Nachrichten und Signale (${detail.signal_count})</h4>`;

                    // Group signals by source
                    for (const [sourceKey, signals] of Object.entries(detail.signals_by_source)) {
                        const sourceName = signals.length > 0 ? signals[0].source_name : sourceKey;
                        signalsHtml += `<div style="margin: 1rem 0; padding: 1rem; background: rgba(88, 166, 255, 0.1); border-radius: 4px; border-left: 3px solid #58a6ff;">`;
                        signalsHtml += `<h5 style="margin: 0 0 0.5rem 0; color: #58a6ff; font-size: 0.95rem;">📰 ${escapeHtml(sourceName)}</h5>`;

                        signals.forEach(sig => {
                            const time = sig.published_at ? new Date(sig.published_at).toLocaleString('de-DE') : '–';
                            const directionColor = sig.direction === 'positive' ? '#3fb950' : (sig.direction === 'negative' ? '#f85149' : '#d29922');
                            const urlLink = sig.url ? `<a href="${escapeHtml(sig.url)}" target="_blank" style="color: #58a6ff; text-decoration: none;">🔗</a>` : '';

                            signalsHtml += `
                                <div style="margin: 0.7rem 0; padding: 0.7rem; background: rgba(22, 27, 34, 0.5); border-radius: 3px;">
                                    <div style="display: flex; justify-content: space-between; align-items: start; gap: 0.5rem;">
                                        <div style="flex: 1; min-width: 0;">
                                            <div style="color: ${directionColor}; font-weight: bold; font-size: 0.9rem;">${sig.direction.toUpperCase()}</div>
                                            <div style="color: #8b949e; font-size: 0.85rem; margin: 0.2rem 0;">${time}</div>
                                            <div style="color: #c9d1d9; margin: 0.3rem 0;">${escapeHtml(sig.title || '(Kein Titel)')}</div>
                                            <div style="color: #8b949e; font-size: 0.85rem; margin-top: 0.3rem;">Relevanz: ${sig.relevance}% | Konfidenz: ${(sig.confidence * 100).toFixed(0)}%</div>
                                        </div>
                                        <div>${urlLink}</div>
                                    </div>
                                </div>
                            `;
                        });

                        signalsHtml += `</div>`;
                    }
                    signalsHtml += `</div>`;
                } else {
                    signalsHtml += `<div style="margin-top: 1rem; padding: 1rem; background: rgba(210, 153, 34, 0.1); border-radius: 4px;">Keine Nachrichten/Signale vorhanden.</div>`;
                }

                const html = `
                    ${modalField("Ticker", detail.ticker)}
                    ${modalField("Name", detail.name)}
                    ${modalField("Sektor", detail.sector || "–")}
                    ${signalsHtml}
                `;
                showModal(`Company: ${detail.ticker}`, html);
            } catch (e) {
                showModal(`Company: ${company.ticker}`, `<p style="color: #f85149;">Fehler beim Laden: ${escapeHtml(e.message)}</p>`);
            }
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

async function loadWatchlist() {
    const body = document.getElementById("watchlist-body");
    try {
        const watchlist = await fetchJSON("/watchlist");
        if (!watchlist.length) {
            body.innerHTML = `<tr><td colspan="4" class="loading">Watchlist ist leer. Nutzen Sie das Formular, um Companies hinzuzufügen.</td></tr>`;
            return;
        }
        body.innerHTML = watchlist.map(w => `
            <tr>
                <td class="ticker">${escapeHtml(w.ticker)}</td>
                <td>${escapeHtml(w.name)}</td>
                <td>${escapeHtml(w.sector || "–")}</td>
                <td>
                    <button class="action-btn small remove-watchlist-btn" data-ticker="${escapeHtml(w.ticker)}" style="background: #f85149;">🗑️ Entfernen</button>
                </td>
            </tr>
        `).join("");
        attachWatchlistRemoveListeners();
    } catch (e) {
        body.innerHTML = `<tr><td colspan="4" class="loading">Fehler: ${escapeHtml(e.message)}</td></tr>`;
    }
}

function attachWatchlistRemoveListeners() {
    document.querySelectorAll(".remove-watchlist-btn").forEach(btn => {
        btn.addEventListener("click", async () => {
            const ticker = btn.dataset.ticker;
            if (confirm(`Wirklich entfernen: ${ticker}?`)) {
                try {
                    await fetchJSON(`/watchlist/${encodeURIComponent(ticker)}`, { method: "DELETE" });
                    await loadWatchlist();
                } catch (e) {
                    alert("Fehler beim Entfernen: " + e.message);
                }
            }
        });
    });
}

async function loadAll() {
    await Promise.all([
        loadStats(),
        loadCharts(),
        loadWatchlist(),
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

    // Company search functionality
    let searchDebounce;
    document.getElementById("search-company-input").addEventListener("input", async (e) => {
        const query = e.target.value.trim();
        const resultsDiv = document.getElementById("search-results");

        clearTimeout(searchDebounce);

        if (query.length < 1) {
            resultsDiv.style.display = "none";
            return;
        }

        searchDebounce = setTimeout(async () => {
            try {
                const result = await fetchJSON(`/search/companies?query=${encodeURIComponent(query)}`);
                if (result.results && result.results.length > 0) {
                    resultsDiv.innerHTML = result.results.map(company => `
                        <div class="search-result-item" style="padding: 0.8rem; border-bottom: 1px solid var(--border); cursor: pointer; transition: background 0.2s;"
                             onmouseover="this.style.background='rgba(88, 166, 255, 0.1)'"
                             onmouseout="this.style.background='transparent'"
                             data-ticker="${escapeHtml(company.ticker)}"
                             data-name="${escapeHtml(company.name)}"
                             data-sector="${escapeHtml(company.sector || '')}">
                            <div style="font-weight: bold; color: #58a6ff;">${escapeHtml(company.ticker)}</div>
                            <div style="color: #8b949e; font-size: 0.9rem;">${escapeHtml(company.name)}</div>
                            ${company.sector ? `<div style="color: #8b949e; font-size: 0.85rem;">📊 ${escapeHtml(company.sector)}</div>` : ''}
                        </div>
                    `).join("");
                    resultsDiv.style.display = "block";

                    // Attach click listeners to results
                    document.querySelectorAll(".search-result-item").forEach(item => {
                        item.addEventListener("click", async () => {
                            const ticker = item.dataset.ticker;
                            const name = item.dataset.name;
                            const sector = item.dataset.sector;

                            try {
                                const params = new URLSearchParams({ ticker, name });
                                if (sector) params.append("sector", sector);
                                await fetchJSON(`/watchlist?${params}`, { method: "POST" });
                                document.getElementById("search-company-input").value = "";
                                resultsDiv.style.display = "none";
                                await loadWatchlist();

                                // Automatisch nach News für diese Company suchen
                                document.getElementById("ticker-filter").value = ticker;
                                await loadSignals();
                            } catch (e) {
                                alert("Fehler beim Hinzufügen: " + e.message);
                            }
                        });
                    });
                } else {
                    resultsDiv.innerHTML = `<div style="padding: 0.8rem; color: #8b949e;">Keine Ergebnisse gefunden</div>`;
                    resultsDiv.style.display = "block";
                }
            } catch (e) {
                resultsDiv.innerHTML = `<div style="padding: 0.8rem; color: #f85149;">Fehler: ${escapeHtml(e.message)}</div>`;
                resultsDiv.style.display = "block";
            }
        }, 300);
    });

    // Suche ausblenden, wenn man anderswo klickt
    document.addEventListener("click", (e) => {
        if (!e.target.closest("#search-company-input") && !e.target.closest("#search-results")) {
            document.getElementById("search-results").style.display = "none";
        }
    });

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
