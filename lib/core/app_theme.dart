import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_text.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    final border = OutlineInputBorder(
      borderRadius: AppRadius.mdAll,
      borderSide: const BorderSide(color: AppColors.line),
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.cyan,
        onPrimary: AppColors.onAccent,
        secondary: AppColors.cyan,
        surface: AppColors.surface,
        onSurface: AppColors.fg,
        error: AppColors.alert,
        outline: AppColors.line,
      ),
      textTheme: GoogleFonts.ibmPlexSansTextTheme(base.textTheme)
          .apply(bodyColor: AppColors.fg, displayColor: AppColors.fg),
      dividerColor: AppColors.line,
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: AppSizes.border, space: AppSizes.border),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        surfaceTintColor: AppColors.transparent,
        elevation: 0,
        titleTextStyle: AppText.title,
        iconTheme: const IconThemeData(color: AppColors.fg),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bg,
        labelStyle: AppText.fieldLabel,
        floatingLabelStyle: AppText.fieldLabel.copyWith(color: AppColors.cyan),
        hintStyle: AppText.small,
        errorStyle: AppText.caption.copyWith(color: AppColors.alert),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.cyan)),
        errorBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.alert)),
        focusedErrorBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.alert)),
      ),
      textSelectionTheme: const TextSelectionThemeData(cursorColor: AppColors.cyan),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.cyan,
        inactiveTrackColor: AppColors.raise,
        thumbColor: AppColors.cyan,
        overlayColor: AppColors.tint(AppColors.cyan),
        trackHeight: AppSizes.sliderTrack,
        valueIndicatorColor: AppColors.raise,
        valueIndicatorTextStyle: AppText.mono,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.cyan : AppColors.transparent),
        checkColor: const WidgetStatePropertyAll(AppColors.onAccent),
        side: const BorderSide(color: AppColors.muted),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.raise,
        contentTextStyle: AppText.body,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.transparent,
        titleTextStyle: AppText.title,
        contentTextStyle: AppText.body,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.line,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.cyan),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.cyan, textStyle: AppText.bodyStrong),
      ),
    );
  }
}
