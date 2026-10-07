import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swiftie_quiz/data/lyrics/danger_zones.dart';
import 'package:swiftie_quiz/domain/engine/clip_selector.dart';
import 'package:swiftie_quiz/domain/models/lyrics.dart';
import 'package:swiftie_quiz/domain/models/track.dart';
import 'package:swiftie_quiz/services/audio/audio_engine.dart';
import 'package:swiftie_quiz/services/audio/preview_downloader.dart';
import 'package:swiftie_quiz/state/audio_controller.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';

const String _userAgent =
    'SwiftieQuiz/0.3.0 (+https://github.com/SatanshuMishra/project-swiftee)';
const String _previewUrl =
    'https://cdnt-preview.dzcdn.net/api/1/1/e/n/enchanted.mp3?hdnea=exp=1791200000~acl=x';
const String _freshPreviewUrl =
    'https://cdnt-preview.dzcdn.net/api/1/1/e/n/enchanted.mp3?hdnea=exp=1791300000~acl=x';
const String _otherPreviewUrl =
    'https://cdns-preview-d.dzcdn.net/stream/c-mine.mp3';
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
  preview: _previewUrl,
  artist: _taylor,
  album: _speakNow,
);
const Track _mine = Track(
  id: 2,
  title: "Mine (Taylor's Version)",
  titleShort: 'Mine',
  duration: 231,
  preview: _otherPreviewUrl,
  artist: _taylor,
  album: _speakNow,
);
const double _clipLength = 30;
const int _sampleRate = 8000;
const int _randomSeed = 7;

final Uint8List _previewBytes = Uint8List.fromList([1, 2, 3]);
final Uint8List _freshPreviewBytes = Uint8List.fromList([4, 5, 6]);
final Uint8List _otherPreviewBytes = Uint8List.fromList([7, 8, 9]);
final DateTime _now = DateTime.utc(2026, 10, 5, 12);

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

http.Response _bytes(Uint8List body, [int status = 200]) =>
    http.Response.bytes(body, status);

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object?> _trackJson(Track track, String preview) => {
  'id': track.id,
  'title': track.title,
  'title_short': track.titleShort,
  'title_version': '',
  'duration': track.duration,
  'preview': preview,
  'artist': {'id': track.artist.id, 'name': track.artist.name},
  'album': {
    'id': track.album.id,
    'title': track.album.title,
    'cover_medium': track.album.coverMedium,
  },
};

final class _FakeClip implements LoadedClip {
  _FakeClip(this.bytes, this.durationSeconds);

  final Uint8List bytes;
  int sampleReads = 0;

  @override
  final double durationSeconds;

  @override
  Future<ClipAudio> readSamples() async {
    sampleReads += 1;
    return _quietMiddle(durationSeconds);
  }
}

typedef _Slice = ({
  AudioVoice voice,
  LoadedClip clip,
  double offset,
  double duration,
  double volume,
});

final class _FakeEngine implements AudioEngine {
  List<Uint8List> loaded = const [];
  List<LoadedClip> unloaded = const [];
  List<_Slice> slices = const [];
  List<AudioVoice> paused = const [];
  List<AudioVoice> resumed = const [];
  List<AudioVoice> stopped = const [];
  List<({AudioVoice voice, double volume})> volumes = const [];
  List<double> quacks = const [];
  List<Completer<void>> decodeGates = const [];
  Map<AudioVoice, double?> _positions = const {};
  int _nextVoice = 1;

  AudioVoice get lastVoice => slices.last.voice;

  void moveTo(AudioVoice voice, double position) =>
      _positions = {..._positions, voice: position};

  void end(AudioVoice voice) => _positions = {..._positions, voice: null};

  @override
  Future<void> init() async {}

  @override
  Future<LoadedClip> loadClip(Uint8List mp3Bytes) async {
    final decode = loaded.length;
    loaded = [...loaded, mp3Bytes];
    if (decode < decodeGates.length) {
      await decodeGates[decode].future;
    }
    return _FakeClip(mp3Bytes, _clipLength);
  }

  @override
  Future<void> unloadClip(LoadedClip clip) async {
    unloaded = [...unloaded, clip];
  }

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
      (
        voice: voice,
        clip: clip,
        offset: offsetSeconds,
        duration: durationSeconds,
        volume: volume,
      ),
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
    end(voice);
  }

  @override
  double? positionOf(AudioVoice voice) => _positions[voice];

  @override
  void setVolume(AudioVoice voice, double volume) =>
      volumes = [...volumes, (voice: voice, volume: volume)];

  @override
  Future<void> playQuack(double volume) async {
    quacks = [...quacks, volume];
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> shutdown() async {}
}

typedef _DangerZoneCall = ({
  String trackTitle,
  String artistName,
  String titleShort,
  num songDurationSeconds,
});

final class _FakeDangerZones implements DangerZoneService {
  _FakeDangerZones(this.zones);

  final List<DangerZone> zones;
  List<_DangerZoneCall> calls = const [];

  @override
  Future<List<DangerZone>> fetchDangerZones(
    String trackTitle,
    String artistName,
    String titleShort,
    num songDurationSeconds,
  ) async {
    calls = [
      ...calls,
      (
        trackTitle: trackTitle,
        artistName: artistName,
        titleShort: titleShort,
        songDurationSeconds: songDurationSeconds,
      ),
    ];
    return zones;
  }

  @override
  void clearDangerZoneCache() {}
}

final class _Harness {
  _Harness({List<DangerZone> zones = const []})
    : engine = _FakeEngine(),
      dangerZones = _FakeDangerZones(zones) {
    container = ProviderContainer.test(
      overrides: [
        appVersionProvider.overrideWithValue(const AsyncData('0.3.0')),
        clockProvider.overrideWithValue(() => _now),
        randomProvider.overrideWithValue(Random(_randomSeed)),
        audioEngineProvider.overrideWithValue(engine),
        dangerZoneServiceProvider.overrideWithValue(AsyncData(dangerZones)),
        httpClientProvider.overrideWithValue(
          MockClient((request) {
            requests = [...requests, request];
            return respond(request);
          }),
        ),
      ],
    );
    container.listen(audioControllerProvider, (_, _) {});
  }

  final _FakeEngine engine;
  final _FakeDangerZones dangerZones;
  late final ProviderContainer container;
  List<http.Request> requests = const [];
  Future<http.Response> Function(http.Request request) respond =
      (request) async => switch ('${request.url}') {
        _previewUrl => _bytes(_previewBytes),
        _freshPreviewUrl => _bytes(_freshPreviewBytes),
        _otherPreviewUrl => _bytes(_otherPreviewBytes),
        _ => _json({'error': 'unexpected'}, 404),
      };

  AudioController get audio => container.read(audioControllerProvider.notifier);

  AudioState get state => container.read(audioControllerProvider);

  GameController get game => container.read(gameControllerProvider.notifier);

  List<String> get requestedUrls => [
    for (final request in requests) '${request.url}',
  ];
}

void main() {
  group('audio controller parity', () {
    test('starts in idle state', () {
      final harness = _Harness();

      expect(harness.state.playing, isFalse);
      expect(harness.state.paused, isFalse);
      expect(harness.state.loading, isFalse);
      expect(harness.state.progress, 0);
      expect(harness.state.clipDuration, 0);
      expect(harness.state.relistenStage, 0);
      expect(harness.state.error, isNull);
    });

    test(
      'exposes play, relisten, pause, resume, stop, reset and playQuack',
      () {
        final audio = _Harness().audio;

        expect(audio.play, isA<Future<void> Function(Track)>());
        expect(audio.relisten, isA<void Function()>());
        expect(audio.pause, isA<void Function()>());
        expect(audio.resume, isA<void Function()>());
        expect(audio.stop, isA<void Function()>());
        expect(audio.reset, isA<void Function()>());
        expect(audio.playQuack, isA<void Function()>());
      },
    );

    test('stop clears all playback state', () {
      final harness = _Harness();

      harness.audio.stop();

      expect(harness.state.playing, isFalse);
      expect(harness.state.paused, isFalse);
      expect(harness.state.progress, 0);
      expect(harness.state.clipDuration, 0);
    });

    test('reset clears all state and increments version', () {
      fakeAsync((async) {
        final harness = _Harness();
        final download = Completer<http.Response>();
        harness.respond = (request) => download.future;

        unawaited(harness.audio.play(_enchanted));
        async.flushMicrotasks();
        harness.audio.reset();
        download.complete(_bytes(_previewBytes));
        async.flushMicrotasks();

        expect(harness.state.playing, isFalse);
        expect(harness.state.paused, isFalse);
        expect(harness.state.loading, isFalse);
        expect(harness.state.progress, 0);
        expect(harness.state.clipDuration, 0);
        expect(harness.engine.loaded, isEmpty);
        expect(harness.engine.slices, isEmpty);
      });
    });

    test('pause is a no-op when not playing', () {
      final harness = _Harness();

      harness.audio.pause();

      expect(harness.state.playing, isFalse);
      expect(harness.state.paused, isFalse);
      expect(harness.engine.paused, isEmpty);
    });

    test('resume is a no-op when not paused', () {
      final harness = _Harness();

      harness.audio.resume();

      expect(harness.state.playing, isFalse);
      expect(harness.state.paused, isFalse);
      expect(harness.engine.resumed, isEmpty);
    });

    test('play sets loading to true then false (without trackInfo)', () {
      fakeAsync((async) {
        final harness = _Harness();
        final download = Completer<http.Response>();
        harness.respond = (request) => download.future;

        unawaited(harness.audio.play(_enchanted, smartClip: false));
        async.flushMicrotasks();

        expect(harness.state.loading, isTrue);

        download.complete(_bytes(_previewBytes));
        async.flushMicrotasks();

        expect(harness.state.loading, isFalse);
        expect(harness.engine.loaded, [_previewBytes]);
      });
    });

    test('play stops previous playback before fetching', () {
      fakeAsync((async) {
        final harness = _Harness();

        unawaited(harness.audio.play(_enchanted));
        async.flushMicrotasks();
        final first = harness.engine.lastVoice;
        unawaited(harness.audio.play(_mine));

        expect(harness.engine.stopped, [first]);
        expect(harness.requestedUrls, [_previewUrl]);

        async.flushMicrotasks();

        expect(harness.requestedUrls, [_previewUrl, _otherPreviewUrl]);
        expect(harness.engine.slices, hasLength(2));
      });
    });

    test('play with trackInfo uses smart clip selection', () {
      fakeAsync((async) {
        final harness = _Harness();

        unawaited(harness.audio.play(_enchanted));
        async.flushMicrotasks();

        expect(harness.dangerZones.calls, [
          (
            trackTitle: _enchanted.title,
            artistName: _enchanted.artist.name,
            titleShort: _enchanted.titleShort,
            songDurationSeconds: _enchanted.duration,
          ),
        ]);
        final slice = harness.engine.slices.single;
        expect(
          slice.offset,
          selectClipStartWithFallback(_quietMiddle(_clipLength), const []),
        );
        expect(slice.offset, 10);
        expect(slice.duration, 10);
        expect((slice.clip as _FakeClip).sampleReads, 1);
      });
    });

    test('smart clip selection steers clear of danger zones', () {
      fakeAsync((async) {
        const zones = [DangerZone(start: 9.5, end: 12.5)];
        final harness = _Harness(zones: zones);

        unawaited(harness.audio.play(_enchanted));
        async.flushMicrotasks();

        final expected = selectClipStartWithFallback(
          _quietMiddle(_clipLength),
          zones,
        );
        expect(harness.engine.slices.single.offset, expected);
        expect(expected, isNot(10));
      });
    });

    test('play without trackInfo does not call fetchDangerZones', () {
      fakeAsync((async) {
        final harness = _Harness();

        unawaited(harness.audio.play(_enchanted, smartClip: false));
        async.flushMicrotasks();

        expect(harness.dangerZones.calls, isEmpty);
        final slice = harness.engine.slices.single;
        expect((slice.clip as _FakeClip).sampleReads, 0);
        expect(
          slice.offset,
          Random(_randomSeed).nextDouble() * (_clipLength - 10),
        );
        expect(slice.duration, 10);
      });
    });

    test('pause during playback sets paused=true and playing=false', () {
      fakeAsync((async) {
        final harness = _Harness();

        unawaited(harness.audio.play(_enchanted));
        async.flushMicrotasks();

        expect(harness.state.playing, isTrue);
        expect(harness.state.paused, isFalse);

        harness.audio.pause();

        expect(harness.state.playing, isFalse);
        expect(harness.state.paused, isTrue);
        expect(harness.state.clipDuration, 10);
        expect(harness.engine.paused, [harness.engine.lastVoice]);
      });
    });

    test('resume after pause restarts playback from paused position', () {
      fakeAsync((async) {
        final harness = _Harness();

        unawaited(harness.audio.play(_enchanted));
        async.flushMicrotasks();
        final voice = harness.engine.lastVoice;
        harness.engine.moveTo(voice, 14);
        async.elapse(progressPollInterval);

        harness.audio.pause();
        async.elapse(const Duration(seconds: 3));

        expect(harness.state.paused, isTrue);
        expect(harness.state.progress, closeTo(0.4, 1e-9));

        harness.audio.resume();

        expect(harness.state.playing, isTrue);
        expect(harness.state.paused, isFalse);
        expect(harness.engine.resumed, [voice]);
        expect(harness.engine.slices, hasLength(1));

        harness.engine.moveTo(voice, 16);
        async.elapse(progressPollInterval);

        expect(harness.state.progress, closeTo(0.6, 1e-9));
      });
    });

    test('stop clears paused state', () {
      fakeAsync((async) {
        final harness = _Harness();

        unawaited(harness.audio.play(_enchanted));
        async.flushMicrotasks();
        harness.audio.pause();

        expect(harness.state.paused, isTrue);

        harness.audio.stop();

        expect(harness.state.playing, isFalse);
        expect(harness.state.paused, isFalse);
        expect(harness.state.progress, 0);
        expect(harness.state.clipDuration, 0);
        expect(harness.engine.stopped, [harness.engine.lastVoice]);
      });
    });

    test('reset clears paused state and buffer', () {
      fakeAsync((async) {
        final harness = _Harness();

        unawaited(harness.audio.play(_enchanted));
        async.flushMicrotasks();
        final clip = harness.engine.slices.single.clip;
        harness.audio
          ..pause()
          ..reset();

        expect(harness.state.playing, isFalse);
        expect(harness.state.paused, isFalse);
        expect(harness.state.loading, isFalse);
        expect(harness.state.progress, 0);
        expect(harness.state.clipDuration, 0);
        expect(harness.engine.unloaded, [clip]);

        harness.audio.relisten();

        expect(harness.engine.slices, hasLength(1));
        expect(harness.container.read(gameControllerProvider).relistenCount, 0);
      });
    });

    test('downloads the preview with the app User-Agent and plays it', () {
      fakeAsync((async) {
        final harness = _Harness();

        unawaited(harness.audio.play(_enchanted));
        async.flushMicrotasks();

        expect(harness.requests.single.headers['User-Agent'], _userAgent);
        expect(harness.engine.loaded, [_previewBytes]);
        expect(harness.engine.slices.single.volume, 0.8);
        expect(harness.state.playing, isTrue);
        expect(harness.state.loading, isFalse);
        expect(harness.state.clipDuration, 10);
        expect(harness.state.error, isNull);
      });
    });

    test('progress polls every 50 ms until the slice ends', () {
      fakeAsync((async) {
        final harness = _Harness();

        unawaited(harness.audio.play(_enchanted));
        async.flushMicrotasks();
        final voice = harness.engine.lastVoice;
        harness.engine.moveTo(voice, 12.5);
        async.elapse(const Duration(milliseconds: 49));

        expect(harness.state.progress, 0);

        async.elapse(const Duration(milliseconds: 1));

        expect(harness.state.progress, closeTo(0.25, 1e-9));
        expect(harness.state.playing, isTrue);

        harness.engine.end(voice);
        async.elapse(progressPollInterval);

        expect(harness.state.progress, 1);
        expect(harness.state.playing, isFalse);
        expect(async.periodicTimerCount, 0);
      });
    });

    test('ignores the results of a superseded play', () {
      fakeAsync((async) {
        final harness = _Harness();
        final firstDownload = Completer<http.Response>();
        harness.respond = (request) => '${request.url}' == _previewUrl
            ? firstDownload.future
            : Future.value(_bytes(_otherPreviewBytes));

        unawaited(harness.audio.play(_enchanted));
        async.flushMicrotasks();
        unawaited(harness.audio.play(_mine));
        async.flushMicrotasks();
        firstDownload.complete(_bytes(_previewBytes));
        async.flushMicrotasks();

        expect(harness.engine.loaded, [_otherPreviewBytes]);
        expect(
          (harness.engine.slices.single.clip as _FakeClip).bytes,
          _otherPreviewBytes,
        );
        expect(harness.state.playing, isTrue);
        expect(harness.state.loading, isFalse);
      });
    });

    test('a superseded decode is unloaded and loading follows the newest', () {
      fakeAsync((async) {
        final harness = _Harness();
        final firstDecode = Completer<void>();
        harness.engine.decodeGates = [firstDecode];
        final secondDownload = Completer<http.Response>();
        harness.respond = (request) => '${request.url}' == _previewUrl
            ? Future.value(_bytes(_previewBytes))
            : secondDownload.future;

        unawaited(harness.audio.play(_enchanted));
        async.flushMicrotasks();
        unawaited(harness.audio.play(_mine));
        async.flushMicrotasks();
        firstDecode.complete();
        async.flushMicrotasks();

        expect(harness.engine.unloaded, hasLength(1));
        expect(
          (harness.engine.unloaded.single as _FakeClip).bytes,
          _previewBytes,
        );
        expect(harness.engine.slices, isEmpty);
        expect(harness.state.loading, isTrue);

        secondDownload.complete(_bytes(_otherPreviewBytes));
        async.flushMicrotasks();

        expect(
          (harness.engine.slices.single.clip as _FakeClip).bytes,
          _otherPreviewBytes,
        );
        expect(harness.state.loading, isFalse);
      });
    });

    test('relisten follows the relisten schedule', () {
      fakeAsync((async) {
        final harness = _Harness();

        unawaited(harness.audio.play(_enchanted));
        async.flushMicrotasks();

        var expectedStage = 0;
        for (final (offset, duration) in const [
          (10.0, 10.0),
          (10.0, 10.0),
          (10.0, 15.0),
          (10.0, 15.0),
          (10.0, 20.0),
          (10.0, 20.0),
          (0.0, 30.0),
          (0.0, 30.0),
        ]) {
          final previous = harness.engine.lastVoice;
          harness.audio.relisten();
          expectedStage += 1;

          final slice = harness.engine.slices.last;
          expect(slice.offset, offset);
          expect(slice.duration, duration);
          expect(harness.state.clipDuration, duration);
          expect(harness.state.relistenStage, expectedStage);
          expect(
            harness.container.read(gameControllerProvider).relistenCount,
            expectedStage,
          );
          expect(harness.engine.stopped.last, previous);
        }
      });
    });

    test('relisten without a loaded clip does nothing', () {
      final harness = _Harness();

      harness.audio.relisten();

      expect(harness.engine.slices, isEmpty);
      expect(harness.container.read(gameControllerProvider).relistenCount, 0);
      expect(harness.state.relistenStage, 0);
    });

    test('volume comes from progress.settings.volume', () {
      fakeAsync((async) {
        final harness = _Harness();
        final progress = harness.container
            .read(gameControllerProvider)
            .progress;
        harness.game.setProgress(
          progress.copyWith(settings: progress.settings.copyWith(volume: 0.4)),
        );

        unawaited(harness.audio.play(_enchanted));
        async.flushMicrotasks();

        expect(harness.engine.slices.single.volume, 0.4);

        harness.game.setProgress(
          progress.copyWith(settings: progress.settings.copyWith(volume: 0.6)),
        );

        expect(harness.engine.volumes, isEmpty);

        harness.audio
          ..pause()
          ..resume();

        expect(harness.engine.volumes, [
          (voice: harness.engine.lastVoice, volume: 0.6),
        ]);
      });
    });

    test('playQuack passes the raw volume to the engine', () {
      final harness = _Harness();

      harness.audio.playQuack();

      expect(harness.engine.quacks, [0.8]);
    });

    test('the engine plays the quack at min(volume x 0.9, 1)', () {
      expect(quackGain(0.8), closeTo(0.72, 1e-9));
      expect(quackGain(1), closeTo(0.9, 1e-9));
      expect(quackGain(2), 1);
      expect(quackGain(0), 0);
    });

    test('dispose stops playback and frees the clip', () {
      fakeAsync((async) {
        final harness = _Harness();

        unawaited(harness.audio.play(_enchanted));
        async.flushMicrotasks();
        final voice = harness.engine.lastVoice;
        final clip = harness.engine.slices.single.clip;

        harness.container.dispose();

        expect(harness.engine.stopped, [voice]);
        expect(harness.engine.unloaded, [clip]);
        expect(async.periodicTimerCount, 0);
      });
    });
  });

  group('expired preview is refreshed once', () {
    test('403 then refreshTrack then playback of the new link', () {
      fakeAsync((async) {
        final harness = _Harness();
        harness.respond = (request) async => switch ('${request.url}') {
          _previewUrl => _bytes(Uint8List(0), 403),
          'https://api.deezer.com/track/1' => _json(
            _trackJson(_enchanted, _freshPreviewUrl),
          ),
          _freshPreviewUrl => _bytes(_freshPreviewBytes),
          _ => _json({'error': 'unexpected'}, 404),
        };

        unawaited(harness.audio.play(_enchanted));
        async.flushMicrotasks();

        expect(harness.requestedUrls, [
          _previewUrl,
          'https://api.deezer.com/track/1',
          _freshPreviewUrl,
        ]);
        expect(harness.engine.loaded, [_freshPreviewBytes]);
        expect(harness.engine.slices, hasLength(1));
        expect(harness.state.playing, isTrue);
        expect(harness.state.loading, isFalse);
        expect(harness.state.error, isNull);
      });
    });

    test('a catalogue track with no link fetches one before playing', () {
      fakeAsync((async) {
        final harness = _Harness();
        harness.respond = (request) async => switch ('${request.url}') {
          'https://api.deezer.com/track/1' => _json(
            _trackJson(_enchanted, _freshPreviewUrl),
          ),
          _freshPreviewUrl => _bytes(_freshPreviewBytes),
          _ => _json({'error': 'unexpected'}, 404),
        };

        unawaited(harness.audio.play(_enchanted.copyWith(preview: '')));
        async.flushMicrotasks();

        expect(harness.requestedUrls, [
          'https://api.deezer.com/track/1',
          _freshPreviewUrl,
        ]);
        expect(harness.engine.loaded, [_freshPreviewBytes]);
        expect(harness.state.playing, isTrue);
        expect(harness.state.error, isNull);
      });
    });

    test('a song with no preview is marked unavailable, not failed', () {
      fakeAsync((async) {
        final harness = _Harness();
        harness.respond = (request) async => switch ('${request.url}') {
          'https://api.deezer.com/track/1' => _json(_trackJson(_enchanted, '')),
          _ => _json({'error': 'unexpected'}, 404),
        };

        unawaited(harness.audio.play(_enchanted.copyWith(preview: '')));
        async.flushMicrotasks();

        expect(harness.requestedUrls, ['https://api.deezer.com/track/1']);
        expect(harness.state.unavailable, isTrue);
        expect(harness.state.error, isNull);
        expect(harness.state.loading, isFalse);
      });
    });

    test('a song Deezer no longer has is marked unavailable', () {
      fakeAsync((async) {
        final harness = _Harness();
        harness.respond = (request) async => _json({
          'error': {'type': 'DataException', 'message': 'no data', 'code': 800},
        });

        unawaited(harness.audio.play(_enchanted.copyWith(preview: '')));
        async.flushMicrotasks();

        expect(harness.state.unavailable, isTrue);
        expect(harness.state.error, isNull);
      });
    });

    test('a link fetched for this play is not refreshed again on a 403', () {
      fakeAsync((async) {
        final harness = _Harness();
        harness.respond = (request) async => switch ('${request.url}') {
          'https://api.deezer.com/track/1' => _json(
            _trackJson(_enchanted, _freshPreviewUrl),
          ),
          _ => _bytes(Uint8List(0), 403),
        };

        unawaited(harness.audio.play(_enchanted.copyWith(preview: '')));
        async.flushMicrotasks();

        expect(harness.requestedUrls, [
          'https://api.deezer.com/track/1',
          _freshPreviewUrl,
        ]);
        expect(harness.state.error, 'Preview download failed: HTTP 403');
      });
    });

    test('a play replaced before its link is asked for never asks', () {
      fakeAsync((async) {
        final harness = _Harness();
        harness.respond = (request) async => switch ('${request.url}') {
          _previewUrl => _bytes(_previewBytes),
          _ => _json({'error': 'unexpected'}, 404),
        };

        unawaited(harness.audio.play(_enchanted.copyWith(preview: '')));
        unawaited(harness.audio.play(_enchanted));
        async.flushMicrotasks();

        expect(harness.requestedUrls, [_previewUrl]);
        expect(harness.engine.loaded, [_previewBytes]);
      });
    });

    test('a play replaced while its link is fetched downloads nothing', () {
      fakeAsync((async) {
        final harness = _Harness();
        final link = Completer<http.Response>();
        harness.respond = (request) => switch ('${request.url}') {
          'https://api.deezer.com/track/1' => link.future,
          _previewUrl => Future.value(_bytes(_previewBytes)),
          _ => Future.value(_json({'error': 'unexpected'}, 404)),
        };

        unawaited(harness.audio.play(_enchanted.copyWith(preview: '')));
        async.flushMicrotasks();
        unawaited(harness.audio.play(_enchanted));
        async.flushMicrotasks();
        link.complete(_json(_trackJson(_enchanted, _freshPreviewUrl)));
        async.flushMicrotasks();

        expect(harness.requestedUrls, [
          'https://api.deezer.com/track/1',
          _previewUrl,
        ]);
        expect(harness.engine.loaded, [_previewBytes]);
        expect(harness.state.loading, isFalse);
      });
    });

    test(
      'a link fetched ahead of time is used without asking Deezer again',
      () {
        fakeAsync((async) {
          final harness = _Harness();
          harness.respond = (request) async => switch ('${request.url}') {
            'https://api.deezer.com/track/1' => _json(
              _trackJson(_enchanted, _freshPreviewUrl),
            ),
            _freshPreviewUrl => _bytes(_freshPreviewBytes),
            _ => _json({'error': 'unexpected'}, 404),
          };

          unawaited(
            harness.audio.prefetchPreview(_enchanted.copyWith(preview: '')),
          );
          async.flushMicrotasks();
          unawaited(harness.audio.play(_enchanted.copyWith(preview: '')));
          async.flushMicrotasks();

          expect(harness.requestedUrls, [
            'https://api.deezer.com/track/1',
            _freshPreviewUrl,
          ]);
          expect(harness.engine.loaded, [_freshPreviewBytes]);
          expect(harness.state.playing, isTrue);
        });
      },
    );

    test('a second 403 gives the error state without a third request', () {
      fakeAsync((async) {
        final harness = _Harness();
        harness.respond = (request) async => switch ('${request.url}') {
          'https://api.deezer.com/track/1' => _json(
            _trackJson(_enchanted, _freshPreviewUrl),
          ),
          _ => _bytes(Uint8List(0), 403),
        };

        unawaited(harness.audio.play(_enchanted));
        async.flushMicrotasks();

        expect(harness.requestedUrls, [
          _previewUrl,
          'https://api.deezer.com/track/1',
          _freshPreviewUrl,
        ]);
        expect(harness.engine.loaded, isEmpty);
        expect(harness.engine.slices, isEmpty);
        expect(harness.state.playing, isFalse);
        expect(harness.state.loading, isFalse);
        expect(harness.state.error, 'Preview download failed: HTTP 403');
      });
    });

    test('a failure other than 403 is retried once but not refreshed', () {
      fakeAsync((async) {
        final harness = _Harness();
        harness.respond = (request) async => _bytes(Uint8List(0), 500);

        unawaited(harness.audio.play(_enchanted));
        async
          ..flushMicrotasks()
          ..elapse(PreviewDownloader.retryDelay);

        expect(harness.requestedUrls, [_previewUrl, _previewUrl]);
        expect(harness.state.error, 'Preview download failed: HTTP 500');
        expect(harness.state.loading, isFalse);
      });
    });

    test('a quota error while refreshing surfaces the rate-limit message', () {
      fakeAsync((async) {
        final harness = _Harness();
        harness.respond = (request) async => switch ('${request.url}') {
          'https://api.deezer.com/track/1' => _json({
            'error': {
              'type': 'Exception',
              'message': 'Quota limit exceeded',
              'code': 4,
            },
          }),
          _ => _bytes(Uint8List(0), 403),
        };

        unawaited(harness.audio.play(_enchanted));
        async.flushMicrotasks();

        expect(harness.requestedUrls, [
          _previewUrl,
          'https://api.deezer.com/track/1',
        ]);
        expect(
          harness.state.error,
          'Taking a breather — try again in a moment.',
        );
      });
    });

    test('the next play clears the error', () {
      fakeAsync((async) {
        final harness = _Harness();
        harness.respond = (request) async => _bytes(Uint8List(0), 500);

        unawaited(harness.audio.play(_enchanted));
        async
          ..flushMicrotasks()
          ..elapse(PreviewDownloader.retryDelay);

        expect(harness.state.error, isNotNull);

        harness.respond = (request) async => _bytes(_otherPreviewBytes);
        unawaited(harness.audio.play(_mine));

        expect(harness.state.error, isNull);

        async.flushMicrotasks();

        expect(harness.state.playing, isTrue);
      });
    });
  });

  group('shelf preview', () {
    const trackEndpoint = 'https://api.deezer.com/track/1';
    const mineEndpoint = 'https://api.deezer.com/track/2';

    _Harness shelfHarness() {
      final harness = _Harness();
      harness.respond = (request) async => switch ('${request.url}') {
        trackEndpoint => _json(_trackJson(_enchanted, _freshPreviewUrl)),
        mineEndpoint => _json(_trackJson(_mine, _otherPreviewUrl)),
        _freshPreviewUrl => _bytes(_freshPreviewBytes),
        _otherPreviewUrl => _bytes(_otherPreviewBytes),
        _ => _bytes(Uint8List(0), 403),
      };
      final progress = harness.container.read(gameControllerProvider).progress;
      harness.game.setProgress(
        progress.copyWith(settings: progress.settings.copyWith(volume: 0.5)),
      );
      return harness;
    }

    test('a shelf preview plays five seconds at seventy percent volume', () {
      fakeAsync((async) {
        final harness = shelfHarness();

        unawaited(harness.audio.previewSnippet('1'));
        async.elapse(snippetRest);

        expect(harness.requestedUrls, [trackEndpoint, _freshPreviewUrl]);
        expect(harness.engine.loaded, [_freshPreviewBytes]);
        final slice = harness.engine.slices.single;
        expect(slice.offset, 8);
        expect(slice.duration, 5);
        expect(slice.volume, closeTo(0.35, 1e-9));
        expect(harness.state, AudioState.idle);

        async.elapse(const Duration(milliseconds: 4999));

        expect(harness.engine.stopped, isEmpty);

        async.elapse(const Duration(milliseconds: 1));

        expect(harness.engine.stopped, [slice.voice]);
        expect(harness.engine.unloaded, [slice.clip]);

        unawaited(harness.audio.previewSnippet('1'));
        async.elapse(snippetRest);
        final second = harness.engine.slices.last;
        harness.audio.stopSnippet();

        expect(harness.engine.stopped, [slice.voice, second.voice]);
        expect(harness.engine.unloaded, [slice.clip, second.clip]);

        async.elapse(const Duration(seconds: 5));

        expect(harness.engine.stopped, hasLength(2));
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('a new shelf preview replaces the one playing', () {
      fakeAsync((async) {
        final harness = shelfHarness();

        unawaited(harness.audio.previewSnippet('1'));
        async.elapse(snippetRest);
        final first = harness.engine.slices.single;
        unawaited(harness.audio.previewSnippet('2'));
        async.elapse(snippetRest);

        expect(harness.engine.stopped, [first.voice]);
        expect(
          (harness.engine.slices.last.clip as _FakeClip).bytes,
          _otherPreviewBytes,
        );
        expect(harness.engine.slices, hasLength(2));
      });
    });

    test('sweeping across records sends no requests', () {
      fakeAsync((async) {
        final harness = shelfHarness();

        unawaited(harness.audio.previewSnippet('1'));
        async.elapse(snippetRest - const Duration(milliseconds: 1));
        unawaited(harness.audio.previewSnippet('2'));
        async.elapse(snippetRest - const Duration(milliseconds: 1));
        harness.audio.stopSnippet();
        async.elapse(const Duration(seconds: 1));

        expect(harness.requestedUrls, isEmpty);
        expect(harness.engine.slices, isEmpty);
      });
    });

    test('leaving before the preview loads plays nothing', () {
      fakeAsync((async) {
        final harness = shelfHarness();
        final refresh = Completer<http.Response>();
        harness.respond = (request) => refresh.future;

        unawaited(harness.audio.previewSnippet('1'));
        async.elapse(snippetRest);
        harness.audio.stopSnippet();
        refresh.complete(_json(_trackJson(_enchanted, _freshPreviewUrl)));
        async.flushMicrotasks();

        expect(harness.requestedUrls, [trackEndpoint]);
        expect(harness.engine.slices, isEmpty);
      });
    });

    test('a failed shelf preview stays silent', () {
      fakeAsync((async) {
        final harness = shelfHarness();
        harness.respond = (request) async => _bytes(Uint8List(0), 500);

        unawaited(harness.audio.previewSnippet('1'));
        async.elapse(snippetRest);

        expect(harness.requestedUrls, [trackEndpoint]);
        expect(harness.engine.slices, isEmpty);
        expect(harness.state, AudioState.idle);
      });
    });
  });

  group('preview downloader', () {
    late List<http.Request> requests;
    late List<Duration> delays;
    late Future<http.Response> Function(http.Request request) respond;
    late PreviewDownloader downloader;

    setUp(() {
      requests = const [];
      delays = const [];
      respond = (request) async => _bytes(_previewBytes);
      downloader = PreviewDownloader(
        MockClient((request) {
          requests = [...requests, request];
          return respond(request);
        }),
        _userAgent,
        delay: (duration) async => delays = [...delays, duration],
      );
    });

    test('a dropped connection is fetched again once after 500 ms', () async {
      respond = (request) async => requests.length == 1
          ? throw http.ClientException('connection reset', request.url)
          : _bytes(_previewBytes);

      expect(await downloader.download(Uri.parse(_previewUrl)), _previewBytes);
      expect(requests, hasLength(2));
      expect(delays, [PreviewDownloader.retryDelay]);
      expect(PreviewDownloader.retryDelay, const Duration(milliseconds: 500));
    });

    test('a server error is fetched again once, then fails', () async {
      respond = (request) async => _bytes(Uint8List(0), 503);

      await expectLater(
        downloader.download(Uri.parse(_previewUrl)),
        throwsA(const PreviewDownloadFailed(503)),
      );
      expect(requests, hasLength(2));
    });

    test('a refusal or a missing clip is not fetched again', () async {
      for (final status in [403, 404]) {
        requests = const [];
        respond = (request) async => _bytes(Uint8List(0), status);

        await expectLater(
          downloader.download(Uri.parse(_previewUrl)),
          throwsA(isA<PreviewError>()),
        );
        expect(requests, hasLength(1), reason: '$status');
      }
      expect(delays, isEmpty);
    });

    test('returns the bytes and sends the User-Agent', () async {
      expect(await downloader.download(Uri.parse(_previewUrl)), _previewBytes);
      expect(requests.single.headers['User-Agent'], _userAgent);
    });

    test(
      'maps 403 to PreviewForbidden and other statuses to failures',
      () async {
        respond = (request) async => _bytes(Uint8List(0), 403);
        await expectLater(
          downloader.download(Uri.parse(_previewUrl)),
          throwsA(const PreviewForbidden()),
        );

        respond = (request) async => _bytes(Uint8List(0), 404);
        await expectLater(
          downloader.download(Uri.parse(_previewUrl)),
          throwsA(const PreviewDownloadFailed(404)),
        );
      },
    );

    test('gives up after 10 s', () {
      fakeAsync((async) {
        respond = (request) => Completer<http.Response>().future;
        Object? failure;
        downloader
            .download(Uri.parse(_previewUrl))
            .then<void>((_) {}, onError: (Object error) => failure = error);

        async.elapse(const Duration(milliseconds: 9999));
        expect(failure, isNull);

        async.elapse(const Duration(milliseconds: 1));
        expect(failure, const PreviewUnreachable('request timed out'));
        expect(requests, hasLength(1));
        expect(delays, isEmpty);
      });
    });

    test('follows redirects only between Deezer preview hosts', () async {
      const redirected = 'https://cdns-preview-e.dzcdn.net/stream/c-mine.mp3';
      respond = (request) async => switch ('${request.url}') {
        _otherPreviewUrl => http.Response(
          '',
          302,
          headers: const {'location': redirected},
        ),
        redirected => _bytes(_otherPreviewBytes),
        _ => http.Response(
          '',
          307,
          headers: const {'location': 'https://example.com/preview.mp3'},
        ),
      };

      expect(
        await downloader.download(Uri.parse(_otherPreviewUrl)),
        _otherPreviewBytes,
      );
      expect(
        [for (final request in requests) '${request.url}'],
        [_otherPreviewUrl, redirected],
      );
      expect(requests.last.headers['User-Agent'], _userAgent);
      expect(requests.every((request) => !request.followRedirects), isTrue);

      requests = const [];
      await expectLater(
        downloader.download(Uri.parse(_previewUrl)),
        throwsA(const PreviewUnreachable('untrusted preview link')),
      );
      expect([for (final request in requests) '${request.url}'], [_previewUrl]);
    });

    test('stops after five redirects', () async {
      respond = (request) async =>
          http.Response('', 301, headers: {'location': '${request.url}'});

      await expectLater(
        downloader.download(Uri.parse(_previewUrl)),
        throwsA(const PreviewDownloadFailed(301)),
      );
      expect(requests, hasLength(6));
    });

    test('only fetches https links on the Deezer preview hosts', () async {
      for (final link in const [
        'http://cdnt-preview.dzcdn.net/api/1/1/a.mp3',
        'https://cdnt-preview.dzcdn.net:8443/api/1/1/a.mp3',
        'https://user@cdnt-preview.dzcdn.net/api/1/1/a.mp3',
        'https://example.com/preview.mp3',
        'https://cdns-preview-d.dzcdn.net.example.com/a.mp3',
        '',
      ]) {
        await expectLater(
          downloader.download(Uri.parse(link)),
          throwsA(const PreviewUnreachable('untrusted preview link')),
          reason: link,
        );
      }
      expect(requests, isEmpty);
      expect(
        await downloader.download(Uri.parse(_otherPreviewUrl)),
        _previewBytes,
      );
    });
  });
}
