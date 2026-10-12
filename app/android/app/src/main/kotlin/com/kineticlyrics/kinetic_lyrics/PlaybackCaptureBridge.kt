package com.kineticlyrics.kinetic_lyrics

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.AudioPlaybackCaptureConfiguration
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.atomic.AtomicBoolean

object PlaybackCaptureBridge : EventChannel.StreamHandler {
    const val requestCode = 7043
    const val sampleRate = 16000

    private var sink: EventChannel.EventSink? = null
    private var projection: MediaProjection? = null
    private var recorder: AudioRecord? = null
    private var worker: Thread? = null
    private val running = AtomicBoolean(false)
    private val main = Handler(Looper.getMainLooper())
    private var requestPending = false
    private var captureUid: Int? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    fun request(activity: Activity, sourcePackage: String?) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            sink?.error("unsupported", "Playback capture requires Android 10 or newer", null)
            return
        }
        if (requestPending) return
        val uid = try {
            require(!sourcePackage.isNullOrBlank()) { "No selected music app" }
            @Suppress("DEPRECATION")
            activity.packageManager.getApplicationInfo(sourcePackage, 0).uid
        } catch (error: Exception) {
            sink?.error("capture_source", "The selected music app cannot be captured: ${error.message}", null)
            return
        }
        if (running.get() && captureUid == uid) {
            sink?.success(mapOf("state" to "capturing"))
            return
        }
        stop()
        captureUid = uid
        requestPending = true
        val manager = activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE)
            as MediaProjectionManager
        activity.startActivityForResult(manager.createScreenCaptureIntent(), requestCode)
    }

    fun permissionResult(granted: Boolean): Boolean {
        val stillRequested = requestPending
        requestPending = false
        if (stillRequested && !granted) sink?.success(mapOf("state" to "denied"))
        return stillRequested
    }

    fun start(
        context: Context,
        resultCode: Int,
        data: Intent?,
        onStopped: () -> Unit,
    ) {
        requestPending = false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            resultCode != Activity.RESULT_OK || data == null
        ) {
            sink?.success(mapOf("state" to "denied"))
            return
        }
        stop()
        val manager = context.getSystemService(Context.MEDIA_PROJECTION_SERVICE)
            as MediaProjectionManager
        val mediaProjection = manager.getMediaProjection(resultCode, data)
        if (mediaProjection == null) {
            sink?.success(mapOf("state" to "denied"))
            return
        }
        projection = mediaProjection
        mediaProjection.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() {
                if (projection !== mediaProjection) return
                stop()
                main.post { sink?.success(mapOf("state" to "stopped")) }
                onStopped()
            }
        }, main)

        try {
            val uid = requireNotNull(captureUid) { "No selected music app" }
            val captureConfig = AudioPlaybackCaptureConfiguration.Builder(mediaProjection)
                .addMatchingUid(uid)
                .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
                .build()
            val format = AudioFormat.Builder()
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setSampleRate(sampleRate)
                .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                .build()
            val minimum = AudioRecord.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
            )
            val audioRecord = AudioRecord.Builder()
                .setAudioFormat(format)
                .setBufferSizeInBytes(maxOf(minimum * 4, sampleRate * 2))
                .setAudioPlaybackCaptureConfig(captureConfig)
                .build()
            recorder = audioRecord
            running.set(true)
            audioRecord.startRecording()
            main.post { sink?.success(mapOf("state" to "capturing")) }
            worker = Thread({ readLoop(audioRecord) }, "lyrics-playback-capture").apply {
                start()
            }
        } catch (error: Exception) {
            stop()
            sink?.error("capture_failed", error.message, null)
        }
    }

    private fun readLoop(audioRecord: AudioRecord) {
        val samples = ShortArray(1600) // 100 ms chunks
        while (running.get()) {
            val count = audioRecord.read(samples, 0, samples.size, AudioRecord.READ_BLOCKING)
            if (count <= 0) continue
            val bytes = ByteBuffer.allocate(count * 2).order(ByteOrder.LITTLE_ENDIAN)
            for (index in 0 until count) bytes.putShort(samples[index])
            val payload = mapOf(
                "state" to "pcm",
                "sampleRate" to sampleRate,
                "samples" to bytes.array(),
            )
            main.post {
                if (running.get() && recorder === audioRecord) sink?.success(payload)
            }
        }
    }

    fun stop(notify: Boolean = false) {
        requestPending = false
        running.set(false)
        val audioRecord = recorder
        recorder = null
        try {
            audioRecord?.stop()
        } catch (_: Exception) {
        }
        audioRecord?.release()
        worker = null
        val mediaProjection = projection
        projection = null
        mediaProjection?.stop()
        if (notify) sink?.success(mapOf("state" to "stopped"))
    }
}
