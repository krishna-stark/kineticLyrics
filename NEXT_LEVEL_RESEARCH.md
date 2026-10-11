# Kinetic Lyrics: raising the bar

Research date: 11 October 2026. Research only; no application changes in this pass.

## Recommendation

Build a visual performance with a recognizable identity for each song. The strongest next investment is a prepared song score: vocal timings, section boundaries, recurring visual motifs, contextual assets and planned transitions. During playback, the renderer follows that score and reacts to live audio. AI prepares meaning and choices ahead of time; it does not improvise expensive assets inside the animation loop.

This is a product recommendation inferred from the sources below, not a proven engagement result. Much of it strengthens requirements already in PRODUCT_VISION.md. New extensions are identified separately.

Retain the user's chosen design: black background; flat, readable, varied typography; lyrics in the upper area; evident bottom-third visualizer; white-to-red bar height gradient; contextual objects behind the words; graceful instrumental expansion.

## Highest-priority improvements to the existing vision

### 1. Typography that performs the vocal

Give words different behavior based on vocal delivery: a sustained word settles and expands slowly; a stressed word gets one decisive entrance; rapid lyrics assemble into a readable phrase with sequential emphasis; an ending word departs with the breath or musical release. Keep one coherent font family pairing per song, with hierarchy changing by section. Preserve complete grapheme clusters in Indic scripts.

Apple Music Sing already distinguishes animated lead vocals, independently animated backing vocals and opposite-side duet lyrics. The opportunity here is more expressive typography while retaining that vocal clarity. [Apple Music Sing](https://www.apple.com/newsroom/2022/12/apple-introduces-apple-music-sing/)

Prerequisite: verified word timing rather than dividing a line evenly. Singing alignment is a distinct multilingual problem; speech timestamps alone are not evidence that Telugu, Tamil or Hindi singing will align correctly. Prefer available verified timestamps; benchmark singing-specific alignment on supported languages; use stable phrase-level emphasis when confidence is low. [Multilingual lyrics-to-audio alignment, ISMIR](https://archives.ismir.net/ismir2020/paper/000101.pdf)

### 2. A section-aware director with recurring motifs

Make verse, build, chorus, bridge and outro look deliberately different. A chorus should bring back a recognizable arrangement and object motif, with controlled development on its second appearance. Reserve the largest reveal for a musical event instead of constantly escalating motion.

Music structural-function research models intro, verse, chorus, bridge, outro, instrumental and silence. This supports investigating section detection; it does not establish dependable coverage for every genre or Indian song form. Start with reviewed song scores and conservative change detection before relying on automatic labels. [Structural-function analysis](https://arxiv.org/abs/2205.14700)

### 3. Instrument-led visualizer choreography

Retain the requested bars. Give low, mid and high activity distinguishable responses through bar regions and attack/release behavior. Bass can provide weight, mids provide sustained body, and treble provides short edge accents. Separate frequency energy from kick/snare onset and beat position: a loud sound is not necessarily a downbeat.

For lyric gaps, prepare restrained full-screen arrangements such as a contour waveform, mirrored spectrum or shallow ribbon field. Enter and leave on phrase or section boundaries, preserving a common visual anchor. Lyrics remain the focal point when vocals return.

TouchDesigner documents separate low/mid/high, kick/snare and rhythm analysis, illustrating the useful separation of signals. Its spectrum documentation also describes the latency-versus-frequency-resolution tradeoff. These are design references, not a recommendation to embed TouchDesigner in the phone app. [Audio analysis](https://derivative.ca/UserGuide/Palette%3AaudioAnalysis), [Spectrum analysis](https://derivative.ca/UserGuide/Audio_Spectrum_CHOP)

Important feasibility distinction: Essentia's RhythmExtractor2013 uses whole-track statistics and is explicitly unsuitable for real-time beat detection. Use such methods only for a prepared score where permitted audio is available; investigate a causal onset/beat tracker for live capture. [Essentia beat-detection tutorial](https://essentia.upf.edu/tutorial_rhythm_beatdetection.html)

### 4. Meaning-aware scenes across languages

Interpret an entire phrase and its emotional context before choosing a prop. Distinguish an actual object from an idiom, named person or metaphor. Match the exact recording/version before using artist or film imagery. Select one primary motif and optional supporting motif, with a clear confidence threshold and provenance.

Prepare translated meaning and assets asynchronously, cache them by recording and lyric version, and schedule appearances from the score. Late results should wait for a suitable transition rather than pop into the current phrase. A low-confidence result should omit the object rather than invent a connection. This supersedes the older abstract-object fallback in the vision for this recommendation, consistent with the user's later preference for relevant objects.

The current bounded object vocabulary and public-image search do not establish universal multilingual understanding. Expanding the library alone will not resolve that gap; meaning evaluation and visual curation are equally necessary.

## New features worth exploring

### 5. Duet and call-and-response choreography

Different singers get consistent positions and typographic voices. A backing response can appear as a smaller echo behind the lead; a duet can assemble into a shared composition at the chorus. Strong potential for film duets and group vocals. Requires singer-role annotations or reliable separation; do not claim arbitrary singer recognition. Apple's duet and backing-vocal views are a concrete precedent. [Apple Music Sing](https://www.apple.com/newsroom/2022/12/apple-introduces-apple-music-sing/)

### 6. Optional meaning and pronunciation

A tap reveals a compact translation or transliteration, then returns to the original script. This adds connection for listeners exploring another language without permanently cluttering the performance. Apple Music offers translation and pronunciation with explicitly limited language/song availability; treat coverage as a measured product capability. [Apple lyric support](https://support.apple.com/en-us/105076)

### 7. Artist-created visual scores and packs

Let artists or designers author a song's typography, motif, chorus reveal and background silhouettes in an editor. Community packs can extend the library after visual and rights review. This creates a route to genuinely authored experiences and a possible creator ecosystem. It is an exploratory product idea, not validated demand.

Use a reusable score format and strict asset budgets; creator content must pass the same readability and performance gates as built-in scenes. Spotify Canvas illustrates track-specific visual identity and reusable loops, while its guidelines caution against rapid cuts and intense flashing. [Spotify Canvas guidelines](https://support.spotify.com/in-en/artists/article/canvas-guidelines/)

### 8. Favorite lyric moments

Save a lyric moment and revisit its visual scene. Later, offer a shareable visual card or permitted short animation with a song deep link. Avoid making captured streaming audio export the prerequisite. First validate that users want to save and revisit moments; do not assume sharing produces retention.

### 9. Personal intensity and optional haptic accents

Offer subtle, cinematic and concert intensity while preserving a song's visual identity. A separate reduced-motion setting keeps typography stable. Investigate sparse, opt-in downbeat haptics after audio/visual timing is reliable; assess battery use and whether they add value on the supported phones.

## Quality gates before expanding effects

Review complete songs, not isolated screenshots. Include fast lyrics, sustained vocals, native and Romanized scripts, duets, silence, seeking, song switches, offline operation and thermal/battery behavior. Evaluate readability, musical alignment, contextual relevance and scene repetition separately.

At 60 Hz a frame has approximately 16.7 ms; inspect frame misses and tail latency, not only average frame rate. The latest short device checks improved raster performance but still contained occasional build spikes, so uninterrupted smoothness is not established. [Android rendering guidance](https://developer.android.com/topic/performance/issues/render)

A musical scene must have a clear focal point and continuity. Material's choreography guidance supports that principle, though its examples concern interface transitions rather than lyric performances. [Material choreography](https://m1.material.io/motion/choreography.html)

Live audio access is also a real constraint: Android requires playback-capture permission and the source app can disallow capture. Do not promise every-song vocal alignment or instrument recognition from an inaccessible stream. [Android playback capture](https://developer.android.com/media/platform/av-capture)

## Suggested order and validation

1. Prove three distinct, reviewed performances: an intimate melody, fast rap, and a high-energy chorus. Use deliberately prepared scores to judge the artistic ceiling before automating it.
2. Fix smoothness and timing, then add section continuity and multilingual context. Evaluate both familiar and previously unseen songs to avoid a hand-picked demo illusion.
3. Add duet choreography and optional meaning/pronunciation.
4. Test demand for creator packs, saved moments and haptics before building a larger ecosystem.

Proposed success criteria: listeners can follow the words, notice verse-to-chorus development, recognize relevant imagery and watch a full song comfortably. Measure these with device traces and listener review. No claim is made that any feature causes dopamine release or a particular retention increase.
