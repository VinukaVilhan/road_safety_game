import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android 13+ needs audio read permission; older Android may need storage.
///
/// If [permission_handler] is not registered (e.g. hot reload after adding the
/// plugin), returns true so we still try to read files instead of crashing.
Future<bool> ensureMusicFolderReadAccess() async {
  if (kIsWeb) return false;
  if (!Platform.isAndroid) return true;

  try {
    var audio = await Permission.audio.status;
    if (!audio.isGranted && !audio.isLimited) {
      audio = await Permission.audio.request();
    }
    if (audio.isGranted || audio.isLimited) return true;

    var storage = await Permission.storage.status;
    if (!storage.isGranted) {
      storage = await Permission.storage.request();
    }
    if (storage.isGranted) return true;

    return false;
  } on MissingPluginException {
    return true;
  }
}
