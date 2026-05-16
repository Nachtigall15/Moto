import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/config.dart';

class GeocodeResult {
  const GeocodeResult({required this.label, required this.position});

  final String label;
  final LatLng position;
}

/// Adresssuche über Nominatim (OpenStreetMap), keyless.
class GeocodingService {
  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<GeocodeResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final uri = Uri.parse(AppConfig.nominatimSearchUrl).replace(
      queryParameters: {
        'q': trimmed,
        'format': 'jsonv2',
        'limit': '6',
        'addressdetails': '0',
      },
    );

    final res = await _client.get(
      uri,
      headers: {'User-Agent': AppConfig.userAgent},
    );
    if (res.statusCode != 200) {
      throw Exception('Adresssuche fehlgeschlagen (${res.statusCode})');
    }

    final data = jsonDecode(res.body) as List<dynamic>;
    return data.map((raw) {
      final m = raw as Map<String, dynamic>;
      return GeocodeResult(
        label: m['display_name'] as String? ?? trimmed,
        position: LatLng(
          double.parse(m['lat'] as String),
          double.parse(m['lon'] as String),
        ),
      );
    }).toList();
  }
}
