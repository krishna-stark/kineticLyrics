# Architecture and extension guide

The app uses dependency inversion at each external boundary:

```text
NowPlayingDetector -> KineticLyricsController -> LyricsRepository
                       |                      -> AnalysisAccumulator/Cache
                       |                      -> ScenePlanner -> MotionPlan
                       +--------------------------------------> PlannedSceneRenderer
```

`AppComposition` in `lib/main.dart` is the only place that selects concrete
implementations.

## Add a playback source

Implement `NowPlayingDetector` and emit normalized `NowPlayingSnapshot` values.
Then inject it into `KineticLyricsController` in `AppComposition`.

Android's current implementation uses the system MediaSession API and therefore
already supports new compliant players without package-specific code. A service
adapter such as Spotify OAuth or an eventual iOS MusicKit source can implement
the same interface without changing lyrics or rendering code.

## Add a lyrics source

Implement `LyricsProvider`:

```dart
class LicensedLyricsProvider implements LyricsProvider {
  @override
  String get id => 'licensed';

  @override
  Future<LyricTimeline?> find(TrackIdentity track) async {
    // Convert the service response to the shared timeline model.
  }
}
```

Register it in priority order:

```dart
LyricsRepository(
  providers: [
    LicensedLyricsProvider(),
    LrcLibProvider(client: DartJsonHttpClient()),
  ],
)
```

Provider exceptions are isolated and the repository continues to the next
source. Successful and missing results are cached per normalized track identity.

## Add a motion primitive

Add a `MotionPrimitiveType`, its channel/cost declaration, and its pure
absolute-time evaluation in `MotionEvaluator`. Add compatibility evidence to
the planner scorer rather than creating separate strength variants. The
intensity allocator continuously scales the same primitive for weak, medium,
and hero moments.

All movement must be derived from absolute song time. Do not start independent
animation controllers for lyric events, because they drift and cannot recreate
the correct frame after a seek. Expensive analysis, candidate scoring, Unicode
segmentation, and text layout belong before paint; the renderer evaluates the
prepared plan only.
