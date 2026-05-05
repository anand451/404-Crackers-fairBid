import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/widgets/app_state_widgets.dart';
import '../providers/auth_provider.dart';
import 'admin_home_screen.dart';
import 'auth_screen.dart';
import 'blocked_account_screen.dart';
import 'user_home_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isInitializing) {
          return const Scaffold(
            body: AppLoadingIndicator(
                label: 'Preparing your FairBid workspace...'),
          );
        }

        if (authProvider.isAuthenticated) {
          if (authProvider.isBlocked) {
            return const BlockedAccountScreen();
          }
          if (authProvider.isAdmin) {
            return const AdminHomeScreen();
          }
          return const UserHomeScreen();
        }

        return const AuthScreen();
      },
    );
  }
}
