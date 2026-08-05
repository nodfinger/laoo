import 'package:flutter/material.dart';

class LaooApp extends StatelessWidget {
  const LaooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Laoo Solutions',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1ABC9C)),
      ),
      home: const Scaffold(
        body: Center(
          child: Text(
            'Laoo Solutions',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
