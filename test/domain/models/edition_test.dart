import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';

void main() {
  test('only the ana define builds the ana edition', () {
    expect(Edition.fromDefine('ana'), Edition.ana);
    expect(Edition.fromDefine('open'), Edition.open);
    expect(Edition.fromDefine(''), Edition.open);
    expect(Edition.fromDefine('ANA'), Edition.open);
  });
}
