import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/icons/app_svg_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/widgets/pressable_scale.dart';

class TagInspectorWaitingView extends StatefulWidget {
  const TagInspectorWaitingView({
    super.key,
    required this.isError,
    required this.errorCode,
    required this.onRetry,
  });

  final bool isError;
  final String? errorCode;
  final VoidCallback onRetry;

  @override
  State<TagInspectorWaitingView> createState() =>
      _TagInspectorWaitingViewState();
}

class _TagInspectorWaitingViewState extends State<TagInspectorWaitingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant TagInspectorWaitingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isError != widget.isError) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    if (!mounted) return;
    final reduced = AppMotion.isReduced(context);
    if (!widget.isError && !reduced) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat();
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
      if (reduced) {
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  ({String title, String desc}) _resolveErrorCopy(AppLocalizations l10n) {
    switch (widget.errorCode) {
      case 'NO_HARDWARE':
        return (title: l10n.nfcTitleNoHardware, desc: l10n.nfcNoHardware);
      case 'DISABLED':
        return (title: l10n.nfcTitleDisabled, desc: l10n.nfcDisabled);
      case 'TAG_LOST':
        return (title: l10n.nfcTitleTagLost, desc: l10n.nfcDescTagLost);
      default:
        return (title: l10n.nfcTitleOpFailed, desc: l10n.inspectErrorGeneric);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isError = widget.isError;
    final accentColor = isError ? AppColors.danger : AppColors.primary;
    final copy = isError
        ? _resolveErrorCopy(l10n)
        : (title: l10n.inspectWaitingTitle, desc: l10n.inspectWaitingDesc);

    return Padding(
      key: const Key('inspector_waiting_card'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 152,
            height: 152,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                if (!isError)
                  _PulseRing(
                    controller: _pulseController,
                    delayFraction: 0.0,
                    color: accentColor,
                  ),
                if (!isError)
                  _PulseRing(
                    controller: _pulseController,
                    delayFraction: 0.45,
                    color: accentColor,
                  ),
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isError
                        ? AppColors.dangerPermGradient
                        : AppColors.primaryGradient,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.38),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: isError
                        ? AppSvgIcons.warningTriangle(
                            size: 32,
                            color: Colors.white,
                          )
                        : AppSvgIcons.chipInspector(
                            size: 34,
                            color: Colors.white,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            copy.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            copy.desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSub,
              fontSize: 13.8,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          if (isError) ...<Widget>[
            const SizedBox(height: 22),
            PressableScale(
              key: const Key('btn_inspector_retry'),
              onTap: widget.onRetry,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  gradient: AppColors.dangerPermGradient,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.danger.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AppSvgIcons.retryRefresh(size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      l10n.nfcRetryBtn,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({
    required this.controller,
    required this.delayFraction,
    required this.color,
  });

  final AnimationController controller;
  final double delayFraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final raw = (controller.value + delayFraction) % 1.0;
        final scale = 0.65 + (raw * 0.55);
        final opacity = (1.0 - raw).clamp(0.0, 1.0) * 0.42;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 124,
            height: 124,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: opacity),
                width: 1.8,
              ),
            ),
          ),
        );
      },
    );
  }
}
