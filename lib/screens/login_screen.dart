import 'package:window_manager/window_manager.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/sync_service.dart';
import '../theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/neo_box.dart';
import '../widgets/neo_button.dart';
import '../widgets/neo_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null && data.event == AuthChangeEvent.signedIn) {
        ref.read(syncServiceProvider).mergeAfterLogin(session.user.id);
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/notes');
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showError('Email and Password are required to log in.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (res.user != null) {
        ref.read(syncServiceProvider).mergeAfterLogin(res.user!.id);
      }
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/notes');
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(e.toString());
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
      final res = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'display_name': _emailController.text.trim().split('@').first,
        },
      );
      if (res.user != null && res.session != null) {
        ref.read(syncServiceProvider).mergeAfterLogin(res.user!.id);
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/notes');
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Check your email for verification link!', style: TextStyle(fontWeight: FontWeight.bold, color: context.neoText)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    HttpServer? server;
    try {
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 54321);
        const redirectUrl = 'http://localhost:54321/auth/callback';

        final res = await Supabase.instance.client.auth.getOAuthSignInUrl(
          provider: OAuthProvider.google,
          redirectTo: redirectUrl,
          queryParams: const {
            'prompt': 'select_account',
          },
        );

        await launchUrl(Uri.parse(res.url), mode: LaunchMode.externalApplication);

        final callbackUri = await _listenForAuthCallback(server).timeout(
          const Duration(minutes: 3),
          onTimeout: () => null,
        );

        if (callbackUri != null) {
          await Supabase.instance.client.auth.getSessionFromUrl(callbackUri);
          if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
            try {
              await windowManager.show();
              await windowManager.focus();
            } catch (_) {}
          }
        }
      } else {
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          queryParams: const {
            'prompt': 'select_account',
          },
        );
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(e.toString());
    } finally {
      await server?.close();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Uri?> _listenForAuthCallback(HttpServer server) async {
    await for (final request in server) {
      final uri = request.uri;
      if (uri.path == '/auth/callback') {
        final hasParams = uri.queryParameters.containsKey('code') ||
            uri.queryParameters.containsKey('access_token') ||
            uri.queryParameters.containsKey('error');

        if (hasParams) {
          final isError = uri.queryParameters.containsKey('error');
          final errorDesc = uri.queryParameters['error_description'] ?? 'Terjadi kesalahan saat login.';
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.html
            ..write(_buildCallbackHtml(isError: isError, errorDesc: errorDesc));
          await request.response.close();
          return uri;
        } else {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.html
            ..write('''<!DOCTYPE html>
<html>
<body>
  <script>
    if (window.location.hash) {
      window.location.href = `/auth/callback?\${window.location.hash.substring(1)}`;
    }
  </script>
</body>
</html>''');
          await request.response.close();
        }
      }
    }
    return null;
  }

  String _buildCallbackHtml({required bool isError, required String errorDesc}) {
    final statusColor = isError ? '#DC2626' : '#16A34A';
    final statusBg = isError ? '#FEF2F2' : '#F0FDF4';
    final badgeText = isError ? 'GAGAL' : 'TERHUBUNG';
    final stampIcon = isError ? '&#10005;' : '&#10003;';
    final title = isError ? 'Login Gagal' : 'Login Berhasil!';
    final subtitle = isError
        ? errorDesc
        : 'Akun Google Anda telah terhubung. Aplikasi NOPEPADS sudah aktif kembali di latar depan.';

    return '''<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>NOPEPADS - $title</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;700;800;900&family=Press+Start+2P&display=swap" rel="stylesheet">
  <style>
    * { box-sizing: border-box; }
    body {
      margin: 0;
      padding: 24px;
      min-height: 100vh;
      background-color: #F4F4F5;
      display: flex;
      align-items: center;
      justify-content: center;
      font-family: 'Space Grotesk', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      color: #000000;
    }
    .card {
      width: 100%;
      max-width: 440px;
      background: #FFFFFF;
      border: 3px solid #000000;
      border-radius: 16px;
      box-shadow: 8px 8px 0px #000000;
      overflow: hidden;
      animation: popIn 0.25s cubic-bezier(0.16, 1, 0.3, 1);
    }
    @keyframes popIn {
      0% { transform: scale(0.92); opacity: 0; }
      100% { transform: scale(1); opacity: 1; }
    }
    .card-header {
      background: #FFFFFF;
      border-bottom: 3px solid #000000;
      padding: 16px 20px;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .brand-title {
      font-family: 'Press Start 2P', monospace;
      font-size: 13px;
      color: #000000;
      letter-spacing: 0.5px;
    }
    .pill-badge {
      background: $statusBg;
      color: $statusColor;
      border: 2px solid #000000;
      font-size: 11px;
      font-weight: 800;
      padding: 4px 10px;
      border-radius: 999px;
      letter-spacing: 0.5px;
    }
    .card-body {
      padding: 32px 28px 24px 28px;
      text-align: center;
    }
    .stamp-container {
      margin-bottom: 20px;
      display: inline-block;
    }
    .stamp {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 68px;
      height: 68px;
      background: $statusBg;
      border: 3px solid #000000;
      border-radius: 50%;
      box-shadow: 4px 4px 0px #000000;
      font-size: 32px;
      color: $statusColor;
      font-weight: 900;
    }
    h1 {
      margin: 0 0 10px 0;
      font-size: 24px;
      font-weight: 900;
      color: #000000;
      letter-spacing: -0.5px;
    }
    p.subtitle {
      margin: 0 0 20px 0;
      font-size: 14px;
      font-weight: 600;
      color: #4B5563;
      line-height: 1.5;
    }
    .info-box {
      background: #F9FAFB;
      border: 2px solid #000000;
      border-radius: 10px;
      padding: 12px 14px;
      margin-bottom: 16px;
      font-size: 13px;
      font-weight: 700;
      color: #1F2937;
      line-height: 1.4;
    }
    .shortcut-tag {
      display: inline-block;
      margin-top: 6px;
      background: #FFFFFF;
      border: 2px solid #000000;
      border-radius: 6px;
      padding: 2px 8px;
      font-family: monospace;
      font-size: 12px;
      font-weight: 800;
      box-shadow: 2px 2px 0px #000000;
    }
    .btn {
      display: inline-block;
      width: 100%;
      padding: 14px 20px;
      background: #000000;
      color: #FFFFFF;
      font-family: inherit;
      font-size: 14px;
      font-weight: 800;
      letter-spacing: 0.5px;
      text-transform: uppercase;
      border: 2px solid #000000;
      border-radius: 10px;
      box-shadow: 4px 4px 0px #000000;
      cursor: pointer;
      transition: transform 0.1s ease, box-shadow 0.1s ease;
    }
    .btn:hover {
      transform: translate(2px, 2px);
      box-shadow: 2px 2px 0px #000000;
    }
    .btn:active {
      transform: translate(4px, 4px);
      box-shadow: 0px 0px 0px #000000;
    }
    .security-note {
      display: none;
      margin-top: 14px;
      padding: 10px 12px;
      background: #FEF3C7;
      border: 2px solid #000000;
      border-radius: 8px;
      font-size: 12px;
      font-weight: 700;
      color: #78350F;
      text-align: left;
      line-height: 1.4;
    }
    .footer-note {
      margin-top: 16px;
      font-size: 11px;
      color: #6B7280;
      font-weight: 600;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="card-header">
      <span class="brand-title">NOPEPADS</span>
      <span class="pill-badge">$badgeText</span>
    </div>
    <div class="card-body">
      <div class="stamp-container">
        <div class="stamp">$stampIcon</div>
      </div>
      <h1>$title</h1>
      <p class="subtitle">$subtitle</p>
      
      <div class="info-box">
        Silakan tutup tab ini untuk kembali ke aplikasi
        <div><span class="shortcut-tag">Pintasan: Ctrl + W</span></div>
      </div>

      <button id="close-btn" class="btn" onclick="handleClose()">Tutup Tab Sekarang</button>
      
      <div id="security-note" class="security-note">
        &#9888; <strong>Browser memblokir penutupan otomatis:</strong><br>
        Demi alasan keamanan, browser melarang website menutup tab secara otomatis. Silakan tutup tab ini menggunakan tanda silang [X] di atas atau pintasan <strong>Ctrl + W</strong>.
      </div>

      <div class="footer-note">NOPEPADS Desktop Authentication</div>
    </div>
  </div>

  <script>
    function tryClose() {
      try {
        window.open('', '_self', '');
        window.close();
      } catch (e) {}
      try {
        window.close();
      } catch (e) {}
    }

    function handleClose() {
      tryClose();
      setTimeout(function() {
        var note = document.getElementById('security-note');
        if (note) note.style.display = 'block';
        var btn = document.getElementById('close-btn');
        if (btn) btn.innerText = 'Tekan Ctrl + W untuk Tutup';
      }, 300);
    }

    // Try closing once shortly after load
    setTimeout(function() {
      tryClose();
    }, 1200);
  </script>
</body>
</html>''';
  }

  void _showError(String message) {
    final theme = context;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, color: theme.neoBorder)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.neoBorder, width: 4),
          borderRadius: BorderRadius.zero,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context;
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: theme.neoBackground,
      body: Row(
        children: [
          // Left Side (Hidden on Mobile)
          if (isDesktop)
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(48.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '"YOU GOT THIS,\nEXPLORER! ONE STEP\nAT A TIME."',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: theme.neoText,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        height: 1.2,
                        shadows: [
                          Shadow(color: theme.neoBorder, offset: const Offset(4, 4)),
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
                          textStyle: TextStyle(
                            color: theme.neoBorder,
                            fontSize: 32,
                            letterSpacing: 2.0,
                            shadows: [
                              Shadow(color: theme.neoText, offset: const Offset(3, 3)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: theme.neoBorder, width: 4)),
                          ),
                          child: Text(
                            'SIGN IN TO YOUR ACCOUNT',
                            style: TextStyle(
                              color: theme.neoBorder,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
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
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'FORGOT PASSWORD?',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: theme.neoBorder,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_isLoading)
                        Center(child: CircularProgressIndicator(color: theme.neoBorder))
                      else ...[
                        NeoButton(
                          text: 'Log in',
                          backgroundColor: theme.neoBorder,
                          textColor: theme.neoText,
                          onPressed: _signIn,
                        ),
                        const SizedBox(height: 16),
                        NeoButton(
                          text: 'Sign up',
                          backgroundColor: theme.neoText,
                          textColor: theme.neoBorder,
                          onPressed: _signUp,
                        ),
                      ],
                      const SizedBox(height: 24),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Divider(color: theme.neoBorder, thickness: 4),
                          Container(
                            color: theme.neoYellow,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR CONTINUE WITH',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: theme.neoBorder,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      NeoButton(
                        text: 'Google',
                        backgroundColor: theme.neoText,
                        textColor: theme.neoBorder,
                        onPressed: _signInWithGoogle,
                        icon: const Text('G', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.blue)),
                      ),
                      const SizedBox(height: 16),
                      NeoButton(
                        text: 'Use Offline / Skip',
                        backgroundColor: const Color(0xFFE6B905),
                        textColor: Colors.black,
                        icon: const Icon(Icons.offline_bolt_rounded, color: Colors.black, size: 22),
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed('/notes');
                        },
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
