import 'package:flutter/material.dart';

import 'screens/moderator_flow.dart';

void main() {
  runApp(const MafiaHostApp());
}

class MafiaHostApp extends StatelessWidget {
  const MafiaHostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '마피아 사회자 기록',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B2838)),
        useMaterial3: true,
      ),
      home: const ModeratorFlow(),
    );
  }
}
