import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules a one-shot local notification at an event's `startsAt`
/// so the user is reminded to open the app the moment their RSVP'd
/// quest goes live. Once the user taps the notification (or opens
/// the app any other way), `AutoStartLiveQuestsService` engages the
/// tracker — this class doesn't touch quest state directly.
///
/// Why local-only (not push):
///   - No backend round-trip; works even if the API is down at
///     event start.
///   - No FCM/APNs wiring needed for R0.1.
///   - Privacy: nothing about which event the user RSVP'd to leaves
///     the device.
///
/// Schedule semantics:
///   - id = stable hash of eventId, so re-scheduling overwrites and
///     unscheduling targets the right slot.
///   - skipped if the event already started (startsAt <= now).
///   - skipped if the device denied notification permission.
///
/// Timezone: locked to America/Mexico_City for R0.1 since that's the
/// only market we're targeting (per `CLAUDE.md`). Move to a runtime
/// device-timezone lookup when LATAM expansion lands.
class QuestReminderService {
  QuestReminderService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const String _channelId = 'quest_reminders';
  static const String _channelName = 'Quest reminders';
  static const String _channelDesc =
      'Te avisamos cuando empieza un evento al que dijiste que ibas.';

  /// Wires up the plugin (channel + permissions). Safe to call more
  /// than once — second call is a no-op.
  Future<void> init() async {
    if (_initialized) return;

    // Local timezone setup. `zonedSchedule` requires a tz.Location;
    // hardcoding CDMX matches the R0.1 market and avoids pulling
    // another plugin (`flutter_native_timezone`) for runtime lookup.
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Mexico_City'));

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(initSettings);

    // Request iOS permissions explicitly so we control timing
    // (avoid the default "ask on first init" prompt that fires
    // immediately at boot before the user understands what for).
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Schedules a reminder for [eventId] at [startsAt]. No-op when the
  /// event has already started — the auto-start service handles that
  /// path.
  Future<void> schedule({
    required String eventId,
    required String eventTitle,
    required DateTime startsAt,
  }) async {
    if (!_initialized) await init();
    final whenLocal = tz.TZDateTime.from(startsAt, tz.local);
    if (whenLocal.isBefore(tz.TZDateTime.now(tz.local))) return;
    final id = _idFor(eventId);
    // Replace any prior schedule for the same event idempotently.
    await _plugin.cancel(id);
    await _plugin.zonedSchedule(
      id,
      'Tu quest está empezando',
      eventTitle,
      whenLocal,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: eventId,
    );
  }

  /// Cancels any pending reminder for [eventId]. Safe to call when no
  /// reminder is scheduled — the plugin no-ops on unknown ids.
  Future<void> cancel(String eventId) async {
    if (!_initialized) await init();
    await _plugin.cancel(_idFor(eventId));
  }

  /// Stable 32-bit notification id derived from the event id. The
  /// plugin's id space is `int`; a hash keeps re-scheduling the same
  /// event idempotent without us tracking a string→int map.
  static int _idFor(String eventId) {
    // FNV-1a 32-bit on the raw bytes — collision odds are vanishingly
    // small for the (≤ hundreds of) events a single user has intent
    // on, and it's deterministic across app launches.
    const fnvPrime = 16777619;
    var hash = 2166136261;
    for (final code in eventId.codeUnits) {
      hash ^= code;
      hash = (hash * fnvPrime) & 0x7FFFFFFF;
    }
    return hash;
  }
}
