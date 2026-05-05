import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'models/user_model.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/verification_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialise FCM, local notifications, and timezone data.
  // The service also registers the background FCM handler and starts
  // listening to auth-state changes to keep the FCM token in sync.
  await NotificationService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder(
      stream: authService.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          return LoginScreen(authService: authService);
        }

        return FutureBuilder(
          future: authService.getCurrentAppUser(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Block unverified accounts from reaching the app.
            final firebaseUser = authService.currentFirebaseUser;
            if (firebaseUser != null && !firebaseUser.emailVerified) {
              return VerificationScreen(
                authService: authService,
                email: firebaseUser.email ?? '',
              );
            }

            if (!userSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: Text('User data error')),
              );
            }

            final appUser = userSnapshot.data!;
            if (appUser.role == UserRole.admin ||
                appUser.role == UserRole.owner) {
              return AdminShell(role: appUser.role);
            } else {
              return const MainShell();
            }
          },
        );
      },
    );
  }
}
