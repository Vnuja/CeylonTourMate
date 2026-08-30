class AppUser {
  final String uid;
  final String name;
  final String email;
  final String photoBase64;
  final String bio;
  final int createdAt;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.photoBase64 = '',
    this.bio = '',
    required this.createdAt,
  });

  factory AppUser.fromMap(String uid, Map<dynamic, dynamic> map) {
    return AppUser(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoBase64: map['photoBase64'] ?? '',
      bio: map['bio'] ?? '',
      createdAt: map['createdAt'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoBase64': photoBase64,
      'bio': bio,
      'createdAt': createdAt,
    };
  }
}