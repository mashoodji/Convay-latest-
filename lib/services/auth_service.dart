import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/App_user.dart';

class AuthService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of AppUser
  Stream<AppUser?> get user {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;

      final userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      if (!userDoc.exists) return null;

      return AppUser.fromMap(userDoc.data()!);
    });
  }

  // Get current user
  AppUser? get currentUser {
    final user = _auth.currentUser;
    return user != null
        ? AppUser(
      uid: user.uid,
      email: user.email ?? '',
      username: '', // Will be set during profile setup
    )
        : null;
  }

  // Email & Password Sign Up
  Future<AppUser?> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) return null;

      // Create user document in Firestore
      final appUser = AppUser(
        uid: user.uid,
        email: email,
        username: username,
      );

      await _firestore.collection('users').doc(user.uid).set(appUser.toMap());

      return appUser;
    } catch (e) {
      print("Sign up error: $e");
      return null;
    }
  }

  // Email & Password Sign In
  Future<AppUser?> signInWithEmail({
    required String email,
    required String password,
   }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) return null;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return null;

      return AppUser.fromMap(userDoc.data()!);
    } catch (e) {
      print("Sign in error: $e");
      return null;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}