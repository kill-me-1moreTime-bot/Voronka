import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SkazochnyeDruzyaApp());
}

class SkazochnyeDruzyaApp extends StatelessWidget {
  const SkazochnyeDruzyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Сказочные друзья',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6BAF7B),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
