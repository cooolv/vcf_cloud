import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'firebase_config.dart';
import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'services/incoming_file.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // ويندوز: دبل كليك على ملف vcf بيبعت المسار كـ argument
  for (final a in args) {
    if (a.toLowerCase().endsWith('.vcf')) IncomingFile.path.value = a;
  }

  if (FirebaseConfig.configured) {
    await Firebase.initializeApp(options: FirebaseConfig.options);
  }
  if (Platform.isAndroid) _listenAndroidIntents();

  runApp(const App());
}

void _listenAndroidIntents() {
  ReceiveSharingIntent.instance.getInitialMedia().then((files) {
    if (files.isNotEmpty) IncomingFile.path.value = files.first.path;
    ReceiveSharingIntent.instance.reset();
  });
  ReceiveSharingIntent.instance.getMediaStream().listen((files) {
    if (files.isNotEmpty) IncomingFile.path.value = files.first.path;
  });
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'جهات الاتصال VCF',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      darkTheme: ThemeData(
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.dark,
          useMaterial3: true),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: FirebaseConfig.configured ? const AuthGate() : const _NotConfigured(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snap.data == null ? const LoginPage() : const HomePage();
      },
    );
  }
}

class _NotConfigured extends StatelessWidget {
  const _NotConfigured();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'إعدادات Firebase ناقصة.\n'
            'النسخة دي اتبنت من غير مفاتيح Firebase.\n'
            'راجع README عشان تضيف الـ Secrets وتعيد البناء.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
