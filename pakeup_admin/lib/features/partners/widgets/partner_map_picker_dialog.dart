import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/partner_location_data.dart';
import 'partner_web_map_view.dart';

class PartnerMapPickerDialog extends StatefulWidget {
  const PartnerMapPickerDialog({
    super.key,
    required this.apiKey,
    this.initialLocation,
  });

  final String apiKey;
  final PartnerLocationData? initialLocation;

  static Future<PartnerLocationData?> open(
    BuildContext context, {
    required String apiKey,
    PartnerLocationData? initialLocation,
  }) {
    return showDialog<PartnerLocationData>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) => PartnerMapPickerDialog(
        apiKey: apiKey,
        initialLocation: initialLocation,
      ),
    );
  }

  @override
  State<PartnerMapPickerDialog> createState() => _PartnerMapPickerDialogState();
}

class _PartnerMapPickerDialogState extends State<PartnerMapPickerDialog> {
  PartnerLocationData? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLocation;
  }

  void _onLocationChanged(PartnerLocationData location) {
    setState(() => _selected = location);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            'Pin Location on Map',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Cancel',
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: PartnerWebMapView(
                apiKey: widget.apiKey,
                latitude: _selected?.latitude ?? widget.initialLocation?.latitude,
                longitude:
                    _selected?.longitude ?? widget.initialLocation?.longitude,
                onLocationChanged: _onLocationChanged,
              ),
            ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.location_on_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selected?.address.isNotEmpty == true
                                        ? _selected!.address
                                        : 'Search or tap the map to select',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5,
                                      height: 1.3,
                                    ),
                                  ),
                                  if (_selected != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_selected!.latitude.toStringAsFixed(6)}, '
                                      '${_selected!.longitude.toStringAsFixed(6)}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondary,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: _selected == null
                                  ? null
                                  : () => Navigator.pop(context, _selected),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: const Text('Confirm Location'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
