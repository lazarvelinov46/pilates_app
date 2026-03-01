import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'main_shell.dart';

class LoginScreen extends StatefulWidget {
  final AuthService authService;

  const LoginScreen({super.key, required this.authService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);

    try {
      if (_isLogin) {
        await widget.authService.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await widget.authService.registerWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
          surname: _surnameController.text.trim(),
        );
      }

      if (!mounted) return;

      // ✅ Navigate to MainShell on success
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } on FirebaseAuthException catch (e) {
        String message;

        switch (e.code) {
          case 'user-not-found':
          case 'wrong-password':
            message = 'Wrong email or password.';
            break;
          case 'email-already-in-use':
            message = 'This email is already registered.';
            break;
          case 'invalid-email':
            message = 'Invalid email format.';
            break;
          default:
            message = 'Authentication failed.';
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
      if (mounted) {
        setState(() => _loading = false);
      }
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isLogin) ...[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _surnameController,
                  decoration: const InputDecoration(labelText: 'Surname'),
                ),
                const SizedBox(height: 12),
              ],

              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: Text(_isLogin ? 'Login' : 'Register'),
              ),

              TextButton(
                onPressed: () {
                  setState(() => _isLogin = !_isLogin);
                },
                child: Text(
                  _isLogin
                      ? "Don't have an account? Register"
                      : "Already have an account? Login",
                ),
              ),

              const SizedBox(height: 20),
              /*
              ElevatedButton(
                onPressed: _loading
                    ? null
                    : () async {
                        await widget.authService.signInWithGoogle();
                      },
                child: const Text('Sign in with Google'),
              ),
              */
            ],
          ),
        ),
      ),
    );
  }
}
