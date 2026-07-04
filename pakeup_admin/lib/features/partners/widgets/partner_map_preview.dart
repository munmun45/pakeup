import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../utils/map_projection.dart';
import '../utils/partner_map_utils.dart';

/// Read-only map preview with lat/lng Google Maps link.
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

  bool get _hasCoords => latitude != null && longitude != null;

  String? get _mapsUrl => _hasCoords
      ? PartnerMapUtils.googleMapsUrl(latitude!, longitude!)
      : null;

  Future<void> _openExternal(BuildContext context) async {
    final url = PartnerMapUtils.externalMapsUrl(
      googleMapEmbed: googleMapEmbed,
      latitude: latitude,
      longitude: longitude,
    );
    if (url == null) return;

    final uri = Uri.parse(url);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        AppSnackBar.error(context, 'Could not open Google Maps');
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackBar.error(context, 'Could not open Google Maps');
      }
    }
  }

  Future<void> _copyUrl(BuildContext context) async {
    final url = _mapsUrl;
    if (url == null) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      AppSnackBar.success(context, 'Google Maps link copied');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCoords = _hasCoords;
    final apiKey = Env.googleMapsApiKey;
    final mapsUrl = _mapsUrl;
    final mapHeight = hasCoords && mapsUrl != null ? height - 44 : height;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: mapHeight,
            width: double.infinity,
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
                          height: mapHeight.round().clamp(100, 640),
                          zoom: 15,
                          showMarker: true,
                        ),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _CoordsMapFallback(
                          latitude: latitude,
                          longitude: longitude,
                          mapsUrl: mapsUrl!,
                          onOpen: () => _openExternal(context),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _OpenMapButton(
                          onTap: () => _openExternal(context),
                        ),
                      ),
                    ],
                  )
                : hasCoords
                    ? _CoordsMapFallback(
                        latitude: latitude,
                        longitude: longitude,
                        mapsUrl: mapsUrl!,
                        onOpen: () => _openExternal(context),
                      )
                    : _EmptyMapPlaceholder(
                        hasEmbed: PartnerMapUtils.extractEmbedUrl(
                              googleMapEmbed,
                            ) !=
                            null,
                      ),
          ),
          if (hasCoords && mapsUrl != null)
            _MapsUrlBar(
              url: mapsUrl,
              onOpen: () => _openExternal(context),
              onCopy: () => _copyUrl(context),
            ),
        ],
      ),
    );
  }
}

class _MapsUrlBar extends StatelessWidget {
  const _MapsUrlBar({
    required this.url,
    required this.onOpen,
    required this.onCopy,
  });

  final String url;
  final VoidCallback onOpen;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.link_rounded,
                size: 16,
                color: AppColors.primary.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.primary,
                  ),
                ),
              ),
              IconButton(
                onPressed: onCopy,
                tooltip: 'Copy link',
                icon: const Icon(Icons.copy_rounded, size: 16),
                color: AppColors.textSecondary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              ),
              IconButton(
                onPressed: onOpen,
                tooltip: 'Open in Google Maps',
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                color: AppColors.primary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              ),
            ],
          ),
        ),
      ),
    );
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
              Icon(Icons.open_in_new, size: 14, color: AppColors.primary),
              SizedBox(width: 4),
              Text(
                'Open Map',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoordsMapFallback extends StatelessWidget {
  const _CoordsMapFallback({
    required this.latitude,
    required this.longitude,
    required this.mapsUrl,
    required this.onOpen,
  });

  final double? latitude;
  final double? longitude;
  final String mapsUrl;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.1),
                AppColors.secondary.withValues(alpha: 0.06),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on_rounded,
                    size: 38, color: AppColors.primary),
                if (latitude != null && longitude != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.map_rounded, size: 18),
                  label: const Text('Open in Google Maps'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: _OpenMapButton(onTap: onOpen),
        ),
      ],
    );
  }
}

class _EmptyMapPlaceholder extends StatelessWidget {
  const _EmptyMapPlaceholder({required this.hasEmbed});

  final bool hasEmbed;

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
            hasEmbed
                ? 'Set latitude & longitude to show map link'
                : 'Set location coordinates to preview map',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
