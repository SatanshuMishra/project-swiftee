import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/engine/misu_lines.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/state/attention_controller.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/misu_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';

final DateTime _evening = DateTime(2026, 10, 6, 19);
final DateTime _morning = DateTime(2026, 10, 6, 8);

const Duration _stay = Duration(seconds: 8);
const Duration _justBefore = Duration(milliseconds: 1);

ProviderContainer _container(
  FakeAsync async,
  MisuVisits visits, {
  Edition edition = Edition.open,
  String nickname = 'Sam',
}) {
  final container = ProviderContainer.test(
    overrides: [
      clockProvider.overrideWithValue(() => _evening.add(async.elapsed)),
      editionProvider.overrideWithValue(edition),
      randomProvider.overrideWithValue(Random(3)),
    ],
  );
  container.read(gameControllerProvider.notifier)
    ..setMisuVisits(visits)
    ..setNickname(nickname);
  container.read(attentionProvider.notifier).track();
  container.read(misuControllerProvider);
  return container;
}

List<String> _lines(
  MisuLine kind, {
  Edition edition = Edition.open,
  int count = 5,
  DateTime? now,
}) => misuLines(
  kind,
  edition: edition,
  name: displayName(edition, 'Sam'),
  now: now ?? _evening,
  count: count,
);

Matcher _visitOf(
  MisuLine kind,
  MisuSide side, {
  Edition edition = Edition.open,
  int count = 5,
  bool long = false,
}) => isA<MisuVisit>()
    .having(
      (visit) => visit.text,
      'text',
      isIn(_lines(kind, edition: edition, count: count)),
    )
    .having((visit) => visit.side, 'side', side)
    .having((visit) => visit.long, 'long', long);

void main() {
  group('misu visits', () {
    test('visit frequency follows the misu setting', () {
      fakeAsync((async) {
        final sometimes = _container(async, MisuVisits.sometimes);
        final misu = sometimes.read(misuControllerProvider.notifier);
        MisuVisit? visit() => sometimes.read(misuControllerProvider).visit;

        misu.afterAnswer(correct: true, streak: 5, missRun: 0, roundNumber: 5);
        expect(visit(), _visitOf(MisuLine.streak5, MisuSide.left));
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
        expect(visit(), _visitOf(MisuLine.miss3, MisuSide.left));
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
        expect(visit(), _visitOf(MisuLine.streak5, MisuSide.left, count: 15));
        misu.dismiss();
        misu.afterAnswer(correct: true, streak: 5, missRun: 0, roundNumber: 5);
        expect(
          visit(),
          _visitOf(MisuLine.streak5, MisuSide.left),
          reason: 'a new game began',
        );

        final often = _container(async, MisuVisits.often);
        final oftenMisu = often.read(misuControllerProvider.notifier);
        MisuVisit? oftenVisit() => often.read(misuControllerProvider).visit;

        oftenMisu.afterAnswer(
          correct: true,
          streak: 5,
          missRun: 0,
          roundNumber: 5,
        );
        expect(oftenVisit(), _visitOf(MisuLine.streak5, MisuSide.left));
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
        expect(oftenVisit(), _visitOf(MisuLine.miss3, MisuSide.left));
        oftenMisu
          ..dismiss()
          ..afterAnswer(correct: true, streak: 10, missRun: 0, roundNumber: 9);
        expect(oftenVisit(), _visitOf(MisuLine.streak10, MisuSide.left));
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

        final off = _container(async, MisuVisits.off);
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
        expect(
          offVisit(),
          _visitOf(MisuLine.intro, MisuSide.right, long: true),
        );
        async.elapse(const Duration(seconds: 12) - _justBefore);
        expect(offVisit(), isNotNull);
        async.elapse(_justBefore);
        expect(offVisit(), isNull);

        misu.dismiss();
        misu.afterAnswer(correct: true, streak: 5, missRun: 0, roundNumber: 1);
        expect(visit(), _visitOf(MisuLine.streak5, MisuSide.left));
        async.elapse(_stay - _justBefore);
        expect(visit(), isNotNull);
        async.elapse(_justBefore);
        expect(visit(), isNull);
      });
    });

    test("greets once per session on the right with the day's version", () {
      fakeAsync((async) {
        final container = _container(async, MisuVisits.sometimes);
        final misu = container.read(misuControllerProvider.notifier);
        MisuState read() => container.read(misuControllerProvider);

        misu.greet(_morning);
        final morning = _lines(MisuLine.greet, now: _morning);
        expect(
          read().visit,
          MisuVisit(
            text: morning[dayVariant(_morning, morning.length)],
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

    test('the greeting moves on to another version the next day', () {
      fakeAsync((async) {
        String greetingOn(DateTime day) {
          final container = _container(async, MisuVisits.sometimes);
          container.read(misuControllerProvider.notifier).greet(day);
          return container.read(misuControllerProvider).visit!.text;
        }

        final greetings = [
          for (var day = 6; day < 10; day++)
            greetingOn(DateTime(2026, 10, day, 8)),
        ];

        expect(
          greetings.toSet(),
          _lines(MisuLine.greet, now: _morning).toSet(),
        );
        expect(greetingOn(DateTime(2026, 10, 6, 11)), greetings.first);
      });
    });

    test('a greeting skipped while off is not shown later', () {
      fakeAsync((async) {
        final container = _container(async, MisuVisits.off);
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
        final container = _container(async, MisuVisits.sometimes);
        final misu = container.read(misuControllerProvider.notifier);
        MisuVisit? visit() => container.read(misuControllerProvider).visit;

        final expected = {
          10: MisuLine.sumHigh,
          8: MisuLine.sumHigh,
          7: MisuLine.sumMid,
          5: MisuLine.sumMid,
          4: MisuLine.sumLow,
          0: MisuLine.sumLow,
        };
        for (final MapEntry(key: right, value: kind) in expected.entries) {
          misu.afterQuickRound(right);
          expect(
            visit(),
            _visitOf(kind, MisuSide.right),
            reason: '$right right',
          );
        }
      });
    });

    test('every version of a line plays before any repeats', () {
      fakeAsync((async) {
        final container = _container(async, MisuVisits.often);
        final misu = container.read(misuControllerProvider.notifier);
        String next() {
          misu.afterQuickRound(9);
          return container.read(misuControllerProvider).visit!.text;
        }

        final said = [for (var round = 0; round < 12; round++) next()];
        final versions = _lines(MisuLine.sumHigh).toSet();

        for (var start = 0; start < said.length; start += 4) {
          expect(said.sublist(start, start + 4).toSet(), versions);
        }
        for (var round = 1; round < said.length; round++) {
          expect(said[round], isNot(said[round - 1]), reason: 'round $round');
        }
      });
    });

    test('the ana edition speaks in the first person', () {
      fakeAsync((async) {
        final container = _container(
          async,
          MisuVisits.often,
          edition: Edition.ana,
        );
        final misu = container.read(misuControllerProvider.notifier)
          ..afterAnswer(correct: true, streak: 5, missRun: 0, roundNumber: 5);

        expect(
          container.read(misuControllerProvider).visit,
          _visitOf(MisuLine.streak5, MisuSide.left, edition: Edition.ana),
        );

        misu.afterQuickRound(9);
        expect(
          container.read(misuControllerProvider).visit,
          _visitOf(MisuLine.sumHigh, MisuSide.right, edition: Edition.ana),
        );
      });
    });

    test('a new visit replaces the old one and restarts its timer', () {
      fakeAsync((async) {
        final container = _container(async, MisuVisits.often);
        final idle = async.pendingTimers.length;
        final misu = container.read(misuControllerProvider.notifier)
          ..introduce();
        MisuVisit? visit() => container.read(misuControllerProvider).visit;

        async.elapse(const Duration(seconds: 3));
        misu.afterQuickRound(6);
        expect(visit(), _visitOf(MisuLine.sumMid, MisuSide.right));

        async.elapse(_stay - _justBefore);
        expect(visit(), isNotNull);
        async.elapse(_justBefore);
        expect(visit(), isNull);
        expect(async.pendingTimers, hasLength(idle));
      });
    });

    test('dismiss and dispose cancel the pending hide', () {
      fakeAsync((async) {
        final container = _container(async, MisuVisits.often);
        final idle = async.pendingTimers.length;
        container.read(misuControllerProvider.notifier)
          ..introduce()
          ..dismiss();
        expect(async.pendingTimers, hasLength(idle));

        container.read(misuControllerProvider.notifier).introduce();
        expect(async.pendingTimers, hasLength(idle + 1));
        container.dispose();
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('misu waits while the window is in the background and gives a full '
        'eight seconds once you are back', () {
      fakeAsync((async) {
        final container = _container(async, MisuVisits.often);
        final attention = container.read(attentionProvider.notifier);
        final misu = container.read(misuControllerProvider.notifier);
        MisuVisit? visit() => container.read(misuControllerProvider).visit;

        misu.afterQuickRound(6);
        async.elapse(const Duration(seconds: 5));
        attention.focus(focused: false);
        async.elapse(const Duration(minutes: 1));
        expect(visit(), isNotNull);

        attention.focus(focused: true);
        async.elapse(const Duration(minutes: 1));
        expect(visit(), isNotNull, reason: 'back in front but not touched');

        attention.input();
        async.elapse(_stay - _justBefore);
        expect(visit(), isNotNull);
        async.elapse(_justBefore);
        expect(visit(), isNull);

        misu.afterQuickRound(6);
        async.elapse(const Duration(seconds: 7));
        attention
          ..focus(focused: false)
          ..focus(focused: true);
        async.elapse(_stay - _justBefore);
        expect(visit(), isNotNull, reason: 'coming back restarts the stay');
        async.elapse(_justBefore);
        expect(visit(), isNull);
      });
    });

    test('a line said while you are idle waits for your next move', () {
      fakeAsync((async) {
        final container = _container(async, MisuVisits.often);
        final misu = container.read(misuControllerProvider.notifier);
        MisuVisit? visit() => container.read(misuControllerProvider).visit;

        async.elapse(AttentionController.activeFor);
        expect(container.read(attentionProvider).watching, isFalse);
        misu.afterQuickRound(6);
        async.elapse(const Duration(minutes: 2));
        expect(visit(), _visitOf(MisuLine.sumMid, MisuSide.right));

        container.read(attentionProvider.notifier).input();
        async.elapse(_stay - _justBefore);
        expect(visit(), isNotNull);
        async.elapse(_justBefore);
        expect(visit(), isNull);
      });
    });

    test('a dialog over misu holds his stay until it closes', () {
      fakeAsync((async) {
        final container = _container(async, MisuVisits.often);
        final misu = container.read(misuControllerProvider.notifier)
          ..afterQuickRound(6)
          ..cover(covered: true);
        MisuVisit? visit() => container.read(misuControllerProvider).visit;

        async.elapse(const Duration(seconds: 20));
        expect(visit(), isNotNull);

        misu.cover(covered: false);
        async.elapse(_stay - _justBefore);
        expect(visit(), isNotNull);
        async.elapse(_justBefore);
        expect(visit(), isNull);
      });
    });

    test('misu drops in once after five minutes away and waits for you', () {
      fakeAsync((async) {
        final container = _container(async, MisuVisits.sometimes);
        MisuVisit? visit() => container.read(misuControllerProvider).visit;

        async.elapse(AttentionController.awayAfter - _justBefore);
        expect(visit(), isNull);
        async.elapse(_justBefore);
        expect(visit(), _visitOf(MisuLine.away, MisuSide.right));
        final first = visit()!.text;

        async.elapse(const Duration(minutes: 20));
        expect(visit()?.text, first, reason: 'still waiting for you');

        container.read(attentionProvider.notifier).input();
        async.elapse(_stay);
        expect(visit(), isNull);

        async.elapse(const Duration(minutes: 4));
        container.read(attentionProvider.notifier).input();
        async.elapse(AttentionController.awayAfter - _justBefore);
        expect(visit(), isNull, reason: 'the absence restarted');
        async.elapse(_justBefore);
        expect(visit(), _visitOf(MisuLine.away, MisuSide.right));
        expect(visit()!.text, isNot(first));
      });
    });

    test('misu stays quiet when you are away with visits off, on the '
        'nickname screen, mid Play together game or while he is talking', () {
      fakeAsync((async) {
        MisuVisit? awayFrom(ProviderContainer container) {
          async.elapse(AttentionController.awayAfter);
          return container.read(misuControllerProvider).visit;
        }

        expect(awayFrom(_container(async, MisuVisits.off)), isNull);

        final nickname = _container(async, MisuVisits.often);
        nickname
            .read(gameControllerProvider.notifier)
            .setPhase(GamePhase.nickname);
        expect(awayFrom(nickname), isNull);

        final together = _container(async, MisuVisits.often);
        together
            .read(misuControllerProvider.notifier)
            .togetherGame(running: true);
        expect(awayFrom(together), isNull);
        together
            .read(misuControllerProvider.notifier)
            .togetherGame(running: false);
        together.read(attentionProvider.notifier).input();
        expect(
          awayFrom(together),
          _visitOf(MisuLine.away, MisuSide.right),
          reason: 'back in the room once the game ends',
        );

        final talking = _container(async, MisuVisits.often);
        async.elapse(AttentionController.activeFor);
        talking.read(misuControllerProvider.notifier).afterQuickRound(6);
        expect(
          awayFrom(talking),
          _visitOf(MisuLine.sumMid, MisuSide.right),
          reason: 'the waiting line is not replaced',
        );
      });
    });

    test('misu state copies keep and clear nullable fields', () {
      const intro = MisuVisit(
        text: "I'm Misu. I'll drop by now and then.",
        side: MisuSide.right,
        long: true,
      );
      const state = MisuState(visit: intro, greeted: true, lastGameRound: 4);

      expect(state.copyWith(), state);
      expect(state.copyWith().hashCode, state.hashCode);
      expect(state.copyWith(visit: null).visit, isNull);
      expect(state.copyWith(visit: null).lastGameRound, 4);
      expect(state.copyWith(lastGameRound: null).lastGameRound, isNull);
      expect(state.copyWith(lastGameRound: null).visit, intro);
      expect(state.copyWith(greeted: false).greeted, isFalse);
      expect(const MisuState(), isNot(state));
    });
  });
}
