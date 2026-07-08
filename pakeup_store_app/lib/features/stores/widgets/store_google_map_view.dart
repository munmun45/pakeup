import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../core/theme/app_theme.dart';
import '../models/store_location_data.dart';
import '../utils/google_maps_picker_html.dart';

class StoreGoogleMapView extends StatefulWidget {
  const StoreGoogleMapView({
    super.key,
    required this.apiKey,
    this.latitude,
    this.longitude,
    required this.onLocationChanged,
  });

  final String apiKey;
  final double? latitude;
  final double? longitude;
  final ValueChanged<StoreLocationData> onLocationChanged;

  @override
  State<StoreGoogleMapView> createState() => _StoreGoogleMapViewState();
}

class _StoreGoogleMapViewState extends State<StoreGoogleMapView> {
  late final WebViewController _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..addJavaScriptChannel(
          'LocationChannel',
          onMessageReceived: (message) {
            try {
              final map =
                  jsonDecode(message.message) as Map<String, dynamic>;
              widget.onLocationChanged(StoreLocationData.fromJson(map));
            } catch (_) {}
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) setState(() => _ready = true);
            },
            onWebResourceError: (error) {
              if (!mounted) return;
              setState(
                () => _error = error.description.isNotEmpty
                    ? error.description
                    : 'Failed to load Google Maps',
              );
            },
          ),
        );

      final platform = _controller.platform;
      if (platform is AndroidWebViewController) {
        await platform.setMediaPlaybackRequiresUserGesture(false);
      }

      await _controller.loadHtmlString(
        buildGoogleMapsPickerHtml(
          widget.apiKey,
          latitude: widget.latitude,
          longitude: widget.longitude,
        ),
        baseUrl: 'https://maps.googleapis.com',
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 42, color: Colors.grey.shade400),
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (!_ready) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }

    return WebViewWidget(controller: _controller);
  }
}
