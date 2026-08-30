import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../services/album_service.dart';
import '../models/photo_album.dart';
import '../theme/ceylon_theme.dart';
import 'album_detail_screen.dart';

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  final _albumService = AlbumService();

  Future<void> _createAlbum(String uid) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Album'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Album name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await _albumService.createAlbum(uid, name);
    }
  }

  Future<void> _deleteAlbum(String uid, PhotoAlbum album) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Album'),
        content: Text('Delete "${album.name}" and all its photos?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await _albumService.deleteAlbum(uid, album.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<app_auth.AuthProvider>().firebaseUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('My Albums')),
      body: StreamBuilder<List<PhotoAlbum>>(
        stream: _albumService.albumsStream(uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final albums = snapshot.data!;
          if (albums.isEmpty) {
            return const Center(child: Text('No albums yet. Tap + to create one.'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AlbumDetailScreen(uid: uid, album: album)),
                ),
                onLongPress: () => _deleteAlbum(uid, album),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          color: CeylonSpiceTheme.darkCard,
                          width: double.infinity,
                          child: album.coverBase64.isNotEmpty
                              ? Image.memory(base64Decode(album.coverBase64), fit: BoxFit.cover)
                              : const Icon(Icons.photo_album, size: 48),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(album.name, style: Theme.of(context).textTheme.bodyLarge, overflow: TextOverflow.ellipsis),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: CeylonSpiceTheme.cinnamon,
        onPressed: () => _createAlbum(uid),
        child: const Icon(Icons.add),
      ),
    );
  }
}