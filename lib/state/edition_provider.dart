import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';

const String editionDefine = String.fromEnvironment('EDITION');

final editionProvider = Provider<Edition>(
  (ref) => Edition.fromDefine(editionDefine),
);
