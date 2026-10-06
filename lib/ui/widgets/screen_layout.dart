import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/back_link.dart';
import 'package:swiftie_quiz/ui/widgets/entrance.dart';
import 'package:swiftie_quiz/ui/widgets/screen_background.dart';

extension SpringTo on AnimationController {
  TickerFuture springTo(
    double target, [
    SpringDescription spring = AppMotion.spring,
  ]) {
    final start = value;
    return animateWith(
      SpringSimulation(
        spring,
        start,
        target,
        velocity,
        tolerance: AppMotion.restTolerance(target - start),
        snapToEnd: true,
      ),
    );
  }
}

abstract final class TailwindBreakpoints {
  static const double sm = 640;
  static const double md = 768;
  static const double lg = 1024;
}

abstract final class TailwindContainers {
  static const double xs = 320;
  static const double md = 448;
  static const double lg = 512;
  static const double xl2 = 672;
  static const double xl3 = 768;
  static const double xl4 = 896;
  static const double xl5 = 1024;
}

List<Widget> spacedVertically(List<Widget> children, double gap) => [
  for (var index = 0; index < children.length; index++) ...[
    if (index > 0) SizedBox(height: gap),
    children[index],
  ],
];

class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    super.key,
    required this.body,
    this.overlays = const [],
  });

  final Widget body;
  final List<Widget> overlays;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ScreenBackground(child: body),
        ...overlays,
      ],
    ),
  );
}

class CenteredScreen extends StatelessWidget {
  const CenteredScreen({
    super.key,
    required this.children,
    this.onBack,
    this.overlays = const [],
  });

  static const double horizontalPadding = 24;
  static const double gap = 32;
  static const double backInset = 32;

  final List<Widget> children;
  final VoidCallback? onBack;
  final List<Widget> overlays;

  @override
  Widget build(BuildContext context) => ScreenScaffold(
    overlays: overlays,
    body: Stack(
      fit: StackFit.passthrough,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: spacedVertically(children, gap),
          ),
        ),
        if (onBack case final onBack?)
          Positioned(
            left: backInset,
            top: backInset,
            child: BackLink(onPressed: onBack),
          ),
      ],
    ),
  );
}

class MaxWidthBox extends StatelessWidget {
  const MaxWidthBox({super.key, required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: SizedBox(width: double.infinity, child: child),
  );
}

class BackHeader extends StatelessWidget {
  const BackHeader({super.key, required this.maxWidth, required this.onBack});

  final double maxWidth;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => MaxWidthBox(
    maxWidth: maxWidth,
    child: Align(
      alignment: Alignment.centerLeft,
      child: BackLink(onPressed: onBack),
    ),
  );
}

class ScreenHeading extends StatelessWidget {
  const ScreenHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.footer,
  });

  static const Offset entranceOffset = Offset(0, -10);
  static const double subtitleGap = 8;
  static const double footerGap = 16;

  final String title;
  final String subtitle;
  final Widget? footer;

  static TextStyle titleStyle(AppTokens tokens) => AppText.xl4
      .copyWith(fontWeight: FontWeight.w700, color: tokens.foreground)
      .trackingTight;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Entrance(
      fromOffset: entranceOffset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, textAlign: TextAlign.center, style: titleStyle(tokens)),
          const SizedBox(height: subtitleGap),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppText.base.copyWith(color: tokens.mutedForeground),
          ),
          if (footer case final footer?) ...[
            const SizedBox(height: footerGap),
            footer,
          ],
        ],
      ),
    );
  }
}

@immutable
class GridColumns {
  const GridColumns(this.base, {this.sm, this.md, this.lg});

  final int base;
  final int? sm;
  final int? md;
  final int? lg;

  int forWindowWidth(double width) =>
      (width >= TailwindBreakpoints.lg ? lg : null) ??
      (width >= TailwindBreakpoints.md ? md : null) ??
      (width >= TailwindBreakpoints.sm ? sm : null) ??
      base;

  @override
  bool operator ==(Object other) =>
      other is GridColumns &&
      other.base == base &&
      other.sm == sm &&
      other.md == md &&
      other.lg == lg;

  @override
  int get hashCode => Object.hash(base, sm, md, lg);
}

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.columns,
    required this.gap,
    required this.maxWidth,
    required this.children,
  });

  final GridColumns columns;
  final double gap;
  final double maxWidth;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final count = columns.forWindowWidth(MediaQuery.sizeOf(context).width);
    final rows = [
      for (var start = 0; start < children.length; start += count)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var column = 0; column < count; column++) ...[
                if (column > 0) SizedBox(width: gap),
                Expanded(
                  child: start + column < children.length
                      ? children[start + column]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
    ];
    return MaxWidthBox(
      maxWidth: maxWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: spacedVertically(rows, gap),
      ),
    );
  }
}

class HoverTransition extends StatefulWidget {
  const HoverTransition({
    super.key,
    required this.builder,
    this.duration = AppMotion.cssTransitionDuration,
    this.cursor = MouseCursor.defer,
  });

  final Widget Function(BuildContext context, double hover) builder;
  final Duration duration;
  final MouseCursor cursor;

  @override
  State<HoverTransition> createState() => _HoverTransitionState();
}

class _HoverTransitionState extends State<HoverTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hover = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  void _setHovered(bool hovered) =>
      _hover.animateTo(hovered ? 1 : 0, curve: AppMotion.cssTransitionCurve);

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.cursor,
    onEnter: (_) => _setHovered(true),
    onExit: (_) => _setHovered(false),
    child: AnimatedBuilder(
      animation: _hover,
      builder: (context, _) => widget.builder(context, _hover.value),
    ),
  );
}

class PlainButton extends StatelessWidget {
  const PlainButton({
    super.key,
    required this.onPressed,
    required this.builder,
    this.duration = AppMotion.cssTransitionDuration,
    this.cursor = SystemMouseCursors.basic,
    this.autofocus = false,
  });

  final VoidCallback onPressed;
  final Widget Function(BuildContext context, double hover) builder;
  final Duration duration;
  final MouseCursor cursor;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    autofocus: autofocus,
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          onPressed();
          return null;
        },
      ),
    },
    child: Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: HoverTransition(
          duration: duration,
          cursor: cursor,
          builder: builder,
        ),
      ),
    ),
  );
}

abstract final class LocalDates {
  static const String invalidDate = 'Invalid Date';
  static const String _fallbackLocale = 'en_US';

  static Locale systemLocale(BuildContext context) =>
      View.of(context).platformDispatcher.locale;

  static String date(DateTime moment, Locale locale) =>
      DateFormat.yMd(_intlLocale(locale)).format(moment.toLocal());

  static String dateTime(DateTime moment, Locale locale) {
    final intlLocale = _intlLocale(locale);
    final local = moment.toLocal();
    return '${DateFormat.yMd(intlLocale).format(local)}, '
        '${DateFormat.jms(intlLocale).format(local)}';
  }

  static String isoDate(String iso, Locale locale) =>
      switch (DateTime.tryParse(iso)) {
        final moment? => date(moment, locale),
        null => invalidDate,
      };

  static String isoDateTime(String iso, Locale locale) =>
      switch (DateTime.tryParse(iso)) {
        final moment? => dateTime(moment, locale),
        null => invalidDate,
      };

  static String _intlLocale(Locale locale) {
    unawaited(initializeDateFormatting());
    return Intl.verifiedLocale(
      locale.toLanguageTag(),
      DateFormat.localeExists,
      onFailure: (_) => _fallbackLocale,
    )!;
  }
}
