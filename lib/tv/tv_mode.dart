import 'package:flutter/foundation.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/services/storage/settings_keys.dart';

/// TV (D-pad / remote control) adaptation layer state.
///
/// The layer is intentionally cheap: it only activates D-pad behaviors,
/// never touches layout. Mode values:
/// 0 = auto (activate on first D-pad key press), 1 = always on, 2 = off.
class TvModeController extends ChangeNotifier {
  TvModeController._();

  static final TvModeController instance = TvModeController._();

  int mode = 0;
  bool _activatedByDpad = false;
  bool virtualCursorOn = false;

  bool get enabled {
    if (mode == 1) return true;
    if (mode == 2) return false;
    return _activatedByDpad;
  }

  void load() {
    mode = GStorage.getSetting(SettingsKeys.tvMode);
    virtualCursorOn =
        GStorage.getSetting(SettingsKeys.tvVirtualCursorDefault) && enabled;
    notifyListeners();
  }

  Future<void> setMode(int value) async {
    if (mode == value) return;
    mode = value;
    _activatedByDpad = enabled;
    if (!enabled) virtualCursorOn = false;
    await GStorage.putSetting(SettingsKeys.tvMode, value);
    notifyListeners();
  }

  Future<void> setVirtualCursorDefault(bool value) async {
    await GStorage.putSetting(SettingsKeys.tvVirtualCursorDefault, value);
    if (enabled) {
      virtualCursorOn = value;
    }
    notifyListeners();
  }

  void toggleVirtualCursor() {
    if (!enabled) return;
    virtualCursorOn = !virtualCursorOn;
    notifyListeners();
  }

  /// Marks the device as D-pad driven (auto mode activation).
  void onDpadSeen() {
    if (_activatedByDpad || mode != 0) return;
    _activatedByDpad = true;
    if (GStorage.getSetting(SettingsKeys.tvVirtualCursorDefault)) {
      virtualCursorOn = true;
    }
    notifyListeners();
  }
}
