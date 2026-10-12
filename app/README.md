# Kinetic Lyrics

Flutter Android app for a full-screen lyric experience, following
[`PRODUCT_VISION.md`](../PRODUCT_VISION.md).

## Implemented reference experience

- OLED black, warm-white lyrics, selective red word emphasis, and a restrained
  fluid instrumental field. Only the active paint surface ticks every frame.
- Pure OLED-black canvas. Generated picture backgrounds are excluded from the
  runtime and APK. Expression comes from typography and audio-driven accents.
- Compact word compositions replace the rejected evenly spaced vertical stack.
  A licensed Roboto Condensed display face, a large emphasized word, and smaller
  paired supporting words establish a poster-like hierarchy. All geometry is
  prepared before arrival; whole Telugu/Tamil words use native fallbacks.
- Successive shots preserve every lyric word. Independent perspective arrivals,
  masked visibility, shallow depth, and different staggered departure paths give
  words deliberate performances. Line-only sources still use estimated word
  timing; precise vocal alignment and pitch-driven motion are not claimed.
- Actual sampling-rate-calibrated low (30–250 Hz), mid (250–4000 Hz) and high
  (4000–16000 Hz, capped at Nyquist) FFT bands have independent energy and
  onset channels. Quantization gating and bounded adaptive gain prevent silence
  amplification. Bands describe frequency content, not isolated instruments.
- The visualizer follows the supplied rounded-bar reference: 40 bars across
  the bottom third, white during melodies and red on strong measured attacks.
  Heights follow 32 logarithmic FFT bins with fast attack and smooth release. Lyrics
  and contextual objects are clipped to the top two-thirds.
- Fast phrases retire completed words into smaller, lighter text; the previous
  shot briefly recedes behind new words. Slow phrases retain readable holds.
- Bundled multilingual E5 analyzes lyric context on a background isolate and
  selects objects and motion families. Those choices direct prepared typography,
  composition, and entrance/departure transitions. Results are cached by lyric
  content; stale track results are discarded. No lyrics are uploaded for this.
  Model failures use an explicitly marked deterministic fallback. Telugu, Tamil,
  and Hindi anchors have native-script regression coverage; cross-language AI
  accuracy is model-dependent and has not been validated for every language.
  Neutral embedding baselines reduce generic motion/object bias; typography
  changes require relative evidence rather than a raw cosine score.
- Bebas Neue, Cormorant Garamond, Space Grotesk, and Roboto Condensed provide
  contrasting typography, with native Telugu/Tamil fallbacks. Font licenses and
  sources are in `assets/fonts/`.
- Forty original CC0 vector silhouettes appear selectively on the black
  canvas, aligned to each original lyric line with a short crossfade.
  Native-language objects appear immediately while AI direction is prepared. They are prepared artwork with
  perspective transforms, not generated pictures or textured 3D models.
- Deliberate notification-access, no-music, loading, unavailable, error, paused,
  and AI preparation/capture/listening/partial-lyrics states. Controls are quiet,
  scroll at large system text sizes, and appear on tap.
- Seeking and track changes invalidate stale lookups and AI previews. Paused
  playback freezes the visual field. New tracks fade in through a single surface.
- Android Remove Animations disables continuous motion. Functional UI follows
  system text size. Playback keeps the foreground display awake; pause or leaving
  the app releases that policy.
- AI audio transcription requires an explicit privacy preflight, reports model progress, supports
  cancellation during download and capture, stores lyrics locally, and gives
  friendly retryable errors. Spectral audio permission also has an explanation.

Visual references inspected: the official [Dhop](https://www.youtube.com/watch?v=09tCNsSRE3U),
[KISSIK](https://www.youtube.com/watch?v=3C1n5lqGdmY),
[NaaNaa Hyraanaa](https://www.youtube.com/watch?v=EqDlrimnMCE), and
[Arabic Kuthu](https://www.youtube.com/watch?v=8FAUEv_E_xQ) videos. The adapted
ideas are lyric hierarchy, layered depth, a recurring title-card identity, and
contrasting energy between sections. The app uses its own vector geometry.
To hear and see real beat response, tap the scene and enable audio reaction.
Permission remains an explicit app flow; without live access, band reactions are inactive and lyric timing continues.
The analyzer uses Android's normalized visualization mode. A running analyzer
with silent data reports “No audio signal · check volume,” not a verified beat.

## Run and verify

```sh
flutter run
flutter analyze
flutter test
flutter run --profile -d <device>
```

Allow Notification Access, start a song in a player that publishes a media
session, and return to Kinetic Lyrics. Tap the surface to reveal controls.
Notification text is not read or stored. Lyrics come from a local generated
cache followed by LRCLIB; uncertain timing is estimated, never invented text.

The test suite covers provider isolation, stale lookups, paused track changes,
model cancellation, multilingual fitting, control access, large system text,
and the hidden-controls full-width regression. Three original three-minute
visual fixtures in `tool/review_prototypes.dart` cover fast multilingual phrases,
verse/chorus/bridge structure, and sparse instrumental gaps. These automated
fixtures do not replace real full-song recordings on the phone.

## Product review still required

This is the reference scene stage, not an approved 12-system catalog.
Follow the vision's rebuild order: review three complete real songs on the
Samsung phone, then build and approve twelve genuinely different core systems.
Only after approval should the catalog expand toward 100 outcomes. The old
README's claims about a compiled MotionPlan, 108 patterns, and a timeline
inspector did not describe the current source and have been removed.

The final 60 FPS, less-than-1% jank and less-than-80-ms audio response targets
require device measurements across complete songs. They are not established by
unit tests or a successful APK build. Reviewed section systems and a larger licensed object catalog remain later work.

## Current visualizer — supplied image reference

The rejected outlines, mirrored icon fans, and unshipped light-field experiment
have been removed from playback. One clear spectrum uses 40 rounded bars on
black. Low frequencies are on the left, mids in the center, highs on the right.
Each bar uses a stationary height gradient: white below 62% of maximum height,
blending toward red above it. Growing bars reveal red tips, not a global palette
flash. The rendering clock never invents frequency movement.

Lyric gaps expand the bars smoothly into the full screen. Upcoming words retract
the field before their entrance. The local clock stays top left, title top right.
Contextual artwork is a single recognizable object associated with the current
lyric, blended at its timestamp; it is not repeated into abstract mirrored fans.
Literal multilingual anchors take priority over the conservative semantic model.
Uncertain context can yield no object rather than a random decorative shape.

Validation: 80 Flutter tests plus a live-network silhouette lookup/render check, clean analysis, 75 native FFT assertions. White/red
fixture images and two-second sequences are in build/review/reference-*.
These checks establish behavior and reference geometry, not user acceptance or
full-song frame-rate/latency guarantees.

## Fonts and recognition

18 locally bundled font families include 12 Latin display/serif/handwritten faces
and Noto Sans/Serif pairs for Telugu, Tamil, and Devanagari. The director selects
a script-appropriate face and holds a style across each phrase block. Licenses
and official sources are retained in assets/fonts. Glyphs use flat white lettering in the selected font. Glass gradients, bevels,
extrusion and bar reflections have been removed. The bars use clean rounded
outlines with black interiors and a stationary white-to-red height gradient.

Phone measurements found live attacks around .19–.48, below the original .55
threshold. Band-specific attacks now emphasize measured bar heights; taller
bars reveal the red portion of the stationary gradient.
The earlier build's color-response recording is historical evidence only;
current playback holds its selected hue throughout the track.

Native and Romanized Tamil/Telugu/Hindi object cues share the same explicit
grounding path in the director and immediate scene preparation. Common native
inflections are covered, including the Tamil fire cue in Neruppu Da. This is
a bounded lexical supplement to multilingual E5, not universal translation.
The director-v8 cache version discards older decisions and includes neighboring phrase context.

## Generic online song context (supersedes curated reference packs)

On each new title/artist, OnlineSongContextStore searches Wikipedia for the song
and Wikimedia Commons for an artist silhouette. It is independent of the lyric
loader and painter, uses no song allowlist, and sends only title/artist metadata.
This is public Wikimedia discovery, not Instagram/YouTube video extraction or
automatic image generation. No API key is required for these public endpoints.

Song articles must match the title and artist before theme/instrument cues can
add a prepared object (for example, a guitar). Explicit current-lyric objects
keep priority. Artist silhouettes can appear independently of lyric words.
Commons artwork must match the artist, belong to silhouette categories, have a
public-domain/CC0 license, and supply a PNG thumbnail. Opaque images are rejected.
A real network check resolved Michael Jackson's silhouette for Beat It without
a track-specific entry. Source pages remain in cache metadata; see
https://commons.wikimedia.org/wiki/File:Michael_Jackson.svg.

Requests run asynchronously, share in-flight jobs, have network deadlines and a
512 KiB response budget. Successful results cache for seven days, misses for six
hours. PNGs decode before painting; stale completions are discarded even after
switching A → B → A. Rendering performs no downloads, decoding, or generation.
Black backing and flat foreground lyrics remain. Missing/unmatched articles or
silhouettes leave the local multilingual lyric director working. Coverage is not
universal, and full-song device profiling is needed before claiming zero lag.

The earlier fixed per-song hue is superseded by the requested white-to-red
height gradient. White remains the lower bar face; only taller tips enter red.

## Animation-stutter correction

Nearby lyric scenes are prepared in a bounded window (current plus three ahead,
with two recent scenes retained), with a 1 ms preparation target per frame.
Prepared glyphs rasterize one at a time ahead of use and then draw as cached
textures with direct alpha during movement/fades. Offscreen glyph material passes
and per-bar blur/reflection passes are removed. Stale textures dispose safely on
track changes and seeks; the font/style library remains intact.

Profile builds log five-second build/raster frame timing summaries during active
playback. This measures actual frame work; compilation and passing tests alone
do not establish that every song is stutter-free. The solid/outline comparison
is in build/review/bar-style-comparison.png.

## Prepared performances, personal style and lyric moments

`SongScore` prepares a stable song identity from title/artist, delivery speed,
multilingual mood cues, repeated phrase sequences and the asynchronous semantic
profile. Two-line repeats identify refrain motifs; this is a conservative lyric
heuristic, not an audio model that reliably labels every musical section.
Fonts stay coherent through the song. Fast assembly, asymmetric clusters,
intimate scenes and centered chorus monuments have different prepared geometry.

`LyricPerformance` is shared by playback, saved-moment replay and visual export.
Confident word timings control entrances, holds, stress and sustained-word
breathing. Estimated timings keep the shot's words readable together rather
than pretending to locate each sung word. Enhanced LRC `<mm:ss.xx>` word tags
are parsed and validated; malformed timing falls back to line-level flow.
No universal singing forced-alignment model was added.

Tap the screen, then **Style and moments**, for Subtle/Cinematic/Concert,
Reduced motion, sparse optional bass-attack haptics, and vocal choreography.
Automatic vocal roles use explicit `[voice:lead|response|backing|together]`
annotations when supplied. Call and response offers a deliberate alternating
layout when annotations are absent. This does not identify singers from audio.
Settings persist locally; haptics default off and stop in the background.

Strong low, mid and high events use independent bar attack/release behavior.
Instrumental gaps expand smoothly; the stable music profile can select the
spectrum, a measured waveform, or layered measured contours. Lyrics regain the
upper two thirds before the next phrase. Waveform styles require actual samples;
missing input never creates simulated beats in production.

Long-press during a lyric or use **Save moment** to keep the current phrase.
Saved moments preserve timing, font identity, vocal role, motif and object;
they replay visually without recorded audio. The preview's Share action exports
a readable PNG of its current shot through Android's share sheet. Nothing is
automatically sent to another app. Exported files use a private cache directory,
a non-exported FileProvider and temporary read grants. The saved library is
bounded to 100 moments with serialized atomic local writes.

The context matcher uses one shared Unicode boundary classifier rather than
compiling hundreds of property expressions on first script use. Meaning cues
remain bounded; uncertain props expire instead of persisting indefinitely, and
generic online music-note fallback is omitted. Search and model inference stay
outside the rendering loop.

Validation: 90 Flutter tests cover timing provenance, repeated motifs, actual
font geometry, multilingual object changes, large text settings, persistence,
haptic gating, replay and explicit PNG export. `tool/performance_review_test.dart`
renders static fixtures; `tool/device_performance_review.dart` is a separate,
clearly labeled synthetic device QA entry point and is never imported by the
production app. Synthetic signals test rendering, not real beat detection or
singing alignment. Real-song coverage and extended battery/thermal testing
remain necessary before claiming universally smooth playback.

### Haptic and menu verification (12 October 2026)

Beat haptics use short native media-vibration pulses rather than keyboard feedback. Enabling the switch gives one confirmation pulse; Test vibration is available while enabled. Reduced motion no longer silently disables independently enabled haptics. Live accents require real signal, attack >= .45 and energy >= .15, with timestamp deduplication and at least 600 ms between pulses. Android vibration policy still applies.

Controls and the scrollable style menu are anchored at the bottom on opaque cards. The measured spectrum and instrumental field fade to 12% over 260 ms while controls or the style dialog are open, then restore; lyric contrast is unchanged.

Validation: all 90 Flutter tests pass, static analysis is clean, and the normal main.dart profile build is installed. Samsung vibrator service records multiple completed MEDIA pulses for this package during live playback; no rejected pulses appeared in the observed app records.

### Cloning this repository

Install Git LFS before cloning, then run `git lfs pull` from the repository root. The bundled semantic model, tokenizer and large desktop runtime libraries are stored in LFS; their full contents are required rather than pointer files. Build outputs and local configuration are excluded from Git.

### Lyric motion update (12 October 2026)

Prepared shot plans now drive distinct impact, slide, lift, dissolve and scatter trajectories. Verified word timing supports bounded 70–160 ms visual anticipation, settling at the vocal cue; estimated timing keeps phrase-level choreography. Lift reveals clip complete shaped words without splitting native-script glyphs. Final words retain full opacity through the nominal end, then finish an independent exit. Fast completed words recede; outgoing groups are bounded and neighboring phrases retreat gradually to make room for incoming lyrics. Reduced motion keeps the active shot stable. Live playback, saved replay and card export share the renderer.

Validation: 92 tests pass, static analysis is clean, and `tool/lyric_motion_review_test.dart` captures five transition sequences with native Telugu and phrase handoffs. The normal `lib/main.dart` release APK builds successfully. Device frame profiling and real-song alignment for this update remain unverified because the phone is remote.

### Recovery preview 1.0.1 (build 2)

Line-synced entrances now have a deliberate 60 ms word stagger and at least 260 ms travel for normal phrases (shorter for fast delivery), with legibility decoupled from movement. Missing-signal recovery is actionable even with permission granted and restarts the native output analyzer. A reconnect affordance appears only when measured audio is absent. Regression coverage checks menu opacity restoring to 1, the no-signal button, and visibly moving estimated entrances; all 92 tests pass. The review tool now renders both provider-verified and line-synced paths. The reported device signal loss remains unconfirmed until device status is supplied.

### Expressive font pairs 1.0.2 (build 3)

Dominant words use an expressive bundled face while supporting words use a contrasting, quieter face. Directed verses respond to the local lyric mood; refrains use display or condensed styles and retain their identity when repeated. Telugu, Tamil and Devanagari use real script-specific Noto serif/sans pairs. Fonts are prepared with glyph layout rather than downloaded during playback, and text remains flat without glass effects.

Validation: all 93 tests pass, static analysis is clean, and the normal player release APK builds. The rendered performance contact sheet checks Latin and native-script verse/refrain compositions with fixture audio. Live playback and the reported missing device audio signal remain unverified remotely.
