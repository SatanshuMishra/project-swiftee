import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum LucideGlyph {
  music('music'),
  album('album'),
  award('award'),
  settings('settings'),
  arrowLeft('arrow-left'),
  volume2('volume-2'),
  bookOpen('book-open'),
  eye('eye'),
  zap('zap'),
  flame('flame'),
  skull('skull'),
  play('play'),
  pause('pause'),
  check('check'),
  x('x'),
  lock('lock'),
  moon('moon'),
  sun('sun'),
  monitor('monitor'),
  clock('clock'),
  trash2('trash-2'),
  bell('bell'),
  archive('archive'),
  cake('cake'),
  sparkles('sparkles'),
  download('download'),
  loaderCircle('loader-circle'),
  circleAlert('circle-alert'),
  refreshCcw('refresh-ccw');

  const LucideGlyph(this.fileName) : assetPath = 'assets/icons/$fileName.svg';

  final String fileName;
  final String assetPath;
}

class AppIcon extends StatelessWidget {
  const AppIcon(
    this.glyph, {
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth = LucideIconLoader.defaultStrokeWidth,
  });

  final LucideGlyph glyph;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final tint =
        color ??
        DefaultTextStyle.of(context).style.color ??
        IconTheme.of(context).color ??
        const Color(0xFF000000);
    return SvgPicture(
      LucideIconLoader(glyph, strokeWidth: strokeWidth),
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}

@immutable
class LucideIconLoader extends SvgAssetLoader {
  LucideIconLoader(this.glyph, {this.strokeWidth = defaultStrokeWidth})
    : super(glyph.assetPath);

  static const double defaultStrokeWidth = 2;
  static const _defaultStrokeAttribute = 'stroke-width="2"';

  final LucideGlyph glyph;
  final double strokeWidth;

  @override
  String provideSvg(ByteData? message) {
    final source = super.provideSvg(message);
    if (strokeWidth == defaultStrokeWidth) {
      return source;
    }
    return source.replaceFirst(
      _defaultStrokeAttribute,
      'stroke-width="$strokeWidth"',
    );
  }

  @override
  SvgCacheKey cacheKey(BuildContext? context) => SvgCacheKey(
    keyData: (
      assetName,
      strokeWidth,
      assetBundle ??
          (context == null ? rootBundle : DefaultAssetBundle.of(context)),
    ),
    theme: getTheme(context),
    colorMapper: colorMapper,
  );

  @override
  bool operator ==(Object other) =>
      other is LucideIconLoader &&
      other.glyph == glyph &&
      other.strokeWidth == strokeWidth &&
      other.assetBundle == assetBundle &&
      other.theme == theme &&
      other.colorMapper == colorMapper;

  @override
  int get hashCode =>
      Object.hash(glyph, strokeWidth, assetBundle, theme, colorMapper);
}
