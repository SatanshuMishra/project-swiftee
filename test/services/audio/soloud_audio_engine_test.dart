import 'dart:async';

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
}
