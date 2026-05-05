import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/auction_provider.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? firebaseInitializationError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    firebaseInitializationError = error.toString();
  }

  runApp(
    FairBidApp(firebaseInitializationError: firebaseInitializationError),
  );
}

class FairBidApp extends StatelessWidget {
  const FairBidApp({
    super.key,
    this.firebaseInitializationError,
  });

  final String? firebaseInitializationError;

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4F8DFF),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F9FC),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF111827),
        elevation: 0,
        centerTitle: false,
      ),
    );

    return MultiProvider(
      providers: [
        if (firebaseInitializationError == null)
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AuctionProvider()),
      ],
      child: MaterialApp(
        title: 'FairBid',
        theme: baseTheme.copyWith(
          cardTheme: baseTheme.cardTheme.copyWith(
            color: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
        ),
        home: firebaseInitializationError == null
            ? const SplashScreen()
            : FirebaseSetupScreen(
                errorMessage: firebaseInitializationError!,
              ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({
    super.key,
    required this.errorMessage,
  });

  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.settings_input_antenna_rounded,
                      size: 48,
                      color: Color(0xFF0F766E),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Firebase needs to be configured',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'The auth flow is wired for Firebase Auth and Firestore, but this project does not yet include native Firebase app configuration.',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Next steps:',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Run flutterfire configure\n2. Put google-services.json in android/app/\n3. Restart the app',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Initialization error: $errorMessage',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
