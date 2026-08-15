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

## Aufbau der Oberfläche

Unten fünf Bereiche, die verwandte Themen bündeln – acht einzelne
Einträge wären auf einem Handy unbedienbar:

| Bereich    | Inhalt                                      |
| ---------- | ------------------------------------------- |
| Übersicht  | Tagesstand, Hinweise, Schnellaktionen        |
| Alltag     | Fütterung · Schlaf · Leckerli                |
| Gesundheit | Gewicht · Medikamente · Impfungen            |
| Kalender   | Termine aller Art                            |
| Training   | Heute · Übungen · Pläne                      |

Der Heimtierausweis hängt am Ausweis-Symbol oben rechts in der
Übersicht – er wird selten geöffnet und dann gezielt.

## Stand

**Alle drei Stufen sind umgesetzt.**

- **Übersicht** – Tagesstand auf einen Blick: Mahlzeiten, Schlaf,
  nächster Termin, letztes Gewicht, Schnellaktionen. Oben stehen die
  Hinweise, die man morgens wirklich lesen muss: offene
  Medikamentengaben, nicht abgehakte Termine, fällige Impfungen.
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
- **Kalender** – Termine nach Art (Tierarzt, Impfung, Medikament,
  Hundeschule, Pflege, Sonstiges), gruppiert in Heute / Diese Woche /
  Später. Vergangene, nicht abgehakte Termine stehen oben, damit sie
  nicht durchrutschen.
- **Medikamente** – Gabezeiten pro Medikament, Tagesplan zum Abhaken
  mit Uhrzeit der tatsächlichen Gabe. Zeitraum (ab/bis) und Pausieren
  für Wurmkur und Kuren. Der Haken hat eine feste Kennung aus
  Medikament, Tag und Uhrzeit – zwei Personen können dieselbe Gabe
  nicht doppelt eintragen.
- **Impfungen** – Datum, Impfstoff, Chargennummer, Tierarzt und
  Gültigkeit. Der Status rechnet nur mit der jeweils jüngsten Impfung
  je Bezeichnung; acht Wochen vor Ablauf gibt es eine Warnung und
  daneben einen Knopf, der direkt den Tierarzttermin anlegt.
- **Training** – Übungskatalog mit Trainingsstand (offen / in Arbeit /
  sitzt), Tagesliste zum Abhaken und Trainingspläne, die bestimmen,
  was unter „Heute" steht. Der Startkatalog (Name, Sitz, Platz, Bleib,
  Aus, Verbieten, Auf den Platz, Rückruf, Leinenführigkeit, Straße
  überqueren, Pfote geben, Suchen …) orientiert sich in Aufbau und
  Reihenfolge an der Arbeit von Anton Fichtlmeier: erst Ruhe,
  Aufmerksamkeit und Körpersprache, dann Signale, dann Ablenkung. Die
  Merksätze sind eigene Kurzfassungen und ersetzen weder Buch noch
  Hundeschule.
- **Leckerli** – getrennt nach „darf er", „in Maßen" und „darf er
  nicht", dazu wie gern er es mag. Die Startliste bringt die bekannten
  Giftigkeiten (Schokolade, Weintrauben, Zwiebeln, Xylit …) gleich mit
  – der eigentliche Grund für so eine Liste, wenn mehrere Personen mit
  dem Hund arbeiten.

Beide Startlisten (Übungen, Leckerli) werden nur auf Knopfdruck
angelegt. Eine App soll nicht ungefragt Daten erzeugen, die hinterher
jemand einzeln wieder löscht.

**Offen**

- Cloud-Anbindung (siehe unten) – bis dahin sieht jedes Gerät nur seine
  eigenen Einträge.
- Push-Erinnerungen für Termine und Medikamente.

## Deployment

Der Workflow `.github/workflows/deploy-dogapp.yml` baut bei jedem Push
auf den Entwicklungsbranch beide Apps und veröffentlicht sie auf
GitHub Pages.

Damit der `deploy`-Schritt durchläuft, muss der Branch in der
Pages-Umgebung freigegeben sein – sonst wird der Job abgewiesen, bevor
er startet (Fehlschlag nach einer Sekunde, ohne Log):

**Settings → Environments → `github-pages` → Deployment branches and
tags** → den Entwicklungsbranch hinzufügen.

Zusätzlich muss unter **Settings → Pages** als Quelle „GitHub Actions"
eingestellt sein.

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
