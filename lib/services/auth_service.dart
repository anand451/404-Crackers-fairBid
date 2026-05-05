import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';

class AuthService {
  static const String adminEmail = 'admin@gmail.com';

  AuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _log('Attempting sign in for ${email.trim()}');
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _ensureUserProfileForSignIn(credential.user);
      _log('Sign in success for ${email.trim()}');
      return credential;
    } on FirebaseAuthException catch (error) {
      _log('Sign in failed [${error.code}] ${error.message}');
      throw _mapAuthException(error);
    } on FirebaseException catch (_) {
      _log('Sign in failed due to Firestore/network issue');
      throw 'We could not reach FairBid services. Please try again.';
    } catch (_) {
      _log('Sign in failed due to unexpected issue');
      throw 'Something went wrong while signing in. Please try again.';
    }
  }

  Future<UserCredential> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String aadhaarNumber,
    required String panNumber,
    required DateTime dateOfBirth,
    required String password,
    required String userType,
  }) async {
    UserCredential? credential;

    try {
      _log('Creating auth user for ${email.trim()}');
      credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw 'Account created, but we could not finish signing you in.';
      }

      final profile = UserModel(
        uid: user.uid,
        fullName: fullName.trim(),
        email: (user.email ?? email).trim(),
        phoneNumber: phoneNumber.trim(),
        aadhaarNumber: aadhaarNumber.trim(),
        panNumber: panNumber.trim().toUpperCase(),
        dateOfBirth: dateOfBirth,
        createdAt: DateTime.now(),
        userType: userType,
        role: _resolveRole(email.trim()),
      );

      _log('Writing user profile for ${user.uid}');
      await user.getIdToken(true);
      await _firestore.collection('users').doc(user.uid).set(profile.toMap());
      await user.updateDisplayName(fullName.trim());
      try {
        await user.sendEmailVerification();
        _log('Verification email sent to ${email.trim()}');
      } on FirebaseAuthException catch (error) {
        _log(
          'Verification email failed [${error.code}] ${error.message}; continuing registration',
        );
      }

      _log('Registration completed for ${user.uid}');
      return credential;
    } on FirebaseAuthException catch (error) {
      _log('Registration failed [${error.code}] ${error.message}');
      throw _mapAuthException(error);
    } on FirebaseException catch (error) {
      _log('Firestore profile write failed [${error.code}] ${error.message}');
      if (credential?.user != null) {
        try {
          await credential!.user!.delete();
        } on FirebaseAuthException catch (deleteError) {
          _log(
            'Could not clean up auth user after profile failure [${deleteError.code}] ${deleteError.message}',
          );
        }
      }
      throw _mapFirestoreException(error);
    } catch (error) {
      _log('Registration failed unexpectedly: $error');
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      _log('Sending reset email to ${email.trim()}');
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      _log('Password reset failed [${error.code}] ${error.message}');
      throw _mapAuthException(error);
    } on FirebaseException catch (_) {
      _log('Password reset failed due to Firestore/network issue');
      throw 'We could not send the reset link right now. Please try again.';
    } catch (_) {
      _log('Password reset failed due to unexpected issue');
      throw 'Something went wrong while sending the reset link.';
    }
  }

  Future<UserModel?> getUserProfile(String uid) async {
    _log('Reading user profile for $uid');
    final document = await _firestore.collection('users').doc(uid).get();
    final data = document.data();
    if (data == null) {
      _log('No profile found for $uid');
      return null;
    }
    return UserModel.fromMap(document.id, data);
  }

  Future<void> reloadCurrentUser() async {
    await _firebaseAuth.currentUser?.reload();
  }

  Future<void> signOut() => _firebaseAuth.signOut();

  Future<void> _ensureUserProfileForSignIn(User? user) async {
    if (user == null) {
      return;
    }

    _log('Ensuring profile exists for sign-in user ${user.uid}');
    final document = _firestore.collection('users').doc(user.uid);
    final snapshot = await document.get();
    final role = _resolveRole(user.email ?? '');

    if (!snapshot.exists) {
      final profile = UserModel(
        uid: user.uid,
        fullName: user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : role == 'admin'
                ? 'FairBid Admin'
                : 'FairBid User',
        email: (user.email ?? '').trim(),
        phoneNumber: '',
        aadhaarNumber: '',
        panNumber: '',
        dateOfBirth: DateTime(2000),
        createdAt: DateTime.now(),
        userType: role == 'admin' ? 'Admin' : 'Buyer',
        role: role,
      );
      await document.set(profile.toMap());
      _log('Created fallback profile for ${user.uid}');
      return;
    }

    final data = snapshot.data() ?? <String, dynamic>{};
    if ((data['role'] as String?) != role) {
      await document.set({'role': role}, SetOptions(merge: true));
      _log('Updated role for ${user.uid} to $role');
    }
  }

  String _resolveRole(String email) {
    return email.trim().toLowerCase() == adminEmail ? 'admin' : 'user';
  }

  String _mapAuthException(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'user-not-found':
        return 'No account found for that email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled for this project.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }

  String _mapFirestoreException(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Firestore rules blocked profile creation. Deploy the latest rules and try again.';
      case 'unavailable':
        return 'Firestore is temporarily unavailable. Check your internet connection and try again.';
      case 'not-found':
        return 'Firestore is not set up for this Firebase project yet.';
      default:
        return error.message ??
            'We could not save your profile right now. Please try again.';
    }
  }

  void _log(String message) {
    debugPrint('[AuthService] $message');
  }
}
