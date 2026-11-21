import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../data/services/hardware_bridge_service.dart';
import '../../../../domain/models/tag_inspection_models.dart';
import '../../../../domain/models/toast_message.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ambient_glow_scaffold.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../view_models/tag_inspector_view_model.dart';
import 'tag_inspector_info_row.dart';
import 'tag_inspector_waiting_view.dart';
import 'tag_record_card.dart';

class TagInspectorScreen extends StatefulWidget {
  const TagInspectorScreen({
    super.key,
    required this.hardwareBridge,
    required this.onShowToast,
    this.onUseUrl,
    this.isArabic = false,
  });

  final HardwareBridgeService hardwareBridge;
  final void Function(String message, {ToastType type}) onShowToast;
  final Future<void> Function(String url)? onUseUrl;
  final bool isArabic;

  @override
  State<TagInspectorScreen> createState() => _TagInspectorScreenState();
}

class _TagInspectorScreenState extends State<TagInspectorScreen>
    with WidgetsBindingObserver {
  late final TagInspectorViewModel _viewModel;
  bool _showSignatureHex = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _viewModel = TagInspectorViewModel(
      hardwareBridge: widget.hardwareBridge,
      onTransientScanError: _handleTransientScanError,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_viewModel.startInspection());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(_viewModel.resumeInspectionIfNeeded());
    }
  }

  void _handleTransientScanError(String errorCode) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;
    final message = errorCode == 'TAG_LOST'
        ? l10n.nfcDescTagLost
        : l10n.inspectErrorGeneric;
    widget.onShowToast(message, type: ToastType.warn);
  }

  Future<void> _copyValue(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: trimmed));
    unawaited(widget.hardwareBridge.triggerLightHaptic());
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    widget.onShowToast(l10n.inspectCopiedValue, type: ToastType.copy);
  }

  Future<void> _openUri(String rawUri) async {
    final uri = Uri.tryParse(rawUri.trim());
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleUseUrl(String url) async {
    if (widget.onUseUrl != null) {
      await widget.onUseUrl!(url);
    }
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  String _formatMemoryText(TagInspectionResult result, AppLocalizations l10n) {
    if (result.hasMemoryPages) {
      return l10n.inspectMemoryPagesFormat(
        result.memoryTotalBytes!,
        result.memoryPageCount!,
        result.memoryPageSize!,
      );
    }
    if (result.hasMemorySectors) {
      return l10n.inspectMemorySectorsFormat(
        result.memoryTotalBytes!,
        result.memorySectorCount!,
        result.memoryBlockCount!,
      );
    }
    if (result.hasMemoryBlocksOnly && result.memoryPageSize != null) {
      return l10n.inspectMemoryPagesFormat(
        result.memoryTotalBytes!,
        result.memoryBlockCount!,
        result.memoryPageSize!,
      );
    }
    if (result.memoryTotalBytes != null) {
      return '${result.memoryTotalBytes} B';
    }
    return l10n.inspectUnknown;
  }

  String _formatSignatureLabel(
    TagSignatureStatus status,
    AppLocalizations l10n,
  ) {
    switch (status) {
      case TagSignatureStatus.valid:
        return l10n.inspectSigValid;
      case TagSignatureStatus.invalid:
        return l10n.inspectSigInvalid;
      case TagSignatureStatus.notSupported:
        return l10n.inspectSigNotSupported;
    }
  }

  Color _resolveSignatureColor(TagSignatureStatus status) {
    switch (status) {
      case TagSignatureStatus.valid:
        return AppColors.successLight;
      case TagSignatureStatus.invalid:
        return AppColors.dangerLight;
      case TagSignatureStatus.notSupported:
        return AppColors.textMuted;
    }
  }

  String _formatPasswordLabel(
    TagPasswordStatus status,
    AppLocalizations l10n,
  ) {
    switch (status) {
      case TagPasswordStatus.protected:
        return l10n.inspectYes;
      case TagPasswordStatus.notProtected:
        return l10n.inspectNo;
      case TagPasswordStatus.unknown:
        return l10n.inspectUnknown;
    }
  }

  Color _resolvePasswordColor(TagPasswordStatus status) {
    switch (status) {
      case TagPasswordStatus.protected:
        return AppColors.amberWifiLight;
      case TagPasswordStatus.notProtected:
        return AppColors.successLight;
      case TagPasswordStatus.unknown:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.currentOverlayStyle,
      child: AmbientGlowScaffold(
        key: const Key('tag_inspector_screen'),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: <Widget>[
                  _buildTopBar(context, l10n, isRtl),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: _viewModel,
                      builder: (BuildContext context, _) {
                        final result = _viewModel.result;
                        if (result == null) {
                          return Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                              child: TagInspectorWaitingView(
                                isError:
                                    _viewModel.state == TagInspectorState.error,
                                errorCode: _viewModel.errorCode,
                                onRetry: _viewModel.retryInspection,
                              ),
                            ),
                          );
                        }
                        return _buildReportBody(context, result, l10n);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    AppLocalizations l10n,
    bool isRtl,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: <Widget>[
          PressableScale(
            key: const Key('btn_inspector_back'),
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.topBarButtonBg,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.borderGlass),
              ),
              child: Center(
                child: AnimatedRotation(
                  turns: isRtl ? 0.5 : 0.0,
                  duration: AppMotion.duration(
                    context,
                    const Duration(milliseconds: 260),
                  ),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.primaryLight,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              l10n.inspectTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: widget.isArabic ? 'Cairo' : 'Inter',
                color: AppColors.textPrimary,
                fontSize: 19.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportBody(
    BuildContext context,
    TagInspectionResult result,
    AppLocalizations l10n,
  ) {
    final sigColor = _resolveSignatureColor(result.signatureStatus);
    final pwdColor = _resolvePasswordColor(result.passwordStatus);
    final sigLabel = _formatSignatureLabel(result.signatureStatus, l10n);
    final pwdLabel = _formatPasswordLabel(result.passwordStatus, l10n);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ..._buildMetadataRows(
            result: result,
            l10n: l10n,
            sigLabel: sigLabel,
            sigColor: sigColor,
            pwdLabel: pwdLabel,
            pwdColor: pwdColor,
          ),
          if (result.records.isNotEmpty) ...<Widget>[
            Divider(height: 1, color: AppColors.borderGlass),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 2, bottom: 4),
              child: Text(
                '${l10n.inspectRecordsSection} (${result.records.length})',
                style: TextStyle(
                  fontFamily: widget.isArabic ? 'Cairo' : 'Inter',
                  color: AppColors.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (var i = 0; i < result.records.length; i++) ...<Widget>[
              if (i > 0) Divider(height: 1, color: AppColors.borderGlass),
              TagRecordCard(
                record: result.records[i],
                onCopyValue: _copyValue,
                onOpenUri: _openUri,
                onUseUrl: widget.onUseUrl != null ? _handleUseUrl : null,
              ),
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> _buildMetadataRows({
    required TagInspectionResult result,
    required AppLocalizations l10n,
    required String sigLabel,
    required Color sigColor,
    required String pwdLabel,
    required Color pwdColor,
  }) {
    final rows = <Widget>[
      TagInspectorInfoRow(
        icon: Icons.memory_rounded,
        title: '${l10n.inspectTagType} : ${result.isoStandard}',
        value: result.tagTypeLabel,
        valueKey: const Key('inspector_chip_name'),
        onCopy: () => _copyValue(result.tagTypeLabel),
      ),
    ];

    if (result.technologies.isNotEmpty) {
      rows.add(
        TagInspectorInfoRow(
          icon: Icons.info_outline_rounded,
          title: l10n.inspectTechnologies,
          value: result.technologiesFormatted,
          onCopy: () => _copyValue(result.technologiesFormatted),
        ),
      );
    }

    if (result.serialNumber.isNotEmpty) {
      rows.add(
        TagInspectorInfoRow(
          key: const Key('inspector_serial'),
          icon: Icons.vpn_key_outlined,
          title: l10n.inspectSerialNumber,
          value: result.serialNumber,
          isMonospace: true,
          onCopy: () => _copyValue(result.serialNumber),
        ),
      );
    }

    if (result.atqa != null) {
      rows.add(
        TagInspectorInfoRow(
          icon: Icons.text_fields_rounded,
          title: l10n.inspectAtqa,
          value: result.atqa!,
          isMonospace: true,
          onCopy: () => _copyValue(result.atqa!),
        ),
      );
    }

    if (result.sak != null) {
      rows.add(
        TagInspectorInfoRow(
          icon: Icons.tag_rounded,
          title: l10n.inspectSak,
          value: result.sak!,
          isMonospace: true,
          onCopy: () => _copyValue(result.sak!),
        ),
      );
    }

    result.extraRfInfo.forEach((label, val) {
      rows.add(
        TagInspectorInfoRow(
          icon: Icons.sensors_rounded,
          title: label,
          value: val,
          isMonospace: true,
          onCopy: () => _copyValue(val),
        ),
      );
    });

    if (result.signatureStatus != TagSignatureStatus.notSupported) {
      rows.add(
        TagInspectorInfoRow(
          key: const Key('inspector_signature'),
          icon: Icons.draw_outlined,
          title: l10n.inspectSignature,
          value: sigLabel,
          accentColor: sigColor,
          statusBadgeColor: sigColor,
          onCopy: result.signatureHex != null
              ? () => _copyValue(result.signatureHex!)
              : null,
          footer: result.signatureHex != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    PressableScale(
                      onTap: () =>
                          setState(() => _showSignatureHex = !_showSignatureHex),
                      child: Text(
                        _showSignatureHex
                            ? '${l10n.inspectActionShowHex} ▲'
                            : '${l10n.inspectActionShowHex} ▼',
                        style: TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_showSignatureHex) ...<Widget>[
                      const SizedBox(height: 6),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: SelectableText(
                          result.signatureHex!,
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            color: AppColors.textSub,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                )
              : null,
        ),
      );
    }

    if (result.passwordStatus != TagPasswordStatus.unknown) {
      rows.add(
        TagInspectorInfoRow(
          icon: Icons.lock_outline_rounded,
          title: l10n.inspectPasswordProtected,
          value: pwdLabel,
          accentColor: pwdColor,
          statusBadgeColor: pwdColor,
        ),
      );
    }

    if (result.memoryTotalBytes != null) {
      rows.add(
        TagInspectorInfoRow(
          key: const Key('inspector_memory'),
          icon: Icons.storage_rounded,
          title: l10n.inspectMemoryInfo,
          value: _formatMemoryText(result, l10n),
        ),
      );
    }

    if (result.dataFormat.isNotEmpty &&
        result.dataFormat != 'Not NDEF formatted') {
      rows.add(
        TagInspectorInfoRow(
          icon: Icons.layers_outlined,
          title: l10n.inspectDataFormat,
          value: result.dataFormat,
        ),
      );
    }

    if (result.usedBytes != null && result.maxBytes != null) {
      final ratio = result.usageRatio ?? 0.0;
      rows.add(
        TagInspectorInfoRow(
          key: const Key('inspector_size'),
          icon: Icons.data_usage_rounded,
          title: l10n.inspectSize,
          value: l10n.inspectSizeBytesFormat(
            result.usedBytes!,
            result.maxBytes!,
          ),
          footer: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: AppColors.subtleButtonBg,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
            ),
          ),
        ),
      );
    }

    if (result.isWritable != null) {
      rows.add(
        TagInspectorInfoRow(
          icon: Icons.edit_note_rounded,
          title: l10n.inspectWritable,
          value: result.isWritable! ? l10n.inspectYes : l10n.inspectNo,
          accentColor: result.isWritable!
              ? AppColors.successLight
              : AppColors.dangerLight,
        ),
      );
    }

    if (result.canMakeReadOnly != null) {
      rows.add(
        TagInspectorInfoRow(
          icon: Icons.enhanced_encryption_outlined,
          title: l10n.inspectCanMakeReadOnly,
          value: result.canMakeReadOnly! ? l10n.inspectYes : l10n.inspectNo,
          accentColor: result.canMakeReadOnly!
              ? AppColors.primaryLight
              : AppColors.textMuted,
        ),
      );
    }

    final interleaved = <Widget>[];
    for (int i = 0; i < rows.length; i++) {
      if (i > 0) {
        interleaved.add(Divider(height: 1, color: AppColors.borderGlass));
      }
      interleaved.add(rows[i]);
    }
    return interleaved;
  }
}
