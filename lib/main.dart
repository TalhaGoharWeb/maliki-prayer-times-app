import 'package:flutter/material.dart';
import 'package:malikiprayertimes/screens/home_screen.dart';

void main() {
  runApp(const MalikiPrayerTimesApp());
}

/// Root of the Maliki prayer-times app (standalone, Milestone 1 scaffold).
class MalikiPrayerTimesApp extends StatelessWidget {
  const MalikiPrayerTimesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maliki Prayer Times',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
