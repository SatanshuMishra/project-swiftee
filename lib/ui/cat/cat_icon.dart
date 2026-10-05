import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CatIcon extends StatelessWidget {
  const CatIcon({super.key, required this.height});

  static const String asset = 'assets/cat/cat-icon.svg';

  final double height;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    asset,
    width: height / 2,
    height: height,
    excludeFromSemantics: true,
  );
}
