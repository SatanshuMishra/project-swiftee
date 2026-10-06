import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftie_quiz/domain/engine/achievements.dart';
import 'package:swiftie_quiz/domain/engine/misu_lines.dart';
import 'package:swiftie_quiz/domain/models/edition.dart';
import 'package:swiftie_quiz/domain/models/era.dart';
import 'package:swiftie_quiz/domain/models/game_types.dart';
import 'package:swiftie_quiz/domain/models/progress.dart';
import 'package:swiftie_quiz/domain/util/birthday.dart';
import 'package:swiftie_quiz/state/catalog_controller.dart';
import 'package:swiftie_quiz/state/edition_provider.dart';
import 'package:swiftie_quiz/state/game_controller.dart';
import 'package:swiftie_quiz/state/misu_controller.dart';
import 'package:swiftie_quiz/state/providers.dart';
import 'package:swiftie_quiz/ui/cat/cat_icon.dart';
import 'package:swiftie_quiz/ui/kit/arrow_row.dart';
import 'package:swiftie_quiz/ui/kit/pill_button.dart';
import 'package:swiftie_quiz/ui/kit/screen_enter.dart';
import 'package:swiftie_quiz/ui/kit/section_label.dart';
import 'package:swiftie_quiz/ui/kit/text_link.dart';
import 'package:swiftie_quiz/ui/kit/two_pane.dart';
import 'package:swiftie_quiz/ui/kit/vinyl.dart';
import 'package:swiftie_quiz/ui/overlays/birthday_card.dart';
import 'package:swiftie_quiz/ui/theme/app_layout.dart';
import 'package:swiftie_quiz/ui/theme/app_motion.dart';
import 'package:swiftie_quiz/ui/theme/app_tokens.dart';
import 'package:swiftie_quiz/ui/theme/app_type.dart';

final birthdayCardSessionProvider = NotifierProvider<BirthdayCardSession, bool>(
  BirthdayCardSession.new,
);

class BirthdayCardSession extends Notifier<bool> {
  @override
  bool build() => false;

  void markShown() => state = true;
}

typedef _Greeting = ({
  String opening,
  String name,
  String closing,
  String subline,
});

_Greeting _greetingFor(DateTime now, String name) => switch (DayPart.of(now)) {
  DayPart.morning => (
    opening: 'Good morning, ',
    name: name,
    closing: '.',
    subline: 'Coffee first, then a quiz.',
  ),
  DayPart.afternoon => (
    opening: 'Good afternoon, ',
    name: name,
    closing: '.',
    subline: 'Perfect time for a quick round.',
  ),
  DayPart.evening => (
    opening: 'Good evening, ',
    name: name,
    closing: '.',
    subline: "Long story short, it's a good night for a quiz.",
  ),
  DayPart.night => (
    opening: 'Still up, ',
    name: name,
    closing: '?',
    subline: 'Midnights, but make it a quiz.',
  ),
};

int _unlockedRecords(Map<String, AchievementState> achievements) =>
    achievementDefs
        .where((def) => achievements[def.id]?.unlocked ?? false)
        .length;

class MainMenu extends ConsumerStatefulWidget {
  const MainMenu({super.key});

  static const Duration greetDelay = Duration(milliseconds: 900);
  static const Duration birthdayCardDelay = Duration(seconds: 1);

  static const String shuffleTitle = 'Shuffle everything';
  static const String shuffleDescription = 'Every song, every era.';
  static const String erasTitle = 'Pick your eras';
  static const String erasDescription = 'Stick to the albums you love most.';
  static const String settingsLabel = 'Settings';
  static const String tonightLabel = "Tonight's era";
  static const String quickRoundLabel = 'A quick round of $quickRoundLength →';

  static String shelfLabel(int unlocked) =>
      'Record shelf · $unlocked of ${achievementDefs.length}';

  static const double leftTop = 48;
  static const double leftBottom = 40;
  static const double leftGap = 32;
  static const double greetingGap = 12;
  static const double headingLineHeight = 1;
  static const double rightTop = 24;
  static const double rightBottom = 40;
  static const double linksTop = 28;
  static const double linksSpacing = 28;
  static const double linksRunSpacing = 12;
  static const double tonightGap = 14;

  @override
  ConsumerState<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends ConsumerState<MainMenu> {
  Timer? _arrival;
  bool _cardOpen = false;

  @override
  void initState() {
    super.initState();
    _arrival = _scheduleArrival();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(gameControllerProvider).albums.isEmpty) {
        unawaited(ref.read(catalogControllerProvider.notifier).loadCatalogue());
      }
    });
  }

  @override
  void dispose() {
    _arrival?.cancel();
    super.dispose();
  }

  Timer? _scheduleArrival() {
    final cardShown = ref.read(birthdayCardSessionProvider);
    if (cardShown || ref.read(misuControllerProvider).greeted) {
      return null;
    }
    final opensCard =
        ref.read(editionProvider) == Edition.ana &&
        shouldAutoShowBirthdayCard(ref.read(clockProvider)(), cardShown);
    return opensCard
        ? Timer(MainMenu.birthdayCardDelay, _autoOpenCard)
        : Timer(MainMenu.greetDelay, _greet);
  }

  void _greet() {
    _arrival = null;
    ref.read(misuControllerProvider.notifier).greet(ref.read(clockProvider)());
  }

  void _autoOpenCard() {
    _arrival = null;
    ref.read(birthdayCardSessionProvider.notifier).markShown();
    _setCardOpen(true);
  }

  void _setCardOpen(bool open) => setState(() => _cardOpen = open);

  @override
  Widget build(BuildContext context) {
    final edition = ref.watch(editionProvider);
    final now = ref.watch(clockProvider)();
    final era = tonightsEra(now);
    final nickname = ref.watch(
      gameControllerProvider.select((game) => game.progress.settings.nickname),
    );
    final cover = ref.watch(
      gameControllerProvider.select(
        (game) => game.albums
            .firstWhereOrNull((album) => album.id == era.deezerAlbumId)
            ?.coverMedium,
      ),
    );
    final unlocked = ref.watch(
      gameControllerProvider.select(
        (game) => _unlockedRecords(game.progress.achievements),
      ),
    );
    final game = ref.read(gameControllerProvider.notifier);
    final ana = edition == Edition.ana;
    return Stack(
      fit: StackFit.expand,
      children: [
        ScreenEnter(
          child: TwoPane(
            left: FocusTraversalGroup(
              child: _MenuIntro(
                greeting: _greetingFor(now, displayName(edition, nickname)),
                birthday: ana
                    ? _BirthdayPrompt(onOpen: () => _setCardOpen(true))
                    : null,
                tonight: _TonightsEra(
                  era: era,
                  coverUrl: cover,
                  onTap: game.startQuickRound,
                ),
              ),
            ),
            right: FocusTraversalGroup(
              child: _MenuActions(
                unlocked: unlocked,
                onShuffle: () => game.beginSetup(GameMode.random),
                onEras: () {
                  game
                    ..setMode(GameMode.album)
                    ..setPhase(GamePhase.albumSelect);
                },
                onShelf: () => game.setPhase(GamePhase.recordShelf),
                onSettings: () => game.setPhase(GamePhase.settings),
              ),
            ),
          ),
        ),
        if (ana)
          BirthdayCard(isOpen: _cardOpen, onClose: () => _setCardOpen(false)),
      ],
    );
  }
}

class _MenuIntro extends StatelessWidget {
  const _MenuIntro({
    required this.greeting,
    required this.birthday,
    required this.tonight,
  });

  final _Greeting greeting;
  final Widget? birthday;
  final Widget tonight;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final layout = AppLayout.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        layout.padX,
        MainMenu.leftTop,
        layout.padX,
        MainMenu.leftBottom,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MainMenu.leftGap,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MainMenu.greetingGap,
            children: [
              Semantics(
                header: true,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: greeting.opening),
                      TextSpan(
                        text: greeting.name,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: tokens.coralT,
                        ),
                      ),
                      TextSpan(text: greeting.closing),
                    ],
                  ),
                  style: AppType.display(
                    layout.h1,
                    height: MainMenu.headingLineHeight,
                    color: tokens.fg,
                  ),
                ),
              ),
              Text(
                greeting.subline,
                style: AppType.bodyLarge.copyWith(color: tokens.mut),
              ),
            ],
          ),
          ?birthday,
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MainMenu.tonightGap,
            children: [const SectionLabel(MainMenu.tonightLabel), tonight],
          ),
        ],
      ),
    );
  }
}

class _BirthdayPrompt extends StatelessWidget {
  const _BirthdayPrompt({required this.onOpen});

  static const String message = "Misu's keeping your birthday card safe.";
  static const String action = 'Open it';
  static const String arrow = '→';
  static const double catHeight = 88;
  static const double gap = 16;
  static const double textGap = 6;
  static const double textBottom = 6;
  static const double arrowGap = 6;
  static const double hoverScale = 1.1;
  static const double pressScale = 0.95;
  static const Duration scaleDuration = Duration(milliseconds: 350);
  static const double nudge = 4;
  static const Duration nudgeDuration = Duration(milliseconds: 200);
  static const BorderRadius focusRadius = BorderRadius.all(Radius.circular(4));

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final actionStyle = AppType.sized(14, 20).copyWith(color: tokens.coralT);
    return _RiseIn(
      child: Pressable(
        onPressed: onOpen,
        focusRadius: focusRadius,
        builder: (context, state) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: gap,
          children: [
            AnimatedScale(
              scale: state.pressed
                  ? pressScale
                  : state.hovered
                  ? hoverScale
                  : 1,
              alignment: Alignment.bottomCenter,
              duration: AppMotion.duration(context, scaleDuration),
              curve: AppMotion.hoverLiftCurve,
              child: const CatIcon(height: catHeight),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: textBottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: textGap,
                  children: [
                    Text(
                      message,
                      style: AppType.display(
                        24,
                        height: 28 / 24,
                        color: tokens.fg,
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: state.hovered ? nudge : 0),
                      duration: AppMotion.duration(context, nudgeDuration),
                      curve: Curves.ease,
                      builder: (context, dx, child) => Transform.translate(
                        offset: Offset(dx, 0),
                        child: child,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: arrowGap,
                        children: [
                          Text(action, style: actionStyle),
                          Text(arrow, style: actionStyle),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiseIn extends StatefulWidget {
  const _RiseIn({required this.child});

  static const Duration delay = Duration(milliseconds: 400);
  static const Duration duration = Duration(milliseconds: 500);
  static const double offset = 8;

  final Widget child;

  @override
  State<_RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<_RiseIn> with SingleTickerProviderStateMixin {
  static final double _delayShare =
      _RiseIn.delay.inMicroseconds /
      (_RiseIn.delay + _RiseIn.duration).inMicroseconds;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _RiseIn.delay + _RiseIn.duration,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Interval(_delayShare, 1, curve: Curves.ease),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _progress,
    child: AnimatedBuilder(
      animation: _progress,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _RiseIn.offset * (1 - _progress.value)),
        child: child,
      ),
      child: widget.child,
    ),
  );
}

class _TonightsEra extends StatelessWidget {
  const _TonightsEra({
    required this.era,
    required this.coverUrl,
    required this.onTap,
  });

  static const double width = 128;
  static const double sleeveSize = 88;
  static const double discSize = 80;
  static const double discLeft = 44;
  static const double discTop = 4;
  static const double labelSize = 28;
  static const double gap = 16;
  static const double textGap = 4;
  static const double hoverOpacity = 0.9;
  static const BorderRadius focusRadius = BorderRadius.all(Radius.circular(4));
  static final VinylStyle discStyle = VinylStyle.standard.copyWith(hole: false);

  final Era era;
  final String? coverUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final placeholder = Color(era.placeholderArgb);
    return Pressable(
      onPressed: onTap,
      focusRadius: focusRadius,
      builder: (context, state) => Opacity(
        opacity: state.hovered ? hoverOpacity : 1,
        child: Row(
          spacing: gap,
          children: [
            SizedBox(
              width: width,
              height: sleeveSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: discLeft,
                    top: discTop,
                    child: VinylDisc(
                      size: discSize,
                      labelUrl: coverUrl,
                      labelColor: placeholder,
                      labelFraction: labelSize / discSize,
                      style: discStyle,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    child: AlbumSleeve(
                      size: sleeveSize,
                      coverUrl: coverUrl,
                      placeholder: placeholder,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: textGap,
                children: [
                  Text(
                    era.eraName,
                    style: AppType.display(
                      28,
                      italic: true,
                      height: 30 / 28,
                      color: tokens.fg,
                    ),
                  ),
                  Text(
                    MainMenu.quickRoundLabel,
                    style: AppType.small.copyWith(color: tokens.mut),
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

class _MenuActions extends StatelessWidget {
  const _MenuActions({
    required this.unlocked,
    required this.onShuffle,
    required this.onEras,
    required this.onShelf,
    required this.onSettings,
  });

  final int unlocked;
  final VoidCallback onShuffle;
  final VoidCallback onEras;
  final VoidCallback onShelf;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        layout.padX,
        MainMenu.rightTop,
        layout.padX,
        MainMenu.rightBottom,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ArrowRow(
            title: MainMenu.shuffleTitle,
            description: MainMenu.shuffleDescription,
            primary: true,
            onTap: onShuffle,
          ),
          ArrowRow(
            title: MainMenu.erasTitle,
            description: MainMenu.erasDescription,
            onTap: onEras,
          ),
          Padding(
            padding: const EdgeInsets.only(top: MainMenu.linksTop),
            child: Wrap(
              spacing: MainMenu.linksSpacing,
              runSpacing: MainMenu.linksRunSpacing,
              children: [
                TextLink(label: MainMenu.shelfLabel(unlocked), onTap: onShelf),
                TextLink(label: MainMenu.settingsLabel, onTap: onSettings),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
