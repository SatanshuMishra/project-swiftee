import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/services/audio/soloud_audio_engine.dart';

final class _FakeSoLoud implements SoLoud {
  _FakeSoLoud({required this.initialized, Future<void>? starting})
    : _starting = starting ?? Future<void>.value();

  final Future<void> _starting;
  bool initialized;
  List<String> calls = const [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = switch (invocation.memberName) {
      #isInitialized => null,
      #init => 'init',
      #deinitAsync => 'deinitAsync',
      final other => throw UnsupportedError('$other was not expected'),
    };
    if (name == null) {
      return initialized;
    }
    calls = [...calls, name];
    return name == 'init'
        ? _starting.then((_) => initialized = true)
        : Future<void>.sync(() => initialized = false);
  }
}

final class _FakeSource implements AudioSource {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} was not expected');
}

final class _PlayingSoLoud implements SoLoud {
  _PlayingSoLoud({required this.failAt});

  final Symbol failAt;
  List<Symbol> calls = const [];
  List<SoundHandle> stopped = const [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    calls = [...calls, name];
    if (name == failAt) {
      throw StateError('$name failed');
    }
    return switch (name) {
      #isInitialized => true,
      #loadMem => Future<AudioSource>.value(_FakeSource()),
      #getLength => const Duration(seconds: 30),
      #play => const SoundHandle(7),
      #stop => Future<void>.sync(
        () => stopped = [
          ...stopped,
          invocation.positionalArguments.single as SoundHandle,
        ],
      ),
      #seek || #setVolume || #scheduleStop || #setPause => null,
      final other => throw UnsupportedError('$other was not expected'),
    };
  }
}

void main() {
  group('the audio engine shuts down before the app exits', () {
    test(
      'an engine that never started leaves the native engine alone',
      () async {
        final soloud = _FakeSoLoud(initialized: false);

        await SoLoudAudioEngine(soloud: soloud).shutdown();

        expect(soloud.calls, isEmpty);
      },
    );

    test('a running engine is stopped off the UI thread', () async {
      final soloud = _FakeSoLoud(initialized: false);
      final engine = SoLoudAudioEngine(soloud: soloud);
      await engine.init();

      await engine.shutdown();

      expect(soloud.calls, ['init', 'deinitAsync']);
      expect(soloud.initialized, isFalse);
    });

    test('an engine still starting is stopped too', () async {
      final starting = Completer<void>();
      final soloud = _FakeSoLoud(initialized: false, starting: starting.future);
      final engine = SoLoudAudioEngine(soloud: soloud);
      unawaited(engine.init());

      await engine.shutdown();

      expect(soloud.calls, ['init', 'deinitAsync']);
    });

    test('an engine started elsewhere is stopped', () async {
      final soloud = _FakeSoLoud(initialized: true);

      await SoLoudAudioEngine(soloud: soloud).shutdown();

      expect(soloud.calls, ['deinitAsync']);
    });

    test('a shut down engine never starts again', () async {
      final soloud = _FakeSoLoud(initialized: false);
      final engine = SoLoudAudioEngine(soloud: soloud);

      await engine.shutdown();

      await expectLater(engine.init(), throwsStateError);
      expect(soloud.calls, isEmpty);
    });
  });

  group('a clip that cannot start playing', () {
    for (final step in const [
      'seek',
      'setVolume',
      'scheduleStop',
      'setPause',
    ]) {
      test('stops its voice when $step fails', () async {
        final soloud = _PlayingSoLoud(failAt: Symbol(step));
        final engine = SoLoudAudioEngine(soloud: soloud);
        final clip = await engine.loadClip(Uint8List(4));

        expect(() => engine.playSlice(clip, 10, 10, 0.8), throwsStateError);
        await pumpEventQueue();

        expect(soloud.stopped, [const SoundHandle(7)]);
      });
    }

    test('a clip that starts keeps its voice', () async {
      final soloud = _PlayingSoLoud(failAt: #none);
      final engine = SoLoudAudioEngine(soloud: soloud);
      final clip = await engine.loadClip(Uint8List(4));

      final voice = engine.playSlice(clip, 10, 10, 0.8);
      await pumpEventQueue();

      expect(voice.id, 7);
      expect(soloud.stopped, isEmpty);
    });
  });
}
