import 'package:flutter/material.dart';
import 'screens/menu_screen.dart';
import 'theme/swiss_theme.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Road Rules',
      theme: SwissTheme.themeData,
      home: MenuScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}