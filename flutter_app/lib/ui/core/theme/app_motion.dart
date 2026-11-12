import 'package:flutter/widgets.dart';

/// Shared motion helpers that honor the app-wide Animations preference
/// (propagated via [MediaQueryData.disableAnimations]) as well as inactive
/// background routes during theme transitions.
abstract final class AppMotion {
  /// Returns `true` when animations should be skipped.
  static bool isReduced(BuildContext context) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  /// Returns [normal] when animations are enabled, or [Duration.zero] when
  /// animations are disabled.
  static Duration duration(BuildContext context, Duration normal) {
    return isReduced(context) ? Duration.zero : normal;
  }

  /// Like [duration], and also returns [Duration.zero] when [context] belongs
  /// to a background route underneath another opaque route (`isCurrent == false`).
  ///
  /// This prevents implicit theme-color fade animations on containers like
  /// `AmbientGlowScaffold` and `GlassCard` from stalling inside a frozen
  /// ticker while `SettingsScreen` is pushed and visibly lagging on pop.
  static Duration routeDuration(BuildContext context, Duration normal) {
    if (isReduced(context)) return Duration.zero;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return Duration.zero;
    }
    return normal;
  }
}
