import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/local_notification_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthService? authService,
    NotificationService? notificationService,
  })  : _authService = authService ?? AuthService(),
        _notificationService = notificationService ?? NotificationService() {
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
  final NotificationService _notificationService;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<UserModel?>? _profileSubscription;
  StreamSubscription<List<AppNotification>>? _notificationSubscription;

  User? _firebaseUser;
  UserModel? _userProfile;
  bool _isInitializing = true;
  bool _isLoginLoading = false;
  bool _isRegisterLoading = false;
  bool _isResetPasswordLoading = false;
  bool _isProfileSaving = false;
  String? _authError;
  String? _infoMessage;
  bool _notificationStreamPrimed = false;
  final Set<String> _seenNotificationIds = <String>{};

  User? get firebaseUser => _firebaseUser;
  UserModel? get userProfile => _userProfile;
  bool get isInitializing => _isInitializing;
  bool get isAuthenticated => _firebaseUser != null;
  bool get isLoginLoading => _isLoginLoading;
  bool get isRegisterLoading => _isRegisterLoading;
  bool get isResetPasswordLoading => _isResetPasswordLoading;
  bool get isProfileSaving => _isProfileSaving;
  String? get authError => _authError;
  String? get infoMessage => _infoMessage;
  bool get isEmailVerified => _firebaseUser?.emailVerified ?? false;
  bool get isAdmin =>
      _userProfile?.isAdmin == true ||
      (_firebaseUser?.email?.trim().toLowerCase() == AuthService.adminEmail);
  bool get isBlocked => _userProfile?.isBlocked ?? false;
  bool get canInteract => isAuthenticated && !isBlocked;
  String get accountStatus => _userProfile?.status ?? 'active';
  String get role => isAdmin ? 'admin' : 'user';

  Future<void> _handleAuthStateChanged(User? user) async {
    await _profileSubscription?.cancel();
    await _notificationSubscription?.cancel();
    _profileSubscription = null;
    _notificationSubscription = null;
    _notificationStreamPrimed = false;
    _seenNotificationIds.clear();
    _firebaseUser = user;
    _authError = null;

    if (user == null) {
      _userProfile = null;
      _isInitializing = false;
      notifyListeners();
      return;
    }

    _isInitializing = true;
    notifyListeners();

    _profileSubscription = _authService.streamUserProfile(user.uid).listen(
      (profile) {
        _userProfile = profile;
        _isInitializing = false;
        if (profile == null) {
          _authError = 'Signed in, but we could not load your profile details.';
        } else if (profile.isBlocked) {
          _infoMessage =
              'Your account has been blocked. Contact the FairBid admin team.';
        }
        _startNotificationListener(user.uid);
        notifyListeners();
      },
      onError: (_) {
        _authError = 'Signed in, but we could not load your profile details.';
        _isInitializing = false;
        notifyListeners();
      },
    );
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
      debugPrint('[AuthProvider] Login requested for ${email.trim()}');
      await _authService.signIn(email: email, password: password);
      _infoMessage = isEmailVerified
          ? 'Welcome back to FairBid.'
          : 'Signed in successfully. Please verify your email when you can.';
      return true;
    } catch (error) {
      debugPrint('[AuthProvider] Login failed: $error');
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
      debugPrint('[AuthProvider] Register requested for ${email.trim()}');
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
      debugPrint('[AuthProvider] Register failed: $error');
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
      notifyListeners();
    } catch (_) {
      _authError = 'Unable to refresh your account right now.';
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    required String fullName,
    required String phoneNumber,
    required DateTime dateOfBirth,
  }) async {
    final user = _firebaseUser;
    if (user == null) {
      _authError = 'Please sign in again and retry.';
      notifyListeners();
      return false;
    }

    _isProfileSaving = true;
    _authError = null;
    _infoMessage = null;
    notifyListeners();

    try {
      await _authService.updateUserProfile(
        uid: user.uid,
        fullName: fullName,
        phoneNumber: phoneNumber,
        dateOfBirth: dateOfBirth,
      );
      _infoMessage = 'Profile updated successfully.';
      return true;
    } catch (error) {
      _authError = error.toString();
      return false;
    } finally {
      _isProfileSaving = false;
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
    _profileSubscription?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _startNotificationListener(String userId) {
    if (_notificationSubscription != null) {
      return;
    }

    _notificationSubscription = _notificationService
        .streamUserNotifications(userId, limit: 20)
        .listen((notifications) {
      if (!_notificationStreamPrimed) {
        _seenNotificationIds.addAll(notifications.map((item) => item.id));
        _notificationStreamPrimed = true;
        return;
      }

      for (final notification in notifications) {
        final isNew = _seenNotificationIds.add(notification.id);
        final shouldSurface =
            notification.type != 'auction' && !notification.readStatus && isNew;
        if (!shouldSurface) {
          continue;
        }
        unawaited(
          LocalNotificationService.instance.showInboxNotification(
            id: notification.id.hashCode.abs(),
            title: notification.title,
            body: notification.message,
          ),
        );
      }
    });
  }
}
