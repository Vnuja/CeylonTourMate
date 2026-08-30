class AlbumPhoto {
  final String id;
  final String data;
  final String caption;
  final int createdAt;

  AlbumPhoto({
    required this.id,
    required this.data,
    this.caption = '',
    required this.createdAt,
  });

  factory AlbumPhoto.fromMap(String id, Map<dynamic, dynamic> map) {
    return AlbumPhoto(
      id: id,
      data: map['data'] ?? '',
      caption: map['caption'] ?? '',
      createdAt: map['createdAt'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {'data': data, 'caption': caption, 'createdAt': createdAt};
  }
}