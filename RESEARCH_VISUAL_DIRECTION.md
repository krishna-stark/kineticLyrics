# Kinetic Lyrics — visual direction research

Research date: 11 October 2026. Implementation is paused. This document proposes a new direction; it does not describe shipped capabilities or replace PRODUCT_VISION.md yet.

## Diagnosis

The current renderer changes the animation of words but leaves most of their composition unchanged. A centered paragraph, fitted to two rows, remains the visual skeleton. Perspective, shadows, and staggered entrances decorate that skeleton. They do not create the hierarchy, editorial pacing, spatial relationships, and section changes of a lyrical music video.

The existing vision explicitly restricts foreground text to two lines, prioritizes a long stable hold, and limits normal beat scale to about 2%. These constraints helped prevent unreadable motion, but treating them as the default art direction has constrained expression. The latest user direction takes precedence: readability should be validated in the resulting scene rather than enforced through one universal composition.

The audio path also needs reconsideration before stronger effects. DeviceAudioBridge currently averages three broad fractions of the FFT and produces one aggregate flux signal. At a hypothetical 48 kHz sampling rate, the present low band spans roughly 120–1920 Hz. That is too broad to isolate bass movement. Mid and high signals are smoothed similarly, so brief high-frequency attacks can become soft background changes. These observations come from local code inspection, not a new device measurement.

## Evidence and its practical limits

[CMU's Kinetic Typography Engine](https://www.cs.cmu.edu/~johnny/academic/KT_Engine_UIST2002.pdf) describes using pacing, size, weight, anticipation, follow-through, and analogous physical motion to convey tone and guide attention. Its useful lesson for this app: choose a word's behavior according to its expression, rather than giving every word the same transform. This is expressive-design research, not a guarantee that any preset will be enjoyable.

[Visual Lyrics, IUI 2026](https://www.davidlin.io/papers/visuallyrics.pdf) combines lyrical meaning and vocal characteristics, including emphasis, pitch change, elongation, and vibrato, with diverse styling and readability checks. It separates planning, generation, and validation. This is directly relevant to the current problem: line highlighting alone does not supply art direction. Its offline vocal separation and generation pipeline cannot simply be assumed to work during arbitrary live Android playback.

[COTODAMA's description of its technology](https://cotodama-speaker.com/pages/our-story) emphasizes interpreting lyrical mood and key lines to choose matching fonts and motion. This is a product precedent, not independent evidence of emotional effectiveness.

[Salimpoor et al., Nature Neuroscience, 2011](https://www.nature.com/articles/nn.2726) measured dopamine release associated with anticipation and peak emotional responses to music. It did not test our visuals. [Cheung et al., Current Biology, 2019](https://www.sciencedirect.com/science/article/pii/S0960982219312588) found musical pleasure depended on interactions between uncertainty and surprise in tonal harmony. My design inference is to use build-up, recognizable motifs, and satisfying release. Neither paper supports promising dopamine release from an animation or maximizing stimulation continuously.

[TouchDesigner spectrum documentation](https://derivative.ca/UserGuide/Audio_Spectrum_CHOP) explains logarithmic frequency presentation and the tradeoff between FFT resolution and temporal freshness. [Android Visualizer documentation](https://developer.android.com/reference/android/media/audiofx/Visualizer) specifies the FFT representation and sampling-rate units. These support calibrating audio features in actual frequency ranges rather than arbitrary array fractions.

The previously inspected official KISSIK, Dhop, Arabic Kuthu, and Naa Naa Hyraanaa references remain useful for phrase hierarchy, large display words, layered framing, and distinct visual worlds. Their footage, manual choreography, and production assets are advantages a live renderer must approximate deliberately. View counts are not evidence that a particular animation caused enjoyment.

## Proposed experience: words perform inside a musical scene

Replace the universal paragraph with prepared compositions selected by delivery, phrase length, meaning, and song section. An LRC line is input timing data, not a mandatory visual unit.

1. **Word spotlight.** One emphasized word owns the screen; short supporting words occupy a quiet nearby cluster. The hero approaches in depth, lands on its accent, then departs through a mask or recession.
2. **Phrase sculpture.** Three to five short word groups form an asymmetric composition, with one clear reading path. Each group has a prepared position and independent entrance/departure. Whole Telugu and Tamil words stay intact.
3. **Rhythmic assembly.** A rapid phrase builds in fixed slots, with stress accents transferring attention. Predictable placement protects reading while the pose and hierarchy remain expressive.
4. **Call and response.** Alternating phrases occupy two distinct spatial regions, preserving performer identity and allowing a visual answer rather than resetting to center.
5. **Chorus monument.** A recognizable hook returns as a large dimensional composition. Lighting, surrounding geometry, and depth intensify on later returns while the motif stays familiar.
6. **Intimate suspension.** Sparse vocals use generous space, gentle reveals, and sustained depth. The visualizer remains sensitive even when the typography is restrained.

These are proposed scene families, not six completed patterns. More than two rows may be appropriate; an unreadable wall of text is not. Prepare the geometry before arrival. Never scatter fast words to random locations or break Indic shaping to gain an effect.

## Distinct response for every audible band

The aim is for every meaningful low, mid, and high event to have a visible consequence. There should be separate continuous energy and transient responses, with one dominant focus. Frequency bands overlap instruments: mids are not a reliable vocal detector, and a bass transient is not automatically a kick drum.

- **Low frequencies:** mass and pressure. Broad surfaces compress or displace, extruded text gains depth, nearby objects feel a short impact, and scene perspective receives a bounded push. A bass hit should visibly move substantial geometry, not merely brighten a thin line.
- **Mid frequencies:** body and articulation. Ribbons, connected panels, and object silhouettes flex; selected word strokes or prepared poses respond to stress. Sustained mid energy produces smooth shape motion; mid transients produce distinct short accents.
- **High frequencies:** detail and sharpness. Fine edge glints, contour tracing, small particles, and short strokes answer hats and bright attacks with quick decay. High-frequency activity should be visibly faster than the low layer.
- **Combined accents:** punctuation. When several bands rise together, a prepared word landing, depth reveal, or scene cut can become the hero event. Smaller band responses continue beneath it.
- **Silence and decay:** release. Energy recedes naturally; particles settle and geometry relaxes. No fabricated beats to keep the screen busy.

Starting calibration proposal: low 30–250 Hz, mid 250–4000 Hz, high 4000 Hz to min(16000 Hz, Nyquist), backed by finer logarithmic bands. These boundaries are design starting points, not universal scientific divisions. Use actual sample rate, exclude DC, retain per-band spectral flux, and normalize adaptively without amplifying background noise into constant activity. Different attack/release envelopes should make low impacts weighty and high attacks crisp. Validate leakage with isolated audio fixtures before evaluating mixed songs.

## Visualizers that complement this direction

**Sculpted surfaces** suit strong bass: a broad plane or relief changes depth and lighting. **Elastic ribbons and contour fields** suit melodic or mid-rich passages: continuous shape motion makes sustained sound visible. **Sparse particle and edge fields** suit bright percussion: rapid detail sits around a readable foreground. **Contextual object scenes** provide narrative: one coherent object has mass, surface motion, and highlights driven by different bands. **Spectral architecture** suits instrumental sections: frequency groups construct a scene with spatial hierarchy rather than a permanently attached equalizer strip.

Use these as components of one visual world per section, not simultaneous unrelated effects. A short spectrum view is useful for debugging band response, but need not become the finished art direction.

## Transitions must have a reason

Each transition should answer three questions: what musical event triggers it, where should attention go, and what remains recognizable?

- A stressed word can emerge from a narrow mask, acquire depth, and settle with follow-through.
- A held note can sustain a stretched pose or trailing outline, then relax at vocal release; do this only with trustworthy vocal information.
- A departing phrase can recede, fold as a plane, or dissolve its outer contour while the next phrase claims focus. Its exit need not reverse its entrance.
- A verse-to-chorus change can expand the visual space and reveal the hook motif.
- A build-up can accumulate tension around a stable focal word; a confirmed strong onset releases that tension.

Live playback offers no guaranteed knowledge of the next drop. Only use anticipation when timing or analysis supports it. Seek, pause, and track changes must select the correct current scene without replaying unrelated choreography.

## Changes proposed for the vision

Replace the two-line rule with a composition and reading-path requirement. Replace universal long stable holds with sufficient readable exposure appropriate to the vocal delivery. Separate tiny continuous text response from larger, intentional word performances. Allow asymmetric entrance/exit choreography for expressive lyrics; interaction controls can retain their own continuity rules. Treat controlled depth as a meaningful scene tool rather than an occasional shadow. Keep bounds checks, multilingual shaping, reduced motion, honest audio status, and prepared assets.

Line-only sources still provide estimated word timing. Before claiming precisely sung word choreography or pitch-driven motion, obtain reliable alignment or use a conservative phrase-level fallback. More energetic animation will make timing errors more obvious.

## Next validation, before another app-wide implementation

Create three 20–30 second directed studies using representative permitted audio: a percussion-heavy hook, a sustained melodic phrase, and a fast multilingual verse. Each study should demonstrate composition changes, distinguishable low/mid/high response, a deliberate entrance and departure, and a section transition. Evaluate full-speed recordings on the phone, not only screenshots.

Compare against the current build: does the movement visibly match specific sounds, can the current lyric be followed, do scenes feel different, does the chorus feel earned, and would the listener choose to keep watching? Ask for preference and perceived synchronization rather than claiming a dopamine measurement. Then validate complete songs, reduced motion, actual audio-to-frame latency, thermal behavior, and frame performance. Approve the artistic direction before expanding the pattern catalog.

No runtime code or installed phone build was changed during this research pass.
