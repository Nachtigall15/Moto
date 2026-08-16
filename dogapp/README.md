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
| Gesundheit | Entwicklung · Medikamente · Impfungen        |
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

1. In der [Firebase-Konsole](https://console.firebase.google.com) das
   Projekt anlegen (hier: `bheki-dog`).
2. **Firestore Database** anlegen (Standort `eur3` oder
   `europe-west3`). **Storage wird nicht gebraucht** – siehe unten.
3. Unter **Authentication → Sign-in method** die Anmeldung per
   **E-Mail/Passwort** einschalten und unter **Users** für jede Person
   ein Konto anlegen.
4. Konfiguration erzeugen – im Ordner `dogapp/`, beschränkt auf Web:

   ```bash
   cd dogapp
   dart pub global activate flutterfire_cli
   flutterfire configure --project=bheki-dog --platforms=web
   ```

   Das überschreibt `lib/firebase_options.dart`. Datei committen –
   die Werte sind keine Geheimnisse, sie benennen nur das Projekt.
   Sobald sie da ist, startet die App von selbst im Cloud-Modus.

5. Die Regeln aus `firestore.rules` in der Konsole hinterlegen
   (Firestore → Regeln).

Die Werte lassen sich auch ohne FlutterFire besorgen: In der Konsole
unter **Projekteinstellungen → Meine Apps → Konfiguration** stehen
dieselben sechs Angaben zum Kopieren.

### Anmeldung

Jede Person meldet sich mit E-Mail und Passwort an. Die App bietet
bewusst **keine Registrierung** – sonst könnte sich jede beliebige
Person ein Konto anlegen und käme an die Daten. Konten legt der Halter
in der Konsole an (Authentication → Users → *Add user*).

Zwei Schritte gehören zusammen:

1. Konto in der Konsole anlegen.
2. Die Adresse in `firestore.rules` in die Liste `zugelassen()`
   eintragen und die Regeln veröffentlichen.

Fehlt der zweite Schritt, kann sich die Person anmelden, sieht aber
nur Fehlermeldungen. Eine Adresse aus der Liste zu streichen entzieht
den Zugriff sofort, auch auf Geräten, die noch angemeldet sind.

Die Anmeldung überdauert Neustarts – niemand muss sich täglich neu
anmelden. Auf der Übersicht steht unten, wer angemeldet ist, mit einem
**Abmelden**-Knopf. „Passwort vergessen" verschickt eine Mail mit
Rücksetz-Link.

Anonyme Anmeldung wäre bequemer gewesen, hat aber einen Haken:
Firebase räumt anonyme Konten nach längerer Inaktivität auf. Echte
Konten bleiben.

Alle Daten liegen unter `haushalte/<id>/…` mit fester Kennung
(`AppConfig.haushalt`). Wer sie sehen darf, entscheiden die Konten und
die Regeln, nicht der Pfad – die Ebene bleibt nur erhalten, damit
später ein zweiter Hund danebenpasst.

## Fotos und Kosten

Fotos werden vor dem Speichern auf 800 px Kantenlänge verkleinert und
als JPEG abgelegt (`lib/core/photo.dart`); übliche Handyfotos landen
danach bei rund 100 kB. Eine Notbremse komprimiert stärker, falls ein
Bild die Grenze von 600 kB doch reißen sollte.

Sie liegen **in der Datenbank**, nicht in Cloud Storage. Storage
verlangt bei neuen Projekten den kostenpflichtigen Blaze-Tarif, also
eine hinterlegte Kreditkarte. Für Bilder dieser Größe ist ein
Firestore-Dokument (1 MiB Grenze) völlig ausreichend – so bleibt die
App im kostenlosen Spark-Tarif, ganz ohne Zahlungsdaten.

Der Verbrauch für einen Hund und zwei, drei Personen liegt bei etwa
einem Prozent der kostenlosen Kontingente. Die Fotos stehen in einer
eigenen Sammlung, die nicht abonniert wird – sie belasten also auch
keine der laufenden Abfragen.

Im lokalen Modus gilt weiterhin die Browser-Grenze von etwa 5 MB.
