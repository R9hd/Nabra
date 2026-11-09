package com.example.nabra

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Two small bridges Dart can call:
 *  - "nabra/lockscreen": show the app over the lock screen ONLY while an alert is active.
 *  - "nabra/phone": place a phone call directly (used for the 5-minute auto-call).
 *    Android itself turns emergency numbers into "dialer opened, press Call".
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "nabra/lockscreen").setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> { setAlertMode(true); result.success(null) }
                "disable" -> { setAlertMode(false); result.success(null) }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "nabra/phone").setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> {
                    if (!hasCallPermission()) requestPermissions(arrayOf(Manifest.permission.CALL_PHONE), 7)
                    result.success(hasCallPermission())
                }
                "call" -> {
                    val number = call.argument<String>("number") ?: ""
                    if (number.isEmpty() || !hasCallPermission()) {
                        result.success(false)
                    } else {
                        try {
                            startActivity(Intent(Intent.ACTION_CALL, Uri.parse("tel:$number")))
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasCallPermission() =
        checkSelfPermission(Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED

    private fun setAlertMode(on: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (on) window.addFlags(flags) else window.clearFlags(flags)
        }
        val keepOn = WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        if (on) window.addFlags(keepOn) else window.clearFlags(keepOn)
    }
}
