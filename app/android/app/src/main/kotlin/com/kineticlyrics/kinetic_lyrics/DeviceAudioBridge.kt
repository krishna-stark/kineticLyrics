package com.kineticlyrics.kinetic_lyrics

import android.media.audiofx.Visualizer
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.EventChannel

/** Low-resolution output-mix analysis for visuals. No audio is stored or transmitted. */
object DeviceAudioBridge : EventChannel.StreamHandler {
    private var sink: EventChannel.EventSink? = null
    private var visualizer: Visualizer? = null
    private val main = Handler(Looper.getMainLooper())
    private val spectrumAnalyzer = SpectrumAnalyzer()
    private var latestWaveform = List(64) { 0.0 }
    private var latestRms = 0.0
    private var latestZeroCrossingRate = 0.0

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        startIfPermitted()
    }

    override fun onCancel(arguments: Any?) {
        sink = null
        stop()
    }

    fun startIfPermitted() {
        if (sink == null || visualizer != null) return
        try {
            val engine = Visualizer(0)
            val range = Visualizer.getCaptureSizeRange()
            engine.captureSize = minOf(1024, range[1])
            // Normalize content rather than tying visual strength to volume.
            engine.scalingMode = Visualizer.SCALING_MODE_NORMALIZED
            engine.setDataCaptureListener(
                object : Visualizer.OnDataCaptureListener {
                    override fun onWaveFormDataCapture(
                        visualizer: Visualizer?, waveform: ByteArray?, samplingRate: Int,
                    ) {
                        if (waveform == null || waveform.isEmpty()) return
                        var sum = 0.0
                        var crossings = 0
                        var previous = 0
                        for (sample in waveform) {
                            val centered = (sample.toInt() and 0xff) - 128
                            sum += centered * centered
                            if ((centered >= 0 && previous < 0) ||
                                (centered < 0 && previous >= 0)
                            ) crossings++
                            previous = centered
                        }
                        val rms = kotlin.math.sqrt(sum / waveform.size) / 128.0
                        latestRms = rms.coerceIn(0.0, 1.0)
                        latestWaveform = (0 until 64).map { slot ->
                            val from = slot * waveform.size / 64
                            val to = maxOf(from + 1, (slot + 1) * waveform.size / 64)
                            var total = 0.0
                            for (index in from until minOf(to, waveform.size)) {
                                total += ((waveform[index].toInt() and 0xff) - 128) / 128.0
                            }
                            (total / (to - from)).coerceIn(-1.0, 1.0)
                        }
                        latestZeroCrossingRate =
                            (crossings.toDouble() / waveform.size).coerceIn(0.0, 1.0)
                    }

                    override fun onFftDataCapture(
                        visualizer: Visualizer?, fft: ByteArray?, samplingRate: Int,
                    ) {
                        if (fft == null || fft.size < 8) return
                        publishSpectrum(fft, samplingRate)
                    }
                },
                minOf(Visualizer.getMaxCaptureRate(), 30000),
                true,
                true,
            )
            engine.enabled = true
            visualizer = engine
        } catch (_: SecurityException) {
            publishUnavailable()
        } catch (_: RuntimeException) {
            publishUnavailable()
        } catch (_: UnsupportedOperationException) {
            publishUnavailable()
        }
    }

    private fun publishSpectrum(fft: ByteArray, samplingRateMilliHz: Int) {
        val features = spectrumAnalyzer.analyze(fft, samplingRateMilliHz, latestRms)
        val payload = hashMapOf<String, Any>(
            "energy" to features.energy,
            "waveform" to latestWaveform,
            "spectrum" to features.spectrum,
            "bass" to features.bass,
            "mid" to features.mid,
            "treble" to features.treble,
            "bassOnset" to features.bassOnset,
            "midOnset" to features.midOnset,
            "trebleOnset" to features.trebleOnset,
            "onset" to features.flux,
            "rms" to latestRms,
            "spectralCentroid" to features.spectralCentroid,
            "spectralFlux" to features.flux,
            "zeroCrossingRate" to latestZeroCrossingRate,
            "timestampUs" to SystemClock.elapsedRealtimeNanos() / 1000,
            "live" to true,
        )
        main.post { sink?.success(payload) }
    }

    private fun publishUnavailable() {
        main.post { sink?.success(mapOf("live" to false)) }
    }

    fun stop() {
        try {
            visualizer?.enabled = false
            visualizer?.release()
        } catch (_: RuntimeException) {
        }
        visualizer = null
        spectrumAnalyzer.reset()
        latestRms = 0.0
        latestWaveform = List(64) { 0.0 }
        latestZeroCrossingRate = 0.0
    }
}
