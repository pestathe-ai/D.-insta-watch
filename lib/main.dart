import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const InstaWatchApp());
}

class InstaWatchApp extends StatelessWidget {
  const InstaWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1F3A5F);
    return MaterialApp(
      title: 'D. Insta Watch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
