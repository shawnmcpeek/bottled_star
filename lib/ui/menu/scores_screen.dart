import 'package:flutter/material.dart';

import '../../game/systems/leaderboard_service.dart';
import '../../theme/game_colors.dart';
import '../../theme/game_fonts.dart';
import 'menu_page_scaffold.dart';

class ScoresScreen extends StatefulWidget {
  const ScoresScreen({super.key});

  @override
  State<ScoresScreen> createState() => _ScoresScreenState();
}

class _ScoresScreenState extends State<ScoresScreen> {
  final LeaderboardService _boards = LeaderboardService();
  late Future<_BoardBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_BoardBundle> _load({bool force = false}) async {
    if (!_boards.isAvailable) {
      return const _BoardBundle.unavailable();
    }
    try {
      final results = await Future.wait([
        _boards.fetchDaily(force: force),
        _boards.fetchAllTime(force: force),
      ]);
      return _BoardBundle(
        daily: results[0],
        allTime: results[1],
        available: true,
      );
    } catch (_) {
      return const _BoardBundle.unavailable();
    }
  }

  void _refresh() {
    setState(() {
      _future = _load(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MenuPageScaffold(
      title: 'Scores',
      child: FutureBuilder<_BoardBundle>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(
                color: GameColors.chamberGlow,
              ),
            );
          }
          final data = snap.data ?? const _BoardBundle.unavailable();
          return RefreshIndicator(
            color: GameColors.chamberGlow,
            backgroundColor: GameColors.spaceDeep,
            onRefresh: () async => _refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Text(
                  'Daily boards reset at 00:00 UTC',
                  style: GameFonts.ui(
                    fontSize: 12,
                    color: GameColors.mutedText.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 22),
                if (!data.available)
                  Text(
                    'Leaderboards unavailable offline.',
                    style: GameFonts.prose(
                      fontSize: 15,
                      color: GameColors.mutedText,
                    ),
                  )
                else ...[
                  _BoardSection(
                    title: 'Daily',
                    subtitle: LeaderboardService.utcDayKey(),
                    entries: data.daily,
                  ),
                  const SizedBox(height: 28),
                  _BoardSection(
                    title: 'All-time',
                    subtitle: 'Top ${LeaderboardService.topN}',
                    entries: data.allTime,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BoardBundle {
  const _BoardBundle({
    required this.daily,
    required this.allTime,
    required this.available,
  });

  const _BoardBundle.unavailable()
      : daily = const [],
        allTime = const [],
        available = false;

  final List<LeaderboardEntry> daily;
  final List<LeaderboardEntry> allTime;
  final bool available;
}

class _BoardSection extends StatelessWidget {
  const _BoardSection({
    required this.title,
    required this.subtitle,
    required this.entries,
  });

  final String title;
  final String subtitle;
  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GameFonts.label(fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GameFonts.ui(
            fontSize: 13,
            color: GameColors.mutedText.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Text(
            'No scores yet',
            style: GameFonts.ui(
              fontSize: 15,
              color: GameColors.mutedText,
            ),
          )
        else
          for (final entry in entries) ...[
            _ScoreRow(entry: entry),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            '${entry.rank}',
            style: GameFonts.score(
              fontSize: 16,
              weight: FontWeight.w600,
              color: GameColors.rimMetal,
            ),
          ),
        ),
        Expanded(
          child: Text(
            entry.displayName,
            overflow: TextOverflow.ellipsis,
            style: GameFonts.ui(
              fontSize: 16,
              weight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          '${entry.score}',
          style: GameFonts.score(
            fontSize: 16,
            weight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
