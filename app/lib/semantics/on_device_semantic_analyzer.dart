import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart_sentencepiece_tokenizer/dart_sentencepiece_tokenizer.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';

import '../lyrics/domain/lyric_timeline.dart';
import '../lyrics/domain/track_identity.dart';
import 'song_semantic_profile.dart';
import 'semantic_direction_ranker.dart';
import 'semantic_object_ranker.dart';
import 'romanized_object_anchors.dart';
import 'lyric_cues.dart';

abstract class LyricSemanticAnalyzer {
  Future<SongSemanticProfile> analyze(
    TrackIdentity track,
    LyricTimeline timeline,
  );

  void dispose() {}
}

/// Runs multilingual E5 once per song. Results are cached and never queried
/// from the animation loop.
class OnDeviceE5SemanticAnalyzer implements LyricSemanticAnalyzer {
  static const _modelAsset = 'assets/models/multilingual-e5-small-int8.onnx';
  static const _tokenizerAsset = 'assets/models/multilingual-e5-tokenizer.json';
  static const _maxTokens = 96;

  OrtSession? _session;
  SentencePieceTokenizer? _tokenizer;

  Future<void> _queue = Future.value();
  Future<ByteData>? _modelBytes;
  Future<String>? _tokenizerJson;
  bool _disposed = false;
  String? lastFailure;

  @override
  Future<SongSemanticProfile> analyze(
    TrackIdentity track,
    LyricTimeline timeline,
  ) {
    final pending = _queue.then((_) => _analyzeQueued(track, timeline));
    _queue = pending.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return pending;
  }

  Future<SongSemanticProfile> _analyzeQueued(
    TrackIdentity track,
    LyricTimeline timeline,
  ) async {
    if (_disposed) throw StateError('Semantic analyzer disposed');
    // Include lyric content: recovered/corrected lyrics must not reuse an old
    // profile merely because their media metadata is unchanged.
    final cacheKey =
        '${track.cacheKey}:director-v8:${_stableHash(timeline.lines.map((line) => line.text).join('\n'))}';
    final cached = await _loadCache(cacheKey, track.cacheKey);
    if (cached != null) return cached;
    final stopwatch = Stopwatch()..start();
    lastFailure = null;
    try {
      _modelBytes ??= rootBundle.load(_modelAsset);
      _tokenizerJson ??= rootBundle.loadString(_tokenizerAsset);
      final model = await _modelBytes!;
      final tokenizerJson = await _tokenizerJson!;
      if (_disposed) throw StateError('Semantic analyzer disposed');
      final payload = _InferenceRequest(
        track,
        timeline,
        model.buffer.asUint8List(model.offsetInBytes, model.lengthInBytes),
        tokenizerJson,
      );
      // Native ONNX setup, tokenization, synchronous inference, and pooling all
      // run off the Flutter isolate; no native result decoding stalls paint.
      final profile = await _startWorker(payload);
      if (!_disposed) await _saveCache(cacheKey, profile);
      return profile;
    } catch (error) {
      lastFailure = error.toString();
      // Do not persist fallback as an AI result: a later launch can retry the
      // model if native initialization failed temporarily.
      return lexicalFallback(
        track,
        timeline,
        elapsed: stopwatch.elapsedMilliseconds,
      );
    }
  }

  static Future<SongSemanticProfile> _startWorker(_InferenceRequest request) =>
      Isolate.run(() => _inferInWorker(request));

  static Future<SongSemanticProfile> _inferInWorker(
    _InferenceRequest request,
  ) async {
    final worker = OnDeviceE5SemanticAnalyzer();
    final stopwatch = Stopwatch()..start();
    try {
      worker._tokenizer = HuggingFaceTokenizerLoader.fromJsonString(
        request.tokenizerJson,
      );
      OrtEnv.instance.init(logId: 'KineticLyricsE5');
      final options = OrtSessionOptions()
        ..setIntraOpNumThreads(2)
        ..setInterOpNumThreads(1)
        ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
      try {
        worker._session = OrtSession.fromBuffer(request.model, options);
      } finally {
        options.release();
      }
      return await worker._infer(request.track, request.timeline, stopwatch);
    } finally {
      worker._session?.release();
      worker._tokenizer = null;
    }
  }

  Future<SongSemanticProfile> _infer(
    TrackIdentity track,
    LyricTimeline timeline,
    Stopwatch stopwatch,
  ) async {
    const neutralQueries = <String>[
      'query: visual meaning of the lyric words in a song',
      'query: visual meaning of the lyric a musical phrase being sung',
      'query: visual meaning of the lyric a song verse and chorus',
    ];
    final queries = <String>[
      ...neutralQueries,
      for (var i = 0; i < timeline.lines.length; i++)
        'query: visual meaning of the lyric ${timeline.lines[i].text}. '
            'Phrase context: ${i > 0 ? timeline.lines[i - 1].text : ''} '
            '${i + 1 < timeline.lines.length ? timeline.lines[i + 1].text : ''}',
    ];
    final objectPassages = [
      for (final prototype in _objectPrototypes)
        'passage: ${prototype.description}',
    ];
    final motionPassages = [
      for (final prototype in _motionPrototypes)
        'passage: ${prototype.description}',
    ];
    final vectors = await _embedBatches([
      ...queries,
      ...objectPassages,
      ...motionPassages,
    ]);
    final objectStart = queries.length;
    final motionStart = objectStart + objectPassages.length;
    final objectVectors = vectors.sublist(objectStart, motionStart);
    final motionVectors = vectors.sublist(motionStart);

    const ranker = SemanticDirectionRanker();
    final baseline = <SemanticMotionPath, double>{
      for (var prototype = 0; prototype < _motionPrototypes.length; prototype++)
        _motionPrototypes[prototype].kind:
            vectors
                .take(neutralQueries.length)
                .map((neutral) => _cosine(neutral, motionVectors[prototype]))
                .reduce((a, b) => a + b) /
            neutralQueries.length,
    };
    final objectBaseline = [
      for (final prototype in objectVectors)
        vectors
                .take(neutralQueries.length)
                .map((neutral) => _cosine(neutral, prototype))
                .reduce((a, b) => a + b) /
            neutralQueries.length,
    ];
    final lines = <int, LineSemanticProfile>{};
    for (var index = 0; index < timeline.lines.length; index++) {
      final vector = vectors[index + neutralQueries.length];
      final text = timeline.lines[index].text;
      final objects = _selectObjects(
        vector,
        objectVectors,
        text,
        limit: 1,
        threshold: .81,
        neutralBaseline: objectBaseline,
      );
      final direction = ranker.rank({
        for (
          var prototype = 0;
          prototype < _motionPrototypes.length;
          prototype++
        )
          _motionPrototypes[prototype].kind: _cosine(
            vector,
            motionVectors[prototype],
          ),
      }, baseline);
      lines[index] = LineSemanticProfile(
        lineIndex: index,
        motionPath: direction.path,
        motionConfidence: direction.confidence,
        objects: objects,
      );
    }
    return SongSemanticProfile(
      trackKey: track.cacheKey,
      aiGenerated: true,
      analysisMilliseconds: stopwatch.elapsedMilliseconds,
      songObjects: ranker.recurringObjects(lines.values),
      lines: lines,
    );
  }

  Future<List<List<double>>> _embedBatches(List<String> texts) async {
    final result = <List<double>>[];
    for (var start = 0; start < texts.length; start += 8) {
      result.addAll(
        await _embed(texts.sublist(start, math.min(start + 8, texts.length))),
      );
    }
    return result;
  }

  Future<List<List<double>>> _embed(List<String> texts) async {
    final tokenizer = _tokenizer!;
    final encoded = texts.map((text) {
      final ids = tokenizer.encode(text).ids;
      // Preserve the terminal special token when bounding long passages.
      // Tokenize the complete Unicode string before truncating token IDs.
      return ids.length <= _maxTokens
          ? ids
          : [...ids.take(_maxTokens - 1), ids.last];
    }).toList();
    final width = math.max(
      2,
      encoded.fold<int>(0, (v, ids) => math.max(v, ids.length)),
    );
    final padId = tokenizer.vocab.padId >= 0 ? tokenizer.vocab.padId : 1;
    final ids = <Int64List>[];
    final masks = <Int64List>[];
    for (final row in encoded) {
      ids.add(
        Int64List.fromList([...row, ...List.filled(width - row.length, padId)]),
      );
      masks.add(
        Int64List.fromList([
          ...List.filled(row.length, 1),
          ...List.filled(width - row.length, 0),
        ]),
      );
    }
    final inputIds = OrtValueTensor.createTensorWithDataList(ids, [
      ids.length,
      width,
    ]);
    final attention = OrtValueTensor.createTensorWithDataList(masks, [
      ids.length,
      width,
    ]);
    final inputs = <String, OrtValue>{
      'input_ids': inputIds,
      'attention_mask': attention,
    };
    OrtValueTensor? tokenTypes;
    if (_session!.inputNames.contains('token_type_ids')) {
      tokenTypes = OrtValueTensor.createTensorWithDataList(
        [for (var i = 0; i < ids.length; i++) Int64List(width)],
        [ids.length, width],
      );
      inputs['token_type_ids'] = tokenTypes;
    }
    final runOptions = OrtRunOptions();
    List<OrtValue?> outputs;
    try {
      outputs = _session!.run(runOptions, inputs);
    } finally {
      inputIds.release();
      attention.release();
      tokenTypes?.release();
      runOptions.release();
    }
    try {
      final hidden = outputs.first!.value as List<Object?>;
      final result = <List<double>>[];
      for (var batch = 0; batch < hidden.length; batch++) {
        final tokens = hidden[batch] as List<Object?>;
        final pooled = List<double>.filled(384, 0);
        var count = 0;
        for (var token = 0; token < tokens.length && token < width; token++) {
          if (masks[batch][token] == 0) continue;
          final values = tokens[token] as List<Object?>;
          for (var dimension = 0; dimension < pooled.length; dimension++) {
            pooled[dimension] += (values[dimension] as num).toDouble();
          }
          count++;
        }
        var norm = 0.0;
        for (var dimension = 0; dimension < pooled.length; dimension++) {
          pooled[dimension] /= math.max(1, count);
          norm += pooled[dimension] * pooled[dimension];
        }
        norm = math.sqrt(norm).clamp(1e-8, double.infinity);
        result.add([for (final value in pooled) value / norm]);
      }
      return result;
    } finally {
      for (final output in outputs) {
        output?.release();
      }
    }
  }

  List<BackgroundObjectKind> _selectObjects(
    List<double> vector,
    List<List<double>> prototypes,
    String source, {
    required int limit,
    required double threshold,
    required List<double> neutralBaseline,
  }) {
    final normalized = source.toLowerCase();
    return const SemanticObjectRanker().select(
      [
        for (var index = 0; index < _objectPrototypes.length; index++)
          SemanticObjectCandidate(
            kind: _objectPrototypes[index].kind,
            similarity: _cosine(vector, prototypes[index]),
            neutralSimilarity: neutralBaseline[index],
            explicitAnchor: _objectAnchor(normalized, _objectPrototypes[index]),
          ),
      ],
      limit: limit,
      minimumSimilarity: threshold,
    );
  }

  /// Conservative offline fallback. These explicit anchors cover a limited
  /// Telugu/Tamil/Hindi vocabulary; multilingual embeddings remain primary.
  SongSemanticProfile lexicalFallback(
    TrackIdentity track,
    LyricTimeline timeline, {
    int elapsed = 0,
  }) {
    final lineProfiles = {
      for (var index = 0; index < timeline.lines.length; index++)
        index: LineSemanticProfile(
          lineIndex: index,
          motionPath: _lexicalMotion(timeline.lines[index].text),
          motionConfidence: 0,
          objects: lexicalObjectsFor(timeline.lines[index].text),
        ),
    };
    return SongSemanticProfile(
      trackKey: track.cacheKey,
      aiGenerated: false,
      analysisMilliseconds: elapsed,
      songObjects: const SemanticDirectionRanker().recurringObjects(
        lineProfiles.values,
      ),
      lines: lineProfiles,
    );
  }

  /// Immediate, explicitly grounded objects while background AI prepares.
  static List<BackgroundObjectKind> lexicalObjectsFor(
    String text, {
    int limit = 1,
  }) {
    final normalized = text.toLowerCase();
    return _objectPrototypes
        .where((prototype) => _objectAnchor(normalized, prototype))
        .take(limit)
        .map((prototype) => prototype.kind)
        .toList();
  }

  static bool _objectAnchor(String text, _ObjectPrototype prototype) =>
      _hasAnchor(text, prototype.anchors) ||
      _hasAnchor(text, romanizedObjectAnchors[prototype.kind] ?? const []);
  static bool _hasAnchor(String text, List<String> anchors) => LyricCues.contains(text,anchors);

  SemanticMotionPath _lexicalMotion(String text) {
    final value = text.toLowerCase();
    if (_hasAnchor(value, ['break', 'broken', 'shatter'])) {
      return SemanticMotionPath.scatter;
    }
    if (_hasAnchor(value, ['run', 'drive', 'road', 'fast'])) {
      return SemanticMotionPath.horizontal;
    }
    if (_hasAnchor(value, ['rise', 'fly', 'hope', 'free'])) {
      return SemanticMotionPath.rise;
    }
    if (_hasAnchor(value, ['fall', 'lost', 'sad'])) {
      return SemanticMotionPath.fall;
    }
    if (_hasAnchor(value, [
      'love',
      'heart',
      'together',
      'ప్రేమ',
      'కలిసి',
      'காதல்',
      'இதயம்',
      'प्यार',
      'दिल',
    ])) {
      return SemanticMotionPath.split;
    }
    if (_hasAnchor(value, [
      'fire',
      'power',
      'fight',
      'అగ్ని',
      'మంట',
      'நெருப்பு',
      'தீ',
      'आग',
    ])) {
      return SemanticMotionPath.tunnel;
    }
    if (_hasAnchor(value, [
      'alone',
      'lonely',
      'away',
      'ఒంటరి',
      'தனிமை',
      'अकेला',
    ])) {
      return SemanticMotionPath.corner;
    }
    if (_hasAnchor(value, [
      'rain',
      'water',
      'dream',
      'వాన',
      'వర్షం',
      'నీరు',
      'కల',
      'மழை',
      'தண்ணீர்',
      'கனவு',
      'बारिश',
      'पानी',
      'सपना',
    ])) {
      return SemanticMotionPath.wave;
    }
    return SemanticMotionPath.stillness;
  }

  double _cosine(List<double> a, List<double> b) {
    var value = 0.0;
    for (var index = 0; index < math.min(a.length, b.length); index++) {
      value += a[index] * b[index];
    }
    return value;
  }

  Future<File> _cacheFile(String trackKey) async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/semantic_profiles');
    await directory.create(recursive: true);
    return File('${directory.path}/${_stableHash(trackKey)}.json');
  }

  Future<SongSemanticProfile?> _loadCache(
    String cacheKey,
    String trackKey,
  ) async {
    try {
      final file = await _cacheFile(cacheKey);
      if (!await file.exists()) return null;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      final profile = SongSemanticProfile.fromJson(json);
      return profile.trackKey == trackKey ? profile : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCache(String cacheKey, SongSemanticProfile profile) async {
    try {
      final file = await _cacheFile(cacheKey);
      await file.writeAsString(jsonEncode(profile.toJson()), flush: true);
    } catch (_) {}
  }

  int _stableHash(String value) {
    var hash = 0x811C9DC5;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  @override
  void dispose() {
    _disposed = true;
    _modelBytes = null;
    _tokenizerJson = null;
  }
}

class _InferenceRequest {
  const _InferenceRequest(
    this.track,
    this.timeline,
    this.model,
    this.tokenizerJson,
  );
  final TrackIdentity track;
  final LyricTimeline timeline;
  final Uint8List model;
  final String tokenizerJson;
}

class _ObjectPrototype {
  const _ObjectPrototype(this.kind, this.description, this.anchors);
  final BackgroundObjectKind kind;
  final String description;
  final List<String> anchors;
}

class _MotionPrototype {
  const _MotionPrototype(this.kind, this.description);
  final SemanticMotionPath kind;
  final String description;
}

const _objectPrototypes = <_ObjectPrototype>[
  _ObjectPrototype(
    BackgroundObjectKind.phone,
    'a telephone, calling someone, messages and reaching out',
    ['phone', 'call', 'calling', 'message', 'ఫోన్', 'தொலைபேசி', 'फोन'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.door,
    'a door, leaving, walking out, departure and saying goodbye',
    ['door', 'leave', 'leaving', 'goodbye', 'తలుపు', 'கதவு', 'दरवाजा'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.chain,
    'a broken chain, release, letting go and freedom from a relationship',
    [
      'let go',
      'letting go',
      'chain',
      "don't care",
      'గొలుసు',
      'சங்கிலி',
      'जंजीर',
    ],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.rose,
    'roses, romance, thorns and a bouquet',
    ['rose', 'roses', 'gulab', 'గులాబీ', 'ரோஜா', 'गुलाब'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.gun,
    'a gun, weapon, bullet, shooting or danger',
    ['gun', 'guns', 'bullet', 'shoot', 'తుపాకీ', 'துப்பாக்கி', 'बंदूक'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.rain,
    'rain, tears, storm clouds and wet weather',
    ['rain', 'tears', 'storm', 'వాన', 'వర్షం', 'மழை', 'बारिश'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.moon,
    'the moon, night sky and lunar light',
    ['moon', 'luna', 'చందమామ', 'చంద్రుడు', 'நிலா', 'சந்திரன்', 'चाँद', 'चांद'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.sun,
    'sunshine, daylight, dawn and warmth',
    ['sun', 'sunshine', 'dawn', 'సూర్యుడు', 'சூரியன்', 'सूरज'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.stars,
    'stars, constellations, space and the universe',
    [
      'star',
      'stars',
      'galaxy',
      'నక్షత్రం',
      'నక్షత్రాలు',
      'நட்சத்திரம்',
      'நட்சத்திரங்கள்',
      'तारा',
      'तारे',
    ],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.heart,
    'love, affection, romance and a human heart',
    ['love', 'heart', 'ప్రేమ', 'హృదయం', 'காதல்', 'இதயம்', 'प्यार', 'दिल'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.flame,
    'fire, burning, heat, passion and flames',
    ['fire', 'burn', 'flame', 'hot', 'అగ్ని', 'మంట', 'நெருப்பு', 'தீ', 'आग'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.water,
    'ocean, sea, river, water and waves',
    ['water', 'నీరు', 'నీళ్ళు', 'தண்ணீர்', 'पानी'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.city,
    'city buildings, streets, skyline and urban life',
    ['city', 'town', 'street', 'నగరం', 'நகரம்', 'शहर'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.road,
    'road, journey, travel, driving and moving away',
    [
      'road',
      'drive',
      'journey',
      'దారి',
      'రహదారి',
      'பாதை',
      'சாலை',
      'रास्ता',
      'सड़क',
    ],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.wings,
    'wings, flying, freedom and escaping into the sky',
    ['fly', 'flying', 'wings', 'free', 'రెక్కలు', 'சிறகுகள்', 'पंख'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.eye,
    'eyes, watching, seeing and looking',
    [
      'eye',
      'eyes',
      'look',
      'see',
      'కన్ను',
      'కళ్ళు',
      'కళ్లు',
      'கண்',
      'கண்கள்',
      'आँख',
      'आंख',
      'आँखें',
    ],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.clock,
    'time, clocks, waiting, yesterday and tomorrow',
    ['time', 'clock', 'waiting', 'గడియారం', 'கடிகாரம்', 'घड़ी'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.crown,
    'a crown, royalty, king, queen and power',
    ['crown', 'king', 'queen', 'కిరీటం', 'கிரீடம்', 'ताज'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.flower,
    'flowers, petals, gardens and blooming',
    ['flower', 'flowers', 'bloom', 'పువ్వు', 'పూలు', 'மலர்', 'பூ', 'फूल'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.smoke,
    'smoke, fog, haze, fading and disappearing',
    ['smoke', 'fog', 'haze', 'పొగ', 'புகை', 'धुआँ', 'धुआं'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.lightning,
    'lightning, electricity, shock and sudden energy',
    ['lightning', 'electric', 'shock', 'మెరుపు', 'மின்னல்', 'बिजली'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.brokenGlass,
    'broken glass, fracture, damage and a shattered relationship',
    ['broken', 'shatter', 'crack'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.mountain,
    'mountains, hills, peaks and a towering landscape',
    [
      'mountain',
      'mountains',
      'hill',
      'కొండ',
      'పర్వతం',
      'மலை',
      'पहाड़',
      'पर्वत',
    ],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.ocean,
    'the ocean, sea, beach, tide and vast saltwater',
    ['ocean', 'sea', 'beach', 'సముద్రం', 'கடல்', 'समुद्र'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.cloud,
    'clouds, cloudy skies and a floating mist in the sky',
    ['cloud', 'clouds', 'మేఘం', 'మేఘాలు', 'மேகம்', 'மேகங்கள்', 'बादल'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.bird,
    'a bird, songbird, dove, sparrow and flight',
    [
      'bird',
      'birds',
      'పక్షి',
      'పక్షులు',
      'பறவை',
      'பறவைகள்',
      'पक्षी',
      'चिड़िया',
    ],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.butterfly,
    'a butterfly, delicate colorful wings and transformation',
    ['butterfly', 'butterflies', 'సీతాకోకచిలుక', 'பட்டாம்பூச்சி', 'तितली'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.tree,
    'a tree, forest, branches, roots and shade',
    ['tree', 'trees', 'forest', 'చెట్టు', 'చెట్లు', 'மரம்', 'மரங்கள்', 'पेड़'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.leaf,
    'a leaf, green leaves, foliage and falling leaves',
    ['leaf', 'leaves', 'ఆకు', 'ఆకులు', 'இலை', 'இலைகள்', 'पत्ता', 'पत्ते'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.lotus,
    'a lotus flower, sacred bloom and a flower on water',
    ['lotus', 'తామర', 'తామరపువ్వు', 'தாமரை', 'कमल'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.river,
    'a river, flowing stream, riverbank and freshwater current',
    ['river', 'stream', 'నది', 'నదులు', 'நதி', 'ஆறு', 'नदी'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.diamond,
    'a diamond, jewel, gemstone and precious sparkling stone',
    ['diamond', 'diamonds', 'వజ్రం', 'வைரம்', 'हीरा'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.key,
    'a key, unlocking, locked doors and opening possibilities',
    ['key', 'keys', 'తాళం చెవి', 'திறவுகோல்', 'சாவி', 'चाबी'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.mirror,
    'a mirror, reflections, seeing oneself and identity',
    ['mirror', 'reflection', 'అద్దం', 'கண்ணாடி', 'आईना', 'दर्पण'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.mask,
    'a mask, disguise, hidden face and pretending',
    ['mask', 'disguise', 'ముసుగు', 'முகமூடி', 'मुखौटा'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.train,
    'a train, railway, station, tracks and rail travel',
    ['train', 'railway', 'రైలు', 'ரயில்', 'रेलगाड़ी'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.plane,
    'an airplane, flying aircraft, airports and air travel',
    ['airplane', 'aeroplane', 'plane', 'విమానం', 'விமானம்', 'विमान'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.compass,
    'a compass, directions, north, navigation and finding a way',
    ['compass', 'దిక్సూచి', 'திசைகாட்டி', 'दिशासूचक'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.hand,
    'a hand, hands, holding hands, touch and reaching out',
    ['hand', 'hands', 'చేయి', 'చేతులు', 'கை', 'கைகள்', 'हाथ'],
  ),
  _ObjectPrototype(
    BackgroundObjectKind.musicNote,
    'music, melody, song, musical notes and singing',
    [
      'music',
      'melody',
      'song',
      'సంగీతం',
      'పాట',
      'இசை',
      'பாட்டு',
      'संगीत',
      'गीत',
    ],
  ),
];

const _motionPrototypes = <_MotionPrototype>[
  _MotionPrototype(
    SemanticMotionPath.orbit,
    'circling, dancing, repeating and revolving around someone',
  ),
  _MotionPrototype(
    SemanticMotionPath.horizontal,
    'running, driving, speed, travel and forward momentum',
  ),
  _MotionPrototype(
    SemanticMotionPath.rise,
    'rising, hope, flying, growing and becoming stronger',
  ),
  _MotionPrototype(
    SemanticMotionPath.fall,
    'falling, sadness, collapse, sinking and loss',
  ),
  _MotionPrototype(
    SemanticMotionPath.split,
    'two people, love, separation, reunion and togetherness',
  ),
  _MotionPrototype(
    SemanticMotionPath.tunnel,
    'impact, power, confrontation, intensity and coming closer',
  ),
  _MotionPrototype(
    SemanticMotionPath.wave,
    'water, calm, dreaming, softness and flowing emotion',
  ),
  _MotionPrototype(
    SemanticMotionPath.corner,
    'loneliness, isolation, distance and being left behind',
  ),
  _MotionPrototype(
    SemanticMotionPath.scatter,
    'breaking, chaos, explosion, fear and fragments',
  ),
  _MotionPrototype(
    SemanticMotionPath.stillness,
    'silence, waiting, peace, stopping and emptiness',
  ),
];
