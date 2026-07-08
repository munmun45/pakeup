import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/store_location_data.dart';
import '../utils/map_static_url.dart';
import 'store_map_picker_screen.dart';

class StoreLocationPicker extends StatelessWidget {
  const StoreLocationPicker({
    super.key,
    required this.apiKey,
    this.latitude,
    this.longitude,
    this.initialAddress = '',
    this.city = '',
    this.state = '',
    required this.onLocationChanged,
  });

  final String apiKey;
  final double? latitude;
  final double? longitude;
  final String initialAddress;
  final String city;
  final String state;
  final ValueChanged<StoreLocationData> onLocationChanged;

  bool get _hasLocation => latitude != null && longitude != null;

  StoreLocationData? get _currentLocation {
    if (!_hasLocation) return null;
    return StoreLocationData(
      latitude: latitude!,
      longitude: longitude!,
      address: initialAddress,
      city: city,
      state: state,
    );
  }

  Future<void> _openMapPicker(BuildContext context) async {
    final result = await StoreMapPickerScreen.open(
      context,
      apiKey: apiKey,
      initialLocation: _currentLocation,
    );
    if (result != null) {
      onLocationChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _hasLocation
        ? [
            if (city.isNotEmpty) city,
            if (state.isNotEmpty) state,
          ].join(', ')
        : 'Open map to search or drop a pin';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openMapPicker(context),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hasLocation
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              _MapThumb(
                apiKey: apiKey,
                hasLocation: _hasLocation,
                latitude: latitude,
                longitude: longitude,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _hasLocation
                          ? (initialAddress.isNotEmpty
                              ? initialAddress
                              : 'Location pinned')
                          : 'Pin location on map',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _hasLocation
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _MapActionChip(hasLocation: _hasLocation),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapThumb extends StatelessWidget {
  const _MapThumb({
    required this.apiKey,
    required this.hasLocation,
    this.latitude,
    this.longitude,
  });

  final String apiKey;
  final bool hasLocation;
  final double? latitude;
  final double? longitude;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 44,
        height: 44,
        child: hasLocation && latitude != null && longitude != null
            ? Image.network(
                buildStaticMapUrl(
                  apiKey: apiKey,
                  latitude: latitude!,
                  longitude: longitude!,
                  width: 120,
                  height: 120,
                  zoom: 15,
                  showMarker: true,
                ),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _MapThumbFallback(),
              )
            : const _MapThumbFallback(),
      ),
    );
  }
}

class _MapThumbFallback extends StatelessWidget {
  const _MapThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Icon(
        Icons.location_on_outlined,
        size: 22,
        color: AppColors.primary.withValues(alpha: 0.75),
      ),
    );
  }
}

class _MapActionChip extends StatelessWidget {
  const _MapActionChip({required this.hasLocation});

  final bool hasLocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasLocation ? Icons.edit_location_alt_rounded : Icons.map_rounded,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            hasLocation ? 'Edit' : 'Map',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
