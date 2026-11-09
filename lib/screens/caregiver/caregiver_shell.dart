import 'dart:async';

import '../../models/alert_event.dart';
import '../../models/app_user.dart';
import '../../services/alarm_service.dart';
import '../../services/alert_notifications.dart';
import '../../services/alert_service.dart';
import '../../services/contact_launcher.dart';
import '../../ui.dart';
import '../shared/alert_prefs_card.dart';
import '../shared/history_screen.dart';
import '../shared/insights_screen.dart';
import '../shared/settings_screen.dart';
import 'caregiver_home_screen.dart';
import 'incoming_alert_screen.dart';

/// Caregiver app. Listens for live alerts from every linked patient and, the
/// moment one arrives, shows a lock-screen notification and opens the
/// incoming-alert screen. Works while the app is open or in the background;
/// if the app is fully closed this needs push (FCM + a server).
class CaregiverShell extends StatefulWidget {
  const CaregiverShell({super.key, required this.user});
  final AppUser user;
  @override
  State<CaregiverShell> createState() => _CaregiverShellState();
}

class _CaregiverShellState extends State<CaregiverShell> {
  StreamSubscription<List<AlertEvent>>? _sub;
  StreamSubscription<NotificationTap>? _taps;
  final _shown = <String>{};
  int _index = 0;

  static const _items = [
    NavItem(Icons.groups_outlined, 'People'),
    NavItem(Icons.history, 'History'),
    NavItem(Icons.bar_chart_outlined, 'Statistics'),
    NavItem(Icons.settings_outlined, 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    AlertNotifications.requestPermissions();
    applyAlertPrefs(widget.user);
    _sub = AlertService.instance.forCaregiver(widget.user.uid).listen(_onAlerts);
    _taps = AlertNotifications.taps.listen(_onTap);
  }

  @override
  void didUpdateWidget(CaregiverShell old) {
    super.didUpdateWidget(old);
    applyAlertPrefs(widget.user);
  }

  void _open(String alertId) {
    if (!mounted || IncomingAlertScreen.openIds.contains(alertId)) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => IncomingAlertScreen(caregiver: widget.user, alertId: alertId),
    ));
  }

  void _onAlerts(List<AlertEvent> alerts) {
    for (final a in alerts) {
      final fresh = DateTime.now().difference(a.startedAt) < AppConstants.staleAlertAge;
      if (a.status == AlertStatus.active && fresh && _shown.add(a.id)) {
        AlertNotifications.caregiverAlert(alertId: a.id, patientName: a.patientName, startedAt: a.startedAt);
        _open(a.id);
      }
      if (!a.status.isLive) AlertNotifications.cancel(AlertNotifications.caregiverNotificationId(a.id));
    }
  }

  void _onTap(NotificationTap t) {
    final id = t.alertId;
    if (id == null) return;
    if (t.action == AlertNotifications.actRespond) {
      AlertService.instance.respond(id, widget.user).catchError((_) {});
    }
    if (t.action == AlertNotifications.actCall) {
      AlarmService.instance.stopAll();
      ContactLauncher.call(AppConstants.emergencyNumber);
      return;
    }
    _open(id);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _taps?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return AppShell(
      items: _items,
      index: _index,
      onSelect: (i) => setState(() => _index = i),
      pages: [
        CaregiverHomeScreen(user: u),
        HistoryScreen(user: u),
        InsightsScreen(user: u),
        SettingsScreen(user: u),
      ],
    );
  }
}
