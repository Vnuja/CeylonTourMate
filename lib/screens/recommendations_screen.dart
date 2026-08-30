import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../services/album_service.dart';
import '../services/recommendation_service.dart';
import '../models/photo_album.dart';
import '../models/destination.dart';
import '../theme/ceylon_theme.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final _albumService = AlbumService();
  final List<Destination> _shown = [];
  List<String> _signals = [];
  bool _initialized = false;

  void _initializeIfNeeded(List<String> signals) {
    if (_initialized) return;
    _signals = signals;
    _shown.addAll(RecommendationService.getRecommendations(signals));
    _initialized = true;
  }

  void _loadMore() {
    setState(() {
      final more = RecommendationService.suggestMore(
        _signals,
        _shown.map((d) => d.name).toList(),
        count: 4,
      );
      _shown.addAll(more);
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<app_auth.AuthProvider>().firebaseUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Explore Sri Lanka')),
      body: StreamBuilder<List<PhotoAlbum>>(
        stream: _albumService.albumsStream(uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final signals = snapshot.data!.map((a) => a.name).toList();
          _initializeIfNeeded(signals);

          final hasMore = _shown.length < RecommendationService.allDestinations.length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Recommended For You', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'Handpicked destinations across Sri Lanka worth adding to your trip.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              ..._shown.map((dest) => _DestinationCard(destination: dest)),
              const SizedBox(height: 8),
              if (hasMore)
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _loadMore,
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Show More Places'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  final Destination destination;

  const _DestinationCard({required this.destination});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CeylonSpiceTheme.darkCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: CeylonSpiceTheme.deepJungle,
            child: Icon(destination.icon, color: CeylonSpiceTheme.saffron),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(destination.name, style: Theme.of(context).textTheme.bodyLarge),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: CeylonSpiceTheme.cinnamon.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        destination.category,
                        style: const TextStyle(fontSize: 11, color: CeylonSpiceTheme.saffron),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(destination.description, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}