import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../models/fixture.dart';
import '../../models/fixture_event.dart';
import '../../models/favorite.dart';
import '../../models/sport.dart';
import '../../providers/fixture_detail_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/fixtures_provider.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/fixture/live_badge.dart';
import '../../widgets/fixture/score_display.dart';
import 'sections/stats_section.dart';
import 'sections/h2h_section.dart';
import 'sections/standings_section.dart';

class FixtureDetailScreen extends StatefulWidget {
  final int fixtureId;
  final SportType sport;
  final Fixture? initialFixture;

  const FixtureDetailScreen({
    super.key,
    required this.fixtureId,
    required this.sport,
    this.initialFixture,
  });

  @override
  State<FixtureDetailScreen> createState() => _FixtureDetailScreenState();
}

class _FixtureDetailScreenState extends State<FixtureDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<FixtureDetailProvider>()
          .fetchDetail(widget.sport, widget.fixtureId, initialFixture: widget.initialFixture);
    });
  }

  @override
  Widget build(BuildContext context) {
    final detailProvider = context.watch<FixtureDetailProvider>();
    final fixture = detailProvider.fixture ?? widget.initialFixture;
    final favoritesProvider = context.watch<FavoritesProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          fixture?.league.name ?? 'Match Details',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (fixture != null)
            IconButton(
              icon: Icon(
                favoritesProvider.isFavorite(widget.sport, widget.fixtureId)
                    ? Icons.star
                    : Icons.star_outline,
                color: favoritesProvider.isFavorite(
                        widget.sport, widget.fixtureId)
                    ? Colors.amber
                    : AppColors.textSecondary,
              ),
              onPressed: () {
                favoritesProvider.toggle(Favorite.match(
                  sport: widget.sport,
                  matchId: widget.fixtureId,
                  displayName:
                      '${fixture.homeTeam.name} vs ${fixture.awayTeam.name}',
                ));
              },
            ),
        ],
      ),
      body: fixture == null && detailProvider.state == LoadingState.loading
          ? const LoadingIndicator()
          : fixture == null && detailProvider.state == LoadingState.error
              ? AppErrorWidget(
                  message: detailProvider.errorMessage ?? 'Failed to load',
                  onRetry: () => detailProvider.fetchDetail(
                      widget.sport, widget.fixtureId, initialFixture: widget.initialFixture),
                )
              : fixture == null
                  ? const SizedBox.shrink()
                  : _buildContent(fixture, detailProvider),
    );
  }

  Widget _buildContent(Fixture fixture, FixtureDetailProvider provider) {
    final hasStats = provider.stats != null && provider.stats!.isNotEmpty;
    final hasH2H = provider.h2h.isNotEmpty;
    final hasStandings = provider.standings.isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        children: [
          if (widget.sport == SportType.formula1)
            _F1Header(fixture: fixture)
          else
            _ScoreHeader(fixture: fixture),
          const SizedBox(height: 8),
          if (hasStats)
            StatsSection(stats: provider.stats!, fixture: fixture),
          if (hasH2H) H2HSection(entries: provider.h2h),
          if (hasStandings)
            StandingsSection(
              rows: provider.standings,
              fixture: fixture,
              season: provider.standingsSeason,
            ),
          const SizedBox(height: 4),
          _buildEvents(fixture, provider),
        ],
      ),
    );
  }

  Widget _buildEvents(Fixture fixture, FixtureDetailProvider provider) {
    if (widget.sport == SportType.formula1 && provider.events.isNotEmpty) {
      return _F1RaceEvents(events: provider.events);
    }
    if (widget.sport == SportType.formula1) {
      return _F1SessionInfo(fixture: fixture);
    }
    if (widget.sport == SportType.football) {
      return _EventsList(events: provider.events);
    }
    if (widget.sport == SportType.basketball && provider.events.isNotEmpty) {
      return _BasketballPlayByPlay(events: provider.events, fixture: fixture);
    }
    if (widget.sport == SportType.basketball) {
      return _BasketballScoreBreakdown(fixture: fixture);
    }
    if (widget.sport == SportType.hockey && provider.events.isNotEmpty) {
      return _HockeyPlayByPlay(events: provider.events, fixture: fixture);
    }
    if (widget.sport == SportType.baseball && provider.events.isNotEmpty) {
      return _BaseballPlayByPlay(events: provider.events, fixture: fixture);
    }
    if (widget.sport == SportType.handball && provider.events.isNotEmpty) {
      return _HandballPlayByPlay(events: provider.events);
    }
    if (widget.sport == SportType.tennis) {
      return _TennisEvents(
          events: provider.events,
          loading: provider.state == LoadingState.loading);
    }
    return _GenericMatchInfo(fixture: fixture);
  }
}

class _ScoreHeader extends StatelessWidget {
  final Fixture fixture;

  const _ScoreHeader({required this.fixture});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: fixture.status.isLive
              ? AppColors.live.withValues(alpha: 0.3)
              : AppColors.border,
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          if (fixture.status.isLive) ...[
            const LiveBadge(),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(child: _TeamInfo(
                name: fixture.homeTeam.name,
                logo: fixture.homeTeam.logo,
                sport: fixture.sport,
              )),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ScoreDisplay(fixture: fixture, fontSize: 32),
              ),
              Expanded(child: _TeamInfo(
                name: fixture.awayTeam.name,
                logo: fixture.awayTeam.logo,
                sport: fixture.sport,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _statusText(fixture),
            style: TextStyle(
              color: fixture.status.isLive
                  ? AppColors.accent
                  : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _statusText(Fixture fixture) {
    if (fixture.status.isLive) {
      final detail = fixture.statusDetail;
      final elapsed = fixture.elapsed;
      final perPeriod = fixture.sport == SportType.basketball ||
          fixture.sport == SportType.hockey ||
          fixture.sport == SportType.baseball ||
          fixture.sport == SportType.handball;

      if (perPeriod && detail != null && detail.isNotEmpty) {
        return elapsed != null ? "$detail · $elapsed'" : detail;
      }
      if (elapsed != null) return "$elapsed' - ${fixture.status.display}";
      return fixture.status.display;
    }
    if (fixture.status.isFinished) return 'Full Time';
    if (fixture.status.isNotStarted) {
      final local = fixture.date.toLocal();
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return fixture.status.display;
  }
}

class _TeamInfo extends StatelessWidget {
  final String name;
  final String? logo;
  final SportType sport;

  const _TeamInfo({required this.name, this.logo, required this.sport});

  @override
  Widget build(BuildContext context) {
    // Tennis has no logos/icons — only names.
    final isTennis = sport == SportType.tennis;
    return Column(
      children: [
        if (!isTennis) ...[
          if (logo != null)
            CachedNetworkImage(
              imageUrl: logo!,
              width: 48,
              height: 48,
              placeholder: (_, __) => const SizedBox(width: 48, height: 48),
              errorWidget: (_, __, ___) =>
                  const Icon(Icons.shield, size: 48, color: AppColors.textSecondary),
            )
          else
            const Icon(Icons.shield, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 8),
        ],
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EventsList extends StatelessWidget {
  final List<FixtureEvent> events;

  const _EventsList({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const EmptyState(
        icon: Icons.timeline,
        message: 'No events available yet',
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return _EventTile(event: event);
      },
    );
  }
}

class _EventTile extends StatelessWidget {
  final FixtureEvent event;

  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: event.isGoal
            ? AppColors.accent.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.3),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              event.timeDisplay,
              style: TextStyle(
                color: event.isGoal ? AppColors.accent : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(
            _eventIcon(event),
            size: 18,
            color: _eventColor(event),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.playerName ?? event.detail ?? event.type,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (event.assistName != null)
                  Text(
                    'Assist: ${event.assistName}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                if (event.detail != null && event.playerName != null)
                  Text(
                    event.detail!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            event.teamName ?? '',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  IconData _eventIcon(FixtureEvent e) {
    if (e.isGoal) return Icons.sports_soccer;
    if (e.isCard) {
      return e.detail?.contains('Yellow') == true
          ? Icons.square
          : Icons.square;
    }
    if (e.isSubstitution) return Icons.swap_horiz;
    if (e.isVar) return Icons.visibility;
    return Icons.circle;
  }

  Color _eventColor(FixtureEvent e) {
    if (e.isGoal) return AppColors.accent;
    if (e.isCard) {
      return e.detail?.contains('Yellow') == true
          ? Colors.amber
          : AppColors.live;
    }
    if (e.isSubstitution) return Colors.cyan;
    if (e.isVar) return Colors.purple;
    return AppColors.textSecondary;
  }
}

class _BasketballScoreBreakdown extends StatelessWidget {
  final Fixture fixture;

  const _BasketballScoreBreakdown({required this.fixture});

  @override
  Widget build(BuildContext context) {
    final periods = fixture.score.periods;
    if (periods == null || periods.isEmpty) {
      return const EmptyState(
        icon: Icons.sports_basketball,
        message: 'Score breakdown not available yet',
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SCORE BY QUARTER',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(
              children: [
                _quarterRow('', 'Q1', 'Q2', 'Q3', 'Q4', 'T', isHeader: true),
                const Divider(height: 1, color: AppColors.border),
                _quarterRow(
                  fixture.homeTeam.name,
                  periods['quarter_1']?[0]?.toString() ?? '-',
                  periods['quarter_2']?[0]?.toString() ?? '-',
                  periods['quarter_3']?[0]?.toString() ?? '-',
                  periods['quarter_4']?[0]?.toString() ?? '-',
                  fixture.score.homeTotal?.toString() ?? '-',
                ),
                const Divider(height: 1, color: AppColors.border),
                _quarterRow(
                  fixture.awayTeam.name,
                  periods['quarter_1']?[1]?.toString() ?? '-',
                  periods['quarter_2']?[1]?.toString() ?? '-',
                  periods['quarter_3']?[1]?.toString() ?? '-',
                  periods['quarter_4']?[1]?.toString() ?? '-',
                  fixture.score.awayTotal?.toString() ?? '-',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quarterRow(
      String team, String q1, String q2, String q3, String q4, String total,
      {bool isHeader = false}) {
    final style = TextStyle(
      color: isHeader ? AppColors.textSecondary : AppColors.textPrimary,
      fontSize: 13,
      fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(team, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          ...[q1, q2, q3, q4, total].map(
            (v) => Expanded(
              child: Text(v, textAlign: TextAlign.center, style: style),
            ),
          ),
        ],
      ),
    );
  }
}

class _BaseballPlayByPlay extends StatelessWidget {
  final List<FixtureEvent> events;
  final Fixture fixture;

  const _BaseballPlayByPlay({
    required this.events,
    required this.fixture,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const EmptyState(
        icon: Icons.sports_baseball,
        message: 'No play-by-play data available',
      );
    }

    final innings = <int, List<FixtureEvent>>{};
    for (final event in events) {
      final inning = event.elapsed ?? 1;
      innings.putIfAbsent(inning, () => []).add(event);
    }
    final sortedKeys = innings.keys.toList()..sort();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final inningNum = sortedKeys[index];
        final inningEvents = innings[inningNum] ?? [];
        return _InningSection(inning: inningNum, events: inningEvents);
      },
    );
  }
}

class _InningSection extends StatelessWidget {
  final int inning;
  final List<FixtureEvent> events;

  const _InningSection({
    required this.inning,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            inning > 100 ? '▼ Bot ${inning - 100}' : '▲ Top $inning',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border, width: 0.3),
          ),
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: events.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final event = events[index];
              return _BaseballEventTile(event: event);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _BaseballEventTile extends StatelessWidget {
  final FixtureEvent event;

  const _BaseballEventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _baseballEventIcon(event),
            size: 16,
            color: _baseballEventColor(event),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.type,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (event.playerName != null)
                  Text(
                    'Batter: ${event.playerName}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                if (event.assistName != null)
                  Text(
                    'Pitcher: ${event.assistName}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                if (event.comments != null)
                  Text(
                    'Count: ${event.comments}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                if (event.detail != null)
                  Text(
                    event.detail!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _baseballEventIcon(FixtureEvent event) {
    return switch (event.type) {
      'Home Run' => Icons.star,
      'Strikeout' => Icons.block,
      'Walk' => Icons.check,
      'Out' => Icons.close,
      'Single' || 'Double' || 'Triple' => Icons.trending_up,
      'Pitch' => Icons.circle_outlined,
      _ => Icons.sports_baseball,
    };
  }

  Color _baseballEventColor(FixtureEvent event) {
    return switch (event.type) {
      'Home Run' => AppColors.accent,
      'Out' => AppColors.live,
      'Strikeout' => Colors.amber,
      'Single' || 'Double' || 'Triple' => Colors.cyan,
      _ => AppColors.textSecondary,
    };
  }
}

class _BasketballPlayByPlay extends StatelessWidget {
  final List<FixtureEvent> events;
  final Fixture fixture;

  const _BasketballPlayByPlay({required this.events, required this.fixture});

  @override
  Widget build(BuildContext context) {
    final quarters = <int, List<FixtureEvent>>{};
    for (final event in events) {
      final q = event.elapsed ?? 1;
      quarters.putIfAbsent(q, () => []).add(event);
    }
    final sortedKeys = quarters.keys.toList()..sort();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final quarter = sortedKeys[index];
        final quarterEvents = quarters[quarter] ?? [];
        final label = quarter <= 4 ? 'Q$quarter' : 'OT${quarter - 4}';
        return _PeriodSection(
          label: label,
          events: quarterEvents,
          icon: Icons.sports_basketball,
          sportColor: Colors.orange,
        );
      },
    );
  }
}

class _HockeyPlayByPlay extends StatelessWidget {
  final List<FixtureEvent> events;
  final Fixture fixture;

  const _HockeyPlayByPlay({required this.events, required this.fixture});

  @override
  Widget build(BuildContext context) {
    final periods = <int, List<FixtureEvent>>{};
    for (final event in events) {
      final p = event.elapsed ?? 1;
      periods.putIfAbsent(p, () => []).add(event);
    }
    final sortedKeys = periods.keys.toList()..sort();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final period = sortedKeys[index];
        final periodEvents = periods[period] ?? [];
        final label = period <= 3 ? 'Period $period' : 'OT${period - 3}';
        return _PeriodSection(
          label: label,
          events: periodEvents,
          icon: Icons.sports_hockey,
          sportColor: Colors.lightBlue,
        );
      },
    );
  }
}

class _HandballPlayByPlay extends StatelessWidget {
  final List<FixtureEvent> events;

  const _HandballPlayByPlay({required this.events});

  @override
  Widget build(BuildContext context) {
    final periods = <int, List<FixtureEvent>>{};
    for (final event in events) {
      final p = event.elapsed ?? 1;
      periods.putIfAbsent(p, () => []).add(event);
    }
    final sortedKeys = periods.keys.toList()..sort();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final period = sortedKeys[index];
        final periodEvents = periods[period] ?? [];
        final label = period <= 2 ? 'Half $period' : 'OT${period - 2}';
        return _PeriodSection(
          label: label,
          events: periodEvents,
          icon: Icons.sports_handball,
          sportColor: const Color(0xFFFF5722),
        );
      },
    );
  }
}

class _TennisEvents extends StatelessWidget {
  final List<FixtureEvent> events;
  final bool loading;

  const _TennisEvents({required this.events, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      if (loading) return const LoadingIndicator();
      return const EmptyState(
        icon: Icons.sports_tennis,
        message: 'No commentary available yet',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final event = events[index];
        return _TennisEventTile(event: event);
      },
    );
  }
}

class _TennisEventTile extends StatelessWidget {
  final FixtureEvent event;

  const _TennisEventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final isPeriod = event.type == 'Period';
    final title = event.detail?.isNotEmpty == true ? event.detail! : event.type;
    final score = event.comments?.trim() ?? '';
    final hasScore = score.replaceAll('-', '').trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isPeriod ? AppColors.surface : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.border,
          width: isPeriod ? 0.6 : 0.3,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: isPeriod ? 14 : 13,
                fontWeight: isPeriod ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (hasScore)
            Text(
              score,
              style: TextStyle(
                color: isPeriod ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: isPeriod ? 14 : 12,
                fontWeight: isPeriod ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

class _PeriodSection extends StatelessWidget {
  final String label;
  final List<FixtureEvent> events;
  final IconData icon;
  final Color sportColor;

  const _PeriodSection({
    required this.label,
    required this.events,
    required this.icon,
    required this.sportColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border, width: 0.3),
          ),
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: events.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final event = events[index];
              return _SportEventTile(event: event, icon: icon, sportColor: sportColor);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SportEventTile extends StatelessWidget {
  final FixtureEvent event;
  final IconData icon;
  final Color sportColor;

  const _SportEventTile({
    required this.event,
    required this.icon,
    required this.sportColor,
  });

  @override
  Widget build(BuildContext context) {
    final isGoal = event.type == 'Goal' || event.type == 'Field Goal' ||
        event.type == 'Three Pointer' || event.type == 'Dunk' ||
        event.type == 'Layup' || event.type == 'Free Throw';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isGoal ? icon : Icons.circle,
            size: 16,
            color: isGoal ? sportColor : AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      event.type,
                      style: TextStyle(
                        color: isGoal ? sportColor : AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (event.comments != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        event.comments!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                if (event.teamName != null)
                  Text(
                    event.teamName!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                if (event.detail != null)
                  Text(
                    event.detail!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _F1Header extends StatelessWidget {
  final Fixture fixture;

  const _F1Header({required this.fixture});

  @override
  Widget build(BuildContext context) {
    final raceType = fixture.awayTeam.name;
    final circuit = fixture.homeTeam.name;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(
            raceType.toLowerCase().contains('race') || raceType.toLowerCase().contains('sprint')
                ? Icons.flag
                : raceType.toLowerCase().contains('qualifying')
                    ? Icons.timer
                    : Icons.speed,
            size: 48,
            color: raceType.toLowerCase().contains('race')
                ? Colors.red
                : raceType.toLowerCase().contains('sprint')
                    ? Colors.orange
                    : raceType.toLowerCase().contains('qualifying')
                        ? Colors.amber
                        : AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            raceType,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            circuit,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: fixture.status.isFinished
                  ? AppColors.textSecondary.withValues(alpha: 0.15)
                  : fixture.status.isLive
                      ? AppColors.accent.withValues(alpha: 0.15)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              fixture.status.isFinished
                  ? 'Completed'
                  : fixture.status.isLive
                      ? 'In Progress'
                      : _formatDateTime(fixture.date),
              style: TextStyle(
                color: fixture.status.isLive
                    ? AppColors.accent
                    : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final local = date.toLocal();
    return '${local.day}/${local.month}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _F1RaceEvents extends StatelessWidget {
  final List<FixtureEvent> events;

  const _F1RaceEvents({required this.events});

  @override
  Widget build(BuildContext context) {
    // Group events by type category. Race control and pit stops are
    // time-ordered by the API (oldest → newest) — reverse so the most
    // recent appears at the top. Positions (P1, P2, ...) are standings,
    // not time-based, so keep their natural order.
    final raceControl = events.where((e) =>
        e.type == 'Safety Car' || e.type == 'VSC' || e.type == 'Red Flag' ||
        e.type == 'Penalty' || e.type == 'Chequered Flag' || e.type == 'Race Control')
        .toList()
        .reversed
        .toList();
    final pitStops = events.where((e) => e.type == 'Pit Stop').toList().reversed.toList();
    final positions = events.where((e) => e.type.startsWith('P')).toList();

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Podium / Final positions
        if (positions.isNotEmpty) ...[
          const _F1SectionLabel(label: 'RESULTS'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border, width: 0.3),
            ),
            child: Column(
              children: [
                for (int i = 0; i < positions.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.border),
                  _F1PositionTile(event: positions[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Race control events
        if (raceControl.isNotEmpty) ...[
          const _F1SectionLabel(label: 'RACE CONTROL'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border, width: 0.3),
            ),
            child: Column(
              children: [
                for (int i = 0; i < raceControl.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.border),
                  _F1RaceControlTile(event: raceControl[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Pit stops
        if (pitStops.isNotEmpty) ...[
          const _F1SectionLabel(label: 'PIT STOPS'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border, width: 0.3),
            ),
            child: Column(
              children: [
                for (int i = 0; i < pitStops.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.border),
                  _F1PitStopTile(event: pitStops[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _F1SectionLabel extends StatelessWidget {
  final String label;
  const _F1SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _F1PositionTile extends StatelessWidget {
  final FixtureEvent event;
  const _F1PositionTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final position = event.type; // "P1", "P2", etc.
    final posNum = int.tryParse(position.substring(1)) ?? 99;
    final color = posNum == 1 ? Colors.amber : posNum == 2 ? Colors.grey.shade300 : posNum == 3 ? Colors.brown.shade300 : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              position,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (posNum <= 3)
            Icon(Icons.emoji_events, size: 18, color: color)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.detail ?? '',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (event.teamName != null)
                  Text(
                    event.teamName!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _F1RaceControlTile extends StatelessWidget {
  final FixtureEvent event;
  const _F1RaceControlTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    switch (event.type) {
      case 'Safety Car':
      case 'VSC':
        icon = Icons.warning_amber;
        color = Colors.amber;
      case 'Red Flag':
        icon = Icons.flag;
        color = Colors.red;
      case 'Penalty':
        icon = Icons.gavel;
        color = Colors.red.shade300;
      case 'Chequered Flag':
        icon = Icons.flag;
        color = AppColors.textPrimary;
      default:
        icon = Icons.info_outline;
        color = AppColors.textSecondary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.type,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (event.detail != null)
                  Text(
                    event.detail!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _F1PitStopTile extends StatelessWidget {
  final FixtureEvent event;
  const _F1PitStopTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.build, size: 16, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.playerName ?? '',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (event.teamName != null)
                  Text(
                    event.teamName!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          if (event.detail != null)
            Text(
              event.detail!,
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

class _F1SessionInfo extends StatelessWidget {
  final Fixture fixture;

  const _F1SessionInfo({required this.fixture});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SESSION INFO',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(
              children: [
                _infoRow('Grand Prix', fixture.league.name),
                if (fixture.league.country != null)
                  _infoRow('Country', fixture.league.country!),
                if (fixture.venue != null)
                  _infoRow('Circuit', fixture.venue!),
                _infoRow('Session', fixture.awayTeam.name),
                _infoRow('Status', fixture.status.display),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenericMatchInfo extends StatelessWidget {
  final Fixture fixture;

  const _GenericMatchInfo({required this.fixture});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MATCH INFO',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(
              children: [
                _infoRow('League', fixture.league.name),
                if (fixture.league.country != null)
                  _infoRow('Country', fixture.league.country!),
                if (fixture.venue != null)
                  _infoRow('Venue', fixture.venue!),
                _infoRow('Status', fixture.status.display),
              ],
            ),
          ),
          if (fixture.score.periods != null &&
              fixture.score.periods!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'SCORE BREAKDOWN',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(
                children: fixture.score.periods!.entries.map((entry) {
                  final label = entry.key
                      .replaceAll('_', ' ')
                      .split(' ')
                      .map((w) =>
                          w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
                      .join(' ');
                  return _infoRow(
                    label,
                    '${entry.value[0] ?? '-'} - ${entry.value[1] ?? '-'}',
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
