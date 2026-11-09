import 'dart:async';

import '../../models/app_user.dart';
import '../../services/alert_notifications.dart';
import '../../services/device_service.dart';
import '../../services/emergency_caller.dart';
import '../../ui.dart';
import '../shared/alert_prefs_card.dart';
import '../shared/history_screen.dart';
import '../shared/insights_screen.dart';
import '../shared/settings_screen.dart';
import 'live_monitor_screen.dart';
import 'patient_home_screen.dart';
import 'seizure_alert_screen.dart';

class PatientShell extends StatefulWidget {
  const PatientShell({super.key, required this.user});
  final AppUser user;
  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  final _device = DeviceService.instance;
  StreamSubscription<Detection>? _sub;
  int _index = 0;
  bool _alertOpen = false;

  static const _items = [
    NavItem(Icons.home_outlined, 'Home'),
    NavItem(Icons.monitor_heart_outlined, 'Monitor'),
    NavItem(Icons.history, 'History'),
    NavItem(Icons.bar_chart_outlined, 'Statistics'),
    NavItem(Icons.settings_outlined, 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    AlertNotifications.requestPermissions().then((_) => EmergencyCaller.requestPermission());
    _syncDevice();
    _sub = _device.detections.listen(_onDetection);
  }

  @override
  void didUpdateWidget(PatientShell old) {
    super.didUpdateWidget(old);
    _syncDevice();
  }

  void _syncDevice() {
    final u = widget.user;
    applyAlertPrefs(u);
    if (u.devicePaired) {
      _device.start(
        uid: u.uid,
        thresholds: u.thresholds,
        sensitivity: u.sensitivity,
        cushionArmed: u.cushionArmed,
      );
    } else if (_device.running) {
      _device.stop();
    }
  }

  Future<void> _onDetection(Detection d) async {
    if (_alertOpen || !mounted) return;
    _alertOpen = true;
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => SeizureAlertScreen(patient: widget.user, detection: d),
    ));
    _alertOpen = false;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _device.stop();
    super.dispose();
  }

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return AppShell(
      items: _items,
      index: _index,
      onSelect: _go,
      pages: [
        PatientHomeScreen(user: u, onOpenMonitor: () => _go(1), onOpenHistory: () => _go(2)),
        LiveMonitorScreen(user: u),
        HistoryScreen(user: u),
        InsightsScreen(user: u),
        SettingsScreen(user: u),
      ],
    );
  }
}
