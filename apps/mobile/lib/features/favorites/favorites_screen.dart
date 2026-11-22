import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supa.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../widgets/common.dart';
import '../search/search_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<ProCard>> _future = ProRepo.instance.favorites();

  Future<void> _reload() async {
    setState(() => _future = ProRepo.instance.favorites());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.myFavorites)),
      body: FutureBuilder<List<ProCard>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorState(error: snap.error!, onRetry: _reload);
          if (!snap.hasData) return const LoadingView();
          final items = snap.data!;
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.favorite_border_rounded,
              title: l.noFavorites,
              message: l.noFavoritesHint,
              action: l.findPro,
              onAction: () => context.go('/search'),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (_, i) => ProListTile(
                pro: items[i],
                trailing: FavoriteButton(proId: items[i].id, initial: true),
              ),
            ),
          );
        },
      ),
    );
  }
}
