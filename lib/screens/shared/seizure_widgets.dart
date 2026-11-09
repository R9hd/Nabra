import '../../services/contact_launcher.dart';
import '../../ui.dart';

/// Big seizure stopwatch with progress toward the 5-minute emergency mark.
class SeizureClock extends StatelessWidget {
  const SeizureClock({super.key, required this.elapsed, this.label = 'Duration'});
  final Duration elapsed;
  final String label;

  @override
  Widget build(BuildContext context) {
    const limit = AppConstants.longSeizure;
    final long = elapsed >= limit;
    final color = long ? AppColors.alert : (elapsed >= limit * 0.6 ? AppColors.warn : AppColors.fg);
    return NabraCard(
      borderColor: long ? AppColors.alert : null,
      child: Column(
        children: [
          SectionLabel(label),
          const Gap(AppSpacing.sm),
          FittedBox(child: Text(Fmt.clock(elapsed), style: AppText.timer.copyWith(color: color))),
          const Gap(AppSpacing.md),
          ClipRRect(
            borderRadius: AppRadius.pillAll,
            child: LinearProgressIndicator(
              value: (elapsed.inSeconds / limit.inSeconds).clamp(0, 1),
              minHeight: AppSizes.sliderTrack,
              color: long ? AppColors.alert : AppColors.cyan,
              backgroundColor: AppColors.raise,
            ),
          ),
          const Gap(AppSpacing.xs),
          Text(
            long
                ? 'Over ${limit.inMinutes} minutes'
                : 'Emergency at ${limit.inMinutes}:00 · ${Fmt.clock(limit - elapsed)} left',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

class LongSeizureBanner extends StatelessWidget {
  const LongSeizureBanner({super.key});
  @override
  Widget build(BuildContext context) => NabraCard(
        borderColor: AppColors.alert,
        color: AppColors.tint(AppColors.alert, 0.12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Call ${AppConstants.emergencyNumber} now', style: AppText.title.copyWith(color: AppColors.alert)),
            const Gap(AppSpacing.xs),
            Text(
              'A seizure longer than ${AppConstants.longSeizure.inMinutes} minutes is a medical emergency. '
              'Give rescue medication if one was prescribed.',
              style: AppText.body,
            ),
            const Gap(AppSpacing.md - 2),
            NabraButton.alert(
              label: 'Call ${AppConstants.emergencyNumber}',
              icon: Icons.call,
              small: true,
              onPressed: () => ContactLauncher.call(AppConstants.emergencyNumber),
            ),
          ],
        ),
      );
}

/// Standard seizure first-aid steps for whoever is with the patient.
class FirstAidCard extends StatelessWidget {
  const FirstAidCard({super.key});

  static const _steps = [
    'Stay calm and stay with them. Keep timing the seizure.',
    'Move hard or sharp objects away. Cushion their head.',
    'Do not hold them down and put nothing in their mouth.',
    'When the jerking stops, roll them onto their side.',
    'Stay until they are fully awake and breathing normally.',
  ];

  @override
  Widget build(BuildContext context) => NabraCard(
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: AppColors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            initiallyExpanded: true,
            iconColor: AppColors.muted,
            collapsedIconColor: AppColors.muted,
            title: const SectionLabel('Seizure first aid'),
            children: [
              for (var i = 0; i < _steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${i + 1}.', style: AppText.bodyStrong.copyWith(color: AppColors.cyan)),
                      const Gap(AppSpacing.sm),
                      Expanded(child: Text(_steps[i], style: AppText.body)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
}
