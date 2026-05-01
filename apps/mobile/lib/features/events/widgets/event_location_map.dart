import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/event.dart';
import '../../../data/models/lat_lng.dart' as smwhr;

/// Compact venue preview embedded under "What you'll earn" on the event
/// detail screen.
///
/// Renders an interactive dark-themed tile map centered on the event's
/// geofence centroid, with a magenta pin and a tappable footer that
/// hands off to Apple Maps (or Google Maps on Android) via the system
/// `maps:` / `geo:` schemes — no API key, no Google plugin, just a
/// `url_launcher` deep-link.
///
/// Tiles: CartoDB Positron-Dark (free, no key required for low-volume
/// use). Attribution lives in the bottom-right of the map per the
/// terms. If the event has no polygon yet (offline cache miss before
/// any successful fetch), the widget renders nothing — the rest of the
/// screen still works.
class EventLocationMap extends StatelessWidget {
  final Event event;

  /// Visual height of the map tile. Wide-aspect by default; the
  /// surrounding card hugs it.
  final double height;

  const EventLocationMap({
    super.key,
    required this.event,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    final center = _polygonCentroid(event.geofencePolygon);
    if (center == null) return const SizedBox.shrink();

    final mapCenter = ll.LatLng(center.latitude, center.longitude);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                fm.FlutterMap(
                  options: fm.MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: 16,
                    interactionOptions: const fm.InteractionOptions(
                      // Disable rotation/zoom inside the card — the
                      // user uses the "Open in Maps" CTA below to
                      // explore. Keeps the preview from hijacking
                      // vertical scroll on the detail page.
                      flags: fm.InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    fm.TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      retinaMode: MediaQuery.of(context).devicePixelRatio > 1.5,
                      userAgentPackageName: 'quest.smwhr.app',
                    ),
                    fm.MarkerLayer(
                      markers: [
                        fm.Marker(
                          point: mapCenter,
                          width: 36,
                          height: 36,
                          alignment: Alignment.topCenter,
                          child: const _Pin(),
                        ),
                      ],
                    ),
                  ],
                ),
                // Subtle dark vignette over the tiles so the magenta
                // pin pops and the card edges feel intentional.
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.bg.withValues(alpha: 0.18),
                        ],
                      ),
                    ),
                  ),
                ),
                // Tap layer — opens external Maps app. Sits ON TOP of
                // the map but BELOW the pin so the visual hierarchy
                // stays right.
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openExternalMap(
                        center: center,
                        venueName: event.venueName,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _OpenInMapsRow(
          venueName: event.venueName,
          center: center,
        ),
      ],
    );
  }

  /// Picks the centroid of the polygon's vertices. Tested against the
  /// 4-vertex squares the seed produces; for irregular polygons it's
  /// still a reasonable visual center.
  static smwhr.LatLng? _polygonCentroid(List<smwhr.LatLng> polygon) {
    if (polygon.isEmpty) return null;
    var sumLat = 0.0;
    var sumLng = 0.0;
    for (final p in polygon) {
      sumLat += p.latitude;
      sumLng += p.longitude;
    }
    return smwhr.LatLng(sumLat / polygon.length, sumLng / polygon.length);
  }
}

class _Pin extends StatelessWidget {
  const _Pin();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.55),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.location_on_rounded,
        size: 36,
        color: AppColors.accent,
      ),
    );
  }
}

class _OpenInMapsRow extends StatelessWidget {
  final String venueName;
  final smwhr.LatLng center;
  const _OpenInMapsRow({required this.venueName, required this.center});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          _openExternalMap(center: center, venueName: venueName),
      borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                venueName,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              Platform.isIOS ? 'Abrir en Apple Maps' : 'Abrir en Maps',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_outward_rounded,
              size: 14,
              color: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}

/// Hands off to the platform's preferred map app:
///
///   - iOS: `maps://?ll=lat,lng&q=<venue>` opens Apple Maps natively.
///   - Android / other: `geo:lat,lng?q=lat,lng(venue)` opens whichever
///     map app the user picked as default (typically Google Maps).
///
/// Wraps in haptic feedback so the tap registers physically.
Future<void> _openExternalMap({
  required smwhr.LatLng center,
  required String venueName,
}) async {
  HapticFeedback.lightImpact();
  final lat = center.latitude;
  final lng = center.longitude;
  final encodedName = Uri.encodeComponent(venueName);

  final Uri primary;
  final Uri fallback;
  if (Platform.isIOS || Platform.isMacOS) {
    primary = Uri.parse('maps://?ll=$lat,$lng&q=$encodedName');
    fallback = Uri.parse('https://maps.apple.com/?ll=$lat,$lng&q=$encodedName');
  } else {
    primary = Uri.parse('geo:$lat,$lng?q=$lat,$lng($encodedName)');
    fallback =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
  }

  if (await canLaunchUrl(primary)) {
    await launchUrl(primary, mode: LaunchMode.externalApplication);
    return;
  }
  await launchUrl(fallback, mode: LaunchMode.externalApplication);
}
