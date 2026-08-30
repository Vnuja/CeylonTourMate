import 'dart:convert';
import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';
import '../models/photo_album.dart';
import '../models/album_photo.dart';

class AlbumService {
  final DatabaseReference _albumsRef = FirebaseDatabase.instance.ref('albums');
  final DatabaseReference _photosRef = FirebaseDatabase.instance.ref('photos');
  final Uuid _uuid = const Uuid();

  Stream<List<PhotoAlbum>> albumsStream(String uid) {
    return _albumsRef.child(uid).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <PhotoAlbum>[];
      final map = Map<dynamic, dynamic>.from(data as Map);
      final albums = map.entries
          .map((e) => PhotoAlbum.fromMap(e.key.toString(), Map<dynamic, dynamic>.from(e.value)))
          .toList();
      albums.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return albums;
    });
  }

  Future<List<PhotoAlbum>> getAlbumsOnce(String uid) async {
    final snapshot = await _albumsRef.child(uid).get();
    if (!snapshot.exists) return [];
    final map = Map<dynamic, dynamic>.from(snapshot.value as Map);
    return map.entries
        .map((e) => PhotoAlbum.fromMap(e.key.toString(), Map<dynamic, dynamic>.from(e.value)))
        .toList();
  }

  Future<String> createAlbum(String uid, String name) async {
    final id = _uuid.v4();
    final album = PhotoAlbum(id: id, name: name, createdAt: DateTime.now().millisecondsSinceEpoch);
    await _albumsRef.child(uid).child(id).set(album.toMap());
    return id;
  }

  Future<void> deleteAlbum(String uid, String albumId) async {
    await _photosRef.child(uid).child(albumId).remove();
    await _albumsRef.child(uid).child(albumId).remove();
  }

  Stream<List<AlbumPhoto>> photosStream(String uid, String albumId) {
    return _photosRef.child(uid).child(albumId).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <AlbumPhoto>[];
      final map = Map<dynamic, dynamic>.from(data as Map);
      final photos = map.entries
          .map((e) => AlbumPhoto.fromMap(e.key.toString(), Map<dynamic, dynamic>.from(e.value)))
          .toList();
      photos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return photos;
    });
  }

  /// Reads [imageFile] and returns JPEG bytes with EXIF orientation baked
  /// into the actual pixel data. Camera/gallery photos often carry an EXIF
  /// "orientation" tag instead of physically rotated pixels; Image.memory
  /// ignores that tag, which is why photos show up sideways/upside-down
  /// after upload. Baking the orientation in here fixes that permanently.
  Future<List<int>> _normalizeOrientation(File imageFile) async {
    final rawBytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      // Not a decodable image (unexpected format) — fall back to raw bytes.
      return rawBytes;
    }
    final oriented = img.bakeOrientation(decoded);
    return img.encodeJpg(oriented, quality: 90);
  }

  /// Adds a single photo, returns the base64 data that was stored.
  Future<String> addPhotoToAlbum(String uid, String albumId, File imageFile) async {
    final bytes = await _normalizeOrientation(imageFile);
    final base64Data = base64Encode(bytes);
    final photoId = _uuid.v4();

    final photo = AlbumPhoto(
      id: photoId,
      data: base64Data,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _photosRef.child(uid).child(albumId).child(photoId).set(photo.toMap());

    final albumSnap = await _albumsRef.child(uid).child(albumId).get();
    if (albumSnap.exists) {
      final albumMap = Map<dynamic, dynamic>.from(albumSnap.value as Map);
      if ((albumMap['coverBase64'] ?? '').toString().isEmpty) {
        await _albumsRef.child(uid).child(albumId).update({'coverBase64': base64Data});
      }
    }
    return base64Data;
  }

  /// Adds multiple photos in sequence. [onProgress] reports (completed, total).
  Future<void> addPhotosToAlbum(
    String uid,
    String albumId,
    List<File> imageFiles, {
    void Function(int completed, int total)? onProgress,
  }) async {
    for (var i = 0; i < imageFiles.length; i++) {
      await addPhotoToAlbum(uid, albumId, imageFiles[i]);
      onProgress?.call(i + 1, imageFiles.length);
    }
  }

  Future<void> deletePhoto(String uid, String albumId, AlbumPhoto photo) async {
    await _photosRef.child(uid).child(albumId).child(photo.id).remove();
    await _refreshCover(uid, albumId);
  }

  /// Recomputes the album's cover thumbnail after a deletion: uses the
  /// newest remaining photo, or clears the cover if the album is now empty.
  /// Without this, a deleted photo's thumbnail would keep showing on the
  /// Albums screen forever since coverBase64 was only ever set once.
  Future<void> _refreshCover(String uid, String albumId) async {
    final snapshot = await _photosRef.child(uid).child(albumId).get();
    String newCover = '';
    if (snapshot.exists) {
      final map = Map<dynamic, dynamic>.from(snapshot.value as Map);
      final photos = map.entries
          .map((e) => AlbumPhoto.fromMap(e.key.toString(), Map<dynamic, dynamic>.from(e.value)))
          .toList();
      if (photos.isNotEmpty) {
        photos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        newCover = photos.first.data;
      }
    }
    await _albumsRef.child(uid).child(albumId).update({'coverBase64': newCover});
  }
}