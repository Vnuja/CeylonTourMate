import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signUp({required String email, required String password}) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signIn({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// Firebase requires a recent sign-in before sensitive actions like
  /// changing a password. This re-proves identity with the current password.
  Future<void> reauthenticate({required String email, required String currentPassword}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user', message: 'No signed-in user found.');
    }
    final credential = EmailAuthProvider.credential(email: email, password: currentPassword);
    await user.reauthenticateWithCredential(credential);
  }

  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user', message: 'No signed-in user found.');
    }
    await user.updatePassword(newPassword);
  }

  String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'invalid-credential':
        return 'Incorrect current password.';
      case 'requires-recent-login':
        return 'Please sign out and sign in again, then retry.';
      case 'no-current-user':
        return 'No signed-in user found.';
      default:
        return e.message ?? 'An unknown error occurred.';
    }
  }
}