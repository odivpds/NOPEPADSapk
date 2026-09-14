import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/neo_box.dart';
import '../widgets/neo_button.dart';
import '../widgets/neo_text_field.dart';
import '../widgets/motivational_quote.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signIn() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showError('Email and Password are required to log in.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/notes');
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUp() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showError('Email and Password are required to sign up.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'display_name': _nameController.text.trim(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check your email for verification link!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    // Basic implementation for Google Auth
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(OAuthProvider.google);
      // Navigation happens automatically via deep links if setup correctly
    } on AuthException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: Colors.black, width: 4),
          borderRadius: BorderRadius.zero,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFF27272A),
      body: Row(
        children: [
          // Left Side (Hidden on Mobile)
          if (isDesktop)
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(48.0),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '"YOU GOT THIS,\nEXPLORER! ONE STEP\nAT A TIME."',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        height: 1.2,
                        shadows: [
                          Shadow(color: Colors.black, offset: Offset(4, 4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Right Side (Form)
          Expanded(
            flex: isDesktop ? 7 : 12,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: NeoBox(
                  width: 450,
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'NOPEPADS',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.pressStart2p(
                          textStyle: const TextStyle(
                            color: Colors.black,
                            fontSize: 32,
                            letterSpacing: 2.0,
                            shadows: [
                              Shadow(color: Colors.white, offset: Offset(3, 3)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.black, width: 4)),
                          ),
                          child: const Text(
                            'SIGN IN TO YOUR ACCOUNT',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      NeoTextField(
                        controller: _nameController,
                        label: 'Tell me your name',
                        hint: '(e.g. Batman, Shizu, or just Bob)',
                      ),
                      const SizedBox(height: 16),
                      NeoTextField(
                        controller: _emailController,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      NeoTextField(
                        controller: _passwordController,
                        label: 'Password',
                        obscureText: true,
                      ),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'FORGOT PASSWORD?',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator(color: Colors.black))
                      else ...[
                        NeoButton(
                          text: 'Log in',
                          backgroundColor: Colors.black,
                          textColor: Colors.white,
                          onPressed: _signIn,
                        ),
                        const SizedBox(height: 16),
                        NeoButton(
                          text: 'Sign up',
                          backgroundColor: Colors.white,
                          textColor: Colors.black,
                          onPressed: _signUp,
                        ),
                      ],
                      const SizedBox(height: 24),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          const Divider(color: Colors.black, thickness: 4),
                          Container(
                            color: const Color(0xFFFDE047),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: const Text(
                              'OR CONTINUE WITH',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      NeoButton(
                        text: 'Google',
                        backgroundColor: Colors.white,
                        textColor: Colors.black,
                        onPressed: _signInWithGoogle,
                        // Using a simple text G for the icon since we don't have the SVG asset
                        icon: const Text('G', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.blue)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

