# Lyric entrances, holds and exits

Research and renderer audit · 12 October 2026. This is a proposed design, not an installed animation update.

## Main finding

The app has dynamic layouts and a semantic transition vocabulary, but its motion renderer collapses almost everything into one fade/scale/tilt. Improving typography requires a timed sequence of anticipation, arrival, readable hold and departure, with relationships between successive words. More effects alone will not fix it.

## Verified gaps in this repository

- `app/lib/visuals/lyric_composition.dart` assigns `SemanticTransition` (impact, slide, lift, dissolve, scatter) to each shot. `app/lib/visuals/lyric_performance.dart` never reads `shot.transition`.
- `VocalWordPose.sample` varies quiet versus other compositions, but uses essentially the same cubic entrance and quadratic departure for all other moods. The selected hero word does not receive a separate arrival trajectory.
- Reliable word entrances begin at the vocal timestamp, so a word is still invisible at its start. They take 45–200 ms; fast delivery caps the entrance around 100 ms. Estimated words use a 26 ms stagger and 150 ms entrance, so a four-word shot fills within about 228 ms.
- A regular 200 ms entrance has already completed 65.7% of its fade after 60 ms. Its 20 px vertical travel has only about 5.5 px remaining at cinematic intensity (.8). Much of the visible phase therefore looks nearly settled. This is a calculation from the code, not a perceptual experiment.
- `LyricComposition.at` selects only the shot whose nominal interval contains the playback time. General outgoing and incoming shots do not coexist; special previous-vocal-role echoes are an exception. A departure cannot continue past the shot boundary.
- Ordinary exits happen together in the final min(180 ms, 12% of shot duration). There is no general handoff that gives the incoming phrase room while preserving the outgoing phrase's last sung word.
- Active-word beat scale is small (.014 bass + .008 mid, multiplied by intensity). It adds an accent, but it cannot provide a distinct entrance or phrase composition.

## Research principles

Adobe's music-synced animation walkthrough explicitly places entrances before the sung words, checks the waveform, and holds words through the phrase. This supports preparing readable words for vocal arrival rather than beginning a long reveal after the singer starts. Precise look-ahead must depend on trusted timestamps; approximate LRC timing cannot justify precise individual-word synchronization.

Source: [Adobe: adding and synchronizing sound](https://www.adobe.com/learn/animate/web/add-sync-soundtrack).

Anticipation prepares the action, staging directs attention, and follow-through/overlap connects movements. Applied to this app, one dominant word should arrive decisively, supporting words should settle around it, and departing words should have a visible relationship to the next phrase. These are design principles, not evidence that a specific preset increases enjoyment.

Source: [Adobe: animation principles](https://www.adobe.com/creativecloud/animation/discover/principles-of-animation.html).

Entrances and exits should have different easing; duration should reflect travel and complexity. Material's mobile guidance is an interface reference, not a rule for musical timing. Its approximate 225 ms entrance and 195 ms exit provide starting points that must be shortened for rap and adapted to actual lyric duration.

Source: [Material: duration and easing](https://m1.material.io/motion/duration-easing.html).

Word- and line-level selectors are established text-animation techniques. Preserve shaped words for Telugu, Tamil and Hindi; do not split conjuncts, combining marks or joined glyphs into arbitrary characters to create effects.

Source: [Adobe: animating text](https://helpx.adobe.com/after-effects/desktop/animating-text/text-animation/animating-text.html).

Reduced motion must remain available. WCAG's cited criterion specifically concerns interaction-triggered motion; it does not establish a compliance claim for this Android music app. Avoid unnecessary camera rotation and whole-screen motion in the lyrical reading region.

Source: [W3C: animation from interactions](https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions).

## Proposed motion vocabulary

Keep the black background, flat white/red song identity, native-script typography, contextual objects and lower-third visualizer. No glass, flashing color alternation or constant floating.

1. **Lift and settle:** melody/romantic phrases. A whole word rises through a local reveal mask, settles, holds clearly and leaves with a gentle upward fade. Initial test range: 180–280 ms entrance, 160–240 ms exit.
2. **Impact and release:** chorus/emphatic word. One hero word arrives with a short scale compression and bounded 3–6% overshoot; supporting words stay steady. Initial range: 100–160 ms attack, 80–140 ms settle. No repeated bouncing.
3. **Directional handoff:** urgent/fast phrases. Word clusters move along a consistent short axis, with outgoing words receding as the next cluster arrives. Initial range: 70–120 ms entry, 90–150 ms exit, 24–48 logical px maximum travel before geometry checks.
4. **Soft reveal:** quiet/sad sections. Opacity plus a small deliberate drift, a longer readable hold and staggered dissolve. Initial range: 220–320 ms reveal; avoid the current generic tiny wiggle.
5. **Assembly:** rhythmic multiword lines. Stagger whole words into stable slots, with one emphasized arrival and restrained supporting entries. Use trusted word timing when available; otherwise animate the phrase as a unit.
6. **Recede to memory:** completed fast words shrink into a faint background position, then expire. New words remain dominant. Maximum two outgoing groups, bounded lifetime, no accumulating clutter.

These values are proposed test ranges, not established optimum durations. Select by delivery, phrase emphasis, timing confidence and section; repeat a coherent motif on repeated choruses rather than cycling randomly.

## Implementation order

First add a prepared motion plan per shot with independent entrance/hold/exit intervals and an explicit timing-confidence policy. Wire the existing transition vocabulary into the renderer. Keep motion calculations separate from glyph shaping and model inference.

Then render the current shot plus at most two bounded outgoing groups. Permit modest visual anticipation only for verified word timing and only within available preceding space. Keep the final sung word readable through its end; clip bounded exits to the lyric region. During estimated timing, use phrase choreography and do not imply exact word alignment.

Finally tune six motion families using a small real-song review set. Reuse the same motion sampler for live lyrics and saved moments; exported cards should select a fully readable hold phase.

## Quality checks before installing

- Review moving captures, not just screenshots: melody, fast rap, chorus, native Telugu/Tamil/Hindi and estimated versus verified timings.
- Inspect onset, entry midpoint, settled hold, word completion, outgoing/incoming overlap, exact shot boundary, seek and pause/resume.
- Every family must be distinguishable in motion while each word remains readable; no abrupt disappearance, ghost jump, hidden final word or overlap with the visualizer.
- Do not test only p95: record cold first phrase and script switch, p99/max frame times and missed-frame count. At 60 Hz a frame budget is roughly 16.7 ms; cached raster glyphs and transforms must stay within it during transition overlap.
- Reduced motion presents stable readable text. Long native-script words and 2x accessibility text must remain bounded.
- Device replay fixtures prove rendering, not actual singing alignment. Confirm with live songs and trusted lyric timestamps before calling synchronization fixed.
