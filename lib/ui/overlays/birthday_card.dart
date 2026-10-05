import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/app_icon.dart';
import 'package:swiftie_quiz/ui/widgets/entrance.dart';
import 'package:swiftie_quiz/ui/widgets/above_app_chrome.dart';

class BirthdayCard extends StatefulWidget {
  const BirthdayCard({super.key, required this.isOpen, required this.onClose});

  static const String heading = 'Happy Birthday!';
  static const String greeting = 'Dear Ana,';
  static const List<String> message = [
    'Sending you the warmest of wishes for a very Happy Birthday!',
    'Thank you for always being there for me over these past couple of '
        "years. I'm very grateful and lucky to have a friend like you.",
    "I've said it before, and I'll say it again: there is nothing you can't "
        'accomplish once you put your mind to it. As you enter this next '
        'year, which will hopefully be filled with exciting opportunities and '
        'unforgettable memories, I have no doubt in my mind that you will '
        'find success and reach the goals you set for yourself!',
    "I can't wait to see what you accomplish in the year ahead! Know that I "
        'am always rooting for you!',
  ];
  static const String closing = 'Your Best Friend,';
  static const String signature = 'Satanshu :)';
  static const String postscript = 'P.S. Meowwwww Meow Meaaww ~ Clef';

  static const Color signatureColor = Color(0xFFE97F6A);
  static const GradientPair headerGradient = GradientPair(
    Color(0xFFE97F6A),
    Color(0xFFFD5E53),
  );
  static const Color backdropColor = Color.from(
    alpha: 0.6,
    red: 0,
    green: 0,
    blue: 0,
  );
  static const Color blobColor = Color.from(
    alpha: 0.1,
    red: 1,
    green: 1,
    blue: 1,
  );
  static const double backdropBlur = 8;
  static const double backdropPadding = 16;
  static const double maxWidth = 512;
  static const double radius = AppRadii.xl2;
  static const double borderWidth = 4;
  static const double closeOffset = 12;
  static const double closeBorderWidth = 2;
  static const double closePadding = 8;
  static const double closeIconSize = 20;
  static const double cakeSize = 32;
  static const double cakeGap = 8;
  static const Duration cakeDelay = Duration(milliseconds: 300);
  static const double headingGap = 12;
  static const double notchDepth = 32;
  static const double fadeMaskHeight = 48;
  static const double scrollableThreshold = 4;
  static const double sectionGap = 24;
  static const double paragraphGap = 12;
  static const double signatureTopPadding = 16;
  static const double closingGap = 4;
  static const double relaxedLineHeight = 1.625;
  static const double hiddenScale = 0.8;
  static const double turnDegrees = 15;

  final bool isOpen;
  final VoidCallback onClose;

  @override
  State<BirthdayCard> createState() => _BirthdayCardState();
}

class _BirthdayCardState extends State<BirthdayCard>
    with TickerProviderStateMixin {
  late final AnimationController _backdrop = AnimationController(
    vsync: this,
    duration: AppMotion.defaultOpacityDuration,
  );
  late final CurvedAnimation _backdropOpacity = CurvedAnimation(
    parent: _backdrop,
    curve: AppMotion.defaultOpacityCurve,
    reverseCurve: AppMotion.defaultOpacityCurve.flipped,
  );
  late final AnimationController _card = AnimationController.unbounded(
    vsync: this,
  );
  late bool _present = widget.isOpen;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isOpen) {
      _enter();
    }
  }

  @override
  void didUpdateWidget(BirthdayCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen == oldWidget.isOpen) {
      return;
    }
    if (widget.isOpen) {
      _present = true;
      _enter();
    } else {
      _leave();
    }
  }

  @override
  void dispose() {
    _backdropOpacity.dispose();
    _backdrop.dispose();
    _card.dispose();
    super.dispose();
  }

  void _enter() {
    _leaving = false;
    unawaited(_backdrop.forward());
    unawaited(_springCard(1));
  }

  void _leave() {
    _leaving = true;
    unawaited(
      Future.wait([_backdrop.reverse().orCancel, _springCard(0).orCancel])
          .then((_) => _finishLeaving(), onError: (Object _) {}),
    );
  }

  void _finishLeaving() {
    if (!mounted || widget.isOpen) {
      return;
    }
    setState(() {
      _present = false;
      _leaving = false;
    });
  }

  TickerFuture _springCard(double target) {
    final start = _card.value;
    return _card.animateWith(
      SpringSimulation(
        AppMotion.spring,
        start,
        target,
        _card.velocity,
        tolerance: AppMotion.restTolerance(target - start),
        snapToEnd: true,
      ),
    );
  }

  Matrix4 _cardTransform(double progress) {
    final scale =
        BirthdayCard.hiddenScale + (1 - BirthdayCard.hiddenScale) * progress;
    final turn =
        (_leaving ? 1 : -1) *
        BirthdayCard.turnDegrees *
        (1 - progress) *
        math.pi /
        180;
    return Matrix4.diagonal3Values(scale, scale, 1)..rotateY(turn);
  }

  @override
  Widget build(BuildContext context) {
    if (!_present) {
      return const SizedBox.shrink();
    }
    return AboveAppChrome(
      child: AnimatedBuilder(
        animation: _backdropOpacity,
        builder: (context, child) => Opacity(
          opacity: _backdropOpacity.value.clamp(0.0, 1.0),
          child: child,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: _buildBackdrop(),
        ),
      ),
    );
  }

  Widget _buildBackdrop() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onClose,
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: BirthdayCard.backdropBlur,
            sigmaY: BirthdayCard.backdropBlur,
          ),
          child: ColoredBox(
            color: BirthdayCard.backdropColor,
            child: Padding(
              padding: const EdgeInsets.all(
                BirthdayCard.backdropPadding - BirthdayCard.closeOffset,
              ),
              child: Center(
                child: AnimatedBuilder(
                  animation: _card,
                  builder: (context, child) => Opacity(
                    opacity: _card.value.clamp(0.0, 1.0),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: _cardTransform(_card.value),
                      child: child,
                    ),
                  ),
                  child: _CardFrame(onClose: widget.onClose),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardFrame extends StatelessWidget {
  const _CardFrame({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(BirthdayCard.closeOffset),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: BirthdayCard.maxWidth),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: GradientPair(
                    tokens.card,
                    tokens.muted.slashOpacity(50),
                  ).tailwind(const CssGradientDirection.toBottomRight()),
                  borderRadius: BorderRadius.circular(BirthdayCard.radius),
                  border: Border.all(
                    color: tokens.border,
                    width: BirthdayCard.borderWidth,
                  ),
                  boxShadow: AppShadows.xl2,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    BirthdayCard.radius - BirthdayCard.borderWidth,
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CardHeader(),
                      Flexible(child: _CardBody()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(top: 0, right: 0, child: _CloseButton(onPressed: onClose)),
      ],
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader();

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 640;
    final padding = wide
        ? const EdgeInsets.fromLTRB(32, 32, 32, 48)
        : const EdgeInsets.fromLTRB(20, 20, 20, 40);
    final headingStyle = (wide ? AppText.xl3 : AppText.xl2)
        .copyWith(fontWeight: FontWeight.w700, color: tokens.foreground)
        .trackingTight;
    return ClipPath(
      clipper: const _NotchClipper(BirthdayCard.notchDepth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: BirthdayCard.headerGradient.tailwind(
            const CssGradientDirection.toBottomRight(),
          ),
        ),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            const Positioned(
              top: 16,
              left: 16,
              child: _GlowBlob(diameter: 80, blur: 40),
            ),
            const Positioned(
              bottom: 16,
              right: 32,
              child: _GlowBlob(diameter: 128, blur: 64),
            ),
            Padding(
              padding: padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Entrance(
                    fromOpacity: 1,
                    fromScale: 0,
                    delay: BirthdayCard.cakeDelay,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: BirthdayCard.cakeGap,
                      children: [
                        AppIcon(
                          LucideGlyph.cake,
                          size: BirthdayCard.cakeSize,
                          color: AppPalette.white,
                        ),
                        AppIcon(
                          LucideGlyph.cake,
                          size: BirthdayCard.cakeSize,
                          color: AppPalette.white,
                        ),
                        AppIcon(
                          LucideGlyph.cake,
                          size: BirthdayCard.cakeSize,
                          color: AppPalette.white,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: BirthdayCard.headingGap),
                  Text(
                    BirthdayCard.heading,
                    textAlign: TextAlign.center,
                    style: headingStyle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.diameter, required this.blur});

  final double diameter;
  final double blur;

  @override
  Widget build(BuildContext context) => ImageFiltered(
    imageFilter: ui.ImageFilter.blur(
      sigmaX: blur,
      sigmaY: blur,
      tileMode: TileMode.decal,
    ),
    child: SizedBox.square(
      dimension: diameter,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          color: BirthdayCard.blobColor,
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}

class _NotchClipper extends CustomClipper<Path> {
  const _NotchClipper(this.depth);

  final double depth;

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(size.width / 2, size.height - depth)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(_NotchClipper oldClipper) => oldClipper.depth != depth;
}

class _CardBody extends StatefulWidget {
  const _CardBody();

  @override
  State<_CardBody> createState() => _CardBodyState();
}

class _CardBodyState extends State<_CardBody> {
  bool _canScrollDown = false;

  bool _track(ScrollMetrics metrics) {
    final canScrollDown =
        metrics.maxScrollExtent - metrics.pixels >
        BirthdayCard.scrollableThreshold;
    if (canScrollDown != _canScrollDown) {
      setState(() => _canScrollDown = canScrollDown);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 640;
    final padding = wide
        ? const EdgeInsets.fromLTRB(32, 24, 32, 32)
        : const EdgeInsets.fromLTRB(20, 16, 20, 20);
    final bodyStyle = AppText.base.copyWith(color: tokens.foreground);
    final relaxedStyle = bodyStyle.copyWith(
      height: BirthdayCard.relaxedLineHeight,
    );
    final signatureStyle = bodyStyle.copyWith(
      color: BirthdayCard.signatureColor,
    );
    final content = NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) => _track(notification.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) => _track(notification.metrics),
        child: SingleChildScrollView(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: BirthdayCard.sectionGap,
            children: [
              Text(
                BirthdayCard.greeting,
                style: bodyStyle.copyWith(fontWeight: FontWeight.w500),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: BirthdayCard.paragraphGap,
                children: [
                  for (final paragraph in BirthdayCard.message)
                    Text(paragraph, style: relaxedStyle),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(
                  top: BirthdayCard.signatureTopPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: BirthdayCard.closingGap,
                  children: [
                    Text(BirthdayCard.closing, style: signatureStyle),
                    Text(BirthdayCard.signature, style: signatureStyle),
                  ],
                ),
              ),
              Text(
                BirthdayCard.postscript,
                style: bodyStyle.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppPalette.black,
          AppPalette.black,
          if (_canScrollDown) const Color(0x00000000) else AppPalette.black,
        ],
        stops: [
          0,
          bounds.height <= 0
              ? 0
              : math.max(
                  0,
                  (bounds.height - BirthdayCard.fadeMaskHeight) / bounds.height,
                ),
          1,
        ],
      ).createShader(bounds),
      child: content,
    );
  }
}

class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hover = AnimationController(
    vsync: this,
    duration: AppMotion.cssTransitionDuration,
  );

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  void _setHovered(bool hovered) =>
      _hover.animateTo(hovered ? 1 : 0, curve: AppMotion.cssTransitionCurve);

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return FocusableActionDetector(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        child: MouseRegion(
          onEnter: (_) => _setHovered(true),
          onExit: (_) => _setHovered(false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: AnimatedBuilder(
              animation: _hover,
              builder: (context, child) => Container(
                padding: const EdgeInsets.all(BirthdayCard.closePadding),
                decoration: BoxDecoration(
                  color: Oklab.mix(tokens.card, tokens.muted, _hover.value),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: tokens.border,
                    width: BirthdayCard.closeBorderWidth,
                  ),
                  boxShadow: AppShadows.lg,
                ),
                child: child,
              ),
              child: AppIcon(
                LucideGlyph.x,
                size: BirthdayCard.closeIconSize,
                color: tokens.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
