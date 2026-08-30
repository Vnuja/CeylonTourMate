import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  User? _firebaseUser;
  AppUser? _appUser;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<AppUser?>? _profileSub;

  AuthProvider() {
    _authSub = _authService.authStateChanges.listen(_onAuthChanged);
  }

  User? get firebaseUser => _firebaseUser;
  AppUser? get appUser => _appUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _firebaseUser != null;

  void _onAuthChanged(User? user) {
    _firebaseUser = user;
    _profileSub?.cancel();
    if (user != null) {
      _profileSub = _userService.userProfileStream(user.uid).listen((profile) {
        _appUser = profile;
        notifyListeners();
      });
    } else {
      _appUser = null;
    }
    notifyListeners();
  }

  Future<bool> register({required String name, required String email, required String password}) async {
    _setLoading(true);
    try {
      final credential = await _authService.signUp(email: email, password: password);
      final uid = credential.user!.uid;
      await credential.user!.updateDisplayName(name);
      final newUser = AppUser(
        uid: uid,
        name: name,
        email: email,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _userService.createUserProfile(newUser);
      _errorMessage = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _authService.getErrorMessage(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _setLoading(true);
    try {
      await _authService.signIn(email: email, password: password);
      _errorMessage = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _authService.getErrorMessage(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() => _authService.signOut();

  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    try {
      await _authService.sendPasswordResetEmail(email);
      _errorMessage = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _authService.getErrorMessage(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Changes the signed-in user's password. Requires the current
  /// password to re-authenticate first (Firebase security requirement).
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    try {
      final email = _firebaseUser?.email;
      if (email == null) {
        _errorMessage = 'No email associated with this account.';
        return false;
      }
      await _authService.reauthenticate(email: email, currentPassword: currentPassword);
      await _authService.updatePassword(newPassword);
      _errorMessage = null;
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _authService.getErrorMessage(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateProfile({String? name, String? bio, String? photoBase64}) async {
    if (_firebaseUser == null) return;
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (bio != null) updates['bio'] = bio;
    if (photoBase64 != null) updates['photoBase64'] = photoBase64;
    if (updates.isNotEmpty) {
      await _userService.updateUserProfile(_firebaseUser!.uid, updates);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}