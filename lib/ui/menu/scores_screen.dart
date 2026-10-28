import 'package:flutter/material.dart';

import '../../game/modes/game_mode.dart';
import '../../game/systems/leaderboard_service.dart';
import '../../theme/game_colors.dart';
import '../../theme/game_fonts.dart';
import 'menu_page_scaffold.dart';

class ScoresScreen extends StatefulWidget {
  const ScoresScreen({super.key});

  @override
  State<ScoresScreen> createState() => _ScoresScreenState();
}

class _ScoresScreenState extends State<ScoresScreen>
    with SingleTickerProviderStateMixin {
  final LeaderboardService _boards = LeaderboardService();
  late final TabController _modeTab;
  late Future<_BoardBundle> _future;
  GameMode _mode = GameMode.classic;

  @override
  void initState() {
    super.initState();
    _modeTab = TabController(length: 2, vsync: this);
    _modeTab.addListener(() {
      if (_modeTab.indexIsChanging) return;
      final next =
          _modeTab.index == 0 ? GameMode.classic : GameMode.collapse;
      if (next == _mode) return;
      setState(() {
        _mode = next;
        _future = _load();
      });
    });
    _future = _load();
  }

  @override
  void dispose() {
    _modeTab.dispose();
    super.dispose();
  }

  Future<_BoardBundle> _load({bool force = false}) async {
    if (!_boards.isAvailable) {
      return const _BoardBundle.unavailable();
    }
    try {
      final results = await Future.wait([
        _boards.fetchDaily(mode: _mode, force: force),
        _boards.fetchAllTime(mode: _mode, force: force),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            controller: _modeTab,
            labelColor: GameColors.scoreText,
            unselectedLabelColor: GameColors.mutedText,
            indicatorColor: GameColors.chamberGlow,
            labelStyle: GameFonts.ui(fontSize: 15, weight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Classic'),
              Tab(text: 'Collapse'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
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
                          board: data.daily,
                        ),
                        const SizedBox(height: 28),
                        _BoardSection(
                          title: 'All-time',
                          subtitle: 'Top ${LeaderboardService.topN}',
                          board: data.allTime,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
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
      : daily = LeaderboardBoard.empty,
        allTime = LeaderboardBoard.empty,
        available = false;

  final LeaderboardBoard daily;
  final LeaderboardBoard allTime;
  final bool available;
}

class _BoardSection extends StatelessWidget {
  const _BoardSection({
    required this.title,
    required this.subtitle,
    required this.board,
  });

  final String title;
  final String subtitle;
  final LeaderboardBoard board;

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
        if (board.top.isEmpty)
          Text(
            'No scores yet',
            style: GameFonts.ui(
              fontSize: 15,
              color: GameColors.mutedText,
            ),
          )
        else
          for (final entry in board.top) ...[
            _ScoreRow(entry: entry),
            const SizedBox(height: 10),
          ],
        if (board.me case final me?) ...[
          Text(
            '···',
            textAlign: TextAlign.center,
            style: GameFonts.score(fontSize: 16, color: GameColors.mutedText),
          ),
          const SizedBox(height: 10),
          _ScoreRow(entry: me),
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
    final me = entry.isMe;
    return Row(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 28),
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              '${entry.rank}',
              style: GameFonts.score(
                fontSize: 16,
                weight: FontWeight.w600,
                color: me ? GameColors.chamberGlow : GameColors.rimMetal,
              ),
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
              color: me ? GameColors.chamberGlow : GameColors.scoreText,
            ),
          ),
        ),
        Text(
          entry.valueLabel,
          style: GameFonts.score(
            fontSize: 16,
            weight: FontWeight.w500,
            color: me ? GameColors.chamberGlow : GameColors.scoreText,
          ),
        ),
      ],
    );
  }
}
