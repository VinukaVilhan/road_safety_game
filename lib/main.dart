import 'package:flutter/material.dart';
import 'menu_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Racing Game',
      theme: ThemeData.dark(),
      home: MenuScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}