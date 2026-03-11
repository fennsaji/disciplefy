package com.disciplefy.bible_study

import android.annotation.TargetApi
import android.app.Activity
import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    companion object {
        private const val SCREENSHOT_CHANNEL = "com.disciplefy/screenshot"
    }

    private var screenshotEventSink: EventChannel.EventSink? = null
    private var screenshotObserver: ContentObserver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SCREENSHOT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    screenshotEventSink = events
                    registerScreenshotListener()
                }

                override fun onCancel(arguments: Any?) {
                    unregisterScreenshotListener()
                    screenshotEventSink = null
                }
            })
    }

    private fun registerScreenshotListener() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Android 14+: dedicated API — no permissions needed
            registerScreenCaptureCallbackApi34()
        } else {
            // Android < 14: ContentObserver on the images store
            val handler = Handler(Looper.getMainLooper())
            val observer = object : ContentObserver(handler) {
                private var lastMs = 0L

                override fun onChange(selfChange: Boolean, uri: Uri?) {
                    val now = System.currentTimeMillis()
                    if (now - lastMs < 1_500) return // debounce duplicate events
                    lastMs = now
                    uri?.let { checkIfScreenshot(it) }
                }
            }
            contentResolver.registerContentObserver(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI, true, observer
            )
            screenshotObserver = observer
        }
    }

    @TargetApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun registerScreenCaptureCallbackApi34() {
        addScreenCaptureCallback(
            Executors.newSingleThreadExecutor(),
            Activity.ScreenCaptureCallback { runOnUiThread { screenshotEventSink?.success(null) } }
        )
    }

    private fun unregisterScreenshotListener() {
        screenshotObserver?.let {
            contentResolver.unregisterContentObserver(it)
            screenshotObserver = null
        }
    }

    /** Queries the specific URI provided by the ContentObserver to check if it is a screenshot. */
    private fun checkIfScreenshot(uri: Uri) {
        try {
            contentResolver.query(
                uri,
                arrayOf(MediaStore.Images.Media.DISPLAY_NAME, MediaStore.Images.Media.RELATIVE_PATH),
                null, null, null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val name = cursor.getString(0)?.lowercase() ?: ""
                    val path = if (cursor.columnCount > 1) cursor.getString(1)?.lowercase() ?: "" else ""
                    if (name.contains("screenshot") || path.contains("screenshot")) {
                        screenshotEventSink?.success(null)
                    }
                }
            }
        } catch (_: Exception) {
            // No permission to read this URI — silently skip
        }
    }
}
