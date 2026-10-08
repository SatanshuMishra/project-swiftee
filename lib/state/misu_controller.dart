import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/engine/misu_lines.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/state/attention_controller.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';

const Object _unchanged = Object();

enum MisuSide { left, right }

final class MisuVisit {
  const MisuVisit({required this.text, required this.side, required this.long});

  final String text;
  final MisuSide side;
  final bool long;

  @override
  bool operator ==(Object other) =>
      other is MisuVisit &&
      other.text == text &&
      other.side == side &&
      other.long == long;

  @override
  int get hashCode => Object.hash(text, side, long);

  @override
  String toString() => 'MisuVisit(text: $text, side: $side, long: $long)';
}

final class MisuState {
  const MisuState({this.visit, this.greeted = false, this.lastGameRound});

  final MisuVisit? visit;
  final bool greeted;
  final int? lastGameRound;

  MisuState copyWith({
    Object? visit = _unchanged,
    bool? greeted,
    Object? lastGameRound = _unchanged,
  }) => MisuState(
    visit: identical(visit, _unchanged) ? this.visit : visit as MisuVisit?,
    greeted: greeted ?? this.greeted,
    lastGameRound: identical(lastGameRound, _unchanged)
        ? this.lastGameRound
        : lastGameRound as int?,
  );

  @override
  bool operator ==(Object other) =>
      other is MisuState &&
      other.visit == visit &&
      other.greeted == greeted &&
      other.lastGameRound == lastGameRound;

  @override
  int get hashCode => Object.hash(visit, greeted, lastGameRound);

  @override
  String toString() =>
      'MisuState(visit: $visit, greeted: $greeted, '
      'lastGameRound: $lastGameRound)';
}

final misuControllerProvider = NotifierProvider<MisuController, MisuState>(
  MisuController.new,
);

class MisuController extends Notifier<MisuState> {
  static const Duration visitDuration = Duration(seconds: 8);
  static const Duration longVisitDuration = Duration(seconds: 12);
  static const int oftenRoundGap = 2;
  static const int sometimesRoundGap = 5;

  Timer? _hide;
  bool _covered = false;
  bool _inTogetherGame = false;
  Map<MisuLine, List<int>> _bags = const {};
  Map<MisuLine, int> _last = const {};

  @override
  MisuState build() {
    ref
      ..onDispose(_cancelHide)
      ..listen(attentionProvider, (previous, next) {
        if (next.away && previous?.away != true) {
          _away();
        }
        if (previous?.watching != next.watching) {
          _countdown();
        }
      });
    return const MisuState();
  }

  void greet(DateTime now) {
    if (state.greeted) {
      return;
    }
    state = state.copyWith(greeted: true);
    if (_visits != MisuVisits.off) {
      _show(_line(MisuLine.greet, now: now), MisuSide.right);
    }
  }

  void introduce() => _show(_line(MisuLine.intro), MisuSide.right, long: true);

  void afterAnswer({
    required bool correct,
    required int streak,
    required int missRun,
    required int roundNumber,
  }) {
    final kind = switch (correct) {
      true when streak > 0 && streak % 5 == 0 =>
        streak == 10 ? MisuLine.streak10 : MisuLine.streak5,
      false when missRun == 3 => MisuLine.miss3,
      _ => null,
    };
    if (kind == null || !_gameVisitAllowed(roundNumber)) {
      return;
    }
    state = state.copyWith(lastGameRound: roundNumber);
    _show(_line(kind, count: streak), MisuSide.left);
  }

  void afterQuickRound(int right) {
    if (_visits == MisuVisits.off) {
      return;
    }
    final kind = right >= 8
        ? MisuLine.sumHigh
        : right >= 5
        ? MisuLine.sumMid
        : MisuLine.sumLow;
    _show(_line(kind), MisuSide.right);
  }

  void togetherCloseFinish(double seconds) {
    if (_visits == MisuVisits.off) {
      return;
    }
    _show(_line(MisuLine.closeFinish, seconds: seconds), MisuSide.right);
  }

  void togetherWon() {
    if (_visits == MisuVisits.off) {
      return;
    }
    _show(_line(MisuLine.wonTogether), MisuSide.right);
  }

  void cover({required bool covered}) {
    if (_covered == covered) {
      return;
    }
    _covered = covered;
    _countdown();
  }

  void dismiss() {
    _cancelHide();
    state = state.copyWith(visit: null);
  }

  void _away() {
    if (_visits == MisuVisits.off || state.visit != null || !_canDropIn) {
      return;
    }
    _show(_line(MisuLine.away), MisuSide.right);
  }

  bool get inTogetherGame => _inTogetherGame;

  void togetherGame({required bool running}) => _inTogetherGame = running;

  bool get _canDropIn =>
      !_inTogetherGame &&
      ref.read(gameControllerProvider).phase != GamePhase.nickname;

  MisuVisits get _visits =>
      ref.read(gameControllerProvider).progress.settings.misuVisits;

  bool _gameVisitAllowed(int roundNumber) {
    final gap = switch (_visits) {
      MisuVisits.often => oftenRoundGap,
      MisuVisits.sometimes => sometimesRoundGap,
      MisuVisits.off => null,
    };
    final last = state.lastGameRound;
    return gap != null &&
        (last == null || roundNumber <= last || roundNumber - last >= gap);
  }

  String _line(
    MisuLine kind, {
    DateTime? now,
    int count = 0,
    double seconds = 0,
  }) {
    final edition = ref.read(editionProvider);
    final at = now ?? ref.read(clockProvider)();
    final lines = misuLines(
      kind,
      edition: edition,
      name: displayName(
        edition,
        ref.read(gameControllerProvider).progress.settings.nickname,
      ),
      now: at,
      count: count,
      seconds: seconds,
    );
    return lines[kind == MisuLine.greet
        ? dayVariant(at, lines.length)
        : _draw(kind, lines.length)];
  }

  int _draw(MisuLine kind, int variants) {
    final (:pick, :rest) = drawVariant(
      _bags[kind] ?? const [],
      variants: variants,
      random: ref.read(randomProvider),
      last: _last[kind],
    );
    _bags = {..._bags, kind: rest};
    _last = {..._last, kind: pick};
    return pick;
  }

  void _show(String text, MisuSide side, {bool long = false}) {
    state = state.copyWith(
      visit: MisuVisit(text: text, side: side, long: long),
    );
    _countdown();
  }

  void _countdown() {
    _cancelHide();
    final visit = state.visit;
    if (visit == null || _covered || !ref.read(attentionProvider).watching) {
      return;
    }
    _hide = Timer(visit.long ? longVisitDuration : visitDuration, () {
      _hide = null;
      state = state.copyWith(visit: null);
    });
  }

  void _cancelHide() {
    _hide?.cancel();
    _hide = null;
  }
}
