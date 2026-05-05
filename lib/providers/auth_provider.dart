import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _authSubscription = _authService.authStateChanges().listen(
      (user) => unawaited(_handleAuthStateChanged(user)),
      onError: (Object error) {
        _authError = 'Unable to monitor authentication state right now.';
        _isInitializing = false;
        notifyListeners();
      },
    );
  }

  final AuthService _authService;
  StreamSubscription<User?>? _authSubscription;

  User? _firebaseUser;
  UserModel? _userProfile;
  bool _isInitializing = true;
  bool _isLoginLoading = false;
  bool _isRegisterLoading = false;
  bool _isResetPasswordLoading = false;
  String? _authError;
  String? _infoMessage;

  User? get firebaseUser => _firebaseUser;
  UserModel? get userProfile => _userProfile;
  bool get isInitializing => _isInitializing;
  bool get isAuthenticated => _firebaseUser != null;
  bool get isLoginLoading => _isLoginLoading;
  bool get isRegisterLoading => _isRegisterLoading;
  bool get isResetPasswordLoading => _isResetPasswordLoading;
  String? get authError => _authError;
  String? get infoMessage => _infoMessage;
  bool get isEmailVerified => _firebaseUser?.emailVerified ?? false;
  bool get isAdmin =>
      _userProfile?.isAdmin == true ||
      (_firebaseUser?.email?.trim().toLowerCase() == AuthService.adminEmail);
  String get role => isAdmin ? 'admin' : 'user';

  Future<void> _handleAuthStateChanged(User? user) async {
    _firebaseUser = user;
    _authError = null;

    if (user == null) {
      _userProfile = null;
      _isInitializing = false;
      notifyListeners();
      return;
    }

    try {
      _userProfile = await _authService.getUserProfile(user.uid);
    } catch (_) {
      _authError = 'Signed in, but we could not load your profile details.';
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoginLoading = true;
    _authError = null;
    _infoMessage = null;
    notifyListeners();

    try {
      await _authService.signIn(email: email, password: password);
      _infoMessage = isEmailVerified
          ? 'Welcome back to FairBid.'
          : 'Signed in successfully. Please verify your email when you can.';
      return true;
    } catch (error) {
      _authError = error.toString();
      return false;
    } finally {
      _isLoginLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String aadhaarNumber,
    required String panNumber,
    required DateTime dateOfBirth,
    required String password,
    required String userType,
  }) async {
    _isRegisterLoading = true;
    _authError = null;
    _infoMessage = null;
    notifyListeners();

    try {
      await _authService.register(
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        aadhaarNumber: aadhaarNumber,
        panNumber: panNumber,
        dateOfBirth: dateOfBirth,
        password: password,
        userType: userType,
      );
      _infoMessage =
          'Account created successfully. A verification email has been sent.';
      return true;
    } catch (error) {
      _authError = error.toString();
      return false;
    } finally {
      _isRegisterLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    _isResetPasswordLoading = true;
    _authError = null;
    _infoMessage = null;
    notifyListeners();

    try {
      await _authService.sendPasswordResetEmail(email);
      _infoMessage = 'Password reset link sent to $email.';
      return true;
    } catch (error) {
      _authError = error.toString();
      return false;
    } finally {
      _isResetPasswordLoading = false;
      notifyListeners();
    }
  }

  Future<void> reloadUser() async {
    try {
      await _authService.reloadCurrentUser();
      _firebaseUser = _authService.currentUser;
      if (_firebaseUser != null) {
        _userProfile = await _authService.getUserProfile(_firebaseUser!.uid);
      }
      notifyListeners();
    } catch (_) {
      _authError = 'Unable to refresh your account right now.';
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _authError = null;
    _infoMessage = null;
    notifyListeners();
    await _authService.signOut();
  }

  void clearFeedback() {
    if (_authError == null && _infoMessage == null) {
      return;
    }
    _authError = null;
    _infoMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
