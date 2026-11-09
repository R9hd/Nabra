import '../../models/app_user.dart';
import '../../services/device_service.dart';
import '../../ui.dart';

/// Blueprint "Live monitor": real-time biosignals + seizure risk.
class LiveMonitorScreen extends StatelessWidget {
  const LiveMonitorScreen({super.key, required this.user});
  final AppUser user;

  static const _signalBars = 20;

  @override
  Widget build(BuildContext context) {
    final device = DeviceService.instance;
    return Scaffold(
      appBar: NabraAppBar(title: 'Live monitor', initial: user.initial),
      body: ListenableBuilder(
        listenable: device,
        builder: (context, _) {
          final v = device.latest;
          if (!user.devicePaired || v == null) {
            return const ResponsiveBody(children: [
              EmptyState(
                icon: Icons.sensors_off_outlined,
                title: 'No live data',
                body: 'Pair your collar from Home to see live vitals.',
              ),
            ]);
          }
          final history = device.history;
          final motion = history.reversed.take(_signalBars).toList().reversed.map((e) => e.motion).toList();
          return ResponsiveBody(children: [
            HeartRateCard(hr: v.hr, trend: history.map((e) => e.hr).toList()),
            TileGrid(children: [
              RiskTile(risk: device.risk),
              VitalTile(
                label: 'Motion',
                value: v.motionLabel,
                sub: v.motionState.name == 'normal' ? 'no abnormal pattern' : 'IMU ${(v.motion * 100).round()}%',
                chip: StatusChip(labelFor(v.motionState, normal: 'Calm'), tone: toneFor(v.motionState)),
              ),
            ]),
            VitalsGrid(vitals: v, thresholds: user.thresholds, includeHr: false),
            NabraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionLabel('Motion signal (last ${_signalBars}s)'),
                  const Gap(AppSpacing.sm),
                  MiniBars(values: motion),
                ],
              ),
            ),
            NabraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: withGaps([
                  const SectionLabel('Demo controls'),
                  Text('Simulate events to show detection, alarms and caregiver alerts.', style: AppText.small),
                  NabraButton.alert(
                    label: 'Simulate seizure (demo)',
                    icon: Icons.bolt,
                    onPressed: device.alertActive ? null : device.simulateSeizure,
                  ),
                  NabraButton.ghost(
                    label: 'Simulate low SpO2 (demo)',
                    icon: Icons.air,
                    small: true,
                    onPressed: device.alertActive ? null : device.simulateLowSpo2,
                  ),
                ], AppSpacing.md - 2),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class HeartRateCard extends StatelessWidget {
  const HeartRateCard({super.key, required this.hr, required this.trend, this.live = true});
  final double hr;
  final List<double> trend;
  final bool live;

  @override
  Widget build(BuildContext context) => NabraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: SectionLabel('Heart rate')),
                if (live) const StatusChip('● Live', tone: Tone.alert),
              ],
            ),
            const Gap(AppSpacing.xs),
            Text.rich(TextSpan(children: [
              TextSpan(text: Fmt.num0(hr), style: AppText.display),
              TextSpan(text: ' bpm', style: AppText.small),
            ])),
            const Gap(AppSpacing.xs),
            Sparkline(values: trend),
          ],
        ),
      );
}
