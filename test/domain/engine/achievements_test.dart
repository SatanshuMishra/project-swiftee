import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/engine/achievements.dart';

void main() {
  group('achievements parity', () {
    group('achievementDefs', () {
      test('has exactly 15 achievements', () {
        expect(achievementDefs.length, 15);
      });

      test('has unique IDs', () {
        final ids = achievementDefs.map((def) => def.id).toList();
        expect(ids.toSet().length, ids.length);
      });

      test('all have required fields', () {
        for (final def in achievementDefs) {
          expect(def.id, isNotEmpty);
          expect(def.name, isNotEmpty);
          expect(def.description, isNotEmpty);
        }
      });

      test('includes all expected achievement IDs', () {
        final ids = achievementDefs.map((def) => def.id).toList();
        expect(ids, contains('first_meow'));
        expect(ids, contains('getting_warmed_up'));
        expect(ids, contains('purrfect_streak'));
        expect(ids, contains('album_explorer'));
        expect(ids, contains('album_completionist'));
        expect(ids, contains('hard_mode_hero'));
        expect(ids, contains('speed_demon'));
        expect(ids, contains('persistent_listener'));
        expect(ids, contains('quack_collector'));
        expect(ids, contains('all_ears'));
        expect(ids, contains('lyric_lover'));
        expect(ids, contains('poet_laureate'));
        expect(ids, contains('lie_detector'));
        expect(ids, contains('dual_threat'));
        expect(ids, contains('lyric_streak'));
      });
    });
  });
}
