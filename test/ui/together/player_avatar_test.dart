import 'dart:typed_data';

import 'package:blobatar/flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftie_quiz/ui/together/player_avatar.dart';

const _first = ValueKey('first');
const _again = ValueKey('again');
const _other = ValueKey('other');

Future<void> _pumpAvatars(WidgetTester tester, List<Widget> avatars) =>
    tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: avatars),
        ),
      ),
    );

Finder _blobatarIn(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(Blobatar));

Future<Uint8List> _pixels(WidgetTester tester, Key key) async {
  final element = tester.element(_blobatarIn(key));
  final pixels = await tester.runAsync(() async {
    final image = await captureImage(element);
    final data = await image.toByteData();
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return pixels!;
}

void main() {
  testWidgets('the same seed always draws the same avatar', (tester) async {
    await _pumpAvatars(tester, const [
      PlayerAvatar(key: _first, seed: 'q7Hk2m', name: 'Maya'),
      PlayerAvatar(key: _again, seed: 'q7Hk2m', name: 'Ana'),
      PlayerAvatar(key: _other, seed: 'Zx81Lp', name: 'Maya'),
    ]);

    final blobatar = tester.widget<Blobatar>(_blobatarIn(_first));

    expect(blobatar.name, 'q7Hk2m');
    expect(blobatar.size, 32);
    expect(
      blobatar.options,
      const BlobatarOptions(background: Backdrop.circle),
    );
    expect(tester.getSize(_blobatarIn(_first)), const Size.square(32));

    final first = await _pixels(tester, _first);

    expect(first.any((channel) => channel != 0), isTrue);
    expect(await _pixels(tester, _again), first);
    expect(await _pixels(tester, _other), isNot(first));
  });

  testWidgets("the avatar is announced with the player's name", (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpAvatars(tester, const [
      PlayerAvatar(seed: 'q7Hk2m', name: 'Maya', size: 48),
    ]);

    expect(find.bySemanticsLabel("Maya's avatar"), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel("Maya's avatar")),
      isSemantics(label: "Maya's avatar", isImage: true),
    );
    expect(tester.getSize(find.byType(PlayerAvatar)), const Size.square(48));
    semantics.dispose();
  });
}
