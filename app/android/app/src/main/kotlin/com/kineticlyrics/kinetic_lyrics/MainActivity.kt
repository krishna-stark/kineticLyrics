package com.kineticlyrics.kinetic_lyrics

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Vibrator
import android.os.VibratorManager
import android.os.VibrationEffect
import android.media.AudioAttributes
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.FileProvider
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val audioPermissionRequest = 7042

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Retired speech-recognition downloads and drafts belong to this app.
        // Keep deletion off the UI thread; semantic models and saved moments stay.
        Thread({
            for (relative in listOf("models/whisper-base-int8", "models/whisper-tiny-int8", "learned_lyrics")) {
                runCatching { File(filesDir, relative).deleteRecursively() }
            }
        }, "retired-lyric-cache-cleanup").start()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kinetic_lyrics/haptics")
            .setMethodCallHandler { call, result ->
                if (call.method != "pulse") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        getSystemService(VibratorManager::class.java).defaultVibrator
                    } else {
                        @Suppress("DEPRECATION")
                        getSystemService(VIBRATOR_SERVICE) as Vibrator
                    }
                    if (!vibrator.hasVibrator()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val attributes = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        // A short, perceptible accent; no sustained buzzing or
                        // keyboard-feedback dependency. Media vibration policy applies.
                        vibrator.vibrate(VibrationEffect.createOneShot(28, 180), attributes)
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(28, attributes)
                    }
                    result.success(true)
                } catch (error: Exception) {
                    result.error("haptic_unavailable", error.message, null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kinetic_lyrics/moments")
            .setMethodCallHandler { call, result ->
                if (call.method != "shareImage") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val png = call.argument<ByteArray>("png")
                if (png == null || png.size < 8 || png.size > 8 * 1024 * 1024 ||
                    png[0] != 0x89.toByte() || png[1] != 0x50.toByte() || png[2] != 0x4e.toByte()) {
                    result.error("invalid_image", "Invalid visual card", null)
                    return@setMethodCallHandler
                }
                // Export I/O stays off the platform UI thread. The share sheet
                // is opened only by an explicit user tap; nothing is sent here.
                Thread {
                    try {
                        val directory = File(cacheDir, "lyric-moments").apply { mkdirs() }
                        directory.listFiles()?.filter { System.currentTimeMillis() - it.lastModified() > 86400000L }
                            ?.forEach { it.delete() }
                        val file = File(directory, "moment-${System.currentTimeMillis()}.png")
                        file.writeBytes(png)
                        val uri = FileProvider.getUriForFile(this, "$packageName.moments", file)
                        val text = call.argument<String>("text")?.take(1000) ?: "Kinetic Lyrics"
                        runOnUiThread {
                            try {
                                val intent = Intent(Intent.ACTION_SEND).apply {
                                    type = "image/png"
                                    putExtra(Intent.EXTRA_STREAM, uri)
                                    putExtra(Intent.EXTRA_TEXT, text)
                                    clipData = android.content.ClipData.newRawUri("Lyric moment", uri)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }
                                startActivity(Intent.createChooser(intent, "Share visual moment"))
                                result.success(null)
                            } catch (error: Exception) {
                                result.error("share_unavailable", error.message, null)
                            }
                        }
                    } catch (error: Exception) {
                        runOnUiThread { result.error("export_failed", error.message, null) }
                    }
                }.start()
            }
        NowPlayingBridge.initialize(applicationContext)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kinetic_lyrics/now_playing/events",
        ).setStreamHandler(NowPlayingBridge)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kinetic_lyrics/now_playing/methods",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openAccessSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(null)
                }
                "setScreenAwake" -> {
                    if (call.arguments == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                "refresh" -> {
                    NowPlayingBridge.refresh()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kinetic_lyrics/audio/events",
        ).setStreamHandler(DeviceAudioBridge)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "kinetic_lyrics/audio/methods",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestAccess" -> {
                    if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                        PackageManager.PERMISSION_GRANTED
                    ) {
                        DeviceAudioBridge.restart()
                    } else {
                        requestPermissions(
                            arrayOf(Manifest.permission.RECORD_AUDIO),
                            audioPermissionRequest,
                        )
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        NowPlayingBridge.refresh()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == audioPermissionRequest &&
            grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        ) {
            DeviceAudioBridge.startIfPermitted()
        }
    }

    override fun onDestroy() {
        DeviceAudioBridge.stop()
        super.onDestroy()
    }
}
