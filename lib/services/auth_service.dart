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
      // Check if username already exists
      final usernameQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      if (usernameQuery.docs.isNotEmpty) {
        throw Exception('Username already taken');
      }

      // Create user with Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) throw Exception('Failed to create user account');

      // Create user document in Firestore
      final appUser = AppUser(
        uid: user.uid,
        email: email,
        username: username,
      );

      await _firestore.collection('users').doc(user.uid).set(appUser.toMap());

      return appUser;
    } on firebase_auth.FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('Email already in use');
        case 'invalid-email':
          throw Exception('Invalid email address');
        case 'weak-password':
          throw Exception('Password is too weak');
        case 'operation-not-allowed':
          throw Exception('Email/password accounts are not enabled');
        default:
          throw Exception('Authentication error: ${e.message}');
      }
    } catch (e) {
      // Rethrow the exception to be handled by the UI
      rethrow;
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
      if (user == null) throw Exception('Failed to sign in');

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) throw Exception('User profile not found');

      return AppUser.fromMap(userDoc.data()!);
    } on firebase_auth.FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No user found with this email');
        case 'wrong-password':
          throw Exception('Incorrect password');
        case 'user-disabled':
          throw Exception('This account has been disabled');
        case 'invalid-email':
          throw Exception('Invalid email address');
        default:
          throw Exception('Authentication error: ${e.message}');
      }
    } catch (e) {
      // Rethrow the exception to be handled by the UI
      rethrow;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}