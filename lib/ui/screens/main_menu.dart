import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/util/birthday.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/ui/cat/cat_icon_button.dart';
import 'package:swiftie_quiz/ui/overlays/birthday_card.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_theme.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/widgets/app_icon.dart';
import 'package:swiftie_quiz/ui/widgets/entrance.dart';
import 'package:swiftie_quiz/ui/widgets/screen_layout.dart';
import 'package:swiftie_quiz/ui/widgets/selection_card.dart';
import 'package:swiftie_quiz/ui/widgets/swiftie_logo.dart';

final birthdayCardSessionProvider = NotifierProvider<BirthdayCardSession, bool>(
  BirthdayCardSession.new,
);

class BirthdayCardSession extends Notifier<bool> {
  @override
  bool build() => false;

  void markShown() => state = true;
}

class MainMenu extends ConsumerStatefulWidget {
  const MainMenu({super.key});

  static const Duration birthdayCardDelay = Duration(seconds: 1);
  static const double catInset = 24;
  static const double logoGap = 16;
  static const double subtitleGap = 8;
  static const double gridGap = 24;

  static TextStyle titleStyle(AppTokens tokens) => AppText.xl5
      .copyWith(fontWeight: FontWeight.w800, color: tokens.foreground)
      .trackingTight;

  @override
  ConsumerState<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends ConsumerState<MainMenu> {
  bool _birthdayCardOpen = false;
  Timer? _autoShow;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider)();
    if (shouldAutoShowBirthdayCard(
      now,
      ref.read(birthdayCardSessionProvider),
    )) {
      _autoShow = Timer(MainMenu.birthdayCardDelay, _autoShowBirthdayCard);
    }
  }

  @override
  void dispose() {
    _autoShow?.cancel();
    super.dispose();
  }

  void _autoShowBirthdayCard() {
    _setBirthdayCardOpen(true);
    ref.read(birthdayCardSessionProvider.notifier).markShown();
  }

  void _setBirthdayCardOpen(bool open) =>
      setState(() => _birthdayCardOpen = open);

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final game = ref.read(gameControllerProvider.notifier);
    return CenteredScreen(
      overlays: [
        Positioned(
          top: MainMenu.catInset,
          right: MainMenu.catInset,
          child: BirthdayCatButton(onTap: () => _setBirthdayCardOpen(true)),
        ),
        BirthdayCard(
          isOpen: _birthdayCardOpen,
          onClose: () => _setBirthdayCardOpen(false),
        ),
      ],
      children: [
        Entrance(
          fromScale: 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SwiftieLogo(),
              const SizedBox(height: MainMenu.logoGap),
              Text(
                'Swiftie Quiz',
                textAlign: TextAlign.center,
                style: MainMenu.titleStyle(tokens),
              ),
              const SizedBox(height: MainMenu.subtitleGap),
              Text(
                "How well do you know Taylor's music?",
                textAlign: TextAlign.center,
                style: AppText.base.copyWith(color: tokens.mutedForeground),
              ),
            ],
          ),
        ),
        ResponsiveGrid(
          columns: const GridColumns(1, md: 2),
          gap: MainMenu.gridGap,
          maxWidth: TailwindContainers.xl2,
          children: [
            SelectionCard(
              glyph: LucideGlyph.music,
              title: 'Random Mode',
              description: 'All songs, shuffled randomly',
              gradient: AppGradients.violet,
              delay: const Duration(milliseconds: 100),
              onTap: () {
                game.setMode(GameMode.random);
                game.setPhase(GamePhase.setup);
              },
            ),
            SelectionCard(
              glyph: LucideGlyph.album,
              title: 'Pick Albums',
              description: 'Choose your favorite albums',
              gradient: AppGradients.pink,
              delay: const Duration(milliseconds: 200),
              onTap: () {
                game.setMode(GameMode.album);
                game.setPhase(GamePhase.albumSelect);
              },
            ),
            SelectionCard(
              glyph: LucideGlyph.award,
              title: 'Cat Gallery',
              description: 'View your achievements',
              gradient: AppGradients.orange,
              delay: const Duration(milliseconds: 300),
              onTap: () => game.setPhase(GamePhase.recordShelf),
            ),
            SelectionCard(
              glyph: LucideGlyph.settings,
              title: 'Settings',
              description: 'Theme, volume & more',
              gradient: AppGradients.cyan,
              delay: const Duration(milliseconds: 400),
              onTap: () => game.setPhase(GamePhase.settings),
            ),
          ],
        ),
      ],
    );
  }
}

class BirthdayCatButton extends StatefulWidget {
  const BirthdayCatButton({super.key, required this.onTap});

  static const String tooltip = 'Birthday Card';
  static const double size = 64;
  static const Duration entranceDelay = Duration(milliseconds: 800);
  static const double hoverScale = 1.1;
  static const double tapScale = 0.95;
  static const SpringDescription gestureSpring = SpringDescription(
    mass: 1,
    stiffness: 400,
    damping: 20,
  );
  static const double tooltipDrop = 28;
  static const EdgeInsets tooltipPadding = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 4,
  );

  final VoidCallback onTap;

  @override
  State<BirthdayCatButton> createState() => _BirthdayCatButtonState();
}

class _BirthdayCatButtonState extends State<BirthdayCatButton>
    with TickerProviderStateMixin {
  late final AnimationController _tooltip = AnimationController(
    vsync: this,
    duration: AppMotion.cssTransitionDuration,
  );
  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  bool _hovered = false;
  bool _pressed = false;
  double _scaleTarget = 1;

  @override
  void dispose() {
    _tooltip.dispose();
    _scale.dispose();
    super.dispose();
  }

  void _setHovered(bool hovered) {
    _hovered = hovered;
    _tooltip.animateTo(hovered ? 1 : 0, curve: AppMotion.cssTransitionCurve);
    _syncScale();
  }

  void _setPressed(bool pressed) {
    _pressed = pressed;
    _syncScale();
  }

  void _syncScale() {
    final target = _pressed
        ? BirthdayCatButton.tapScale
        : _hovered
        ? BirthdayCatButton.hoverScale
        : 1.0;
    if (target == _scaleTarget) {
      return;
    }
    _scaleTarget = target;
    unawaited(
      _scale.springTo(
        target,
        target == 1 ? AppMotion.spring : BirthdayCatButton.gestureSpring,
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse ||
        event.buttons == kPrimaryMouseButton) {
      _setPressed(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        MouseRegion(
          onEnter: (_) => _setHovered(true),
          onExit: (_) => _setHovered(false),
          child: Listener(
            onPointerDown: _handlePointerDown,
            onPointerUp: (_) => _setPressed(false),
            onPointerCancel: (_) => _setPressed(false),
            child: Entrance(
              fromScale: 0,
              delay: BirthdayCatButton.entranceDelay,
              child: AnimatedBuilder(
                animation: _scale,
                builder: (context, child) =>
                    Transform.scale(scale: _scale.value, child: child),
                child: CatIconButton(
                  onTap: widget.onTap,
                  size: BirthdayCatButton.size,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: -BirthdayCatButton.tooltipDrop,
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _tooltip,
              child: Container(
                padding: BirthdayCatButton.tooltipPadding,
                decoration: BoxDecoration(
                  color: tokens.card,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: tokens.border),
                  boxShadow: AppShadows.lg,
                ),
                child: Text(
                  BirthdayCatButton.tooltip,
                  softWrap: false,
                  style: AppText.xs.copyWith(color: tokens.mutedForeground),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
