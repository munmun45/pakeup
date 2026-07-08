import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/store_location_data.dart';
import 'store_google_map_view.dart';

class StoreMapPickerScreen extends StatefulWidget {
  const StoreMapPickerScreen({
    super.key,
    required this.apiKey,
    this.initialLocation,
  });

  final String apiKey;
  final StoreLocationData? initialLocation;

  static Future<StoreLocationData?> open(
    BuildContext context, {
    required String apiKey,
    StoreLocationData? initialLocation,
  }) {
    return Navigator.of(context).push<StoreLocationData>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => StoreMapPickerScreen(
          apiKey: apiKey,
          initialLocation: initialLocation,
        ),
      ),
    );
  }

  @override
  State<StoreMapPickerScreen> createState() => _StoreMapPickerScreenState();
}

class _StoreMapPickerScreenState extends State<StoreMapPickerScreen> {
  StoreLocationData? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pin Location on Map'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: StoreGoogleMapView(
              apiKey: widget.apiKey,
              latitude: _selected?.latitude ?? widget.initialLocation?.latitude,
              longitude:
                  _selected?.longitude ?? widget.initialLocation?.longitude,
              onLocationChanged: (location) {
                setState(() => _selected = location);
              },
            ),
          ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: const Border(top: BorderSide(color: AppColors.border)),
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
                            child: const Icon(
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
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
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
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
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
                              backgroundColor: AppColors.primary,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
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
    );
  }
}
