import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/app_theme.dart';
import '../utils/map_projection.dart';
import '../utils/partner_map_utils.dart';

/// Read-only map preview — static image embed, no WebView (no scroll zoom).
class PartnerMapPreview extends StatelessWidget {
  const PartnerMapPreview({
    super.key,
    this.googleMapEmbed,
    this.latitude,
    this.longitude,
    this.height = 220,
  });

  final String? googleMapEmbed;
  final double? latitude;
  final double? longitude;
  final double height;

  @override
  Widget build(BuildContext context) {
    final hasCoords = latitude != null && longitude != null;
    final apiKey = Env.googleMapsApiKey;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasCoords && apiKey != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  buildStaticMapUrl(
                    apiKey: apiKey,
                    latitude: latitude!,
                    longitude: longitude!,
                    width: 640,
                    height: height.round().clamp(100, 640),
                    zoom: 15,
                    showMarker: true,
                  ),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _FallbackMapCard(
                    latitude: latitude,
                    longitude: longitude,
                    onOpen: () => _openExternal(),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _OpenMapButton(onTap: () => _openExternal()),
                ),
              ],
            )
          : _EmptyMapPlaceholder(
              hasCoords: hasCoords,
              hasEmbed: PartnerMapUtils.extractEmbedUrl(googleMapEmbed) != null,
              onOpen: hasCoords ? () => _openExternal() : null,
            ),
    );
  }

  Future<void> _openExternal() async {
    final url = PartnerMapUtils.externalMapsUrl(
      googleMapEmbed: googleMapEmbed,
      latitude: latitude,
      longitude: longitude,
    );
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _OpenMapButton extends StatelessWidget {
  const _OpenMapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.open_in_new, size: 14),
              SizedBox(width: 4),
              Text(
                'Open Map',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMapPlaceholder extends StatelessWidget {
  const _EmptyMapPlaceholder({
    required this.hasCoords,
    required this.hasEmbed,
    this.onOpen,
  });

  final bool hasCoords;
  final bool hasEmbed;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          const Text(
            'Map preview',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            hasCoords
                ? 'Add GOOGLE_MAPS_API_KEY to show map preview'
                : 'Set location to preview map',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          if (onOpen != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.map_rounded, size: 18),
              label: const Text('Open in Google Maps'),
            ),
          ],
        ],
      ),
    );
  }
}

class _FallbackMapCard extends StatelessWidget {
  const _FallbackMapCard({
    required this.latitude,
    required this.longitude,
    required this.onOpen,
  });

  final double? latitude;
  final double? longitude;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.secondary.withValues(alpha: 0.06),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, size: 36, color: AppColors.primary),
            if (latitude != null && longitude != null) ...[
              const SizedBox(height: 8),
              Text(
                '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.map_rounded, size: 18),
              label: const Text('Open in Google Maps'),
            ),
          ],
        ),
      ),
    );
  }
}
