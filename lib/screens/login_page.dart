import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _register = false, _busy = false;
  String? _error;

  String _msg(String code) {
    switch (code) {
      case 'invalid-email':
        return 'الإيميل مش صحيح';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'الإيميل أو الباسورد غلط';
      case 'email-already-in-use':
        return 'الإيميل ده مسجل قبل كده';
      case 'weak-password':
        return 'الباسورد ضعيف (6 حروف على الأقل)';
      case 'network-request-failed':
        return 'مفيش اتصال بالإنترنت';
      case 'too-many-requests':
        return 'محاولات كتير، جرّب بعد شوية';
      default:
        return 'حصل خطأ: $code';
    }
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (_register) {
        await auth.createUserWithEmailAndPassword(
            email: _email.text.trim(), password: _pass.text);
      } else {
        await auth.signInWithEmailAndPassword(
            email: _email.text.trim(), password: _pass.text);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _msg(e.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'اكتب الإيميل الأول');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _email.text.trim());
      setState(() => _error = 'اتبعت لك رابط إعادة الباسورد على الإيميل');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _msg(e.code));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.contacts, size: 72),
              const SizedBox(height: 8),
              Text('جهات الاتصال VCF',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                    labelText: 'الإيميل', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass,
                obscureText: true,
                textDirection: TextDirection.ltr,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                    labelText: 'الباسورد', border: OutlineInputBorder()),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_register ? 'إنشاء حساب' : 'دخول'),
              ),
              TextButton(
                onPressed: () => setState(() => _register = !_register),
                child: Text(_register ? 'عندي حساب' : 'مستخدم جديد؟ سجّل'),
              ),
              TextButton(onPressed: _reset, child: const Text('نسيت الباسورد')),
            ],
          ),
        ),
      ),
    );
  }
}
