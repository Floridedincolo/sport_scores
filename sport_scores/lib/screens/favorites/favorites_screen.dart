import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/favorite.dart';
import '../../providers/favorites_provider.dart';
import '../../widgets/common/empty_state.dart';
import '../fixture/fixture_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favoritesProvider = context.watch<FavoritesProvider>();
    final matchFavs = favoritesProvider.matchFavorites;
    final leagueFavs = favoritesProvider.leagueFavorites;

    if (matchFavs.isEmpty && leagueFavs.isEmpty) {
      return const Column(
        children: [
          SizedBox(height: 60),
          EmptyState(
            icon: Icons.star_outline,
            message:
                'No favorites yet.\nStar matches or leagues to follow them here.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 4, top: 8),
          child: Text(
            'Favorites',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (matchFavs.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'FOLLOWED MATCHES',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          ...matchFavs.map(
            (f) => Dismissible(
              key: ValueKey(f.compositeKey),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_outline, color: AppColors.error),
              ),
              onDismissed: (_) => favoritesProvider.toggle(f),
              child: _FavoriteTile(
                favorite: f,
                icon: Icons.sports,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FixtureDetailScreen(
                      fixtureId: f.entityId,
                      sport: f.sport,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        if (leagueFavs.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'FOLLOWED LEAGUES',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          ...leagueFavs.map(
            (f) => Dismissible(
              key: ValueKey(f.compositeKey),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_outline, color: AppColors.error),
              ),
              onDismissed: (_) => favoritesProvider.toggle(f),
              child: _FavoriteTile(
                favorite: f,
                icon: Icons.emoji_events,
                onTap: () {},
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  final Favorite favorite;
  final IconData icon;
  final VoidCallback onTap;

  const _FavoriteTile({
    required this.favorite,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    favorite.displayName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    favorite.sport.name[0].toUpperCase() + favorite.sport.name.substring(1),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
