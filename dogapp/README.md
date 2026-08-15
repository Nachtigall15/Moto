# Hunde-App

Alltagsdokumentation für den Hund: Fütterung, Schlaf, Gewichtskontrolle
mit Fotos und Heimtierausweis – gebaut als Flutter-Web-App (PWA), die
sich auf dem Handy als App-Icon ablegen lässt.

Die App liegt im selben Repository wie die Moto-App, aber in einem
eigenen Flutter-Projekt (`dogapp/`). Beide teilen sich eine
GitHub-Pages-Seite:

| App        | Adresse       |
| ---------- | ------------- |
| Moto       | `/Moto/`      |
| Hunde-App  | `/Moto/dog/`  |

## Stand

**Stufe 1 (fertig)**

- **Übersicht** – Tagesstand auf einen Blick: Mahlzeiten, Schlaf,
  letztes Gewicht, Schnellaktionen.
- **Fütterung** – was, wann, wie viel, welche Mahlzeit, Notiz. Bereits
  benutzte Futtersorten werden beim Eintippen vorgeschlagen. Mengen
  werden pro Einheit summiert (Gramm und Stück nie vermischt).
- **Schlaf** – „Schläft jetzt" / „Aufgewacht" per Knopfdruck, laufende
  Phase mit mitlaufender Dauer, Nachtragen und Korrigieren möglich,
  Tagessumme.
- **Gewicht & Fotos** – Messung mit Datum/Uhrzeit, optionalem Foto und
  Notiz. Verlaufsdiagramm mit optionaler Zielgewichtslinie; Fotos
  hängen direkt am jeweiligen Messwert, so entsteht der
  Entwicklungsverlauf.
- **Heimtierausweis** – Stammdaten, Kennzeichnung (Chipnummer,
  Implantationsdatum und -stelle, Tätowierung), Ausweisdaten, Halter
  und Tierarzt inklusive Notfallnummer und Sprechzeiten.

**Als Nächstes**

- Stufe 2: Kalender/Termine (Tierarzt, Hundetrainerin), Medikamente,
  Impfungen mit Erinnerungen.
- Stufe 3: Training nach Fichtlmeyer mit Trainingsplänen und
  Checkboxen, Leckerli-Übersicht (darf er / mag er).

## Entwickeln

```bash
cd dogapp
flutter pub get
flutter run -d chrome
flutter test
flutter analyze
```

## Datenspeicherung und mehrere Geräte

Die App spricht ausschließlich mit dem Interface `DogRepository`
(`lib/data/dog_repository.dart`). Dahinter steckt aktuell
`LocalRepository`: alle Daten liegen im Browser des jeweiligen Geräts.
Das heißt – **bis Firebase eingerichtet ist, sieht jedes Gerät nur
seine eigenen Einträge.** Die Übersicht weist unten darauf hin.

Weil alle Lesezugriffe schon heute Streams sind, ändert der Umstieg auf
die Cloud nichts an der Oberfläche: es wird eine andere Implementierung
des Interfaces eingehängt, Änderungen anderer Geräte laufen dann von
selbst in die Listen.

### Firebase einrichten

1. Auf <https://console.firebase.google.com> ein Projekt anlegen.
2. Eine **Web-App** hinzufügen (`</>`-Symbol).
3. **Firestore Database** und **Storage** aktivieren.
4. Die sechs Werte aus der Firebase-Konfiguration in den
   GitHub-Repo-Secrets hinterlegen:
   `FIREBASE_API_KEY`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_PROJECT_ID`,
   `FIREBASE_STORAGE_BUCKET`, `FIREBASE_MESSAGING_SENDER_ID`,
   `FIREBASE_APP_ID`.

Diese Werte sind keine Geheimnisse – sie identifizieren nur das
Projekt. Der Zugriffsschutz passiert über die Firestore-Regeln.

Lokal zum Ausprobieren:

```bash
flutter run -d chrome \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_APP_ID=...
```

## Fotos

Fotos werden vor dem Speichern auf 900 px Kantenlänge verkleinert und
als JPEG abgelegt (`lib/core/photo.dart`). Ohne diesen Schritt wäre der
lokale Browser-Speicher nach wenigen Handyfotos voll. Im lokalen Modus
gilt trotzdem die Browser-Grenze von etwa 5 MB – ausreichend für den
Anfang, aber der eigentliche Ort für Fotos ist Firebase Storage.
