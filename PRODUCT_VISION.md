# Kinetic Lyrics — Product Vision and UI Requirements

## Product vision

Build a full-screen lyric experience where users can **feel the song through its words**.

Typography expresses the song's meaning, emotion, rhythm, and structure. The result must feel authored for the current song—not like lyrics placed over a generic beat visualizer.

> The user should feel the song by looking at the lyrics, not merely see words reacting to a beat.

The experience follows Apple-style design principles: immediate response, continuity, interruptibility, spatial consistency, restraint, accessibility, responsibility, and craft.

## 1. Lyrics are the hero

- Lyrics are always the dominant visual element.
- Background objects and visualizers remain secondary.
- Metadata and controls stay quiet and appear only when useful.
- The current lyric must be immediately recognizable.

## 2. Lyrics must remain readable

- Choose a word, natural phrase, or complete line before its entrance.
- Never combine text and split it during the same lyric.
- Fast lyrics use stable phrase geometry with changing word emphasis.
- Do not create a new layout for every fast word.
- Choose a prepared composition: word spotlight, asymmetric word cluster,
  rhythmic assembly, call and response, chorus monument, or intimate scene.
  Two foreground lines are one option, not the universal layout.
- Long lyric lines become sequential short shots of complete words. Preserve
  a clear reading path and enough exposure for the vocal delivery.
- Never break a word, grapheme cluster, or Indic conjunct.
- Long English, Telugu, Tamil, and mixed-script lyrics must fit safely.
- The complete transformed text—including rotation, depth, outline, extrusion, and shadow—must remain inside the screen.
- Target a maximum of 86% viewport width and 72% viewport height.
- Maintain at least 24 logical pixels of visual edge clearance.

## 3. Meaning controls the scene

- Lyric meaning chooses composition, motion, emphasis, and contextual objects.
- Beat information controls intensity and timing, not the entire design.
- Quiet, heavy, romantic, aggressive, lonely, joyful, and urgent lyrics should feel different.
- Musical sections must be visually recognizable.
- Repeated choruses reuse an identifiable motif with controlled evolution.

## 4. Stable foreground motion

Every lyric scene has:

1. An entrance.
2. A stable, readable hold.
3. An exit.

Readable exposure takes priority over a fixed hold percentage. Typography may
perform through emphasis, depth and deliberate transitions while its reading
path remains predictable.

- Lyrics must not continuously shake.
- Normal beat-driven text translation stays near or below 4 logical pixels.
- Continuous beat-driven text scale stays near or below 5%; brief entrances and
  departures may use a larger prepared motion budget.
- Larger movement is reserved for brief, reviewed hero moments.
- Background elements absorb most continuous beat response.

## 5. No repetitive directional movement

The following cannot become default lyric behavior:

- Circular or orbital movement.
- Repeated top-to-bottom movement.
- Repeated left-to-right or right-to-left movement.
- S-curves.
- Tunnels.
- Conveyor-belt lyrics.
- Constantly floating phrases.

Rotation is allowed only when the lyric meaning genuinely calls for it and only for a brief moment.

## 6. Pattern system

- Start with 12 genuinely distinct core scene systems.
- Each system must differ in composition, hierarchy, timing, and spatial behavior.
- Changing only the font, direction, color, or seed does not create a new pattern.
- Each system must work across an entire song section.
- Review the first 12 systems using full-song recordings.
- Expand toward 100 or more outcomes only after the core systems are approved.
- The final outcomes must be perceptually different, not mathematical parameter combinations.
- No pattern should dominate more than 25% of a song unless intentionally tied to a recurring chorus or motif.

## 7. Contextual background objects

- Use objects from a prepared, licensed asset store.
- Do not generate images during playback.
- On-device AI may select objects based on lyrical context.
- Show at most one primary and one secondary object simultaneously.
- Objects stay behind the lyrics and never reduce readability.
- Objects persist for approximately 8–20 seconds rather than changing every line.
- Low-confidence context falls back to abstract mood geometry.
- Objects react through lighting, depth, deformation, particles, or breathing.
- Literal objects remain restrained. A reference to guns and roses may introduce those motifs without turning the screen into a loud illustration.

## 8. Audio reaction

- Calibrate low, mid and high bands using the actual sample rate and frequency
  ranges, not fixed fractions of the FFT array.
- Bass controls mass, depth, pressure surfaces and large background displacement.
- Mids control connective geometry, elastic ribbons and body movement.
- Treble controls fast edge strokes, fine texture and highlights.
- Independent low, mid and high onsets trigger distinct accents with different
  attack/release timing. Every meaningful band event has a visible consequence.
- Text reacts selectively.
- Backgrounds and objects carry most continuous audio movement.
- Audio-to-visual response should normally remain below 80 milliseconds.

## 9. Instrumental and missing-lyric states

- The screen never becomes blank because vocals or lyrics are absent.
- Instrumental passages receive a fluid, music-sensitive visualizer.
- Missing lyrics continue with a complete instrumental experience.
- Track metadata does not become a large static substitute for lyrics.
- On-device AI transcription remains optional.
- Partial AI lyrics appear only when stable enough to read.

## 10. Required application states

The UI deliberately handles:

- First launch.
- Notification-access explanation.
- No music.
- Music detected.
- Lyrics loading.
- Lyrics ready.
- Lyrics unavailable.
- AI model preflight.
- AI model download.
- Audio-capture permission.
- AI listening.
- Partial AI lyrics.
- Instrumental sections.
- Paused playback.
- Seeking.
- Track changes.
- Network errors.
- Storage errors.
- Permission errors.
- AI model errors.

No state may appear broken, corrupted, accidental, or unfinished.

## 11. Apple-style interaction behavior

- Controls respond visually on touch-down.
- Touch targets are at least 44 × 44 logical pixels.
- Draggable UI follows the finger one-to-one.
- Interactive animations remain interruptible.
- Reversing an interaction does not cause a visual jump.
- Springs begin from the current visible state.
- Critically damped movement is the default.
- Bounce is reserved for momentum-driven gestures.
- Interactive controls preserve continuous entrance and dismissal paths.
  Expressive lyric entrances and exits may follow different authored paths.
- Input remains available while transitions run.
- Haptics are reserved for meaningful commits, snaps, successes, and errors.

## 12. State continuity

- Pause freezes progression without corrupting the composition.
- Resume continues naturally from the current position.
- Seeking does not replay unrelated old animations.
- Track changes use a controlled transition.
- Lyrics arriving after loading enter at the current timestamp.
- Old and new visualizers never appear together.
- Hard scene cuts are reserved for intentional musical impact.

## 13. Typography

- Functional UI uses the platform system font.
- Custom typography is reserved for expressive lyrics.
- Large text uses tighter tracking.
- Small functional text uses more open tracking.
- Controls, permissions, progress, and errors respect system text scaling.
- Every custom lyric font has multilingual fallbacks.
- Current words never become too large to fit.
- Fast lyrics do not become enormous merely because their exposure time is short.

## 14. Visual language

- The primary background is OLED black.
- Do not use static or repeating generated picture backgrounds. Expression
  comes from typography, word choreography and localized audio-driven geometry.
- The primary lyric color is warm white.
- Red is a controlled accent for emphasis, tension, impact, and important words.
- Red appears more frequently than before but does not dominate every scene.
- Black space is an intentional part of the composition.
- Depth and perspective remain soft and purposeful.
- Decorative elements never compromise lyric contrast.

## 15. Performance

- Only the active visual surface repaints every frame.
- The application root and static controls do not rebuild continuously.
- Maintain 60 FPS on the reference Samsung device.
- Target less than 1% visibly janky frames during a complete song.
- Touch feedback begins within one rendered frame.
- Text layout, lyric timing, semantic cues, and scene decisions are prepared in advance.
- Network and AI operations never block animation.
- Never render two full-screen visualizers simultaneously.

## 16. Reduced motion and adaptability

- Respect Android's Remove Animations setting.
- Replace large travel, parallax, elastic motion, and looping backgrounds with short fades or static states.
- Reduced motion still communicates playback and progress.
- Functional UI respects system text size.
- Red is never the only status indicator.
- Live screen-reader lyric announcements remain deferred following the current product decision.

## 17. AI privacy and responsibility

Before AI transcription begins, explain:

- An approximately 80 MB model must be downloaded once.
- Android will request playback-audio capture.
- Recognition happens locally.
- Captured audio is not uploaded.
- Generated lyrics and timing are stored locally.
- The user can cancel or retry.

Never expose raw technical exceptions. Errors explain what happened and what the user can do next.

## Explicitly prohibited

- Lyrics continuously moving in circles.
- The same directional pattern for most songs.
- Combining a phrase and then splitting it.
- One layout change for every rapidly sung word.
- Giant words that disappear too quickly.
- Continuous lyric shaking.
- Blank instrumental screens.
- Static song-title screens replacing the visualizer.
- Old and new visualizers painted together.
- Text leaving the mobile screen.
- Random contextual objects.
- Calling parameter combinations “108 patterns.”
- Hidden downloads or unexplained permissions.
- Raw exception messages.
- Accidental hard state changes.

## Definition of done

The UI is complete only when three entire songs work convincingly on the physical phone:

1. A fast song remains readable without per-word relayout.
2. A normal song develops visually through verse, chorus, and bridge.
3. A sparse or instrumental song remains fluid and emotionally relevant.

## Current implementation direction

The 11 October research pass is recorded in `RESEARCH_VISUAL_DIRECTION.md`.
Word scenes replace the universal two-line paragraph. Three audio bands have
distinct visual roles. This aims for enjoyment, anticipation and satisfying
release; it makes no claim to measure or guarantee dopamine release.

## Rebuild order

1. Build one reference-quality Cotodama-style scene.
2. Validate it using three complete song prototypes.
3. Build and approve 12 core scene systems.
4. Add the contextual object layer.
5. Expand toward 100 or more genuinely distinct outcomes.


## Current visual direction (11 October 2026)

- Keep the canvas OLED black; avoid repeating generated background pictures.
- Reserve the top two-thirds for kinetic lyrics and faint contextual objects.
- During lyrics, give the visualizer the bottom third, with clearly visible independent low, mid, and high gestures. In lyric gaps, smoothly expand it to the full screen and retract before words arrive.
- In fast passages, completed words shrink and lighten behind the next words.
- On-device semantic AI selects contextual objects and directs fonts, composition, motion, and transitions from prepared options.

- The supplied rounded spectrum-bar image overrides the rejected preset catalog: white for melodies, red for strong beats, with frequency-dependent bar heights.
- Contextual objects follow individual lyric timestamps with short blends; avoid fixed holds that outlast their lyrical meaning.
- Keep contextual objects single and recognizable; do not turn them into mirrored abstract forms.
- Keep local time at the top left and the current song title at the top right.

## Latest visual correction — supplied image (11 October 2026)

Use one rounded spectrum-bar field matching the user's supplied image. Keep
OLED black; use white for melody and red for strong beats, with a soft vertical
fade and restrained edge glow. Bars fill the bottom third during lyrics and
expand smoothly in lyric gaps. Preserve recognizable, relevant lyric objects
as single contextual illustrations. The earlier multi-preset/abstract-object
direction is superseded by this explicit reference.

- Lyrics stay consistently white, with a restrained glass bevel and neutral
  depth edge. Do not switch foreground lyric hue on beats or active words.
- Glass highlights may add polish to bars while preserving the black canvas
  and white-melody/red-beat palette.
- Expand locally bundled fonts, including native Telugu, Tamil, and Devanagari
  sans/serif alternatives; preserve shaping and script-appropriate spacing.

## Song palette correction

Choose the visualizer's white or red palette once from the first audible audio
frame and hold it for the song. Beats animate heights, never hue. Pause, seek,
silence, and instrumental takeover retain that palette; a new track resets
the choice. This supersedes the earlier beat-triggered color alternation.


## Generic context and height-gradient correction (October 11, 2026)

Search public Wikipedia/Commons asynchronously for every new song title and artist,
without a curated song allowlist. Cache verified song cues and licensed artist
silhouettes. Keep direct lyric objects primary; artist identity can appear behind
lyrics independently. Missing artwork must not fabricate a likeness or delay lyrics.
The visualizer uses a white lower region blending into red above 62% of its height;
bar growth reveals red tips instead of switching the whole song palette.
This supersedes the earlier fixed-color and three-reference-pack implementations.


## Flat typography and outline correction (October 11, 2026)

Remove the glass treatment from lyrics; retain script-appropriate font variety
and kinetic transitions. Use thin rounded spectrum outlines with black interiors
and white-to-red height gradients. Reduce animation stutter through a bounded
lookahead window and prepared glyph textures, rather than repainting glass masks
or bar glow each frame. Validate with physical-device frame timings. This
supersedes the earlier glass typography and filled spectrum bar treatment.
