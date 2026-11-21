import 'package:flutter/material.dart';

import '../../../../domain/models/tag_inspection_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/icons/app_svg_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/widgets/pressable_scale.dart';

class TagRecordCard extends StatefulWidget {
  const TagRecordCard({
    super.key,
    required this.record,
    required this.onCopyValue,
    required this.onOpenUri,
    this.onUseUrl,
  });

  final InspectedNdefRecord record;
  final void Function(String value) onCopyValue;
  final void Function(String uri) onOpenUri;
  final void Function(String url)? onUseUrl;

  @override
  State<TagRecordCard> createState() => _TagRecordCardState();
}

class _TagRecordCardState extends State<TagRecordCard> {
  bool _showRawHex = false;
  bool _obscureWifiPassword = true;

  IconData _resolveKindIcon() {
    switch (widget.record.kind) {
      case InspectedRecordKind.uri:
        return Icons.link_rounded;
      case InspectedRecordKind.text:
        return Icons.notes_rounded;
      case InspectedRecordKind.wifi:
        return Icons.wifi_rounded;
      case InspectedRecordKind.vcard:
        return Icons.contact_page_outlined;
      case InspectedRecordKind.aar:
        return Icons.android_rounded;
      case InspectedRecordKind.mime:
      case InspectedRecordKind.external:
        return Icons.data_object_rounded;
      case InspectedRecordKind.empty:
      case InspectedRecordKind.unknown:
        return Icons.tag_rounded;
    }
  }

  Color _resolveKindColor() {
    switch (widget.record.kind) {
      case InspectedRecordKind.uri:
        return AppColors.primaryLight;
      case InspectedRecordKind.wifi:
        return AppColors.amberWifiLight;
      case InspectedRecordKind.text:
        return AppColors.skyLocationLight;
      case InspectedRecordKind.vcard:
      case InspectedRecordKind.aar:
        return AppColors.successLight;
      case InspectedRecordKind.mime:
      case InspectedRecordKind.external:
      case InspectedRecordKind.empty:
      case InspectedRecordKind.unknown:
        return AppColors.textSub;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rec = widget.record;
    final accent = _resolveKindColor();
    final isEmpty = rec.kind == InspectedRecordKind.empty;
    final isWifi = rec.kind == InspectedRecordKind.wifi;
    final isCodeText = rec.kind == InspectedRecordKind.uri ||
        rec.kind == InspectedRecordKind.aar ||
        rec.kind == InspectedRecordKind.unknown;

    return Padding(
      key: Key('inspector_record_${rec.index}'),
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Header
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(_resolveKindIcon(), size: 18, color: accent),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.inspectRecordTitle(rec.index, rec.typeLabel),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      rec.tnf,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (rec.languageCode != null) ...<Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.subtleButtonBg,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    rec.languageCode!.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      color: AppColors.textSub,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '${rec.payloadSize} B',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    color: accent,
                    fontSize: 10.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (!isEmpty) ...<Widget>[
            const SizedBox(height: 11),

            // Record Value Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.urlBoxBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderGlass),
              ),
              child: isWifi
                  ? _buildWifiPayload(rec)
                  : isCodeText
                      ? Directionality(
                          textDirection: TextDirection.ltr,
                          child: SelectableText(
                            rec.displayValue.isEmpty ? '-' : rec.displayValue,
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              color: AppColors.textPrimary,
                              fontSize: 12.6,
                              fontWeight: FontWeight.w500,
                              height: 1.45,
                            ),
                          ),
                        )
                      : SelectableText(
                          rec.displayValue.isEmpty ? '-' : rec.displayValue,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13.4,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                          ),
                        ),
            ),

            const SizedBox(height: 10),

            // Action Chips Row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (rec.fullValue.isNotEmpty)
                  _ActionChipButton(
                    icon: AppSvgIcons.copyIcon(
                      size: 13,
                      color: AppColors.textPrimary,
                    ),
                    label: l10n.inspectActionCopy,
                    onTap: () => widget.onCopyValue(rec.fullValue),
                  ),
                if (rec.isOpenableUri)
                  _ActionChipButton(
                    icon: AppSvgIcons.openExternal(
                      size: 13,
                      color: AppColors.skyLocationLight,
                    ),
                    label: l10n.inspectActionOpen,
                    accentColor: AppColors.skyLocationLight,
                    onTap: () => widget.onOpenUri(rec.fullValue),
                  ),
                if (rec.isHttpUrl && widget.onUseUrl != null)
                  _ActionChipButton(
                    key: Key('btn_inspector_use_url_${rec.index}'),
                    icon: AppSvgIcons.linkChain(
                      size: 13,
                      color: AppColors.primaryLight,
                    ),
                    label: l10n.inspectActionUseUrl,
                    accentColor: AppColors.primaryLight,
                    onTap: () => widget.onUseUrl!(rec.fullValue),
                  ),
                if (rec.payloadHex.isNotEmpty)
                  _ActionChipButton(
                    icon: Icon(
                      _showRawHex
                          ? Icons.expand_less_rounded
                          : Icons.code_rounded,
                      size: 15,
                      color: AppColors.textSub,
                    ),
                    label: l10n.inspectActionShowHex,
                    onTap: () => setState(() => _showRawHex = !_showRawHex),
                  ),
              ],
            ),

            // Expandable Raw Hex View
            AnimatedSize(
              duration: AppMotion.duration(
                context,
                const Duration(milliseconds: 200),
              ),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _showRawHex
                  ? Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: AppColors.inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderGlass),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: SelectableText(
                              rec.payloadHex,
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                color: AppColors.textSub,
                                fontSize: 11.2,
                                height: 1.45,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: _ActionChipButton(
                              icon: AppSvgIcons.copyIcon(
                                size: 13,
                                color: AppColors.textSub,
                              ),
                              label: l10n.inspectActionCopyHex,
                              onTap: () => widget.onCopyValue(rec.payloadHex),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWifiPayload(InspectedNdefRecord rec) {
    final hasPassword =
        rec.wifiPassword != null && rec.wifiPassword!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                rec.wifiSsid ?? rec.displayValue,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (rec.wifiEncryption != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.amberWifi.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  rec.wifiEncryption!,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    color: AppColors.amberWifiLight,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        if (hasPassword) ...<Widget>[
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    _obscureWifiPassword
                        ? '•' * rec.wifiPassword!.length.clamp(6, 14)
                        : rec.wifiPassword!,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      color: AppColors.textSub,
                      fontSize: 12.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              PressableScale(
                onTap: () => setState(
                  () => _obscureWifiPassword = !_obscureWifiPassword,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: _obscureWifiPassword
                      ? AppSvgIcons.eyeOpen(size: 16, color: AppColors.textSub)
                      : AppSvgIcons.eyeClosed(
                          size: 16,
                          color: AppColors.textSub,
                        ),
                ),
              ),
              const SizedBox(width: 6),
              PressableScale(
                onTap: () => widget.onCopyValue(rec.wifiPassword!),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: AppSvgIcons.copyIcon(
                    size: 15,
                    color: AppColors.textSub,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.accentColor,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final tint = accentColor ?? AppColors.textPrimary;
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: accentColor != null
              ? accentColor!.withValues(alpha: 0.13)
              : AppColors.secondaryBtnBg,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: accentColor != null
                ? accentColor!.withValues(alpha: 0.30)
                : AppColors.borderGlass,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            icon,
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: tint,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
