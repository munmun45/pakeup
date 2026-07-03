import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../../core/theme/app_theme.dart';
import '../models/partner_location_data.dart';
import '../utils/google_maps_picker_html.dart';

class PartnerWebMapView extends StatefulWidget {
  const PartnerWebMapView({
    super.key,
    required this.apiKey,
    this.latitude,
    this.longitude,
    required this.onLocationChanged,
  });

  final String apiKey;
  final double? latitude;
  final double? longitude;
  final ValueChanged<PartnerLocationData> onLocationChanged;

  @override
  State<PartnerWebMapView> createState() => _PartnerWebMapViewState();
}

class _PartnerWebMapViewState extends State<PartnerWebMapView> {
  WebviewController? _controller;
  StreamSubscription? _messageSub;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (kIsWeb || !Platform.isWindows) {
      setState(() {
        _error = 'Interactive map requires the Windows desktop app.';
      });
      return;
    }

    try {
      final version = await WebviewController.getWebViewVersion();
      if (version == null) {
        throw StateError(
          'Install Microsoft Edge WebView2 Runtime to use the map picker.',
        );
      }

      final controller = WebviewController();
      await controller.initialize();
      await controller.setBackgroundColor(Colors.white);
      await controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      await controller.setZoomFactor(1.0);

      _messageSub = controller.webMessage.listen((message) {
        try {
          final map = message is String
              ? jsonDecode(message) as Map<String, dynamic>
              : message as Map<String, dynamic>;
          widget.onLocationChanged(PartnerLocationData.fromJson(map));
        } catch (_) {}
      });

      final html = buildGoogleMapsPickerHtml(
        widget.apiKey,
        latitude: widget.latitude,
        longitude: widget.longitude,
      );
      await controller.loadStringContent(html);

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _ready = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
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
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (!_ready || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }

    return Webview(_controller!);
  }
}
