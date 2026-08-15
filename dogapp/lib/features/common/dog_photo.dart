import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';

/// Zeigt ein gespeichertes Foto anhand seiner Referenz.
///
/// Der kleine Cache verhindert, dass beim Scrollen durch den
/// Gewichtsverlauf jedes Bild bei jedem Aufbau neu aus dem Speicher
/// geholt und dekodiert wird.
class DogPhoto extends StatefulWidget {
  const DogPhoto({
    super.key,
    required this.fotoRef,
    this.size = 56,
    this.radius = 12,
    this.fit = BoxFit.cover,
  });

  final String fotoRef;
  final double size;
  final double radius;
  final BoxFit fit;

  static final Map<String, Uint8List> _cache = {};

  /// Nach dem Löschen eines Fotos muss der Cache-Eintrag weg, sonst
  /// taucht ein bereits entferntes Bild wieder auf.
  static void evict(String ref) => _cache.remove(ref);

  @override
  State<DogPhoto> createState() => _DogPhotoState();
}

class _DogPhotoState extends State<DogPhoto> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DogPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fotoRef != widget.fotoRef) _load();
  }

  Future<void> _load() async {
    final cached = DogPhoto._cache[widget.fotoRef];
    if (cached != null) {
      setState(() => _bytes = cached);
      return;
    }
    final bytes = await context.read<AppState>().loadPhoto(widget.fotoRef);
    if (bytes != null) DogPhoto._cache[widget.fotoRef] = bytes;
    if (mounted) setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.radius);
    if (_bytes == null) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: radius,
        ),
        child: Icon(
          Icons.pets,
          size: widget.size * 0.4,
          color: Theme.of(context).colorScheme.outline,
        ),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: Image.memory(
        _bytes!,
        width: widget.size,
        height: widget.size,
        fit: widget.fit,
        gaplessPlayback: true,
      ),
    );
  }
}

/// Foto groß anschauen (Tippen auf ein Vorschaubild).
void showPhotoDialog(BuildContext context, String fotoRef, String caption) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      // Die Kantenlänge muss sich am Gerät orientieren – ein fester
      // Wert läuft auf schmalen Handys aus dem Bild.
      final groesse = MediaQuery.of(dialogContext).size;
      final kante = [
        groesse.width - 64,
        groesse.height - 200,
        480.0,
      ].reduce((a, b) => a < b ? a : b);

      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DogPhoto(
              fotoRef: fotoRef,
              size: kante < 120 ? 120 : kante,
              radius: 12,
              fit: BoxFit.contain,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(caption, textAlign: TextAlign.center),
            ),
          ],
        ),
      );
    },
  );
}
