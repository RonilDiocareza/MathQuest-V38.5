import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'models/user_account.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';
import 'screens/teacher_analytics_screen.dart';
import 'services/auth_service.dart';
import 'widgets/math_background.dart';

const _mathQuestSystemUiStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarDividerColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  systemNavigationBarIconBrightness: Brightness.light,
  systemStatusBarContrastEnforced: false,
  systemNavigationBarContrastEnforced: false,
);

class AppColors {
  static const woodDark = Color(0xFF5A3620);
  static const woodMedium = Color(0xFF8F5C2D);
  static const woodLight = Color(0xFFB6783E);
  static const cream = Color(0xFFF7EAD0);
  static const creamDeep = Color(0xFFF0D6A1);
  static const chocolate = Color(0xFF3C2A1C);
  static const copper = Color(0xFFB98C52);
  static const gold = Color(0xFFD09F5C);
  static const ember = Color(0xFFE77F5C);
  static const sage = Color(0xFF5D8E4A);
  static const sky = Color(0xFF4E8BA8);
  static const violet = Color(0xFF6A7CC9);
}

ThemeData buildMathQuestTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.woodMedium,
    brightness: Brightness.light,
    primary: AppColors.woodMedium,
    secondary: AppColors.copper,
    surface: AppColors.cream,
    onSurface: AppColors.chocolate,
    tertiary: AppColors.gold,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: Colors.transparent,
    primaryColor: AppColors.woodMedium,
    splashFactory: InkRipple.splashFactory,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: AppColors.cream,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.woodDark, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.woodMedium,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.woodDark, width: 2),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8F3E8),
      hintStyle: const TextStyle(
        color: Color(0xFF7C5B3A),
        fontWeight: FontWeight.w600,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF7A5634), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF7A5634), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.copper, width: 2.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.woodDark, width: 2),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: AppColors.chocolate,
        fontWeight: FontWeight.w900,
      ),
      headlineMedium: TextStyle(
        color: AppColors.chocolate,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: TextStyle(
        color: AppColors.chocolate,
        fontWeight: FontWeight.w800,
      ),
      bodyLarge: TextStyle(color: AppColors.chocolate),
      bodyMedium: TextStyle(color: AppColors.chocolate),
      labelLarge: TextStyle(
        color: AppColors.chocolate,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(_mathQuestSystemUiStyle);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  Object? startupError;

  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyAj_7-oW2itTWEKQS2r5jJCyleCKEscnR4',
          authDomain: 'mathquest-4dd85.firebaseapp.com',
          appId: '1:827434338158:web:006f9247cfacd47b9ee37f',
          messagingSenderId: '827434338158',
          projectId: 'mathquest-4dd85',
          storageBucket: 'mathquest-4dd85.firebasestorage.app',
          measurementId: 'G-Z8G4B28KHH',
        ),
      );
    } else {
      await Firebase.initializeApp();
    }

    debugPrint(
      'Firebase initialized successfully: '
      'projectId=${Firebase.app().options.projectId}',
    );
  } catch (error) {
    startupError = error;
    if (error is FirebaseException) {
      debugPrint(
        'Firebase initialization failed: '
        'code=${error.code}, message=${error.message}',
      );
    } else {
      debugPrint('Firebase initialization failed: $error');
    }
  }

  runApp(MyApp(startupError: startupError));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.startupError});

  final Object? startupError;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setImmersiveMode();
  }

  Future<void> _setImmersiveMode() async {
    if (!kIsWeb) {
      SystemChrome.setSystemUIOverlayStyle(_mathQuestSystemUiStyle);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setImmersiveMode();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildMathQuestTheme(),
      themeMode: ThemeMode.light,
      builder: (context, child) => MathBackground(
        child: child ?? const SizedBox.shrink(),
      ),
      home: widget.startupError == null
          ? const _SessionStartupRouter()
          : const StartupErrorScreen(),
    );
  }
}

class _SessionStartupRouter extends StatefulWidget {
  const _SessionStartupRouter();

  @override
  State<_SessionStartupRouter> createState() => _SessionStartupRouterState();
}

class _SessionStartupRouterState extends State<_SessionStartupRouter> {
  late Future<UserAccount?> _restoreSession;

  @override
  void initState() {
    super.initState();
    _restoreSession = _restoreSessionWithTimeout();
  }

  Future<UserAccount?> _restoreSessionWithTimeout() async {
    final timer = Stopwatch()..start();
    try {
      return await AuthService.restoreSignedInAccount().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException(
          'Secure sign-in verification timed out.',
        ),
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[SessionStartupRouter] Session restore failed after '
          '${timer.elapsedMilliseconds} ms: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  void _retryRestore() {
    setState(() {
      _restoreSession = _restoreSessionWithTimeout();
    });
  }

  Widget _dashboardFor(UserAccount account) {
    switch (account.role.trim().toLowerCase()) {
      case 'student':
        return const LandingScreen(role: 'student');
      case 'teacher':
        return const TeacherAnalyticsScreen(isTeacherDashboard: true);
      case 'admin':
        return const AdminDashboardScreen();
      default:
        return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserAccount?>(
      future: _restoreSession,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      snapshot.error is TimeoutException
                          ? 'Sign-in verification is taking too long. '
                              'Check your connection and retry.'
                          : 'Could not verify your saved sign-in session. '
                              'Check your connection and try again.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _retryRestore,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData &&
            snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final account = snapshot.data;
        return account == null ? const LoginScreen() : _dashboardFor(account);
      },
    );
  }
}

class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: const Text(
            'MathQuest is temporarily unavailable. Please try again later.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
