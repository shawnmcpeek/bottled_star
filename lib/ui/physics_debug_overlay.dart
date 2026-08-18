import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/bottled_star_game.dart';
import '../game/element_tier.dart';
import '../game/element_tuning.dart';
import '../theme/game_colors.dart';
import '../theme/game_fonts.dart';

/// Live physics diagnostics for playtesting element scale (debug builds only).
class PhysicsDebugOverlay extends StatefulWidget {
  const PhysicsDebugOverlay({super.key, required this.game});

  final BottledStarGame game;

  @override
  State<PhysicsDebugOverlay> createState() => _PhysicsDebugOverlayState();
}

class _PhysicsDebugOverlayState extends State<PhysicsDebugOverlay> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode || !ElementTuning.showPhysicsDebug) {
      return const SizedBox.shrink();
    }

    final world = widget.game.world;
    final area = world.totalOccupiedArea;
    final fill = world.occupiedAreaFraction;
    final elapsed = world.runElapsedSeconds;
    final he = world.countForTier(ElementTier.helium);
    final fe = world.countForTier(ElementTier.iron);
    final scale = ElementTuning.elementScaleFor(widget.game.mode);

    return IgnorePointer(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 12, top: 120),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: GameColors.spaceDeep.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: GameColors.chamberGlow.withValues(alpha: 0.35),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: DefaultTextStyle(
                style: GameFonts.ui(
                  fontSize: 11,
                  color: GameColors.scoreText.withValues(alpha: 0.92),
                  height: 1.35,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PHYSICS DEBUG',
                      style: GameFonts.label(fontSize: 10),
                    ),
                    Text('scale  ${scale.toStringAsFixed(2)}'),
                    Text('shots  ${world.shotCount}'),
                    Text('bodies  ${world.nuclei.length}'),
                    Text('area Σπr²  ${area.toStringAsFixed(0)}'),
                    Text('fill  ${(fill * 100).toStringAsFixed(1)}%'),
                    Text('He  $he   Fe  $fe'),
                    Text('time  ${elapsed.toStringAsFixed(1)}s'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
