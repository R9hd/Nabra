import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_dimens.dart';
import '../core/app_text.dart';
import 'basics.dart';

/// Blueprint `.field`: dark input with a small mono label.
class NabraField extends StatefulWidget {
  const NabraField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.maxLines = 1,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final int maxLines;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;

  @override
  State<NabraField> createState() => _NabraFieldState();
}

class _NabraFieldState extends State<NabraField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      maxLines: widget.obscure ? 1 : widget.maxLines,
      minLines: 1,
      onFieldSubmitted: widget.onSubmitted,
      textCapitalization: widget.textCapitalization,
      style: AppText.body,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        suffixIcon: widget.obscure
            ? IconButton(
                tooltip: _hidden ? 'Show password' : 'Hide password',
                icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: AppSizes.icon, color: AppColors.muted),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
      ),
    );
  }
}

/// Blueprint `.seg2` segmented control.
class Segmented extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.index, required this.onChanged});

  final List<String> options;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs - 1),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.line),
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: Semantics(
                selected: i == index,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: i == index ? AppColors.cyan : AppColors.transparent,
                      borderRadius: AppRadius.smAll,
                    ),
                    child: Text(
                      options[i],
                      textAlign: TextAlign.center,
                      style: i == index
                          ? AppText.bodyStrong.copyWith(color: AppColors.onAccent, fontSize: 13)
                          : AppText.small,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontal scrolling filter chips (blueprint history filters).
class FilterBar extends StatelessWidget {
  const FilterBar({super.key, required this.options, required this.selected, required this.onSelected});

  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: withGaps([
          for (var i = 0; i < options.length; i++)
            InkWell(
              borderRadius: AppRadius.pillAll,
              onTap: () => onSelected(i),
              child: StatusChip(options[i], tone: i == selected ? Tone.cyan : Tone.neutral),
            ),
        ], AppSpacing.xs + 2),
      ),
    );
  }
}

/// Selectable card used for role choice.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: NabraCard(
        onTap: onTap,
        color: selected ? AppColors.tint(AppColors.cyan, 0.08) : AppColors.bg,
        borderColor: selected ? AppColors.cyan : AppColors.line,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? AppColors.cyan : AppColors.muted, size: AppSizes.icon),
            const Gap(AppSpacing.xs + 2),
            Text(title, style: AppText.bodyStrong),
            Text(subtitle, style: AppText.caption),
          ],
        ),
      ),
    );
  }
}
