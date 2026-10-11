package com.kineticlyrics.kinetic_lyrics

import kotlin.math.hypot
import kotlin.math.sqrt
import kotlin.math.max
import kotlin.math.pow

/** Pure FFT analysis: no Android runtime, audio storage, or synthetic rhythm. */
internal data class SpectrumFrame(
    val energy: Double = 0.0, val bass: Double = 0.0,
    val mid: Double = 0.0, val treble: Double = 0.0,
    val bassOnset: Double = 0.0, val midOnset: Double = 0.0,
    val trebleOnset: Double = 0.0, val flux: Double = 0.0,
    val spectralCentroid: Double = 0.0,
    val spectrum: List<Double> = emptyList(),
)

internal class SpectrumAnalyzer {
    private var previousSpectrum = DoubleArray(0)
    private val bandPeaks = doubleArrayOf(.08, .04, .025)

    fun analyze(fft: ByteArray, samplingRateMilliHz: Int, rms: Double): SpectrumFrame {
        // Android supplies mHz, while FFT bin spacing is sample-rate / N.
        val sampleRateHz = samplingRateMilliHz / 1000.0
        if (sampleRateHz <= 0.0 || fft.size < 8) return SpectrumFrame()
        val bins = DoubleArray(fft.size / 2)
        for (bin in 1 until bins.size) {
            val index = bin * 2
            // One quantization step is gated before gain; silence must not
            // become a lively high-frequency field when adaptive gain rises.
            bins[bin] = max(0.0,
                hypot(fft[index].toDouble(), fft[index + 1].toDouble()) / 128.0 - 1.0 / 128.0)
        }
        val limits = arrayOf(30.0 to 250.0, 250.0 to 4000.0,
            4000.0 to minOf(16000.0, sampleRateHz / 2.0))
        val amplitudes = DoubleArray(3)
        val attacks = DoubleArray(3)
        val minima = doubleArrayOf(.035, .018, .012)
        val maxima = doubleArrayOf(12.0, 22.0, 30.0)
        val gains = DoubleArray(3)
        for (band in limits.indices) {
            var power = 0.0
            var positivePower = 0.0
            var count = 0
            for (bin in 1 until bins.size) {
                val frequencyHz = bin * sampleRateHz / fft.size
                if (frequencyHz < limits[band].first || frequencyHz >= limits[band].second) continue
                val value = bins[bin]
                power += value * value
                if (previousSpectrum.size == bins.size) {
                    val rise = max(0.0, value - previousSpectrum[bin])
                    positivePower += rise * rise
                }
                count++
            }
            val raw = sqrt(power / max(1, count))
            val rise = sqrt(positivePower / max(1, count))
            // A slowly releasing reference follows the track's dynamic range;
            // bounded gain cannot amplify silence or saturate every FFT frame.
            bandPeaks[band] = max(minima[band], max(raw, bandPeaks[band] * .995))
            val gain = minOf(maxima[band], .75 / bandPeaks[band])
            gains[band] = gain
            amplitudes[band] = compress(raw * gain)
            attacks[band] = compress(rise * gain * 1.6)
        }
        previousSpectrum = bins
        var weighted = 0.0
        var magnitude = 0.0
        for (index in 1 until bins.size) {
            weighted += index * bins[index]
            magnitude += bins[index]
        }
        val spectralCentroid = if (magnitude <= 0.0) 0.0 else
            (weighted / magnitude / bins.size).coerceIn(0.0, 1.0)
        val signalPresent = rms > .004 && magnitude > .01
        val bass = if (signalPresent) amplitudes[0] else 0.0
        val mid = if (signalPresent) amplitudes[1] else 0.0
        val treble = if (signalPresent) amplitudes[2] else 0.0
        val bassOnset = if (signalPresent) attacks[0] else 0.0
        val midOnset = if (signalPresent) attacks[1] else 0.0
        val trebleOnset = if (signalPresent) attacks[2] else 0.0
        val flux = max(bassOnset, max(midOnset, trebleOnset))
        val energy = (bass * .38 + mid * .42 + treble * .20).coerceIn(0.0, 1.0)
        val upperHz = minOf(16000.0, sampleRateHz / 2.0)
        val detail = (0 until 32).map { slot ->
            val from = 30.0 * (upperHz / 30.0).pow(slot / 32.0)
            val to = 30.0 * (upperHz / 30.0).pow((slot + 1) / 32.0)
            var power = 0.0
            var count = 0
            for (bin in 1 until bins.size) {
                val hz = bin * sampleRateHz / fft.size
                if (hz >= from && hz < to) { power += bins[bin] * bins[bin]; count++ }
            }
            // Narrow low-frequency slots can lie between FFT bins. Interpolate
            // those measured neighbors rather than creating permanent gaps.
            if (count == 0) {
                val location = sqrt(from * to) * fft.size / sampleRateHz
                val lower = location.toInt().coerceIn(1, bins.lastIndex)
                val upper = minOf(lower + 1, bins.lastIndex)
                val value = bins[lower] + (bins[upper] - bins[lower]) *
                    (location - lower).coerceIn(0.0, 1.0)
                power = value * value
                count = 1
            }
            val band = if (from < 250.0) 0 else if (from < 4000.0) 1 else 2
            if (signalPresent) compress(sqrt(power / max(1, count)) * gains[band] * 1.5) else 0.0
        }
        return SpectrumFrame(energy, bass, mid, treble, bassOnset,
            midOnset, trebleOnset, flux, spectralCentroid, detail)
    }

    private fun compress(value: Double): Double = value / (1.0 + value)

    fun reset() {
        previousSpectrum = DoubleArray(0)
        bandPeaks[0] = .08
        bandPeaks[1] = .04
        bandPeaks[2] = .025
    }
}
