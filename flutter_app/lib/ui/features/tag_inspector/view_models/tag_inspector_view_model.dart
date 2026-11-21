import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../../data/services/hardware_bridge_service.dart';
import '../../../../domain/models/nfc_models.dart';
import '../../../../domain/models/tag_inspection_models.dart';

enum TagInspectorState {
  waiting,
  inspected,
  error,
}

class TagInspectorViewModel extends ChangeNotifier {
  TagInspectorViewModel({
    required this._hardwareBridge,
    this.onTransientScanError,
  }) {
    _eventsSub = _hardwareBridge.nfcEvents.listen(_handleHardwareEvent);
  }

  final HardwareBridgeService _hardwareBridge;
  final void Function(String errorCode)? onTransientScanError;

  StreamSubscription<NfcHardwareEvent>? _eventsSub;
  bool _disposed = false;
  bool _sessionPausedByLifecycle = false;

  TagInspectorState _state = TagInspectorState.waiting;
  TagInspectorState get state => _state;

  TagInspectionResult? _result;
  TagInspectionResult? get result => _result;

  String? _errorCode;
  String? get errorCode => _errorCode;

  int _scanCount = 0;
  int get scanCount => _scanCount;

  Future<void> startInspection() async {
    if (_disposed) return;
    _errorCode = null;
    _sessionPausedByLifecycle = false;
    if (_result == null) {
      _state = TagInspectorState.waiting;
    }
    notifyListeners();

    final started = await _hardwareBridge.startNfcInspect();
    if (_disposed) return;
    if (!started) {
      if (_result == null) {
        _state = TagInspectorState.error;
        _errorCode = 'NO_HARDWARE';
        notifyListeners();
      } else {
        onTransientScanError?.call('NO_HARDWARE');
      }
    }
  }

  Future<void> retryInspection() async {
    if (_disposed) return;
    _errorCode = null;
    _state = TagInspectorState.waiting;
    notifyListeners();
    await startInspection();
  }

  Future<void> resumeInspectionIfNeeded() async {
    if (_disposed || !_sessionPausedByLifecycle) return;
    _sessionPausedByLifecycle = false;
    await startInspection();
  }

  void _handleHardwareEvent(NfcHardwareEvent event) {
    if (_disposed) return;
    switch (event.type) {
      case NfcHardwareEventType.tagInspected:
        final inspected = event.inspectedTag;
        if (inspected == null) return;
        _result = inspected;
        _state = TagInspectorState.inspected;
        _errorCode = null;
        _sessionPausedByLifecycle = false;
        _scanCount++;
        notifyListeners();

      case NfcHardwareEventType.error:
        final code = event.errorCode ?? 'INSPECT_FAILED';
        if (_result == null) {
          _state = TagInspectorState.error;
          _errorCode = code;
          notifyListeners();
        } else {
          onTransientScanError?.call(code);
        }

      case NfcHardwareEventType.sessionPaused:
        _sessionPausedByLifecycle = true;

      case NfcHardwareEventType.writeSuccess:
      case NfcHardwareEventType.eraseSuccess:
      case NfcHardwareEventType.wifiRead:
      case NfcHardwareEventType.urlRead:
      case NfcHardwareEventType.permLockSuccess:
      case NfcHardwareEventType.pwdSuccess:
        break;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _eventsSub?.cancel();
    unawaited(_hardwareBridge.cancelNfcSession());
    super.dispose();
  }
}
