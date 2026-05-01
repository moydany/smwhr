import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Badge;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/badge.dart';
import '../../../data/models/event.dart';
import '../../../data/models/event_category.dart';
import '../../../data/models/lat_lng.dart';
import '../../../features/camera/widgets/badge_frame_overlay.dart';
import '../../../features/events/widgets/event_artwork.dart';

/// Wraps the BadgeFrameOverlay in a glow-bordered surface and renders
/// the post-capture composite. Defaults to the procedural EventArtwork
/// fallback (used in the profile collection grid where the captured
/// file isn't available locally); the reveal screen overrides with a
/// `FileImage` of the just-captured photo.
class BadgeCard extends StatelessWidget {
  final Badge badge;
  final bool dimmed; // mid-animation, before composite finishes
  final ImageProvider? photoOverride;

  const BadgeCard({
    super.key,
    required this.badge,
    this.dimmed = false,
    this.photoOverride,
  });

  @override
  Widget build(BuildContext context) {
    // Synthesise an Event from the badge metadata so BadgeFrameOverlay can
    // reuse its existing constructor. Once the real photo URL lands, we'll
    // pass it as `photo:` instead.
    final event = Event(
      id: badge.eventId,
      slug: badge.eventId,
      title: badge.eventTitle,
      artistName: badge.artistName,
      venueName: badge.venueName,
      city: badge.city,
      countryCode: badge.countryCode,
      startsAt: badge.eventDate,
      description: '',
      category: badge.category,
      geofencePolygon: const <LatLng>[],
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
        boxShadow: dimmed
            ? null
            : [
                BoxShadow(
                  color: _ambient(badge.category).withValues(alpha: 0.35),
                  blurRadius: 28,
                  spreadRadius: -2,
                ),
              ],
      ),
      child: BadgeFrameOverlay(
        event: event,
        photoSlot: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          child: photoOverride != null
              ? Image(image: photoOverride!, fit: BoxFit.cover)
              : badge.composedBadgeUrl != null
                  ? CachedNetworkImage(
                      imageUrl: badge.composedBadgeUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => EventArtwork(event: event, large: true),
                      errorWidget: (context, url, err) => EventArtwork(event: event, large: true),
                    )
                  : EventArtwork(event: event, large: true),
        ),
        serialLabel: 'SMWHR ${badge.serialLabel}',
        verified: true,
      ),
    );
  }

  static Color _ambient(EventCategory c) => switch (c) {
        EventCategory.music => AppColors.musicAmbient,
        EventCategory.sports => AppColors.sportsAmbient,
        EventCategory.festivals => AppColors.festivalsAmbient,
        EventCategory.outdoor => AppColors.outdoorAmbient,
        EventCategory.culture => AppColors.cultureAmbient,
      };
}
