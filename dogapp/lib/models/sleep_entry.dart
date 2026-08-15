import '../core/format.dart';

/// Eine Schlafphase. [ende] ist null, solange der Hund noch schläft –
/// so kann man den Schlaf per Knopfdruck starten und später beenden.
class SleepEntry {
  SleepEntry({
    String? id,
    required this.start,
    this.ende,
    this.ort = '',
    this.notiz = '',
  }) : id = id ?? newId();

  final String id;
  final DateTime start;
  final DateTime? ende;
  final String ort;
  final String notiz;

  bool get laeuft => ende == null;

  Duration get dauer => (ende ?? DateTime.now()).difference(start);

  String get dauerLabel => formatDuration(dauer);

  SleepEntry copyWith({
    DateTime? start,
    DateTime? ende,
    bool clearEnde = false,
    String? ort,
    String? notiz,
  }) =>
      SleepEntry(
        id: id,
        start: start ?? this.start,
        ende: clearEnde ? null : (ende ?? this.ende),
        ort: ort ?? this.ort,
        notiz: notiz ?? this.notiz,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start.toIso8601String(),
        'ende': ende?.toIso8601String(),
        'ort': ort,
        'notiz': notiz,
      };

  static SleepEntry fromJson(Map<String, dynamic> json) => SleepEntry(
        id: json['id'] as String?,
        start: DateTime.tryParse(json['start'] as String? ?? '') ??
            DateTime.now(),
        ende: DateTime.tryParse(json['ende'] as String? ?? ''),
        ort: json['ort'] as String? ?? '',
        notiz: json['notiz'] as String? ?? '',
      );
}
