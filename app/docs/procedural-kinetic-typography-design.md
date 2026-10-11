# Procedural Kinetic Typography: Production Architecture

Status: implementation design approved by repository audit  
Principle: **Typography does not react after the music; it is scheduled so it appears to belong to the music.**

## 1. Current architecture summary

The application is a Flutter full-screen Android experience. `NowPlayingBridge` reads Android media sessions and emits metadata, playback state, playback speed, and a timestamped playback position. Flutter extrapolates that position between native updates and repaints from a `Ticker`, so visual state is derived from absolute song time and correctly reconstructs after pause, resume, or seek.

Lyrics are resolved through `LyricsRepository`. It tries the on-device generated cache and then LRCLIB. Synchronized LRC provides **line timestamps only**; `LrcParser` estimates word spans from token length and punctuation. Plain lyrics receive estimated line and word spans. The on-device Whisper path captures permitted playback audio, transcribes two-second windows, and spreads words uniformly within each transcription section. Although sherpa-onnx returns tokens and timestamps, the current learner does not use those timestamps. There is no syllable model or grapheme model.

`KineticLyricsController` joins media-session state, lyrics, and a stream of live audio frames. Android `Visualizer(0)` supplies a 1024-bin FFT/waveform stream at up to 30 kHz capture callbacks. Native code reduces every callback to energy, bass, mid, treble, and positive spectral flux (`onset`). `MusicStateTracker` smooths those values, assigns one of five coarse profiles, and flags peaks.

`MotionDirector.frameAt` is called every painted frame. It finds the current line/word, infers a tempo-like pulse from median lyric-word intervals, mixes that pulse with live onset, chooses a `MotionMode`, and chooses one of 108 `AuthoredTypographyStage` patterns using a seeded stride. The seed includes a launch salt and visit serial, so the same song deliberately changes identity between visits. Repeated text is treated as a chorus even when it is not a structural chorus.

Rendering uses Flutter `CustomPainter`, `Canvas`, and `TextPainter`/SkParagraph. The screen ticker is frame-driven; no lyric animation controller or delayed event timer exists. The main path currently bypasses `SceneStrategyRegistry` for lyrics and paints `AuthoredTypographyStage` directly; instrumental gaps use `BeatTypographyStage`. Text is shaped by Flutter and whole words/phrases are transformed on the canvas. Some legacy scenes split strings by whitespace and some effects operate on word strings, but there is no safe grapheme-cluster abstraction. Relayout is performed frequently inside paint calls.

## 2. Why the current visuals feel repetitive

1. The apparent variety is a Cartesian catalog: 18 layouts × 6 signatures. Large counts do not produce musical authorship when each line independently selects an entry.
2. There is no persistent song-level `VisualDNA`, section map, motif, intensity envelope, or planned narrative arc.
3. `MotionMode` is a preset enum, and painter classes contain complete entrance/hold/exit behavior. WHAT and HOW STRONGLY are coupled.
4. Selection uses pools and hashes, not scored musical evidence. The cooldown avoids exact recent modes but not repeated direction, scale, density, or compositional center bias.
5. Beat timing is mostly inferred from lyric word starts. Live onset arrives at impact time, so movement can only react after the event; it cannot anticipate it.
6. Live audio has no history. BPM, downbeats, sections, drops, buildup, silence, vocal contour, and repeated musical motifs are absent.
7. Every line receives an entrance and exit. Stillness is not budgeted as a first-class scene, so importance is flattened.
8. Transitions are local fades/transforms near line bounds. The outgoing and incoming scenes do not share anchors or camera continuity.
9. Repeated choruses do not share a stable structural identity; repeated text is a weak proxy and the changing visit seed fights coherence.
10. Layout and animation are recomputed during paint, producing avoidable CPU work and making larger per-grapheme compositions risky.

## 3. Components to reuse

- `NowPlayingDetector`, `NowPlayingTrack.positionAt`, and the absolute-time render clock.
- `LyricsProvider`/`LyricsRepository` and LRCLIB as one source in a richer alignment pipeline.
- Android playback capture and sherpa-onnx worker, upgraded to preserve timestamp evidence.
- Android output-mix FFT as the low-latency feature source where the OS permits it.
- Flutter `CustomPainter`/Skia for GPU-friendly transform, clip, opacity, and path rendering.
- `FittedTextLayout` as a fallback measurement utility, moved out of the frame loop.
- Existing painters as a compatibility/fallback renderer during migration and as reference material for primitives.
- `SemanticMotionProvider` as a deterministic provider boundary.
- Reduced-motion support and source/quality chrome.

## 4. Components requiring refactoring

- Replace `MotionMode` preset selection with parameterized `MotionPrimitiveSpec` compositions.
- Replace `KineticFrame` as the planning model with a thin runtime `RenderFrame` evaluated from a cached `MotionPlan`.
- Replace visit-random `experienceSeed` with a stable song seed plus an explicit plan revision.
- Expand `AudioFeatures` and create timestamped audio-event and song-analysis models.
- Preserve Whisper timestamps and introduce alignment confidence, syllables, and graphemes.
- Move shaping/layout out of painters into prepared scene assets.
- Replace direct `AuthoredTypographyStage.paint` dispatch with `PlannedSceneRenderer`.
- Add persistent preprocessing cache, incremental analysis, debug overlay, and timeline inspector.

## 5. Complete target architecture

```text
MediaSession clock ───────────────────────────────────────────────┐
                                                                  v
Playback capture / media file -> FeatureExtractor -> AnalysisAccumulator
                                              |             |
                                              |             +-> AnalysisCache
                                              v
                                    SongAnalysis + AudioEventTimeline
                                              |
Lyrics providers -> Forced alignment -> LyricTimelineV2          |
                                              |                   |
                                              +---------+---------+
                                                        v
                                               VisualDNACompiler
                                                        v
                                   SectionTimeline + MotifLibrary
                                                        v
                         Deterministic ScenePlanner / CandidateScorer
                                                        v
                               cached MotionPlan + PreparedTextLayouts
                                                        v
MediaSession position --------------------------> MotionEvaluator
                                                        v
                                              PlannedSceneRenderer
                                                        v
                                              Flutter Canvas / Skia
```

Pre-analysis owns expensive intelligence. The frame loop performs binary searches, curve evaluation, transform composition, and cached paragraph/glyph drawing only.

## 6. Five musical timescales

- **Song:** `VisualDNA` fixes the song's typography family, weight/width ranges, spatial bias, motion temperament, density, depth, color accents, motif seeds, and global fatigue limits.
- **Section:** typed sections define base intensity bands, layout density, motif prominence, and hero eligibility. Repeated section fingerprints share a motif family and increase an evolution index.
- **Phrase:** the planner selects layout, focal hierarchy, negative space, depth, transition topology, and a small primitive composition.
- **Word/syllable/grapheme:** alignment, prosody, semantic salience, and repetition determine local emphasis. A shaped grapheme cluster is the smallest transformable textual unit.
- **Beat/transient:** scheduled micro-reactions modulate an existing scene. They never replace the phrase plan and are thinned by salience and budget.

## 7. Audio-analysis strategy

Feature extraction runs on 20–46 ms windows with a 50% hop when PCM is available, and on Android Visualizer frames as a degraded live source. Persist timestamped normalized features:

- RMS and LUFS-like relative loudness envelope.
- FFT magnitude, spectral centroid/brightness, spectral rolloff, spectral flux, and zero-crossing rate.
- bass/mid/treble band energy and low-frequency dominance.
- onset strength using half-wave spectral flux with adaptive median threshold.
- beat timestamps and BPM using onset-envelope autocorrelation plus dynamic-programming beat tracking.
- downbeats using meter hypotheses over beat accent patterns.
- silence from adaptive noise floor plus duration hysteresis.
- transient class heuristics: kick (low-band attack), snare (broad mid/high attack), hi-hat (high centroid short attack), cymbal (high-band sustained flux), bass hit (low-band attack without broadband evidence).
- vocal activity/intensity from the ASR/VAD path; pitch contour from normalized autocorrelation/YIN on vocal-positive windows.
- buildup/drop from multi-feature slope followed by a high-confidence discontinuity.
- repeated musical motifs from beat-synchronous chroma/MFCC-like fingerprints when the capture quality supports them.

Priority by value/cost: loudness/onsets/silence/band energy first; BPM/beats/downbeats next; section novelty and vocal activity next; pitch contour and repeated fingerprints next. Source separation and genre inference are optional model providers, not frame-loop dependencies.

The critical limitation is source access: Android media sessions expose timing and metadata, not the song file. Some players prohibit playback capture and `Visualizer(0)` is device-dependent. Therefore the production contract supports three qualities: `offlineFull`, `capturedIncremental`, and `liveDegraded`. Missing evidence lowers confidence and disables unsupported decisions rather than fabricating them.

## 8. Song-section detection strategy

Create beat-synchronous feature vectors from loudness, bass ratio, brightness, onset density, vocal probability, pitch activity, and optional chroma. Compute a self-similarity matrix and novelty curve; pick boundaries with minimum-duration and beat/downbeat snapping. Cluster segments by fingerprint to identify repeated verse/chorus families. Label types with deterministic structural rules using position, repetition, vocal density, energy percentile, buildup/drop evidence, and lyric repetition. Labels remain confidence-scored and can be overridden by authored metadata.

Typical intensity priors are intro .10–.35, verse .25–.50, pre-chorus .40–.72, chorus .70–1.00, post-chorus .55–.85, bridge .35–.80, breakdown .05–.35, instrumental .30–.85, drop .85–1.00, outro .08–.40. The actual envelope is clamped by the song's dynamic range rather than forcing every chorus to maximal motion.

## 9. Lyric timing and alignment

Provider evidence is retained rather than overwritten:

1. Accept native word/syllable timestamps when a licensed provider offers them.
2. For line-synced LRC, capture permitted PCM and run Whisper/VAD tokens; align provider text to recognized tokens with normalized Unicode-aware dynamic programming, preserving the trusted LRC line boundaries.
3. For plain lyrics, align the complete text against timestamped ASR tokens; use VAD gaps as phrase boundaries.
4. If audio capture is unavailable, estimate word spans with language-aware weights and mark confidence/quality honestly.
5. Syllables use language-specific providers where available; otherwise ASR token pieces and vowel-group heuristics are advisory only.
6. Graphemes are segmented with Unicode extended grapheme cluster rules. Timing is distributed within the parent word/syllable using shaped advance widths, never UTF-16/code-point count.

Every timed unit includes provenance and confidence. The planner reduces independent motion as timing confidence falls.

## 10. VisualDNA

`VisualDNA` contains normalized continuous properties: energy, valence, rhythmicStrength, bassStrength, brightness, vocalIntensity, acousticness, electronicness, dynamicRange, syncopation, density, motionSharpness, motionElasticity, spatialExpansion, depth, stillnessPreference, typographyWeight, typographyWidth, trackingRange, curvature, contrast, and palette temperature. Categorical descriptors (`motionPersonality`, `typographyPersonality`, `spatialStyle`) are derived for debugging only; planning uses continuous values.

Valence and semantic tone come from a confidence-weighted blend of acoustic cues and lyric sentiment. Genre is not required. If a model supplies genre/style probabilities, they adjust compatibility scores but never choose a preset.

## 11. Motion primitives

The primitive vocabulary is data, not classes per strength. Each `MotionPrimitiveSpec` names a primitive and supplies target scope, timing envelope, direction/vector, strength, duration, easing, stagger, overshoot, amplitude, frequency, randomness, blend mode, and constraints.

Supported transform primitives: impact, squash, stretch, drift, float, snap, slide, push, pull, rotate, tilt, shake, vibrate, fall, rise, depthPush, depthPull, perspectiveTilt, freeze. Typography primitives: expand/contract tracking, baselineWave, letterCascade, stack. Reveal/effect primitives: fade, blurIn/out, focus, maskReveal, wipe, scatter, regroup, echo, trail. Expensive primitives declare GPU cost and mutually exclusive groups.

Every primitive evaluates pure functions of absolute time. A strength of zero is valid; no `weakImpact` or `strongImpact` types exist.

## 12. Motion composition

A phrase composition has at most one major spatial primitive, one typography primitive, one reveal/transition primitive, and a bounded micro-reaction lane. Primitives blend through typed channels (translation, scale, rotation, opacity, blur, tracking, mask, depth) with explicit additive/multiplicative/replace semantics. Channel conflict resolution occurs at plan time.

Motion timing uses `anticipationStart`, `impactAt`, and `settleEnd`. Offline/cached beats allow anticipation before impact. With live-only onsets, predictive beat phase schedules likely future impacts; unexpected transients can cause a small immediate reaction but cannot launch a large late motion.

## 13. Animation scoring

For each scene, enumerate valid primitive/layout/transition candidates. Normalize every component to [-1, 1]:

```text
score = 1.20 motifCompatibility
      + 1.00 sectionCompatibility
      + 0.95 energyCompatibility
      + 0.85 phraseCompatibility
      + 0.80 beatCompatibility
      + 0.75 typographyCompatibility
      + 0.70 transitionContinuity
      + 0.65 semanticCompatibility * semanticConfidence
      + 0.45 visualDNACompatibility
      - 1.15 primitiveCooldownPenalty
      - 0.90 directionRepetitionPenalty
      - 0.85 channelRepetitionPenalty
      - 1.00 fatiguePenalty
      - 1.25 budgetOverflowPenalty
      - 2.00 legibilityRisk
      - 2.00 performanceRisk
```

Hard constraints reject unsafe Indic per-codepoint transforms, conflicting replace-channel primitives, too many moving units, insufficient phrase duration, low timing confidence, and cost-budget overflow. Select from candidates within 8% of the maximum using a stable song/section/phrase seed and weighted softmax at low temperature. This produces approximately 70% identity, 20% controlled variation, and 10% rare/hero behavior while remaining reproducible.

`MotionHistory` records major primitive, channels, direction octant, focal position, density, scale range, motif, transition, hero use, and timestamp. Cooldowns prevent the same major primitive within two phrases, the same direction three times, repeated scale-dominant effects, and persistent center composition. Micro-events are thinned so only salient beats react.

## 14. Scene planner

`planScene(lyric, section, visualDNA, audioEvents, previousScene, upcomingScene, motionHistory)` is deterministic and rule/scoring based. Optional ML providers may supply sentiment, semantic roles, VAD, pitch, genre probabilities, or section proposals; their outputs are frozen into `SongAnalysis` with model/version/confidence. The planner never calls a model and never accepts generated drawing code.

Planning order: establish section budget; detect focal word and hero eligibility; choose motif/evolution; create candidate layouts; create candidate transitions continuous with neighbors; create candidate primitive compositions; schedule impacts to known events; score/reject; reserve budget; commit history; prepare shaped layouts. A trace stores candidate scores and rejection reasons for the debugger.

## 15. Intensity budget

Build a continuous `IntensityEnvelope` from section priors, normalized loudness, onset density, lyric salience, and hero reservations. Integrate intensity over rolling 8-second and 30-second windows. A scene requests cost across motion, typography, camera, effect, and micro-reaction channels; the allocator scales or drops lowest-salience channels to stay within both instantaneous and rolling budgets.

Stillness is explicitly scheduled when silence occurs, when fatigue is high, before a reserved hero, after a hero, or when timing confidence is poor. Peak intensity requires a reservation; ordinary phrases are capped below .78. Beat reactions are gated by transient salience and a refractory interval.

## 16. Visual motifs

The compiler selects 1–3 motifs from compatible primitive/layout atoms, not preset scenes. A motif includes a spatial axis, one signature transform, typography modulation, transition gesture, and allowed evolution dimensions. Motifs recur at section-family boundaries and hooks. Repeated chorus instances share the motif ID while `evolutionIndex` increases depth, density, scale, counter-motion, or background echo within budget. Motif selection is stable for the track cache key and analysis version.

## 17. Semantic animation

Semantic cues are sparse and confidence-gated. Candidate cues include action direction (fall/rise/run/stop/break), spatial language (far/close/alone/together), body/emotion anchors (heart/breathe), title/hook words, contrast, negation, and repetition. A cue may boost a compatible primitive but cannot override legibility, section budget, motif coherence, cooldown, or timing confidence. At most one semantic hero exists per phrase, and literal effects require high confidence. Telugu/Tamil cues require locale lexicons or a local multilingual classifier; unsupported language falls back to repetition, placement, acoustic stress, and title matching.

## 18. Hero moments

Generate candidates from first/final chorus, high-confidence drop, sustained silence, top-percentile vocal intensity/pitch, title lyric, repeated hook, bridge boundary, final lyric, and strongest instrumental hit. Score emotional salience, structural importance, surprise, confidence, and distance from prior heroes. Enforce minimum separation and song-duration quotas. Hero plans may relax scale/depth/density limits but retain text-shaping and frame-cost constraints. Reserve anticipation and recovery budget around each hero.

## 19. Transition architecture

`TransitionPlan` is shared by outgoing and incoming scenes and evaluated in a common world/camera coordinate space. Supported topologies include anchor handoff, baseline continuation, spatial push, mask carry, depth swap, foreground/background swap, off-screen continuation, expanding reveal, and echo inheritance. Word morphing is allowed only when shaped-cluster correspondence is reliable; otherwise use mask/anchor continuity. Scene planning is bidirectional so entry decisions know the outgoing scene and exit decisions know the incoming scene.

## 20. Telugu/Tamil and Indic typography

Never split `String.codeUnits`, runes, or raw Unicode characters for animation. Use the `characters` package for Unicode extended grapheme clusters and Flutter/SkParagraph for shaping. The hierarchy is phrase → word → syllable (when reliable) → extended grapheme cluster; a cluster may still shape contextually with neighbors, so the production renderer lays out the complete word/phrase first and derives safe cluster boxes from text positions. Conjunct integrity and combining marks remain together.

Prefer Noto Sans/Serif Telugu and Noto Sans/Serif Tamil assets for predictable glyph coverage and weight. HarfBuzz is already used beneath Flutter's text stack; custom native shaping is unnecessary unless exact glyph-run extraction becomes required. Avoid independent tracking changes inside Indic words because letter spacing can disturb shaping; apply tracking between shaped word groups or to the whole paragraph. Per-cluster transforms are limited to translation/opacity/scale around cached cluster bounds and disabled when cluster box extraction is ambiguous.

## 21. Performance architecture

Target stable 60 FPS, with a 16.67 ms frame budget and a renderer goal below 8 ms on mid-range Android hardware. Limit simultaneously independently transformed shaped units to 48 normally and 72 for reserved heroes; beyond that, animate word/phrase groups. Cache paragraph layouts, line metrics, grapheme boxes, paths, and static layers per scene/viewport/text-scale key. Never rebuild a paragraph or allocate candidate lists in paint.

Prefer canvas transforms and opacity over relayout. Tracking animation uses a small number of pre-shaped buckets or whole-word spacing, not paragraph reconstruction every frame. Blur is capped, downsampled, and never combined across many layers. Use `Picture`/`ui.Image` caching for static echoes and background texture, `saveLayer` only when required, and batch equal paint states. Analysis and planning run in isolates. Ring buffers and reusable typed arrays prevent FFT/PCM garbage churn. Frame timings drive an adaptive quality governor that reduces blur/trails/independent units before reducing motion correctness.

## 22. Preprocessing and caching

Cache key: normalized track identity + duration + optional media fingerprint + analysis schema version + model versions. Persist compact versioned JSON for lyrics/analysis/plans and binary sidecars for dense feature timelines. Atomic `.partial` writes prevent corruption. The cache stores source quality and completion coverage so captured analysis can improve over successive plays. A plan is invalidated when analysis, lyric alignment, viewport class, font bundle, planner version, or accessibility settings change.

On first encounter without full audio access, the app starts with a deterministic degraded plan from lyrics and metadata, incrementally records permitted features, replans only at safe future section boundaries, and persists the stronger analysis. Current-scene visuals never mutate mid-phrase.

## 23. Debugging and timeline tooling

The in-app overlay displays BPM/confidence, beat/downbeat/strength, section/type/intensity, VisualDNA energy, current lyric/focal word, primitives and motif, budget use, semantic cue, next event, hero state, scene ID, analysis quality, FPS, build/raster time, and animated-unit count. It is toggled with a long press and excluded from release builds unless explicitly enabled.

The timeline inspector provides zoom/pan lanes for waveform/loudness, spectral bands, onsets, beats/downbeats, sections, vocals/pitch, lyrics/words/syllables, transitions, intensity envelope, hero reservations, and primitive events. Selecting a scene exposes its scoring trace and rejection reasons; scrubbing uses the same absolute-time evaluator as playback.

## 24. Third-party libraries and models

- `characters`: Unicode extended grapheme segmentation.
- Flutter `TextPainter`/SkParagraph (HarfBuzz-backed): shaping and cluster geometry.
- Existing `sherpa_onnx`: Whisper transcription/token timestamps and VAD-compatible local inference.
- Optional production DSP native module: aubio or Essentia for validated beat/onset/pitch/section features when licensing and binary size are accepted. The in-repo deterministic extractor remains the fallback.
- Noto Telugu and Tamil font families: predictable coverage and weights.
- Optional multilingual local sentiment/semantic ONNX model; deterministic lexicons remain the fallback and all outputs carry confidence/version.

No cloud AI is required for frame-time operation.

## 25. Proposed data models

```dart
SongAnalysis { trackKey, schemaVersion, quality, coverage, bpm, bpmConfidence,
  meter, beats, audioEvents, sections, globalFeatures, vocalContour,
  repeatedMotifs, generatedAt, sourceVersions }
VisualDNA { energy, valence, rhythmicStrength, bassStrength, brightness,
  vocalIntensity, acousticness, electronicness, dynamicRange, syncopation,
  density, motionSharpness, motionElasticity, spatialExpansion, depth,
  stillnessPreference, typography, palette, stableSeed }
SongSection { id, type, start, end, confidence, intensityRange,
  repetitionGroup, occurrence, fingerprint }
BeatEvent { timestamp, strength, confidence, beatInBar, downbeat }
AudioEvent { type, timestamp, anticipation, settle, strength, confidence, bands }
LyricLine { id, text, start, end, words, confidence, provenance }
LyricWord { id, text, start, end, syllables, graphemes, stress, pitch, confidence }
LyricSyllable { text, start, end, stress, confidence, graphemes }
LyricGrapheme { text, start, end, clusterIndex, confidence }
SemanticCue { kind, anchorWordId, confidence, polarity, suggestedDirections }
TypographyStyle { family, fallbackFamilies, weight, width, size, tracking,
  lineHeight, alignment, curvature, orientation, perspective, depth,
  outline, fill, opacity, blur, mask }
MotionPrimitiveSpec { id, type, scope, channels, start, impact, end, strength,
  easing, direction, stagger, overshoot, amplitude, frequency, randomness,
  targets, cost, constraints }
MotionComposition { primitives, microReactions, channelPolicy, totalCost }
VisualMotif { id, atoms, sectionFamilies, evolutionRules, recurrenceWeight }
MotionHistory { recentPrimitives, directions, channels, focalZones, motifs,
  transitions, heroes, fatigue }
AnimationIntensity { base, allocated, rolling8s, rolling30s, channelBudgets }
TransitionPlan { type, start, handoff, end, anchors, outgoing, incoming, camera }
HeroMoment { type, timestamp, window, salience, confidence, ruleRelaxations }
Scene { id, phraseId, sectionId, start, end, layout, typography, focalWordId,
  motifId, evolutionIndex, composition, transitionIn, transitionOut,
  intensity, camera, preparedTextKey, debugTrace }
MotionPlan { trackKey, version, seed, analysisVersion, scenes, motifs,
  intensityEnvelope, heroes, preparedLayoutKeys }
```

## 26. Proposed module structure

```text
lib/engine/
  analysis/{models,feature_extractor,beat_tracker,section_detector,visual_dna}.dart
  lyrics/{alignment,indic_segmentation,prosody,semantic_analyzer}.dart
  planning/{scene_planner,candidate_scorer,intensity_budget,motif_compiler,
            hero_detector,transition_planner,motion_history}.dart
  motion/{primitive,composition,evaluator,curves}.dart
  rendering/{planned_scene_renderer,prepared_text,layout_cache,quality_governor}.dart
  cache/{analysis_cache,motion_plan_cache,versioned_codec}.dart
  debug/{debug_overlay,timeline_inspector,planning_trace}.dart
```

Platform audio feature extraction remains behind `AudioAnalyzer`; native implementations publish timestamped frames/events and quality metadata.

## 27. Exact changes required in this codebase

1. Add the engine models, deterministic DSP accumulator, VisualDNA compiler, section detector, lyric enricher, planner, scorer, budget, motifs, heroes, transitions, evaluator, cache, and debugging UI.
2. Expand native/Dart audio frames with timestamps, centroid, flux, RMS, and transient evidence; feed a persistent per-track accumulator.
3. Upgrade lyric models and serialization to stable IDs, confidence/provenance, syllables, and graphemes; use Whisper timestamps.
4. Add `characters` and bundled Indic fonts.
5. Have the controller own preprocessing state and a cached `MotionPlan`; keep live features only for bounded micro-correction.
6. Replace the production `AuthoredTypographyStage` dispatch with `PlannedSceneRenderer`; preserve old painters only as fallback/reference.
7. Add a debug long-press overlay and timeline inspector route.
8. Add unit tests for deterministic plans, scoring/cooldowns, beat landing, budget limits, grapheme integrity, seek reconstruction, transition continuity, cache migration, and renderer smoke/performance ceilings.

## 28. Existing architectural limitations

- No legal/reliable random access to third-party streaming audio files. Full preprocessing is only possible for imported/local audio or accumulated permitted playback capture.
- Android playback capture may be denied by the user or disabled by the source app; iOS capture is not implemented.
- Android `Visualizer(0)` timing/resolution is insufficient for high-confidence offline downbeats and section structure.
- LRCLIB supplies line-sync, not authoritative word/syllable timing.
- Whisper token timestamps are ASR evidence, not guaranteed lyrical forced alignment, especially for polyphonic mixes and Indic languages.
- Flutter exposes shaped text boxes rather than a stable public glyph-run API; some contextual-script cluster transforms must stay at word level.
- The repository has no commits and the full app tree is currently untracked, so change review must use explicit file lists rather than a reliable baseline diff.

These constraints change confidence and fallback behavior; they do not remove architecture components.

## 29. Complete execution plan

1. Establish versioned domain models and Unicode-safe lyric enrichment.
2. Implement timestamped analysis accumulation, beat tracking, event extraction, section detection, VisualDNA, and disk cache.
3. Preserve ASR timestamps and implement confidence-aware lyric alignment/enrichment.
4. Implement primitives, channel composition, anticipation/impact/settle evaluation, intensity budgeting, history, motifs, heroes, transitions, and deterministic scoring.
5. Build the whole-song scene planner and plan cache.
6. Build cached shaped-text preparation and the planned renderer, then switch the production view to it.
7. Integrate preprocessing/planning lifecycle in the controller, including degraded-to-enriched safe-boundary replanning.
8. Add overlay and timeline inspector.
9. Add complete unit/widget tests, run formatting/static analysis/tests, and profile representative long Latin, Telugu, and Tamil songs at 60 FPS.

The production system is hybrid in evidence acquisition but deterministic in direction: ML/DSP providers may describe the song; only the versioned planner composes the visuals. That boundary is what keeps the result debuggable, reproducible, safe for Indic shaping, and recognizably the same song on every play.
