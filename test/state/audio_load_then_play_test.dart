import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/data/lyrics/danger_zones.dart';
import 'package:swiftie_quiz/domain/engine/clip_selector.dart';
import 'package:swiftie_quiz/domain/engine/relisten_schedule.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/services/audio/audio_engine.dart';
import 'package:swiftie_quiz/services/audio/preview_downloader.dart';
import 'package:swiftie_quiz/state/audio_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';

const String _enchantedUrl =
    'https://cdnt-preview.dzcdn.net/api/1/1/e/n/enchanted.mp3';
const String _mineUrl = 'https://cdns-preview-d.dzcdn.net/stream/c-mine.mp3';
const String _brokenUrl = 'https://cdns-preview-d.dzcdn.net/stream/broken.mp3';
const Artist _taylor = Artist(id: 12246, name: 'Taylor Swift');
const Album _speakNow = Album(
  id: 10,
  title: "Speak Now (Taylor's Version)",
  coverMedium: null,
);
const Track _enchanted = Track(
  id: 1,
  title: "Enchanted (Taylor's Version)",
  titleShort: 'Enchanted',
  duration: 319,
  preview: _enchantedUrl,
  artist: _taylor,
  album: _speakNow,
);
const Track _mine = Track(
  id: 2,
  title: "Mine (Taylor's Version)",
  titleShort: 'Mine',
  duration: 231,
  preview: _mineUrl,
  artist: _taylor,
  album: _speakNow,
);
const Track _broken = Track(
  id: 3,
  title: "Sparks Fly (Taylor's Version)",
  titleShort: 'Sparks Fly',
  duration: 260,
  preview: _brokenUrl,
  artist: _taylor,
  album: _speakNow,
);
const double _clipLength = 30;
const int _sampleRate = 8000;

final Uint8List _enchantedBytes = Uint8List.fromList([1, 2, 3]);
final Uint8List _mineBytes = Uint8List.fromList([4, 5, 6]);

ClipAudio _quietMiddle(double durationSeconds) => ClipAudio(
  Float32List.fromList(
    List<double>.generate(
      (durationSeconds * _sampleRate).ceil(),
      (index) =>
          index >= 5 * _sampleRate && index < 25 * _sampleRate ? 0.1 : 0.5,
    ),
  ),
  _sampleRate,
  durationSeconds,
);

final class _FakeClip implements LoadedClip {
  _FakeClip(this.bytes);

  final Uint8List bytes;
  int sampleReads = 0;

  @override
  double get durationSeconds => _clipLength;

  @override
  Future<ClipAudio> readSamples() async {
    sampleReads += 1;
    return _quietMiddle(durationSeconds);
  }
}

typedef _Slice = ({LoadedClip clip, double offset, double duration});

final class _FakeEngine implements AudioEngine {
  List<_FakeClip> loaded = const [];
  List<_Slice> slices = const [];
  int _nextVoice = 1;

  @override
  Future<void> init() async {}

  @override
  Future<LoadedClip> loadClip(Uint8List mp3Bytes) async {
    final clip = _FakeClip(mp3Bytes);
    loaded = [...loaded, clip];
    return clip;
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
    slices = [
      ...slices,
      (clip: clip, offset: offsetSeconds, duration: durationSeconds),
    ];
    _nextVoice += 1;
    return AudioVoice(_nextVoice);
  }

  @override
  void pause(AudioVoice voice) {}

  @override
  void resume(AudioVoice voice) {}

  @override
  Future<void> stop(AudioVoice voice) async {}

  @override
  double? positionOf(AudioVoice voice) => 0;

  @override
  void setVolume(AudioVoice voice, double volume) {}

  @override
  Future<void> playQuack(double volume) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> shutdown() async {}
}

final class _FakeDangerZones implements DangerZoneService {
  List<String> calls = const [];

  @override
  Future<List<DangerZone>> fetchDangerZones(
    String trackTitle,
    String artistName,
    String titleShort,
    num songDurationSeconds,
  ) async {
    calls = [...calls, trackTitle];
    return const [];
  }

  @override
  void clearDangerZoneCache() {}
}

void main() {
  test(
    'a loaded clip plays from a given start and play still picks its own',
    () {
      fakeAsync((async) {
        final engine = _FakeEngine();
        final dangerZones = _FakeDangerZones();
        final container = ProviderContainer.test(
          overrides: [
            appVersionProvider.overrideWithValue(const AsyncData('0.3.0')),
            clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 7)),
            randomProvider.overrideWithValue(Random(7)),
            audioEngineProvider.overrideWithValue(engine),
            dangerZoneServiceProvider.overrideWithValue(AsyncData(dangerZones)),
            httpClientProvider.overrideWithValue(
              MockClient(
                (request) async => switch ('${request.url}') {
                  _enchantedUrl => http.Response.bytes(_enchantedBytes, 200),
                  _mineUrl => http.Response.bytes(_mineBytes, 200),
                  _ => http.Response('', 500),
                },
              ),
            ),
          ],
        )..listen(audioControllerProvider, (_, _) {});
        final audio = container.read(audioControllerProvider.notifier);
        AudioState state() => container.read(audioControllerProvider);
        final smartStart = selectClipStartWithFallback(
          _quietMiddle(_clipLength),
          const [],
        );

        bool? loaded;
        unawaited(audio.load(_enchanted).then((value) => loaded = value));
        expect(state().loading, isTrue);
        async.flushMicrotasks();
        expect(loaded, isTrue);
        expect(state().loading, isFalse);
        expect(engine.loaded.single.bytes, _enchantedBytes);
        expect(engine.slices, isEmpty);

        audio.playLoaded(12.5);
        expect(engine.slices.single.offset, 12.5);
        expect(engine.slices.single.duration, sliceDurationSeconds);
        expect(engine.slices.single.clip, engine.loaded.single);
        expect(engine.loaded.single.sampleReads, 0);
        expect(dangerZones.calls, isEmpty);
        expect(state().playing, isTrue);

        audio.relisten();
        expect(
          engine.slices.last.offset,
          getRelistenSlice(1, 12.5, _clipLength).offset,
        );

        double? prepared = -1;
        unawaited(audio.prepare(_mine).then((value) => prepared = value));
        async.flushMicrotasks();
        expect(prepared, smartStart);
        expect(dangerZones.calls, [_mine.title]);
        expect(engine.loaded.last.bytes, _mineBytes);
        expect(engine.loaded.last.sampleReads, 1);
        expect(engine.slices, hasLength(2));
        expect(state().playing, isFalse);
        expect(state().loading, isFalse);

        unawaited(audio.load(_broken).then((value) => loaded = value));
        async
          ..flushMicrotasks()
          ..elapse(PreviewDownloader.retryDelay);
        expect(loaded, isFalse);
        expect(state().error, isNotNull);
        unawaited(audio.prepare(_broken).then((value) => prepared = value));
        async
          ..flushMicrotasks()
          ..elapse(PreviewDownloader.retryDelay);
        expect(prepared, isNull);
        expect(engine.slices, hasLength(2));

        unawaited(audio.play(_enchanted));
        async.flushMicrotasks();
        expect(engine.slices, hasLength(3));
        expect(engine.slices.last.offset, smartStart);
        expect(smartStart, isNot(12.5));
        expect(engine.loaded.last.sampleReads, 1);
        expect(dangerZones.calls, [
          _mine.title,
          _broken.title,
          _enchanted.title,
        ]);
        expect(state().playing, isTrue);
        expect(state().error, isNull);
      });
    },
  );
}
