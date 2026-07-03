import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/partner_location_data.dart';
import '../utils/map_projection.dart';
import 'partner_map_picker_dialog.dart';

class PartnerLocationPicker extends StatelessWidget {
  const PartnerLocationPicker({
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
  final ValueChanged<PartnerLocationData> onLocationChanged;

  bool get _hasLocation => latitude != null && longitude != null;

  PartnerLocationData? get _currentLocation {
    if (!_hasLocation) return null;
    return PartnerLocationData(
      latitude: latitude!,
      longitude: longitude!,
      address: initialAddress,
      city: city,
      state: state,
    );
  }

  Future<void> _openMapPicker(BuildContext context) async {
    final result = await PartnerMapPickerDialog.open(
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
    return _LocationPreviewCard(
      apiKey: apiKey,
      hasLocation: _hasLocation,
      address: initialAddress,
      city: city,
      state: state,
      latitude: latitude,
      longitude: longitude,
      onTap: () => _openMapPicker(context),
    );
  }
}

class _LocationPreviewCard extends StatelessWidget {
  const _LocationPreviewCard({
    required this.apiKey,
    required this.hasLocation,
    required this.address,
    required this.city,
    required this.state,
    required this.latitude,
    required this.longitude,
    required this.onTap,
  });

  final String apiKey;
  final bool hasLocation;
  final String address;
  final String city;
  final String state;
  final double? latitude;
  final double? longitude;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasLocation
                    ? AppColors.primary.withValues(alpha: 0.25)
                    : AppColors.border,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasLocation)
                  Image.network(
                    buildStaticMapUrl(
                      apiKey: apiKey,
                      latitude: latitude!,
                      longitude: longitude!,
                      width: 640,
                      height: 240,
                      zoom: 15,
                      showMarker: true,
                    ),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const _MapPlaceholder(),
                  )
                else
                  const _MapPlaceholder(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.04),
                        Colors.black.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_rounded, size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          hasLocation ? 'Change' : 'Open map',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasLocation
                            ? (address.isNotEmpty ? address : 'Location pinned')
                            : 'Tap to pin location on map',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                      if (hasLocation) ...[
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (city.isNotEmpty) city,
                            if (state.isNotEmpty) state,
                          ].join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.background,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.map_outlined,
          size: 36,
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
