import 'package:blobatar/flutter.dart';
import 'package:flutter/widgets.dart';

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.seed,
    required this.name,
    this.size = 32,
  });

  final String seed;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Blobatar(
    name: seed,
    size: size,
    semanticLabel: "$name's avatar",
    options: const BlobatarOptions(background: Backdrop.circle),
  );
}
