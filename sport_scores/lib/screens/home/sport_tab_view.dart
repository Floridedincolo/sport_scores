import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../models/sport.dart';
import '../../models/fixture.dart';
import '../../models/league.dart';
import '../../providers/fixtures_provider.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/fixture/fixture_card.dart';
import '../../widgets/fixture/live_badge.dart';
import '../fixture/fixture_detail_screen.dart';

class SportTabView extends StatefulWidget {
  final SportType sport;

  const SportTabView({super.key, required this.sport});

  @override
  State<SportTabView> createState() => _SportTabViewState();
}

class _SportTabViewState extends State<SportTabView> {
  bool _showAllUpcoming = false;
  bool _showAllFinished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void didUpdateWidget(SportTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sport != widget.sport) {
      _showAllUpcoming = false;
      _showAllFinished = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
    }
  }

  void _loadData() {
    final fixturesProvider = context.read<FixturesProvider>();
    fixturesProvider.refreshAll(widget.sport);
  }

  @override
  Widget build(BuildContext context) {
    final fixturesProvider = context.watch<FixturesProvider>();

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: () async {
        await fixturesProvider.refreshAll(widget.sport);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Live section
          if (fixturesProvider.liveState == LoadingState.loaded &&
              fixturesProvider.liveFixtures.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionHeader(
              title: 'LIVE NOW',
              trailing: const LiveBadge(),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: fixturesProvider.liveFixtures.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final fixture = fixturesProvider.liveFixtures[index];
                  return SizedBox(
                    width: 220,
                    child: FixtureCard(
                      fixture: fixture,
                      onTap: () => _openFixture(fixture),
                    ),
                  );
                },
              ),
            ),
          ],

          // F1: show upcoming/finished instead of date strip
          if (widget.sport == SportType.formula1) ...[
            const SizedBox(height: 16),
            if (fixturesProvider.dateState == LoadingState.loading)
              const LoadingIndicator()
            else if (fixturesProvider.dateState == LoadingState.error)
              AppErrorWidget(
                message: fixturesProvider.errorMessage ?? 'Failed to load',
                onRetry: () => fixturesProvider.fetchAllF1Races(),
              )
            else ...[
              // Upcoming races
              () {
                final upcoming = fixturesProvider.dateFixtures
                    .where((f) => f.status.isNotStarted)
                    .toList();
                if (upcoming.isEmpty) return const SizedBox.shrink();
                final visible = _showAllUpcoming ? upcoming : upcoming.take(3).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(title: 'UPCOMING RACES'),
                    const SizedBox(height: 8),
                    ...visible.map(
                      (f) => _F1RaceItem(
                        fixture: f,
                        onTap: () => _openFixture(f),
                      ),
                    ),
                    if (upcoming.length > 3 && !_showAllUpcoming)
                      _SeeMoreButton(
                        count: upcoming.length - 3,
                        onTap: () => setState(() => _showAllUpcoming = true),
                      ),
                  ],
                );
              }(),
              const SizedBox(height: 20),
              // Finished races
              () {
                final finished = fixturesProvider.dateFixtures
                    .where((f) => f.status.isFinished)
                    .toList()
                    .reversed
                    .toList();
                if (finished.isEmpty) return const SizedBox.shrink();
                final visible = _showAllFinished ? finished : finished.take(3).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(title: 'FINISHED RACES'),
                    const SizedBox(height: 8),
                    ...visible.map(
                      (f) => _F1RaceItem(
                        fixture: f,
                        onTap: () => _openFixture(f),
                      ),
                    ),
                    if (finished.length > 3 && !_showAllFinished)
                      _SeeMoreButton(
                        count: finished.length - 3,
                        onTap: () => setState(() => _showAllFinished = true),
                      ),
                  ],
                );
              }(),
              if (fixturesProvider.dateFixtures.isEmpty)
                const EmptyState(
                  icon: Icons.sports_motorsports,
                  message: 'No races found',
                ),
            ],
          ] else ...[
            // Date picker strip (non-F1 sports)
            const SizedBox(height: 20),
            _DateStrip(
              selectedDate: fixturesProvider.selectedDate,
              onDateSelected: (date) {
                fixturesProvider.fetchDateFixtures(widget.sport, date: date);
              },
            ),

            // League filter chips
            if (fixturesProvider.dateState == LoadingState.loaded &&
                fixturesProvider.availableLeagues.length > 1) ...[
              const SizedBox(height: 12),
              _LeagueFilterChips(
                leagues: fixturesProvider.availableLeagues,
                selectedLeague: fixturesProvider.selectedLeague,
                onSelected: (league) => fixturesProvider.selectLeague(league),
              ),
            ],

            // Fixtures for selected date
            const SizedBox(height: 16),
            if (fixturesProvider.dateState == LoadingState.loading)
              const LoadingIndicator()
            else if (fixturesProvider.dateState == LoadingState.error)
              AppErrorWidget(
                message: fixturesProvider.errorMessage ?? 'Failed to load',
                onRetry: () => fixturesProvider.fetchDateFixtures(widget.sport),
              )
            else if (fixturesProvider.filteredFixtures.isEmpty)
              const EmptyState(
                icon: Icons.sports,
                message: 'No matches found',
              )
            else
              ...fixturesProvider.filteredByLeague.entries.map(
                (entry) => _LeagueFixtureGroup(
                  league: entry.key,
                  fixtures: entry.value,
                  onFixtureTap: _openFixture,
                ),
              ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _openFixture(Fixture fixture) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FixtureDetailScreen(
          fixtureId: fixture.id,
          sport: fixture.sport,
          initialFixture: fixture,
        ),
      ),
    );
  }
}

/// Horizontal scrollable date strip: past 7 days + today + next 3 days.
class _DateStrip extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _DateStrip({
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    // Only yesterday, today, tomorrow — API only reliably supports this window.
    final dates = List.generate(3, (i) {
      return DateTime(today.year, today.month, today.day - 1 + i);
    });

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = date.year == selectedDate.year &&
              date.month == selectedDate.month &&
              date.day == selectedDate.day;
          final isToday = date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;

          return GestureDetector(
            onTap: () => onDateSelected(date),
            child: Container(
              width: 60,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isToday && !isSelected
                      ? AppColors.accent.withValues(alpha: 0.5)
                      : AppColors.border,
                  width: isToday && !isSelected ? 1.5 : 0.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isToday ? 'TODAY' : DateFormat('E').format(date).toUpperCase(),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.black
                          : AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      color: isSelected
                          ? Colors.black
                          : AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(date).toUpperCase(),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.black
                          : AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Horizontal scrollable league filter chips.
class _LeagueFilterChips extends StatelessWidget {
  final List<League> leagues;
  final League? selectedLeague;
  final ValueChanged<League?> onSelected;

  const _LeagueFilterChips({
    required this.leagues,
    required this.selectedLeague,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: leagues.length + 1, // +1 for "All" chip
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = selectedLeague == null;
            return GestureDetector(
              onTap: () => onSelected(null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accent : AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? AppColors.accent : AppColors.border,
                    width: 0.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'All',
                  style: TextStyle(
                    color: isSelected ? Colors.black : AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }

          final league = leagues[index - 1];
          final isSelected = selectedLeague?.id == league.id;
          return GestureDetector(
            onTap: () => onSelected(isSelected ? null : league),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent : AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? AppColors.accent : AppColors.border,
                  width: 0.5,
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (league.logo != null) ...[
                    CachedNetworkImage(
                      imageUrl: league.logo!,
                      width: 18,
                      height: 18,
                      placeholder: (_, __) => const SizedBox(width: 18, height: 18),
                      errorWidget: (_, __, ___) => const SizedBox(width: 18, height: 18),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    league.name,
                    style: TextStyle(
                      color: isSelected ? Colors.black : AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

class _LeagueFixtureGroup extends StatelessWidget {
  final League league;
  final List<Fixture> fixtures;
  final ValueChanged<Fixture> onFixtureTap;

  const _LeagueFixtureGroup({
    required this.league,
    required this.fixtures,
    required this.onFixtureTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (league.countryFlag != null &&
                  !league.countryFlag!.endsWith('.svg')) ...[
                Image.network(
                  league.countryFlag!,
                  width: 16,
                  height: 12,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  league.country != null && league.country!.isNotEmpty
                      ? '${league.country} - ${league.name}'
                      : league.name,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...fixtures.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: FixtureCard(
                fixture: f,
                onTap: () => onFixtureTap(f),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// F1 race item with a clear date header and the race card below.
class _F1RaceItem extends StatelessWidget {
  final Fixture fixture;
  final VoidCallback onTap;

  const _F1RaceItem({required this.fixture, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final local = fixture.date.toLocal();
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(local);
    final timeStr = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 2),
            child: Text(
              '$dateStr  ·  $timeStr',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          FixtureCard(fixture: fixture, onTap: onTap),
        ],
      ),
    );
  }
}

/// "See more" button for collapsed lists.
class _SeeMoreButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _SeeMoreButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Center(
            child: Text(
              'See $count more',
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
