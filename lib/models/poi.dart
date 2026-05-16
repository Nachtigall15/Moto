import 'package:latlong2/latlong.dart';

/// POI-Kategorie als reine Daten (kein Flutter-Import in der Modell-
/// schicht). Icon/Farbe werden in der UI gemappt.
///
/// `overpassSelectors` sind Tag-Filter, die in der Overpass-Abfrage
/// hinter `nwr` gehängt werden, z. B. `["shop"="motorcycle"]`.
class PoiCategory {
  const PoiCategory({
    required this.id,
    required this.label,
    required this.overpassSelectors,
  });

  final String id;
  final String label;
  final List<String> overpassSelectors;

  static const motorcycleShop = PoiCategory(
    id: 'moto_shop',
    label: 'Motorrad-Geschäfte',
    overpassSelectors: ['["shop"="motorcycle"]'],
  );

  static const workshop = PoiCategory(
    id: 'workshop',
    label: 'Werkstatt / Reparatur',
    overpassSelectors: [
      '["shop"="motorcycle_repair"]',
      '["shop"="motorcycle"]["service:motorcycle:repair"="yes"]',
    ],
  );

  static const all = <PoiCategory>[motorcycleShop, workshop];

  @override
  bool operator ==(Object other) =>
      other is PoiCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class Poi {
  const Poi({
    required this.position,
    required this.category,
    this.name,
  });

  final LatLng position;
  final PoiCategory category;
  final String? name;
}
