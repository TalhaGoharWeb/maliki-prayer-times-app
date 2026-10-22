import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:malikiprayertimes/engine/coordinates.dart';
import 'package:malikiprayertimes/engine/prayer_times.dart';
import 'package:malikiprayertimes/l10n/app_localizations.dart';
import 'package:malikiprayertimes/services/battery_service.dart';
import 'package:malikiprayertimes/services/notification_service.dart';
import 'package:malikiprayertimes/services/settings_service.dart';
import 'package:malikiprayertimes/services/timezone_service.dart';
import 'package:malikiprayertimes/utils/digits.dart';

/// Notification settings section for the settings screen.
///
/// Owned by Track A (notifications). The coordinator embeds this widget into
/// `settings_screen.dart` itself — this file never edits any screen.
///
/// Contents: notification-permission status row with a request button,
/// Android exact-alarm status row (with an honest "may arrive late" note when
/// exact alarms are denied, and a button opening the system settings),
/// per-prayer toggles (including sunrise, labeled as a timetable marker),
/// the pre-prayer reminder offset picker, and honest plain-language notes
/// about Android Doze/battery-optimization and iOS background limits:
/// delivery is best-effort and the app does not promise exact delivery on
/// locked or aggressively-optimized phones.
///
/// Times are scheduled from [SettingsService.effectiveProfile] (the same
/// profile the home screen displays) through [SettingsService.adjustedTime],
/// minus the reminder offset.
class NotificationSettingsSection extends StatefulWidget {
  final NotificationService notifications;
  final SettingsService settings;
  final Coordinates coordinates;
  final Duration timeZoneOffset;

  /// IANA zone id the schedule renders in (per-date offsets resolve from
  /// it). Null = legacy constructor-offset behavior.
  final String? zoneId;

  /// Observer elevation in meters for the horizon dip correction.
  final double elevationMeters;

  const NotificationSettingsSection({
    super.key,
    required this.notifications,
    required this.settings,
    required this.coordinates,
    required this.timeZoneOffset,
    this.zoneId,
    this.elevationMeters = 0.0,
  });

  @override
  State<NotificationSettingsSection> createState() =>
      _NotificationSettingsSectionState();
}

class _NotificationSettingsSectionState
    extends State<NotificationSettingsSection> {
  late Future<bool> _permissionFuture;
  late Future<bool> _exactAlarmFuture;
  late Future<int> _pendingFuture;
  late Future<ScheduleReport?> _reportFuture;
  late Future<({String error, DateTime atUtc})?> _errorFuture;
  late Future<bool?> _batteryFuture;

  @override
  void initState() {
    super.initState();
    _refreshStatuses();
  }

  void _refreshStatuses() {
    _permissionFuture = widget.notifications.areNotificationsEnabled();
    _exactAlarmFuture = widget.notifications.canScheduleExactAlarms();
    _pendingFuture = widget.notifications.pendingScheduledCount();
    _reportFuture = widget.notifications.lastScheduleReport();
    _errorFuture = widget.notifications.lastScheduleError();
    _batteryFuture = BatteryService.isIgnoringBatteryOptimizations();
  }

  String _prayerLabel(AppLocalizations l10n, Prayer p) => switch (p) {
        Prayer.fajr => l10n.prayerFajr,
        Prayer.sunrise => l10n.prayerSunrise,
        Prayer.dhuhr => l10n.prayerDhuhr,
        Prayer.asr => l10n.prayerAsr,
        Prayer.maghrib => l10n.prayerMaghrib,
        Prayer.isha => l10n.prayerIsha,
      };

  NotificationTexts _texts(AppLocalizations l10n) => NotificationTexts(
        titleFor: (p) => l10n.notifTitle(_prayerLabel(l10n, p)),
        bodyFor: (p) => l10n.notifBody(_prayerLabel(l10n, p)),
        reminderTitleFor: (p, m) =>
            l10n.notifReminderTitle(_prayerLabel(l10n, p), '$m'),
        reminderBodyFor: (p, m) =>
            l10n.notifReminderBody(_prayerLabel(l10n, p), '$m'),
      );

  Future<void> _reschedule(AppLocalizations l10n) async {
    try {
      final zoneId = widget.zoneId;
      await widget.notifications.rescheduleAll(
        coords: widget.coordinates,
        profile: widget.settings.effectiveProfile,
        settings: widget.settings,
        timeZoneOffset: zoneId == null
            ? widget.timeZoneOffset
            : TimezoneService.offsetFor(zoneId, DateTime.now()),
        timeZoneOffsetForDate: zoneId == null
            ? null
            : (date) => TimezoneService.offsetFor(zoneId, date),
        elevationMeters: widget.elevationMeters,
        texts: _texts(l10n),
      );
    } catch (e) {
      // Recorded as well as shown: the delivery-status card below keeps
      // the failure visible (with its text) after the snackbar is gone.
      await widget.notifications.recordScheduleError(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.notificationScheduleError)),
        );
      }
    }
    // The armed-alert count changes with every reschedule; re-read it so
    // the diagnostic card below reflects the schedule just written.
    if (mounted) setState(_refreshStatuses);
  }

  Future<void> _onToggle(
      AppLocalizations l10n, Prayer prayer, bool value) async {
    await widget.settings.setNotificationEnabled(prayer, value);
    await _reschedule(l10n);
  }

  Future<void> _onOffsetChanged(AppLocalizations l10n, int? minutes) async {
    if (minutes == null) return;
    await widget.settings.setReminderOffsetMinutes(minutes);
    await _reschedule(l10n);
  }

  Widget _permissionCard(AppLocalizations l10n, ThemeData theme) {
    return Card(
      child: FutureBuilder<bool>(
        future: _permissionFuture,
        builder: (context, snapshot) {
          final granted = snapshot.data ?? false;
          return ListTile(
            leading: Icon(
              granted ? Icons.notifications_active : Icons.notifications_off,
            ),
            title: Text(l10n.notificationPermissionTitle),
            subtitle: Text(
              granted ? l10n.permissionGranted : l10n.permissionNotGranted,
              style: theme.textTheme.bodySmall,
            ),
            trailing: granted
                ? null
                : TextButton(
                    onPressed: () async {
                      await widget.notifications.requestPermissions();
                      setState(_refreshStatuses);
                    },
                    child: Text(l10n.requestPermissionButton),
                  ),
          );
        },
      ),
    );
  }

  Widget _exactAlarmCard(AppLocalizations l10n, ThemeData theme) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    return Card(
      child: FutureBuilder<bool>(
        future: _exactAlarmFuture,
        builder: (context, snapshot) {
          final allowed = snapshot.data ?? false;
          return ListTile(
            leading: Icon(
              allowed ? Icons.alarm_on : Icons.alarm_off,
            ),
            title: Text(l10n.exactAlarmTitle),
            subtitle: Text(
              allowed ? l10n.exactAlarmGranted : l10n.exactAlarmDenied,
              style: theme.textTheme.bodySmall,
            ),
            trailing: allowed
                ? null
                : TextButton(
                    onPressed: () async {
                      await widget.notifications.openExactAlarmSettings();
                      setState(_refreshStatuses);
                    },
                    child: Text(l10n.openExactAlarmSettingsButton),
                  ),
          );
        },
      ),
    );
  }

  /// Delivery status: what the phone actually holds right now. The armed
  /// count is read back from the platform (a week of prayers is dozens;
  /// zero means scheduling itself is broken, while a healthy count with
  /// nothing arriving points at the phone's battery manager). Below it,
  /// the persisted report of the last scheduling pass — next alert and
  /// when it was armed — and any recorded scheduling failure, so one
  /// screenshot of this screen shows the whole delivery state.
  Widget _scheduledCard(AppLocalizations l10n, ThemeData theme) {
    final lang = Localizations.localeOf(context).languageCode;
    final use24 = widget.settings.use24Hour;
    String at(DateTime utc) => formatPrayerTime(utc.toLocal(), lang,
        use24Hour: use24);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule, size: 20),
                const SizedBox(width: 8),
                Text(l10n.scheduledAlertsTitle,
                    style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            FutureBuilder<int>(
              future: _pendingFuture,
              builder: (context, snapshot) {
                final count = snapshot.data;
                return Text(
                  count == null
                      ? '…'
                      : l10n.scheduledAlertsBody(
                          localizeDigits('$count', lang)),
                  style: theme.textTheme.bodySmall,
                );
              },
            ),
            FutureBuilder<ScheduleReport?>(
              future: _reportFuture,
              builder: (context, snapshot) {
                final report = snapshot.data;
                if (report == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (report.nextPrayer != null &&
                        report.nextFireUtc != null)
                      Text(
                        l10n.nextAlertLabel(
                          _prayerLabel(l10n, report.nextPrayer!),
                          at(report.nextFireUtc!),
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    Text(
                      l10n.lastScheduledLabel(at(report.scheduledAtUtc)),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                );
              },
            ),
            FutureBuilder<({String error, DateTime atUtc})?>(
              future: _errorFuture,
              builder: (context, snapshot) {
                final failure = snapshot.data;
                if (failure == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${l10n.scheduleErrorTitle} — '
                    '${l10n.scheduleErrorBody(failure.error)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Battery-protection card (Android only): the state of the app's
  /// battery-optimization exemption plus one-tap routes to fix it. On
  /// phones whose battery managers freeze background apps, this — not
  /// anything in the scheduling code — is what decides whether prayer
  /// alerts can wake the phone.
  Widget _batteryCard(AppLocalizations l10n, ThemeData theme) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.battery_saver, size: 20),
                const SizedBox(width: 8),
                Text(l10n.batteryTitle, style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            Text(l10n.batteryBody, style: theme.textTheme.bodySmall),
            FutureBuilder<bool?>(
              future: _batteryFuture,
              builder: (context, snapshot) {
                final ignoring = snapshot.data;
                if (ignoring == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    ignoring ? l10n.batteryAllowed : l10n.batteryRestricted,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: ignoring ? null : theme.colorScheme.error,
                    ),
                  ),
                );
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    await BatteryService.openAppSettings();
                    setState(_refreshStatuses);
                  },
                  child: Text(l10n.appSettingsButton),
                ),
                TextButton(
                  onPressed: () async {
                    await BatteryService.requestIgnoreBatteryOptimizations();
                    setState(_refreshStatuses);
                  },
                  child: Text(l10n.batteryAllowButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Locked-phone probe: a test adhan 2 minutes out, sent through the
  /// same scheduled path as a real prayer alert. The 5-second test only
  /// proves the foreground path; this one proves (or disproves)
  /// background delivery on the user's actual phone.
  Future<void> _sendProbe(AppLocalizations l10n) async {
    final enabled = await widget.notifications.areNotificationsEnabled();
    if (!mounted) return;
    if (!enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.testNotificationNoPermission)),
      );
      return;
    }
    try {
      await widget.notifications.sendTestNotification(
        title: l10n.testNotificationTitle,
        body: l10n.testNotificationBody,
        delay: const Duration(minutes: 2),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.probeTestSent)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.notificationScheduleError)),
      );
    }
  }

  Widget _probeCard(AppLocalizations l10n, ThemeData theme) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.lock),
        title: Text(l10n.probeTestTitle),
        subtitle: Text(
          l10n.probeTestHint,
          style: theme.textTheme.bodySmall,
        ),
        trailing: TextButton(
          onPressed: () => _sendProbe(l10n),
          child: Text(l10n.probeTestSend),
        ),
      ),
    );
  }

  Future<void> _sendTest(AppLocalizations l10n) async {
    final enabled = await widget.notifications.areNotificationsEnabled();
    if (!mounted) return;
    if (!enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.testNotificationNoPermission)),
      );
      return;
    }
    try {
      await widget.notifications.sendTestNotification(
        title: l10n.testNotificationTitle,
        body: l10n.testNotificationBody,
      );
      if (!mounted) return;
      final exact = await widget.notifications.canScheduleExactAlarms();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(exact
              ? l10n.testNotificationSent
              : l10n.testNotificationSentInexact),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.notificationScheduleError)),
      );
    }
  }

  Widget _testCard(AppLocalizations l10n, ThemeData theme) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.volume_up),
        title: Text(l10n.testNotificationTitle),
        subtitle: Text(
          l10n.testNotificationHint,
          style: theme.textTheme.bodySmall,
        ),
        trailing: TextButton(
          onPressed: () => _sendTest(l10n),
          child: Text(l10n.testNotificationSend),
        ),
      ),
    );
  }

  Widget _toggleRow(
      AppLocalizations l10n, SettingsService settings, Prayer prayer) {
    return SwitchListTile(
      title: Text(l10n.notifyPrayerLabel(_prayerLabel(l10n, prayer))),
      subtitle: prayer == Prayer.sunrise
          ? Text(
              l10n.timetableMarkerNote,
              style: Theme.of(context).textTheme.bodySmall,
            )
          : null,
      value: settings.notificationToggles[prayer] ?? true,
      onChanged: (value) => _onToggle(l10n, prayer, value),
    );
  }

  Widget _offsetPicker(
      AppLocalizations l10n, ThemeData theme, SettingsService settings) {
    final lang = Localizations.localeOf(context).languageCode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: DropdownButtonFormField<int>(
          initialValue: settings.reminderOffsetMinutes,
          decoration: InputDecoration(
            border: InputBorder.none,
            labelText: l10n.reminderOffsetLabel,
          ),
          items: SettingsService.allowedReminderOffsets
              .map(
                (m) => DropdownMenuItem<int>(
                  value: m,
                  child: Text(m == 0
                      ? l10n.reminderOffsetOptionNone
                      // Digit-localized for `ar` (Arabic-Indic) so the
                      // options never show raw Western digits.
                      : l10n.reminderOffsetOptionMinutes(
                          localizeDigits('$m', lang))),
                ),
              )
              .toList(),
          onChanged: (m) => _onOffsetChanged(l10n, m),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        final settings = widget.settings;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.notificationsSection,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              l10n.notificationsIntro,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            _permissionCard(l10n, theme),
            _exactAlarmCard(l10n, theme),
            _scheduledCard(l10n, theme),
            Card(
              child: Column(
                children: [
                  for (final p in Prayer.values) _toggleRow(l10n, settings, p),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _offsetPicker(l10n, theme, settings),
            const SizedBox(height: 4),
            _testCard(l10n, theme),
            const SizedBox(height: 4),
            _probeCard(l10n, theme),
            const SizedBox(height: 4),
            _batteryCard(l10n, theme),
            if (isAndroid)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.androidDeliveryNote,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            if (isIOS)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.iosDeliveryNote,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
