import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/album_service.dart';
import '../models/photo_album.dart';
import '../models/album_photo.dart';
import '../theme/ceylon_theme.dart';
import 'photo_viewer_screen.dart';

class AlbumDetailScreen extends StatefulWidget {
  final String uid;
  final PhotoAlbum album;

  const AlbumDetailScreen({super.key, required this.uid, required this.album});

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  final _albumService = AlbumService();
  final _picker = ImagePicker();
  bool _uploading = false;
  int _uploadDone = 0;
  int _uploadTotal = 0;

  Future<void> _pickFromCamera() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 600,
      imageQuality: 40,
    );
    if (picked == null) return;
    await _uploadFiles([File(picked.path)]);
  }

  Future<void> _pickFromGalleryMultiple() async {
    // image_picker's pickMultiImage opens the native Photos/Gallery picker
    // (Android Photo Picker / iOS PHPicker) with thumbnail previews, unlike
    // file_picker which opens a generic file browser ("My Files").
    final picked = await _picker.pickMultiImage(
      maxWidth: 1600,
      imageQuality: 70,
    );
    if (picked.isEmpty) return;

    final files = picked.map((x) => File(x.path)).toList();
    await _uploadFiles(files);
  }

  Future<void> _uploadFiles(List<File> files) async {
    setState(() {
      _uploading = true;
      _uploadDone = 0;
      _uploadTotal = files.length;
    });

    try {
      await _albumService.addPhotosToAlbum(
        widget.uid,
        widget.album.id,
        files,
        onProgress: (done, total) {
          if (mounted) setState(() => _uploadDone = done);
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _showAddOptions() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              subtitle: const Text('Take a single photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              subtitle: const Text('Choose multiple photos from your gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
          ],
        ),
      ),
    );

    if (choice == 'camera') {
      await _pickFromCamera();
    } else if (choice == 'gallery') {
      await _pickFromGalleryMultiple();
    }
  }

  Future<void> _deletePhoto(AlbumPhoto photo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Remove this photo from the album?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await _albumService.deletePhoto(widget.uid, widget.album.id, photo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.album.name)),
      body: Column(
        children: [
          if (_uploading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _uploadTotal == 0 ? null : _uploadDone / _uploadTotal,
                    color: CeylonSpiceTheme.saffron,
                  ),
                  const SizedBox(height: 6),
                  Text('Uploading $_uploadDone of $_uploadTotal...'),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<AlbumPhoto>>(
              stream: _albumService.photosStream(widget.uid, widget.album.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final photos = snapshot.data!;
                if (photos.isEmpty) {
                  return const Center(child: Text('No photos yet. Tap + to add some.'));
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PhotoViewerScreen(
                              photos: photos,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                      onLongPress: () => _deletePhoto(photo),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(base64Decode(photo.data), fit: BoxFit.cover),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: CeylonSpiceTheme.cinnamon,
        onPressed: _uploading ? null : _showAddOptions,
        child: _uploading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.add_a_photo),
      ),
    );
  }
}