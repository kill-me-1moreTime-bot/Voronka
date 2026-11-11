import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'characters.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Персонажи из assets/characters.json — до первого экрана.
  await loadCharacters();
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
