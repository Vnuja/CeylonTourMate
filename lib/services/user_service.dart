import 'package:firebase_database/firebase_database.dart';
import '../models/app_user.dart';

class UserService {
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');

  Future<void> createUserProfile(AppUser user) {
    return _usersRef.child(user.uid).set(user.toMap());
  }

  Stream<AppUser?> userProfileStream(String uid) {
    return _usersRef.child(uid).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;
      return AppUser.fromMap(uid, Map<dynamic, dynamic>.from(data as Map));
    });
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> updates) {
    return _usersRef.child(uid).update(updates);
  }
}