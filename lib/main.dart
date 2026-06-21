import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'models/user_model.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/verification_screen.dart';
import 'theme.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Pre-load locale data for date formatting in both supported languages.
  await initializeDateFormatting('en');
  await initializeDateFormatting('sr');

  await NotificationService().init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  // Global locale notifier — updated after login and from preferences.
  static final localeNotifier = ValueNotifier<Locale>(const Locale('en'));

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    MyApp.localeNotifier.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    MyApp.localeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: MyApp.localeNotifier.value,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('sr'),
      ],
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

            // Apply the user's saved language preference.
            final savedLocale = Locale(appUser.preferences.language);
            if (MyApp.localeNotifier.value != savedLocale) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => MyApp.localeNotifier.value = savedLocale,
              );
            }

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
