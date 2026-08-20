import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_routes.dart';
import 'features/auth/screens/auth_gate.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/registration/screens/registration_screen.dart';
import 'features/rides/screens/available_requests_screen.dart';
import 'features/rides/screens/create_request_screen.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with configuration (supports compile-time --dart-define)
  await Supabase.initialize(
    url: SupabaseConfig.url,
    // ignore: deprecated_member_use
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const RideShareApp());
}

class RideShareApp extends StatelessWidget {
  const RideShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FFL Smart Ride',
      scrollBehavior: const AppScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      initialRoute: AppRoutes.authGate,
      routes: {
        AppRoutes.authGate: (context) => const AuthGate(),
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.registration: (context) => const RegistrationScreen(),
        AppRoutes.home: (context) => const HomeScreen(),
        AppRoutes.createRequest: (context) => const CreateRequestScreen(),
        AppRoutes.availableRequests: (context) => const AvailableRequestsScreen(),
      },
    );
  }
}