class PhotoAlbum {
  final String id;
  final String name;
  final String coverBase64;
  final int createdAt;

  PhotoAlbum({
    required this.id,
    required this.name,
    this.coverBase64 = '',
    required this.createdAt,
  });

  factory PhotoAlbum.fromMap(String id, Map<dynamic, dynamic> map) {
    return PhotoAlbum(
      id: id,
      name: map['name'] ?? '',
      coverBase64: map['coverBase64'] ?? '',
      createdAt: map['createdAt'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'coverBase64': coverBase64, 'createdAt': createdAt};
  }
}