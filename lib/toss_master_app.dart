import 'package:flutter/material.dart';
import 'homepage.dart';

class TossMasterApp extends StatelessWidget {
  const TossMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TossMaster - ZJU CG 2024',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(title: 'TossMaster - ZJU CG 2024'),
    );
  }
}
