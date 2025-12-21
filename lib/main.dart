import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'auth/Auth wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Email Sender',
      theme: ThemeData.light(),
      // darkTheme: ThemeData.dark(),
      home: AuthWrapper(),
    );
  }
}
