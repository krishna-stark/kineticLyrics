package com.kineticlyrics.kinetic_lyrics

/** Run as a plain JVM main against SpectrumAnalyzer; no device required. */
fun main() {
    fun fft(frequency: Double, rate: Int, amplitude: Int = 90): ByteArray {
        val data = ByteArray(1024)
        val bin = kotlin.math.round(frequency * data.size / rate).toInt()
        data[bin * 2] = amplitude.toByte()
        return data
    }
    fun amplitude(frame: SpectrumFrame) = listOf(frame.bass, frame.mid, frame.treble)
    fun attacks(frame: SpectrumFrame) = listOf(frame.bassOnset, frame.midOnset, frame.trebleOnset)
    var assertions = 0
    fun verify(condition: Boolean, message: String) {
        check(condition) { message }
        assertions++
    }
    for (rate in listOf(22050, 44100, 48000)) {
        for ((band, frequency) in listOf(100.0, 1000.0, 8000.0).withIndex()) {
            val analyzer = SpectrumAnalyzer()
            analyzer.analyze(ByteArray(1024), rate * 1000, .2)
            val hit = analyzer.analyze(fft(frequency, rate), rate * 1000, .2)
            verify(amplitude(hit)[band] > .04, "$frequency Hz missing at $rate Hz")
            verify(attacks(hit)[band] > .04, "$frequency Hz attack missing")
            for (other in 0..2) if (other != band) {
                verify(amplitude(hit)[other] == 0.0, "frequency leaked into band $other")
                verify(attacks(hit)[other] == 0.0, "attack leaked into band $other")
            }
            val hold = analyzer.analyze(fft(frequency, rate), rate * 1000, .2)
            verify(attacks(hold).all { it == 0.0 }, "sustained tone created attack")
            verify(amplitude(hold).all { it in 0.0..<1.0 }, "saturated amplitude")
        }
    }
    val quiet = SpectrumAnalyzer()
    repeat(200) { quiet.analyze(ByteArray(1024), 48000000, 0.0) }
    val quantization = quiet.analyze(fft(8000.0, 48000, 1), 48000000, .01)
    verify(amplitude(quantization).all { it == 0.0 }, "quantization noise became signal")
    val silentWave = quiet.analyze(fft(100.0, 48000), 48000000, 0.0)
    verify(amplitude(silentWave).all { it == 0.0 }, "silent waveform generated energy")
    val invalid = quiet.analyze(ByteArray(8), 0, .5)
    verify(invalid == SpectrumFrame(), "invalid sampling rate not guarded")
    println("SpectrumAnalyzer: $assertions synthetic FFT assertions passed")
}
