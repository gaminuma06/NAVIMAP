import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class NaviMapUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;

  NaviMapUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ValueNotifier<NaviMapUser?> _userNotifier = ValueNotifier<NaviMapUser?>(null);

  NaviMapUser? get currentUser {
    try {
      final user = fb.FirebaseAuth.instance.currentUser;
      return user != null ? _mapFirebaseUser(user) : null;
    } catch (_) {
      return null;
    }
  }

  ValueNotifier<NaviMapUser?> get userNotifier => _userNotifier;

  Stream<NaviMapUser?> get authStateChanges {
    try {
      return fb.FirebaseAuth.instance.authStateChanges().map((user) {
        final mapped = user != null ? _mapFirebaseUser(user) : null;
        _userNotifier.value = mapped;
        return mapped;
      });
    } catch (_) {
      return Stream.value(null);
    }
  }

  NaviMapUser _mapFirebaseUser(fb.User user) {
    return NaviMapUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? user.email?.split('@')[0] ?? 'Usuario de NaviMap',
      photoUrl: user.photoURL,
    );
  }

  Future<NaviMapUser?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final fb.AuthCredential credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final fb.UserCredential userCredential =
          await fb.FirebaseAuth.instance.signInWithCredential(credential);
      
      final mapped = userCredential.user != null ? _mapFirebaseUser(userCredential.user!) : null;
      _userNotifier.value = mapped;
      return mapped;
    } catch (e) {
      debugPrint('Error en signInWithGoogle: $e');
      rethrow;
    }
  }

  Future<NaviMapUser?> signInWithEmail(String email, String password) async {
    try {
      final fb.UserCredential userCredential = await fb.FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      
      final mapped = userCredential.user != null ? _mapFirebaseUser(userCredential.user!) : null;
      _userNotifier.value = mapped;
      return mapped;
    } catch (e) {
      debugPrint('Error en signInWithEmail: $e');
      rethrow;
    }
  }

  Future<NaviMapUser?> signUpWithEmail(String email, String password) async {
    try {
      final fb.UserCredential userCredential = await fb.FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      
      final mapped = userCredential.user != null ? _mapFirebaseUser(userCredential.user!) : null;
      _userNotifier.value = mapped;
      return mapped;
    } catch (e) {
      debugPrint('Error en signUpWithEmail: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
      await fb.FirebaseAuth.instance.signOut();
      _userNotifier.value = null;
    } catch (e) {
      debugPrint('Error en signOut: $e');
    }
  }
}

