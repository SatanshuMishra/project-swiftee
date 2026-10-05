import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/data/lyrics/danger_zones.dart';
import 'package:swiftie_quiz/domain/engine/clip_selector.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/services/audio/audio_engine.dart';
import 'package:swiftie_quiz/state/audio_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/ui/cat/cat_loader.dart';
import 'package:swiftie_quiz/ui/game/audio_player.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/app_icon.dart';

const Track _enchanted = Track(
  id: 1,
  title: "Enchanted (Taylor's Version)",
  titleShort: 'Enchanted',
  duration: 319,
  preview: 'https://cdnt-preview.dzcdn.net/api/1/1/e/n/enchanted.mp3',
  artist: Artist(id: 12246, name: 'Taylor Swift'),
  album: Album(id: 10, title: 'Speak Now', coverMedium: null),
);
const Track _mine = Track(
  id: 2,
  title: "Mine (Taylor's Version)",
  titleShort: 'Mine',
  duration: 231,
  preview: 'https://cdnt-preview.dzcdn.net/api/1/1/m/i/mine.mp3',
  artist: Artist(id: 12246, name: 'Taylor Swift'),
  album: Album(id: 10, title: 'Speak Now', coverMedium: null),
);
const double _clipLength = 30;
const int _sampleRate = 8000;

final class _FakeClip implements LoadedClip {
  _FakeClip(this.durationSeconds);

  @override
  final double durationSeconds;

  @override
  Future<ClipAudio> readSamples() async => ClipAudio(
    Float32List((durationSeconds * _sampleRate).ceil())
      ..fillRange(0, (durationSeconds * _sampleRate).ceil(), 0.5),
    _sampleRate,
    durationSeconds,
  );
}

typedef _Slice = ({AudioVoice voice, double offset, double duration});

final class _FakeEngine implements AudioEngine {
  List<Completer<void>> decodeGates = const [];
  int decodes = 0;
  List<_Slice> slices = const [];
  List<AudioVoice> paused = const [];
  List<AudioVoice> resumed = const [];
  List<AudioVoice> stopped = const [];
  Map<AudioVoice, double?> _positions = const {};
  int _nextVoice = 1;

  _Slice get lastSlice => slices.last;

  void moveTo(AudioVoice voice, double position) =>
      _positions = {..._positions, voice: position};

  @override
  Future<void> init() async {}

  @override
  Future<LoadedClip> loadClip(Uint8List mp3Bytes) async {
    final decode = decodes;
    decodes += 1;
    if (decode < decodeGates.length) {
      await decodeGates[decode].future;
    }
    return _FakeClip(_clipLength);
  }

  @override
  Future<void> unloadClip(LoadedClip clip) async {}

  @override
  AudioVoice playSlice(
    LoadedClip clip,
    double offsetSeconds,
    double durationSeconds,
    double volume,
  ) {
    final voice = AudioVoice(_nextVoice);
    _nextVoice += 1;
    slices = [
      ...slices,
      (voice: voice, offset: offsetSeconds, duration: durationSeconds),
    ];
    moveTo(voice, offsetSeconds);
    return voice;
  }

  @override
  void pause(AudioVoice voice) => paused = [...paused, voice];

  @override
  void resume(AudioVoice voice) => resumed = [...resumed, voice];

  @override
  Future<void> stop(AudioVoice voice) async {
    stopped = [...stopped, voice];
    _positions = {..._positions, voice: null};
  }

  @override
  double? positionOf(AudioVoice voice) => _positions[voice];

  @override
  void setVolume(AudioVoice voice, double volume) {}

  @override
  Future<void> playQuack(double volume) async {}

  @override
  Future<void> dispose() async {}
}

final class _NoDangerZones implements DangerZoneService {
  @override
  Future<List<DangerZone>> fetchDangerZones(
    String trackTitle,
    String artistName,
    String titleShort,
    num songDurationSeconds,
  ) async => const [];

  @override
  void clearDangerZoneCache() {}
}

final class _Harness {
  _Harness(WidgetTester tester) : engine = _FakeEngine() {
    overrides = [
      appVersionProvider.overrideWithValue(const AsyncData('0.3.0')),
      clockProvider.overrideWithValue(() => tester.binding.clock.now()),
      randomProvider.overrideWithValue(Random(7)),
      audioEngineProvider.overrideWithValue(engine),
      dangerZoneServiceProvider.overrideWithValue(AsyncData(_NoDangerZones())),
      httpClientProvider.overrideWithValue(
        MockClient((request) async {
          previewRequests = [...previewRequests, request.url];
          return request.url.host == 'cdnt-preview.dzcdn.net'
              ? http.Response.bytes([1, 2, 3], 200)
              : http.Response('', 404);
        }),
      ),
    ];
  }

  final _FakeEngine engine;
  late final List<Override> overrides;
  List<Uri> previewRequests = const [];
  int loaded = 0;

  Widget host(Widget child) => ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Center(child: SizedBox(width: 512, child: child)),
      ),
    ),
  );

  Widget player({Track track = _enchanted, bool active = true}) => host(
    AudioPlayer(track: track, active: active, onLoaded: () => loaded += 1),
  );

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold)));

  AudioState audio(WidgetTester tester) =>
      container(tester).read(audioControllerProvider);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

Finder _icon(LucideGlyph glyph) => find.byWidgetPredicate(
  (widget) => widget is AppIcon && widget.glyph == glyph,
);

BoxDecoration _buttonFace(WidgetTester tester, LucideGlyph glyph) =>
    tester
            .widget<Container>(
              find
                  .ancestor(of: _icon(glyph), matching: find.byType(Container))
                  .first,
            )
            .decoration!
        as BoxDecoration;

Future<void> _finishSlice(WidgetTester tester, _FakeEngine engine) async {
  final slice = engine.lastSlice;
  engine.moveTo(slice.voice, slice.offset + slice.duration);
  await tester.pump(progressPollInterval);
}

void main() {
  group('audio player parity', () {
    testWidgets('shows the heading, subheading and a gradient play state', (
      tester,
    ) async {
      final harness = _Harness(tester);
      await tester.pumpWidget(harness.player(active: false));
      await _settle(tester);

      expect(find.text('Name That Song!'), findsOneWidget);
      expect(find.text('Listen carefully and guess the track'), findsOneWidget);
      expect(_icon(LucideGlyph.play), findsOneWidget);
      expect(_buttonFace(tester, LucideGlyph.play).gradient, isNotNull);
      expect(
        tester.widget<AppIcon>(_icon(LucideGlyph.play)).color,
        AppPalette.white,
      );
      expect(harness.engine.slices, isEmpty);
      expect(find.textContaining(' / '), findsNothing);
    });

    testWidgets('auto-plays when active and reports onLoaded', (tester) async {
      final harness = _Harness(tester);
      await tester.pumpWidget(harness.player());
      await _settle(tester);

      expect(harness.engine.slices, hasLength(1));
      expect(harness.engine.lastSlice.duration, sliceDurationSeconds);
      expect(harness.loaded, 1);
      expect(harness.audio(tester).playing, isTrue);
      expect(_icon(LucideGlyph.pause), findsOneWidget);
      expect(_buttonFace(tester, LucideGlyph.pause).gradient, isNotNull);
      expect(find.text('0s / 10s'), findsOneWidget);
    });

    testWidgets(
      'shows the small cat loader in its 80 x 80 slot while loading',
      (tester) async {
        final harness = _Harness(tester);
        final decode = Completer<void>();
        harness.engine.decodeGates = [decode];
        await tester.pumpWidget(harness.player());
        await _settle(tester);

        final loader = tester.widget<CatLoader>(find.byType(CatLoader));
        expect(loader.size, CatLoaderSize.sm);
        expect(tester.getSize(find.byType(CatLoader)), const Size(80, 80));
        expect(_icon(LucideGlyph.play), findsNothing);
        expect(_icon(LucideGlyph.pause), findsNothing);
        expect(harness.loaded, 0);

        decode.complete();
        await _settle(tester);

        expect(find.byType(CatLoader), findsNothing);
        expect(_icon(LucideGlyph.pause), findsOneWidget);
        expect(harness.loaded, 1);
      },
    );

    testWidgets('tapping while playing pauses and tapping again resumes', (
      tester,
    ) async {
      final harness = _Harness(tester);
      await tester.pumpWidget(harness.player());
      await _settle(tester);
      final voice = harness.engine.lastSlice.voice;

      await tester.tap(_icon(LucideGlyph.pause));
      await tester.pump();

      expect(harness.engine.paused, [voice]);
      expect(harness.audio(tester).paused, isTrue);
      expect(_icon(LucideGlyph.play), findsOneWidget);
      final pausedFace = _buttonFace(tester, LucideGlyph.play);
      expect(pausedFace.gradient, isNull);
      expect(
        pausedFace.border,
        Border.all(
          color: AppPalette.purple500.withValues(alpha: 0.5),
          width: 2,
        ),
      );
      expect(
        tester.widget<AppIcon>(_icon(LucideGlyph.play)).color,
        AppPalette.purple400,
      );

      await tester.tap(_icon(LucideGlyph.play));
      await tester.pump();

      expect(harness.engine.resumed, [voice]);
      expect(harness.audio(tester).playing, isTrue);
      expect(_icon(LucideGlyph.pause), findsOneWidget);
    });

    testWidgets('progress text shows whole elapsed and clip seconds', (
      tester,
    ) async {
      final harness = _Harness(tester);
      await tester.pumpWidget(harness.player());
      await _settle(tester);
      final slice = harness.engine.lastSlice;

      harness.engine.moveTo(slice.voice, slice.offset + 3.4);
      await tester.pump(progressPollInterval);

      expect(find.text('3s / 10s'), findsOneWidget);
      expect(harness.audio(tester).progress, closeTo(0.34, 1e-9));
    });

    testWidgets('tapping after the clip ends relistens', (tester) async {
      final harness = _Harness(tester);
      await tester.pumpWidget(harness.player());
      await _settle(tester);
      await _finishSlice(tester, harness.engine);

      expect(harness.audio(tester).playing, isFalse);
      expect(_buttonFace(tester, LucideGlyph.play).gradient, isNull);

      await tester.tap(_icon(LucideGlyph.play));
      await tester.pump();

      expect(harness.engine.slices, hasLength(2));
      expect(harness.engine.lastSlice.duration, 10);
      expect(
        harness.container(tester).read(gameControllerProvider).relistenCount,
        1,
      );
      expect(harness.loaded, 1);
    });

    testWidgets('the extension notice appears from the third relisten', (
      tester,
    ) async {
      final harness = _Harness(tester);
      await tester.pumpWidget(harness.player());
      await _settle(tester);

      for (var relisten = 1; relisten <= 3; relisten++) {
        expect(
          find.text('Clip extended to help with your guess'),
          findsNothing,
        );
        await _finishSlice(tester, harness.engine);
        await tester.tap(_icon(LucideGlyph.play));
        await tester.pump();
      }

      expect(harness.engine.slices.map((slice) => slice.duration), [
        10,
        10,
        10,
        15,
      ]);
      final notice = tester.widget<Text>(
        find.text('Clip extended to help with your guess'),
      );
      expect(notice.style!.fontSize, 12);
      expect(
        notice.style!.color,
        AppTokens.dark.mutedForeground.withValues(alpha: 0.7),
      );
    });

    testWidgets('an inactive player stays silent and going inactive resets', (
      tester,
    ) async {
      final harness = _Harness(tester);
      await tester.pumpWidget(harness.player(active: false));
      await _settle(tester);
      expect(harness.engine.slices, isEmpty);

      await tester.pumpWidget(harness.player());
      await _settle(tester);
      final voice = harness.engine.lastSlice.voice;
      expect(harness.audio(tester).playing, isTrue);

      await tester.pumpWidget(harness.player(active: false));
      await _settle(tester);

      expect(harness.engine.stopped, contains(voice));
      expect(harness.audio(tester), AudioState.idle);
      expect(_icon(LucideGlyph.play), findsOneWidget);
    });

    testWidgets('a new track plays the new preview', (tester) async {
      final harness = _Harness(tester);
      await tester.pumpWidget(harness.player());
      await _settle(tester);

      await tester.pumpWidget(harness.player(track: _mine));
      await _settle(tester);

      expect(harness.previewRequests.map((url) => url.toString()), [
        _enchanted.preview,
        _mine.preview,
      ]);
      expect(harness.engine.slices, hasLength(2));
      expect(harness.loaded, 2);
    });

    testWidgets('leaving the screen stops playback', (tester) async {
      final harness = _Harness(tester);
      await tester.pumpWidget(harness.player());
      await _settle(tester);
      final voice = harness.engine.lastSlice.voice;

      await tester.pumpWidget(harness.host(const SizedBox()));
      await _settle(tester);

      expect(harness.engine.stopped, contains(voice));
      expect(harness.audio(tester).playing, isFalse);
    });
  });
}
