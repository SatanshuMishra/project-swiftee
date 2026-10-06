import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/misu_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';

final DateTime _evening = DateTime(2026, 10, 6, 19);
final DateTime _morning = DateTime(2026, 10, 6, 8);

const MisuVisit _openStreak5 = MisuVisit(
  text: "Five in a row, Sam. Misu's tail is doing the thing.",
  side: MisuSide.left,
  long: false,
);
const MisuVisit _openMiss3 = MisuVisit(
  text: "Misu isn't judging. Misu is a little judging.",
  side: MisuSide.left,
  long: false,
);
const MisuVisit _intro = MisuVisit(
  text: "I'm Misu. I'll drop by now and then.",
  side: MisuSide.right,
  long: true,
);

ProviderContainer _container(
  MisuVisits visits, {
  Edition edition = Edition.open,
  String nickname = 'Sam',
}) {
  final container = ProviderContainer.test(
    overrides: [
      clockProvider.overrideWithValue(() => _evening),
      editionProvider.overrideWithValue(edition),
    ],
  );
  container.read(gameControllerProvider.notifier)
    ..setMisuVisits(visits)
    ..setNickname(nickname);
  return container;
}

void main() {
  group('misu visits', () {
    test('visit frequency follows the misu setting', () {
      fakeAsync((async) {
        final sometimes = _container(MisuVisits.sometimes);
        final misu = sometimes.read(misuControllerProvider.notifier);
        MisuVisit? visit() => sometimes.read(misuControllerProvider).visit;

        misu.afterAnswer(correct: true, streak: 5, missRun: 0, roundNumber: 5);
        expect(visit(), _openStreak5);
        misu.dismiss();
        expect(visit(), isNull);

        misu.afterAnswer(correct: false, streak: 0, missRun: 3, roundNumber: 9);
        expect(visit(), isNull);
        misu.afterAnswer(
          correct: false,
          streak: 0,
          missRun: 3,
          roundNumber: 10,
        );
        expect(visit(), _openMiss3);
        misu.dismiss();
        misu.afterAnswer(
          correct: true,
          streak: 10,
          missRun: 0,
          roundNumber: 14,
        );
        expect(visit(), isNull);
        misu.afterAnswer(
          correct: true,
          streak: 15,
          missRun: 0,
          roundNumber: 15,
        );
        expect(visit()?.text, startsWith('Fifteen in a row, Sam.'));
        misu.dismiss();
        misu.afterAnswer(correct: true, streak: 5, missRun: 0, roundNumber: 5);
        expect(visit(), _openStreak5, reason: 'a new game began');

        final often = _container(MisuVisits.often);
        final oftenMisu = often.read(misuControllerProvider.notifier);
        MisuVisit? oftenVisit() => often.read(misuControllerProvider).visit;

        oftenMisu.afterAnswer(
          correct: true,
          streak: 5,
          missRun: 0,
          roundNumber: 5,
        );
        expect(oftenVisit(), _openStreak5);
        oftenMisu
          ..dismiss()
          ..afterAnswer(correct: false, streak: 0, missRun: 3, roundNumber: 6);
        expect(oftenVisit(), isNull);
        oftenMisu.afterAnswer(
          correct: false,
          streak: 0,
          missRun: 3,
          roundNumber: 7,
        );
        expect(oftenVisit(), _openMiss3);
        oftenMisu
          ..dismiss()
          ..afterAnswer(correct: true, streak: 10, missRun: 0, roundNumber: 9);
        expect(
          oftenVisit(),
          const MisuVisit(
            text: "Ten in a row. Misu's telling everyone.",
            side: MisuSide.left,
            long: false,
          ),
        );
        oftenMisu.dismiss();
        for (final (correct, streak, missRun) in [
          (true, 4, 0),
          (true, 6, 0),
          (false, 0, 2),
          (false, 0, 4),
        ]) {
          oftenMisu.afterAnswer(
            correct: correct,
            streak: streak,
            missRun: missRun,
            roundNumber: 20,
          );
          expect(oftenVisit(), isNull, reason: '$correct $streak $missRun');
        }

        final off = _container(MisuVisits.off);
        final offMisu = off.read(misuControllerProvider.notifier);
        MisuVisit? offVisit() => off.read(misuControllerProvider).visit;

        offMisu
          ..afterAnswer(correct: true, streak: 5, missRun: 0, roundNumber: 5)
          ..afterAnswer(correct: false, streak: 0, missRun: 3, roundNumber: 8)
          ..greet(_evening)
          ..afterQuickRound(9);
        expect(offVisit(), isNull);
        expect(off.read(misuControllerProvider).lastGameRound, isNull);

        offMisu.introduce();
        expect(offVisit(), _intro);
        async.elapse(const Duration(milliseconds: 6999));
        expect(offVisit(), _intro);
        async.elapse(const Duration(milliseconds: 1));
        expect(offVisit(), isNull);

        misu.dismiss();
        misu.afterAnswer(correct: true, streak: 5, missRun: 0, roundNumber: 1);
        expect(visit(), _openStreak5);
        async.elapse(const Duration(milliseconds: 4199));
        expect(visit(), _openStreak5);
        async.elapse(const Duration(milliseconds: 1));
        expect(visit(), isNull);
      });
    });

    test('greets once per session on the right by time of day', () {
      fakeAsync((async) {
        final container = _container(MisuVisits.sometimes);
        final misu = container.read(misuControllerProvider.notifier);
        MisuState read() => container.read(misuControllerProvider);

        misu.greet(_morning);
        expect(
          read().visit,
          const MisuVisit(
            text: "Morning, Sam. Misu's been up since five.",
            side: MisuSide.right,
            long: false,
          ),
        );
        expect(read().greeted, isTrue);

        misu
          ..dismiss()
          ..greet(_evening);
        expect(read().visit, isNull);
      });
    });

    test('a greeting skipped while off is not shown later', () {
      fakeAsync((async) {
        final container = _container(MisuVisits.off);
        final misu = container.read(misuControllerProvider.notifier)
          ..greet(_evening);
        expect(container.read(misuControllerProvider).visit, isNull);
        expect(container.read(misuControllerProvider).greeted, isTrue);

        container
            .read(gameControllerProvider.notifier)
            .setMisuVisits(MisuVisits.often);
        misu.greet(_evening);
        expect(container.read(misuControllerProvider).visit, isNull);
      });
    });

    test('the quick round summary line follows the score', () {
      fakeAsync((async) {
        final container = _container(MisuVisits.sometimes);
        final misu = container.read(misuControllerProvider.notifier);
        MisuVisit? visit() => container.read(misuControllerProvider).visit;

        final expected = {
          10: "Even Misu's impressed, Sam.",
          8: "Even Misu's impressed, Sam.",
          7: 'Solid round. Misu approves.',
          5: 'Solid round. Misu approves.',
          4: 'Shake it off, Sam. Again?',
          0: 'Shake it off, Sam. Again?',
        };
        for (final MapEntry(key: right, value: text) in expected.entries) {
          misu.afterQuickRound(right);
          expect(
            visit(),
            MisuVisit(text: text, side: MisuSide.right, long: false),
            reason: '$right right',
          );
        }
      });
    });

    test('the ana edition speaks in the first person', () {
      fakeAsync((async) {
        final container = _container(MisuVisits.often, edition: Edition.ana);
        final misu = container.read(misuControllerProvider.notifier)
          ..afterAnswer(correct: true, streak: 5, missRun: 0, roundNumber: 5);

        expect(
          container.read(misuControllerProvider).visit?.text,
          'Five in a row, Ana. My tail is doing the thing.',
        );

        misu.afterQuickRound(9);
        expect(
          container.read(misuControllerProvider).visit?.text,
          "Even I'm impressed. And I'm a cat.",
        );
      });
    });

    test('a new visit replaces the old one and restarts its timer', () {
      fakeAsync((async) {
        final container = _container(MisuVisits.often);
        final misu = container.read(misuControllerProvider.notifier)
          ..introduce();
        MisuVisit? visit() => container.read(misuControllerProvider).visit;

        async.elapse(const Duration(seconds: 3));
        misu.afterQuickRound(6);
        expect(visit()?.text, 'Solid round. Misu approves.');

        async.elapse(const Duration(milliseconds: 4199));
        expect(visit()?.text, 'Solid round. Misu approves.');
        async.elapse(const Duration(milliseconds: 1));
        expect(visit(), isNull);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('dismiss and dispose cancel the pending hide', () {
      fakeAsync((async) {
        final container = _container(MisuVisits.often);
        container.read(misuControllerProvider.notifier)
          ..introduce()
          ..dismiss();
        expect(async.pendingTimers, isEmpty);

        container.read(misuControllerProvider.notifier).introduce();
        expect(async.pendingTimers, hasLength(1));
        container.dispose();
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('misu state copies keep and clear nullable fields', () {
      const state = MisuState(visit: _intro, greeted: true, lastGameRound: 4);

      expect(state.copyWith(), state);
      expect(state.copyWith().hashCode, state.hashCode);
      expect(state.copyWith(visit: null).visit, isNull);
      expect(state.copyWith(visit: null).lastGameRound, 4);
      expect(state.copyWith(lastGameRound: null).lastGameRound, isNull);
      expect(state.copyWith(lastGameRound: null).visit, _intro);
      expect(state.copyWith(greeted: false).greeted, isFalse);
      expect(const MisuState(), isNot(state));
    });
  });
}
