import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'main_shell.dart';
import 'admin/admin_shell.dart';
import 'verification_screen.dart';

class LoginScreen extends StatefulWidget {
  final AuthService authService;

  const LoginScreen({super.key, required this.authService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    _animController.reverse().then((_) {
      setState(() => _isLogin = !_isLogin);
      _animController.forward();
    });
  }

  Future<void> _forgotPassword() async {
    final emailController =
        TextEditingController(text: _emailController.text.trim());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your email and we\'ll send you a reset link.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send link'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final email = emailController.text.trim();
    if (email.isEmpty) return;

    try {
      await widget.authService.resetPassword(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent to $email'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Failed to send reset email.'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _submit() async {
    setState(() => _loading = true);

    try {
      if (_isLogin) {
        // ── Login path ───────────────────────────────────────────────────
        final appUser = await widget.authService.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (!mounted) return;

        final target = appUser.role == UserRole.admin
            ? const AdminShell()
            : const MainShell();

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => target),
        );
      } else {
        // ── Register path — create account + send verification email ─────
        await widget.authService.registerAndSendVerification(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
          surname: _surnameController.text.trim(),
        );

        if (!mounted) return;

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VerificationScreen(
              authService: widget.authService,
              email: _emailController.text.trim(),
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // ── Logo ─────────────────────────────────────────────────────
              SvgPicture.asset(
                'assets/images/logo.svg',
                width: 200,
                height: 165,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 8),

              // ── Subtitle ─────────────────────────────────────────────────
              Text(
                _isLogin ? 'Welcome back!' : 'Create your account',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.55),
                  letterSpacing: 0.2,
                ),
              ),

              const SizedBox(height: 32),

              // ── Form Card ─────────────────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Register-only fields ─────────────────────────
                      if (!_isLogin) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _StyledTextField(
                                controller: _nameController,
                                label: 'First Name',
                                icon: Icons.person_outline_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StyledTextField(
                                controller: _surnameController,
                                label: 'Last Name',
                                icon: Icons.person_outline_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Email ────────────────────────────────────────
                      _StyledTextField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),

                      // ── Password ─────────────────────────────────────
                      _StyledTextField(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: colorScheme.onSurface.withOpacity(0.45),
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Submit button ────────────────────────────────
                      SizedBox(
                        height: 52,
                        child: _loading
                            ? Center(
                                child: SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              )
                            : FilledButton(
                                onPressed: _submit,
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  _isLogin ? 'Sign In' : 'Create Account',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_isLogin) ...[
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: _forgotPassword,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── Toggle login / register ──────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin
                        ? "Don't have an account?"
                        : 'Already have an account?',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  TextButton(
                    onPressed: _toggleMode,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _isLogin ? 'Register' : 'Sign in',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared styled text field ─────────────────────────────────────────────────

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

  const _StyledTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: colorScheme.primary),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
