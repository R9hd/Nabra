import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_dimens.dart';
import '../core/app_text.dart';

/// Square gap usable in both Rows and Columns.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size);
}

List<Widget> withGaps(List<Widget> children, double gap) => [
      for (var i = 0; i < children.length; i++) ...[if (i > 0) Gap(gap), children[i]],
    ];

enum Tone {
  ok,
  warn,
  alert,
  cyan,
  neutral;

  Color get color => switch (this) {
        Tone.ok => AppColors.ok,
        Tone.warn => AppColors.warn,
        Tone.alert => AppColors.alert,
        Tone.cyan => AppColors.cyan,
        Tone.neutral => AppColors.muted,
      };

  Color get background => this == Tone.neutral ? AppColors.raise : AppColors.tint(color);
}

/// Blueprint `.card`.
class NabraCard extends StatelessWidget {
  const NabraCard({super.key, required this.child, this.borderColor, this.onTap, this.padding, this.color});

  final Widget child;
  final Color? borderColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.xlAll,
        side: BorderSide(color: borderColor ?? AppColors.line),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding ?? const EdgeInsets.all(AppSpacing.card), child: child),
      ),
    );
  }
}

/// Blueprint `.chip`.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.tone = Tone.cyan, this.icon});

  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = tone.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 1, vertical: AppSpacing.xs - 1),
      decoration: BoxDecoration(color: tone.background, borderRadius: AppRadius.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: AppSizes.iconXs, color: fg), const Gap(AppSpacing.xs + 2)],
          Flexible(child: Text(label, style: AppText.chip.copyWith(color: fg), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

/// Blueprint `.lbl` (uppercase mono label).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color, this.textAlign});
  final String text;
  final Color? color;
  final TextAlign? textAlign;
  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), textAlign: textAlign, style: AppText.label.copyWith(color: color));
}

class Dot extends StatelessWidget {
  const Dot(this.color, {super.key, this.size = AppSizes.dot});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// Blueprint `.icobx`.
class IconBox extends StatelessWidget {
  const IconBox(this.icon, {super.key, this.color = AppColors.cyan});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: AppSizes.iconBox,
        height: AppSizes.iconBox,
        decoration: BoxDecoration(color: AppColors.raise, borderRadius: AppRadius.smAll),
        child: Icon(icon, size: AppSizes.icon, color: color),
      );
}

/// Round initial avatar (blueprint `.ab .dot`).
class Avatar extends StatelessWidget {
  const Avatar(this.initial, {super.key});
  final String initial;
  @override
  Widget build(BuildContext context) => Container(
        width: AppSizes.avatar,
        height: AppSizes.avatar,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: AppColors.raise, shape: BoxShape.circle),
        child: Text(initial, style: AppText.bodyStrong.copyWith(color: AppColors.cyan)),
      );
}

/// Blueprint `.list .it` row.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.divider = true,
    this.top,
  });

  final Widget? leading;
  final Widget? top;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md - 1),
        decoration: BoxDecoration(
          border: divider ? const Border(bottom: BorderSide(color: AppColors.line)) : null,
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const Gap(AppSpacing.md - 2)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (top != null) ...[top!, const Gap(AppSpacing.xs)],
                  Text(title, style: AppText.bodyStrong),
                  if (subtitle != null) ...[
                    const Gap(AppSpacing.xxs),
                    Text(subtitle!, style: AppText.caption),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const Gap(AppSpacing.sm), trailing!],
          ],
        ),
      ),
    );
  }
}

/// Column of [ListRow]s with the last divider removed.
class RowList extends StatelessWidget {
  const RowList({super.key, required this.rows});
  final List<ListRow> rows;
  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            ListRow(
              key: rows[i].key,
              title: rows[i].title,
              subtitle: rows[i].subtitle,
              leading: rows[i].leading,
              trailing: rows[i].trailing,
              onTap: rows[i].onTap,
              top: rows[i].top,
              divider: i < rows.length - 1,
            ),
        ],
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body});
  final IconData icon;
  final String title;
  final String? body;
  @override
  Widget build(BuildContext context) => NabraCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Column(
            children: [
              Icon(icon, color: AppColors.muted, size: AppSizes.iconLg),
              const Gap(AppSpacing.sm),
              Text(title, style: AppText.bodyStrong, textAlign: TextAlign.center),
              if (body != null) ...[
                const Gap(AppSpacing.xs),
                Text(body!, style: AppText.small, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
