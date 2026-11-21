import 'package:flutter/material.dart';

import '../../../core/icons/app_svg_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pressable_scale.dart';

class TagInspectorInfoRow extends StatelessWidget {
  const TagInspectorInfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.valueKey,
    this.accentColor,
    this.isMonospace = false,
    this.statusBadgeColor,
    this.onCopy,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String value;
  final Key? valueKey;
  final Color? accentColor;
  final bool isMonospace;
  final Color? statusBadgeColor;
  final VoidCallback? onCopy;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final badgeTint = accentColor ?? AppColors.primaryLight;
    final valueText = Text(
      value,
      key: valueKey,
      style: TextStyle(
        fontFamily: isMonospace ? 'JetBrainsMono' : null,
        color: statusBadgeColor ?? AppColors.textPrimary,
        fontSize: isMonospace ? 13.0 : 13.8,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: badgeTint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(icon, size: 18, color: badgeTint),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                if (statusBadgeColor != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusBadgeColor!.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: statusBadgeColor!.withValues(alpha: 0.32),
                      ),
                    ),
                    child: isMonospace
                        ? Directionality(
                            textDirection: TextDirection.ltr,
                            child: valueText,
                          )
                        : valueText,
                  )
                else if (isMonospace)
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: valueText,
                  )
                else
                  valueText,
                if (footer != null) ...<Widget>[
                  const SizedBox(height: 8),
                  footer!,
                ],
              ],
            ),
          ),
          if (onCopy != null) ...<Widget>[
            const SizedBox(width: 8),
            PressableScale(
              onTap: onCopy,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.subtleButtonBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: AppSvgIcons.copyIcon(
                    size: 15,
                    color: AppColors.textSub,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
