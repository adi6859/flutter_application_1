import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/location_service.dart';
import 'services/session_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final session = await SessionService.getSession();

  if (!kIsWeb) {
    unawaited(LocationService.instance.initialize());
  }

  runApp(
    MyApp(
      isLoggedIn: session.loggedIn,
      email: session.email,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.isLoggedIn,
    required this.email,
  });

  final bool isLoggedIn;
  final String email;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geo Tracker - Battery POC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: isLoggedIn ? HomeScreen(email: email) : const LoginScreen(),
    );
  }
}
