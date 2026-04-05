package com.acenzo.roadrick

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.acenzo.roadrick/fm_radio",
        ).setMethodCallHandler { call, result ->
            if (call.method == "openFmRadio") {
                val pm = applicationContext.packageManager
                for (pkg in FM_RADIO_PACKAGES) {
                    try {
                        val intent = pm.getLaunchIntentForPackage(pkg) ?: continue
                        startActivity(intent)
                        result.success(true)
                        return@setMethodCallHandler
                    } catch (_: Exception) {
                        // try next package
                    }
                }
                result.success(false)
            } else {
                result.notImplemented()
            }
        }
    }

    private companion object {
        /** OEM / AOSP package names; first match wins. */
        val FM_RADIO_PACKAGES = listOf(
            "com.sec.android.app.fm",
            "com.samsung.android.app.radio",
            "com.motorola.fmplayer",
            "com.motorola.fmradio",
            "com.caf.fmradio",
            "com.miui.fm",
            "com.huawei.android.FMRadio",
            "com.sonyericsson.fmradio",
            "com.lge.fmradio",
            "com.mediatek.fmradio",
            "com.android.fmradio",
        )
    }
}
