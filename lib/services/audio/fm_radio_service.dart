import 'package:flutter/services.dart';

/// Best-effort launcher for the phone's built-in FM radio app (Android only).
/// There is no public cross-device API to tune FM hardware from Flutter; the user
/// tunes in the OEM app and aligns the in-game dial to the same frequency.
class FmRadioService {
  FmRadioService._();
  static const MethodChannel _channel =
      MethodChannel('com.acenzo.roadrick/fm_radio');

  /// Tries known OEM FM package names; returns true if an activity was started.
  static Future<bool> openDeviceFmRadioApp() async {
    try {
      final ok = await _channel.invokeMethod<bool>('openFmRadio');
      return ok == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
