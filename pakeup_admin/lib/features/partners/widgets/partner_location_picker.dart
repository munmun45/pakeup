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
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasLocation
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : AppColors.border,
                width: 1.2,
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
                      height: 280,
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
                        Colors.black.withValues(alpha: 0.02),
                        Colors.black.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasLocation
                              ? Icons.edit_location_alt_rounded
                              : Icons.map_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          hasLocation ? 'Edit on Map' : 'Select on Map',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            hasLocation
                                ? Icons.check_circle_rounded
                                : Icons.touch_app_rounded,
                            size: 15,
                            color: hasLocation ? AppColors.success : Colors.white70,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hasLocation
                                  ? (address.isNotEmpty
                                      ? address
                                      : 'Location pinned')
                                  : 'Tap to pin location on map',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (hasLocation) ...[
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 23),
                          child: Text(
                            [
                              if (city.isNotEmpty) city,
                              if (state.isNotEmpty) state,
                            ].join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.02),
            AppColors.secondary.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Grid pattern overlay for a high-tech mapping look
          Positioned.fill(
            child: GridPaper(
              color: AppColors.primary.withValues(alpha: 0.06),
              divisions: 1,
              subdivisions: 1,
              interval: 30,
              child: const SizedBox.expand(),
            ),
          ),
          // Pulsing location halo in the center
          Center(
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.06),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.location_searching_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
