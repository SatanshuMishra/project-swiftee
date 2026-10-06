import 'package:swiftie_quiz/data/catalog/deezer_json.dart';
import 'package:swiftie_quiz/domain/engine/catalogue_rules.dart';

bool isPlayableSong(DeezerTrack track) => isPlayableTitle(
  track.track.title,
  track.titleVersion,
  track.track.duration,
);
