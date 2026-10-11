# Visualizer reset: classic Windows references

11 October 2026. The five outlined visualizers and mirrored icon fan were rejected
by the user. Functional tests did not establish aesthetic quality. They should
not be described as an approved catalog.

## References actually inspected

- [Microsoft: User Overview](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/wmp/user-overview): classic Ambience, Plenoptic, Spike/Amoeba and preset families.
- [WMP browser reconstruction](https://wmp.ryancircelli.com/), authored by [Ryan Circelli](https://github.com/ryancircelli/wmp-legacy-visualizers): viewed Alchemy, Battery brightsphere, Battery kaleidovision, and Ambience Water. This is a third-party reconstruction, not a Microsoft-certified fidelity result. Without supplied audio, it only establishes visible structure and motion, not beat accuracy.
- [Original MilkDrop creator's screenshots](https://www.geisswerks.com/milkdrop/screenshots.html): visually inspected layered light, organic warping, texture and depth. MilkDrop is a separate Winamp reference, not a Windows Media Player preset.
- [Geiss: how the visualizer worked](https://www.geisswerks.com/geiss/secrets.html): audio marks plus warp/fade feedback create a changing field.
- [MilkDrop original authoring guide](https://www.geisswerks.com/milkdrop/milkdrop_preset_authoring.html): independent bands and attenuated bands, decay, distortion, aspect correction, preset behavior and quality assurance.
- [Flutter fragment shaders](https://docs.flutter.dev/ui/design/graphics/fragment-shaders) and [GPU-resident image creation](https://api.flutter.dev/flutter/dart-ui/Picture/toImageSync.html): support the intended native rendering path.

## Why the rejected build failed

A few mathematically symmetric line shapes stayed structurally similar while
opacity, scale and small strokes changed. Increasing their brightness did not
add temporal development, surface detail, spatial layering or authored motion.
Repeating vector icons introduced visual clutter and weakened their literal
meaning. AI choosing an attractive-sounding preset name did not improve its art.

Tests proved clipping, signal separation and state handling. They did not prove
that watching the animation was satisfying. That distinction must be explicit.

## Fit against the user's requirements

The useful Windows-era qualities are evolving texture, luminous depth, persistent
trails, recognizably different visual worlds, and a strong relationship to sound.
The proposed adaptation keeps black as the canvas, calmer motion than aggressive
classic presets, lyrics above a substantial bottom-third field, and full-screen
instrumental continuity. The clock and title stay in quiet corners.

Do not adopt bright full-screen inversion, constantly rotating cameras, violent
zoom tunnels, an imitation Windows skin, or low-resolution raster aesthetics.
Those conflict with black space, lyric contrast and the request to avoid dizziness.
Do not copy Microsoft's proprietary visualization algorithms/assets. Implement
original effects inspired by the references and the documented feedback idea.

## Implementation plan

1. Extend the local audio bridge with 64 waveform samples and 32 logarithmic FFT
   bins. Keep calibrated bands and independent onset envelopes. Silence must not
   become fabricated beats.
2. Build one bounded GPU feedback surface. Audio injects marks; a slow flow field
   advects and decays their history. No CPU pixel readback during playback.
3. Prepare three actually different looks: Aurora Flow (layered horizontal light
   currents), Ember Nebula (organic clouds with bright fine points), and Prismatic
   Echo (restrained mirrored light texture). These are original implementations,
   not exact ports or claimed replicas of Alchemy/Battery/MilkDrop.
4. Let the semantic director select among reviewed effects with stable decisions.
   Audio drives deformation and detail, not rapid preset switching. Change
   parameters through one surface; preserve lyric/instrumental expansion.
5. Remove the rejected outline visualizers and repeated-icon fan from playback.
   Contextual literal art stays secondary and appears only when grounded.

## Quality gates before declaring acceptance

- Compare candidate images and multi-second motion clips against reference
  structure: layered depth, development over time, and a clear visual focus.
- Isolated low/mid/high fixtures must produce visibly different consequences;
  silent input must decay rather than animate false strikes.
- Readability check at phone proportions with long English/Telugu/Tamil lyrics;
  no glow or history bleeds into the protected lyric region.
- Instrumental expansion/retraction, pause, seek and track-change continuity.
- Check sparse, sustained and fast/percussive signals, not only one upbeat track.
- Inspect the actual phone recording, measure raster/UI frame times and resource
  lifetime. Full-song 60 FPS/<1% jank/<80 ms response remain unproven until measured
  across the required complete songs. A passing unit suite is not that evidence.

The user's visual acceptance remains the final aesthetic judgment. Internal
review must be honest and cannot label a rejected result "reference quality."

## Superseded by explicit image reference

The user rejected the light-field direction before it was installed and supplied
a rounded spectrum-bar image. The implemented direction now follows that image:
40 bottom-aligned rounded bars, white for melodies and red for strong attacks.
The GPU feedback plan above is research history, not shipped functionality.
Relevant contextual objects are single recognizable illustrations, not folded
textures. Current implementation and checks are documented in app/README.md.
