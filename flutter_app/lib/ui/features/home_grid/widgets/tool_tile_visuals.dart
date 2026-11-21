/// Theme-aware visual metadata mapping [HomeToolId] entries onto localized
/// titles, subtitles, surfaces, and SVG icons for the home grid.
library;

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/icons/app_svg_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../models/grid_tile_models.dart';

/// Immutable UI presentation descriptor for a single grid tool tile.
final class ToolTilePresentation {
  const ToolTilePresentation({
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.badgeColor,
    required this.iconBuilder,
    this.backgroundGradient,
    this.badgeGradient,
    this.badgeIconColor,
  });

  /// Primary localized tool title.
  final String title;

  /// Secondary localized helper subtitle surfaced in wider/taller tile spans.
  final String subtitle;

  /// Foreground accent color used for icons, highlights, and chevrons.
  final Color accentColor;

  /// Base tile background fill when [backgroundGradient] is omitted.
  final Color backgroundColor;

  /// Optional tile gradient fill (used for prominent hero cards).
  final Gradient? backgroundGradient;

  /// Resting tile border stroke color.
  final Color borderColor;

  /// Icon badge surface color when [badgeGradient] is omitted.
  final Color badgeColor;

  /// Optional icon badge gradient (used for the primary hero icon badge).
  final Gradient? badgeGradient;

  /// Icon foreground inside badges; defaults to [accentColor] when `null`.
  final Color? badgeIconColor;

  /// Builder returning a crisp vector icon scaled to [size] and tinted [color].
  final Widget Function(double size, Color color) iconBuilder;
}

/// Resolves theme-adaptive visual tokens for every [HomeToolId].
abstract final class ToolTileVisuals {
  /// Returns the localized and theme-matched [ToolTilePresentation] for [id].
  static ToolTilePresentation resolve(
    HomeToolId id,
    AppLocalizations l10n,
  ) {
    final neutralTileBg = AppColors.isLight
        ? const Color(0xFFF3F1ED)
        : const Color(0x80120F0E);
    final wifiTileBg = AppColors.isLight
        ? const Color(0xFFFEF7EA)
        : const Color(0x8015110D);
    final dangerTileBg = AppColors.isLight
        ? const Color(0xFFFDF0F3)
        : const Color(0x80170E12);
    final hubTileBg = AppColors.isLight
        ? const Color(0xFFEEECFA)
        : const Color(0x99191522);

    final primaryBadgeBg = AppColors.primaryLight.withValues(
      alpha: AppColors.isLight ? 0.12 : 0.18,
    );
    final dangerBadgeBg = AppColors.pinkLock.withValues(
      alpha: AppColors.isLight ? 0.12 : 0.18,
    );
    final wifiBadgeBg = AppColors.amberWifi.withValues(
      alpha: AppColors.isLight ? 0.14 : 0.20,
    );
    final hubBadgeBg = AppColors.primaryLight.withValues(
      alpha: AppColors.isLight ? 0.14 : 0.20,
    );

    return switch (id) {
      HomeToolId.inspectCard => ToolTilePresentation(
          title: l10n.lblInspectTag,
          subtitle: l10n.lblInspectTagSub,
          accentColor: AppColors.primaryLight,
          backgroundColor: Colors.transparent,
          backgroundGradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: AppColors.isLight
                ? const <Color>[Color(0x1C7C3AED), Color(0x0D8B5CF6)]
                : const <Color>[Color(0x2B7C3AED), Color(0x141F1C1A)],
          ),
          borderColor: AppColors.primaryLight.withValues(alpha: 0.36),
          badgeColor: AppColors.primary,
          badgeGradient: AppColors.primaryGradient,
          badgeIconColor: Colors.white,
          iconBuilder: (double size, Color color) =>
              AppSvgIcons.chipInspector(size: size, color: color),
        ),
      HomeToolId.cloneCard => ToolTilePresentation(
          title: l10n.lblReadTag,
          subtitle: l10n.lblCloneTagSub,
          accentColor: AppColors.primaryLight,
          backgroundColor: neutralTileBg,
          borderColor: AppColors.borderGlass,
          badgeColor: primaryBadgeBg,
          iconBuilder: (double size, Color color) =>
              AppSvgIcons.readScanner(size: size, color: color),
        ),
      HomeToolId.wifiCard => ToolTilePresentation(
          title: l10n.lblWifiTag,
          subtitle: l10n.lblWifiTagSub,
          accentColor: AppColors.amberWifiLight,
          backgroundColor: wifiTileBg,
          borderColor: AppColors.amberWifi.withValues(alpha: 0.24),
          badgeColor: wifiBadgeBg,
          iconBuilder: (double size, Color color) =>
              AppSvgIcons.wifiWaves(size: size, color: color),
        ),
      HomeToolId.pinLock => ToolTilePresentation(
          title: l10n.lblPwdLockTag,
          subtitle: l10n.lblPinLockSub,
          accentColor: AppColors.primaryLight,
          backgroundColor: neutralTileBg,
          borderColor: AppColors.borderGlass,
          badgeColor: primaryBadgeBg,
          iconBuilder: (double size, Color color) =>
              AppSvgIcons.lockClosed(size: size, color: color),
        ),
      HomeToolId.eraseCard => ToolTilePresentation(
          title: l10n.lblEraseTag,
          subtitle: l10n.lblEraseTagSub,
          accentColor: AppColors.pinkLock,
          backgroundColor: dangerTileBg,
          borderColor: AppColors.pinkLock.withValues(alpha: 0.26),
          badgeColor: dangerBadgeBg,
          iconBuilder: (double size, Color color) =>
              AppSvgIcons.trash(size: size, color: color),
        ),
      HomeToolId.permLock => ToolTilePresentation(
          title: l10n.lblPermLockTag,
          subtitle: l10n.lblPermLockSub,
          accentColor: AppColors.pinkLock,
          backgroundColor: dangerTileBg,
          borderColor: AppColors.pinkLock.withValues(alpha: 0.26),
          badgeColor: dangerBadgeBg,
          iconBuilder: (double size, Color color) =>
              AppSvgIcons.shieldPermLock(size: size, color: color),
        ),
      HomeToolId.toolsHub => ToolTilePresentation(
          title: l10n.lblToolsHub,
          subtitle: l10n.lblToolsHubSub,
          accentColor: AppColors.primaryLight,
          backgroundColor: hubTileBg,
          borderColor: AppColors.primaryLight.withValues(alpha: 0.28),
          badgeColor: hubBadgeBg,
          iconBuilder: (double size, Color color) =>
              AppSvgIcons.toolsHubGrid(size: size, color: color),
        ),
    };
  }
}
