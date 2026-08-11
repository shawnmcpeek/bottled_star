import 'package:flutter/material.dart';

import '../../game/systems/achievement_defs.dart';
import '../../game/systems/achievement_store.dart';
import '../../theme/game_colors.dart';
import '../../theme/game_fonts.dart';
import 'menu_page_scaffold.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  @override
  void initState() {
    super.initState();
    AchievementStore.instance.load().then((_) {
      if (mounted) setState(() {});
    });
    AchievementStore.instance.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AchievementStore.instance.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AchievementStore.instance;
    final unlockedCount =
        AchievementId.values.where(store.isUnlocked).length;

    return MenuPageScaffold(
      title: 'Achievements',
      child: ListView(
        children: [
          Text(
            '$unlockedCount / ${AchievementId.values.length} unlocked',
            style: GameFonts.ui(
              fontSize: 13,
              color: GameColors.mutedText.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 20),
          for (final a in AchievementId.values) ...[
            _AchievementRow(
              achievement: a,
              unlocked: store.isUnlocked(a),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({
    required this.achievement,
    required this.unlocked,
  });

  final AchievementId achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final titleColor = unlocked ? GameColors.scoreText : GameColors.mutedText;
    final descColor = GameColors.mutedText.withValues(alpha: unlocked ? 0.9 : 0.55);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            unlocked ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 22,
            color: unlocked ? GameColors.chamberGlow : GameColors.mutedText,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                achievement.title,
                style: GameFonts.ui(
                  fontSize: 16,
                  weight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                achievement.description,
                style: GameFonts.ui(fontSize: 13, color: descColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
