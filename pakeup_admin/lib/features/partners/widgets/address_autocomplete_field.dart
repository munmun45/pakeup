import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/partner_location_data.dart';
import '../services/google_maps_places_service.dart';
import 'partner_form_field.dart';

class AddressAutocompleteField extends StatefulWidget {
  const AddressAutocompleteField({
    super.key,
    required this.apiKey,
    required this.onLocationSelected,
    this.initialQuery = '',
    this.compact = false,
  });

  final String apiKey;
  final ValueChanged<PartnerLocationData> onLocationSelected;
  final String initialQuery;
  final bool compact;

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  late final TextEditingController _controller;
  late final GoogleMapsPlacesService _service;
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();

  Timer? _debounce;
  List<PlacePrediction> _predictions = [];
  bool _loading = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _service = GoogleMapsPlacesService(widget.apiKey);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 150), _removeOverlay);
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      if (value.trim().length < 2) {
        setState(() => _predictions = []);
        _removeOverlay();
        return;
      }

      setState(() => _loading = true);
      final results = await _service.autocomplete(value);
      if (!mounted) return;
      setState(() {
        _predictions = results;
        _loading = false;
      });
      _showOverlay();
    });
  }

  Future<void> _selectPrediction(PlacePrediction prediction) async {
    _controller.text = prediction.description;
    _removeOverlay();
    _focusNode.unfocus();

    setState(() => _loading = true);
    final location = await _service.placeDetails(prediction.placeId);
    if (!mounted) return;
    setState(() => _loading = false);

    if (location != null) {
      widget.onLocationSelected(location);
    }
  }

  void _showOverlay() {
    _removeOverlay();
    if (_predictions.isEmpty) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: _fieldWidth(),
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, widget.compact ? 52 : 78),
          child: Material(
            elevation: 8,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(12),
            color: AppColors.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _predictions.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  indent: 48,
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
                itemBuilder: (context, index) {
                  final p = _predictions[index];
                  return ListTile(
                    dense: true,
                    leading: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      p.description,
                      style: const TextStyle(fontSize: 13),
                    ),
                    onTap: () => _selectPrediction(p),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  double _fieldWidth() {
    final box = context.findRenderObject() as RenderBox?;
    return box?.size.width ?? 400;
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: _onQueryChanged,
      style: const TextStyle(fontSize: 14),
      decoration: PartnerFormField.fieldDecoration(
        hint: widget.compact
            ? 'Search address...'
            : 'Type address, city, or landmark...',
      ).copyWith(
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: widget.compact ? 12 : 14,
        ),
        suffixIcon: _loading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Icon(
                Icons.search_rounded,
                size: 20,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
      ),
    );

    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.compact) ...[
            const PartnerFieldLabel(
              icon: Icons.search_rounded,
              label: 'Search Address',
            ),
            const SizedBox(height: 8),
          ],
          field,
        ],
      ),
    );
  }
}
