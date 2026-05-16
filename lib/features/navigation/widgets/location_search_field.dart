import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/geocoding_service.dart';

typedef PlaceSearch = Future<List<GeocodeResult>> Function(String query);

/// Textfeld mit Adress-Vorschlägen (debounced) für Start/Ziel.
class LocationSearchField extends StatefulWidget {
  const LocationSearchField({
    super.key,
    required this.label,
    required this.icon,
    required this.onSearch,
    required this.onSelected,
    this.selectedLabel,
  });

  final String label;
  final IconData icon;
  final PlaceSearch onSearch;
  final ValueChanged<GeocodeResult> onSelected;
  final String? selectedLabel;

  @override
  State<LocationSearchField> createState() => _LocationSearchFieldState();
}

class _LocationSearchFieldState extends State<LocationSearchField> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<GeocodeResult> _results = const [];
  bool _busy = false;

  @override
  void didUpdateWidget(covariant LocationSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedLabel != null &&
        widget.selectedLabel != oldWidget.selectedLabel) {
      _controller.text = widget.selectedLabel!;
      _results = const [];
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _run(value));
  }

  Future<void> _run(String value) async {
    if (value.trim().length < 3) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await widget.onSearch(value);
      if (mounted) setState(() => _results = r);
    } catch (_) {
      if (mounted) setState(() => _results = const []);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: Icon(widget.icon),
            suffixIcon: _busy
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final r = _results[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_outlined, size: 18),
                  title: Text(
                    r.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  onTap: () {
                    _controller.text = r.label;
                    setState(() => _results = const []);
                    widget.onSelected(r);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
