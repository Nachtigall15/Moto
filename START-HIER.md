# 🚀 StockIntel Dashboard starten (Mac)

Diese Anleitung bringt dir das Dashboard in **3 Schritten** auf den Bildschirm.
Kein Programmieren, kein Terminal-Tippen.

---

## Schritt 1 – Docker Desktop installieren (nur einmal)

1. Gehe auf **https://www.docker.com/products/docker-desktop**
2. Lade **Docker Desktop für Mac** herunter (bei neuem Mac: „Apple Chip").
3. Installiere es (Datei öffnen → Docker ins Programme-Ordner ziehen).
4. Starte **Docker Desktop** einmal und warte, bis das kleine Wal-Symbol
   oben in der Menüleiste ruhig steht (nicht mehr animiert).

---

## Schritt 2 – Projekt auf den Mac laden (nur einmal)

1. Öffne diese Adresse im Browser:
   **https://github.com/nachtigall15/moto/archive/refs/heads/claude/gallant-hamilton-lr5Ud.zip**
   (Das lädt das Projekt als ZIP herunter.)
2. Öffne die heruntergeladene ZIP-Datei (Doppelklick) – es entsteht ein Ordner.
3. Schiebe diesen Ordner an einen Ort, den du wiederfindest, z. B. den
   **Schreibtisch**.

---

## Schritt 3 – Dashboard starten

1. Öffne den Projekt-Ordner.
2. **Rechtsklick** auf die Datei **`start.command`** → **„Öffnen"**
   → im Sicherheitshinweis nochmal **„Öffnen"**.
   *(Nur beim allerersten Mal nötig – danach reicht Doppelklick.)*
3. Ein schwarzes Fenster geht auf und arbeitet.
   **Das erste Mal dauert es ein paar Minuten** (es wird alles aufgebaut).
4. Danach öffnet sich dein Browser automatisch mit dem Dashboard:
   **http://localhost:8000**

✅ **Fertig!**

> Falls die Seite beim ersten Mal noch leer wirkt: kurz warten und die Seite
> einmal neu laden (Cmd + R). Die Daten werden im Hintergrund geladen.

---

## 📱 Auf dem iPad ansehen

Solange der Mac läuft und im **gleichen WLAN** ist:

1. Das `start.command`-Fenster zeigt dir eine Adresse wie
   `http://192.168.x.x:8000`.
2. Diese Adresse im **Safari auf dem iPad** eingeben. Fertig.

---

## 🔁 Tägliche Nutzung (ganz kurz)

| Was du willst | Was du tust |
|---|---|
| Dashboard starten | **`start.command`** doppelklicken |
| Frische Daten holen | **`update-data.command`** doppelklicken |
| Dashboard stoppen | **`stop.command`** doppelklicken |

Deine Daten bleiben gespeichert (im Ordner `data`), auch nach dem Stoppen.

---

## ❓ Wenn etwas klemmt

- **„Docker Desktop läuft nicht"** → erst Docker Desktop öffnen, warten bis das
  Wal-Symbol ruhig ist, dann `start.command` erneut.
- **Seite lädt nicht** → 1–2 Minuten warten (erster Start dauert), dann neu laden.
- **Sonst** → den Text aus dem schwarzen Fenster kopieren und mir schicken.
