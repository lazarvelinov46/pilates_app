import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/booking/booking_screen.dart';
import 'screens/admin/admin_session_screen.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AuthGate(),
    );
  }
}
class AuthGate extends StatelessWidget {
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();

  AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _authService.authStateChanges(),
      builder: (context, snapshot) {
        
        return LoginScreen(authService: _authService);
        /*
        if (snapshot.hasData) {
          final user = snapshot.data!;
          
          // 🔔 Initialize notifications HERE
          //_notificationService.initialize(user.uid);

          //return AdminSessionsScreen();
          return MainShell();
        } else {
          return LoginScreen(authService: _authService);
        }
        */
      },
    );
  }
}