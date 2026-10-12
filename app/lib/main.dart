import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app/kinetic_lyrics_controller.dart';
import 'audio/audio_analyzer.dart';
import 'lyrics/data/json_http_client.dart';
import 'lyrics/data/lrclib_provider.dart';
import 'lyrics/data/lyrics_ovh_provider.dart';
import 'lyrics/data/lyrics_repository.dart';
import 'now_playing/now_playing_detector.dart';
import 'ui/player_screen.dart';
import 'semantics/on_device_semantic_analyzer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const KineticLyricsApp());
}

class AppComposition {
  static KineticLyricsController createController() {
    final lyrics = LyricsRepository(
      providers: [
        LrcLibProvider(client: DartJsonHttpClient()),
        LyricsOvhProvider(client: DartJsonHttpClient()),
      ],
    );
    return KineticLyricsController(
      nowPlaying: NowPlayingDetector.forCurrentPlatform(),
      lyrics: lyrics,
      audio: PlatformAudioAnalyzer(),
      semanticAnalyzer:
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? OnDeviceE5SemanticAnalyzer()
          : null,
    );
  }
}

class KineticLyricsApp extends StatelessWidget {
  const KineticLyricsApp({super.key, this.controller});

  final KineticLyricsController? controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Kinetic Lyrics',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffef6262),
        brightness: Brightness.dark,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(44, 48)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(44, 48)),
      ),
    ),
    home: _AppShell(controller: controller),
  );
}

class _AppShell extends StatefulWidget {
  const _AppShell({this.controller});

  final KineticLyricsController? controller;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  late final KineticLyricsController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? AppComposition.createController();
    _controller.initialize();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PlayerScreen(controller: _controller);
}
