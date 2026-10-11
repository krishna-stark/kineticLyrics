import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_lyrics/lyrics/domain/lyric_timeline.dart';
import 'package:kinetic_lyrics/lyrics/domain/track_identity.dart';
import 'package:kinetic_lyrics/semantics/on_device_semantic_analyzer.dart';
import 'package:kinetic_lyrics/semantics/song_semantic_profile.dart';

void main() {
  const track = TrackIdentity(
    title: 'Context study',
    artist: 'Test',
    album: null,
    duration: Duration(minutes: 3),
    sourcePackage: 'test',
  );
  SongSemanticProfile fallback(List<String> texts) {
    final analyzer = OnDeviceE5SemanticAnalyzer();
    final profile = analyzer.lexicalFallback(
      track,
      LyricTimeline(
        provider: 'test',
        quality: LyricsTimingQuality.lineSynced,
        lines: [
          for (var i = 0; i < texts.length; i++)
            LyricLine(
              text: texts[i],
              start: Duration(seconds: i * 3),
              end: Duration(seconds: i * 3 + 3),
            ),
        ],
      ),
    );
    analyzer.dispose();
    return profile;
  }

  test('Indic anchors recognize complete Telugu Tamil Hindi words', () {
    final profile = fallback([
      'చందమామ వెలుగులో',
      'వాన వచ్చింది',
      'తామర అందంగా',
      'நிலா அழகாக',
      'மழை வருகிறது',
      'பட்டாம்பூச்சி பறக்கிறது',
      'चाँद चमकता है',
      'बारिश आई',
      'तितली उड़ती है',
    ]);
    final objects = profile.lines.values
        .map((line) => line.objects.single)
        .toList();
    expect(objects, [
      BackgroundObjectKind.moon,
      BackgroundObjectKind.rain,
      BackgroundObjectKind.lotus,
      BackgroundObjectKind.moon,
      BackgroundObjectKind.rain,
      BackgroundObjectKind.butterfly,
      BackgroundObjectKind.moon,
      BackgroundObjectKind.rain,
      BackgroundObjectKind.butterfly,
    ]);
    expect(profile.aiGenerated, isFalse);
    expect(
      profile.songObjects,
      unorderedEquals([BackgroundObjectKind.moon, BackgroundObjectKind.rain]),
    );
  });

  test('native love and fire cues preserve meaningful fallback direction', () {
    final profile = fallback([
      'ప్రేమ',
      'காதல்',
      'प्यार',
      'మంట',
      'நெருப்பு',
      'आग',
    ]);
    expect(
      profile.lines.values.take(3).map((line) => line.motionPath),
      everyElement(SemanticMotionPath.split),
    );
    expect(
      profile.lines.values.skip(3).map((line) => line.motionPath),
      everyElement(SemanticMotionPath.tunnel),
    );
  });

  test(
    'word boundaries prevent embedded substring and unknown-script guessing',
    () {
      final profile = fallback([
        'begun sunny monkey',
        'అచందమామక',
        'अनजानी बात',
      ]);
      expect(
        profile.lines.values.map((line) => line.objects),
        everyElement(isEmpty),
      );
    },
  );

  test(
    'inflected native Tamil fire imagery is grounded before AI completes',
    () {
      expect(OnDeviceE5SemanticAnalyzer.lexicalObjectsFor('நெருப்புடா...'), [
        BackgroundObjectKind.flame,
      ]);
      expect(OnDeviceE5SemanticAnalyzer.lexicalObjectsFor('கண்ணாலே'), [
        BackgroundObjectKind.eye,
      ]);
      expect(OnDeviceE5SemanticAnalyzer.lexicalObjectsFor('వెన్నెలలో'), [
        BackgroundObjectKind.moon,
      ]);
    },
  );

  test('all forty object names survive profile cache serialization', () {
    expect(BackgroundObjectKind.values, hasLength(40));
    const profile = SongSemanticProfile(
      trackKey: 'test',
      aiGenerated: true,
      analysisMilliseconds: 1,
      songObjects: BackgroundObjectKind.values,
    );
    final restored = SongSemanticProfile.fromJson(profile.toJson());
    expect(restored.songObjects, BackgroundObjectKind.values);
    expect(restored.songObjects, contains(BackgroundObjectKind.musicNote));
  });

  test('Romanized Tamil Telugu Hindi select actual lyric objects', () {
    final profile = fallback([
      'Kaadhal en nenjil',
      'Nilave nee',
      'Mazhaiyil',
      'Neruppu',
      'Kannaale',
      'Suruttu puk pola',
      'Prema manasulo',
      'Vennelalo',
      'Vaanalo',
      'Nippula',
      'Kannullo',
      'Dil mein pyaar',
      'Chaand',
      'Baarish',
      'Aag',
      'Aankhon',
    ]);
    expect(profile.lines.values.map((line) => line.objects.single), [
      BackgroundObjectKind.heart,
      BackgroundObjectKind.moon,
      BackgroundObjectKind.rain,
      BackgroundObjectKind.flame,
      BackgroundObjectKind.eye,
      BackgroundObjectKind.smoke,
      BackgroundObjectKind.heart,
      BackgroundObjectKind.moon,
      BackgroundObjectKind.rain,
      BackgroundObjectKind.flame,
      BackgroundObjectKind.eye,
      BackgroundObjectKind.heart,
      BackgroundObjectKind.moon,
      BackgroundObjectKind.rain,
      BackgroundObjectKind.flame,
      BackgroundObjectKind.eye,
    ]);
    expect(fallback(['diluted sunlight rainfall']).lines[0]!.objects, isEmpty);
  });
}
