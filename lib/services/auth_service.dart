import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';

class AuthService {
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
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw _mapAuthException(error);
    } on FirebaseException catch (_) {
      throw 'We could not reach FairBid services. Please try again.';
    } catch (_) {
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
        email: email.trim(),
        phoneNumber: phoneNumber.trim(),
        aadhaarNumber: aadhaarNumber.trim(),
        panNumber: panNumber.trim().toUpperCase(),
        dateOfBirth: dateOfBirth,
        createdAt: DateTime.now(),
        userType: userType,
      );

      await _firestore.collection('users').doc(user.uid).set(profile.toMap());
      await user.updateDisplayName(fullName.trim());
      await user.sendEmailVerification();

      return credential;
    } on FirebaseAuthException catch (error) {
      throw _mapAuthException(error);
    } on FirebaseException catch (_) {
      if (credential?.user != null) {
        await credential!.user!.delete();
      }
      throw 'We could not save your profile right now. Please try again.';
    } catch (error) {
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw _mapAuthException(error);
    } on FirebaseException catch (_) {
      throw 'We could not send the reset link right now. Please try again.';
    } catch (_) {
      throw 'Something went wrong while sending the reset link.';
    }
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final document = await _firestore.collection('users').doc(uid).get();
    final data = document.data();
    if (data == null) {
      return null;
    }
    return UserModel.fromMap(document.id, data);
  }

  Future<void> reloadCurrentUser() async {
    await _firebaseAuth.currentUser?.reload();
  }

  Future<void> signOut() => _firebaseAuth.signOut();

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
}
