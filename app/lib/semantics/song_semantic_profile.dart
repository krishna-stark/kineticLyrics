enum BackgroundObjectKind {
  phone,
  door,
  chain,
  rose,
  gun,
  rain,
  moon,
  sun,
  stars,
  heart,
  flame,
  water,
  city,
  road,
  wings,
  eye,
  clock,
  crown,
  flower,
  smoke,
  lightning,
  brokenGlass,
  mountain,
  ocean,
  cloud,
  bird,
  butterfly,
  tree,
  leaf,
  lotus,
  river,
  diamond,
  key,
  mirror,
  mask,
  train,
  plane,
  compass,
  hand,
  musicNote,
}

enum SemanticMotionPath {
  orbit,
  horizontal,
  rise,
  fall,
  split,
  tunnel,
  wave,
  corner,
  scatter,
  stillness,
}

enum SemanticTypography { display, condensed, elegant, soft }

enum SemanticComposition { spotlight, staggered, paired, drifting }

enum SemanticTransition { impact, slide, lift, dissolve, scatter }

class LineSemanticProfile {
  const LineSemanticProfile({
    required this.lineIndex,
    required this.motionPath,
    required this.motionConfidence,
    this.objects = const [],
  });

  final int lineIndex;
  final SemanticMotionPath motionPath;
  final double motionConfidence;
  final List<BackgroundObjectKind> objects;

  // The embedding selects a meaning/motion family; the art director maps it
  // to a coherent font/layout/transition rather than randomizing each frame.
  SemanticTypography get typography => switch (motionPath) {
    SemanticMotionPath.tunnel ||
    SemanticMotionPath.scatter => SemanticTypography.display,
    SemanticMotionPath.horizontal ||
    SemanticMotionPath.orbit => SemanticTypography.condensed,
    SemanticMotionPath.split ||
    SemanticMotionPath.rise => SemanticTypography.elegant,
    _ => SemanticTypography.soft,
  };
  SemanticComposition get composition => switch (motionPath) {
    SemanticMotionPath.split => SemanticComposition.paired,
    SemanticMotionPath.horizontal ||
    SemanticMotionPath.scatter => SemanticComposition.staggered,
    SemanticMotionPath.wave ||
    SemanticMotionPath.corner ||
    SemanticMotionPath.fall => SemanticComposition.drifting,
    _ => SemanticComposition.spotlight,
  };
  SemanticTransition get transition => switch (motionPath) {
    SemanticMotionPath.tunnel => SemanticTransition.impact,
    SemanticMotionPath.scatter => SemanticTransition.scatter,
    SemanticMotionPath.horizontal ||
    SemanticMotionPath.orbit => SemanticTransition.slide,
    SemanticMotionPath.rise ||
    SemanticMotionPath.split => SemanticTransition.lift,
    _ => SemanticTransition.dissolve,
  };

  Map<String, Object?> toJson() => {
    'lineIndex': lineIndex,
    'motionPath': motionPath.name,
    'motionConfidence': motionConfidence,
    'objects': objects.map((value) => value.name).toList(),
  };

  factory LineSemanticProfile.fromJson(Map<String, Object?> json) =>
      LineSemanticProfile(
        lineIndex: json['lineIndex'] as int,
        motionPath: SemanticMotionPath.values.byName(
          json['motionPath'] as String,
        ),
        motionConfidence: (json['motionConfidence'] as num).toDouble(),
        objects: (json['objects'] as List<Object?>? ?? const [])
            .map((value) => BackgroundObjectKind.values.byName(value as String))
            .toList(),
      );
}

class SongSemanticProfile {
  const SongSemanticProfile({
    required this.trackKey,
    required this.aiGenerated,
    required this.analysisMilliseconds,
    this.songObjects = const [],
    this.lines = const {},
  });

  final String trackKey;
  final bool aiGenerated;
  final int analysisMilliseconds;
  final List<BackgroundObjectKind> songObjects;
  final Map<int, LineSemanticProfile> lines;

  LineSemanticProfile? lineAt(int index) => lines[index];

  Map<String, Object?> toJson() => {
    'trackKey': trackKey,
    'aiGenerated': aiGenerated,
    'analysisMilliseconds': analysisMilliseconds,
    'songObjects': songObjects.map((value) => value.name).toList(),
    'lines': lines.values.map((value) => value.toJson()).toList(),
  };

  factory SongSemanticProfile.fromJson(Map<String, Object?> json) {
    final lineValues = (json['lines'] as List<Object?>? ?? const [])
        .map(
          (value) => LineSemanticProfile.fromJson(
            (value as Map<Object?, Object?>).cast<String, Object?>(),
          ),
        )
        .toList();
    return SongSemanticProfile(
      trackKey: json['trackKey'] as String,
      aiGenerated: json['aiGenerated'] as bool? ?? false,
      analysisMilliseconds: json['analysisMilliseconds'] as int? ?? 0,
      songObjects: (json['songObjects'] as List<Object?>? ?? const [])
          .map((value) => BackgroundObjectKind.values.byName(value as String))
          .toList(),
      lines: {for (final value in lineValues) value.lineIndex: value},
    );
  }
}
