import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/fa_solid.dart';
import 'package:iconify_flutter/icons/ep.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SigninPage extends StatefulWidget {
  const SigninPage({super.key});

  @override
  State<SigninPage> createState() => _SigninPageState();
}

class _SigninPageState extends State<SigninPage> {
  bool obscurePassword = true;
  bool _isLoading = false;
  
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // Get supabase client safely
  SupabaseClient get supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();

    // Listen to auth state changes
    _setupAuthListener();
  }

  void _setupAuthListener() {
    supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null && mounted) {
        debugPrint('=== User Logged In ===');
        debugPrint('User ID: ${data.session?.user.id}');
        debugPrint('Email: ${data.session?.user.email}');
        debugPrint('Provider: ${data.session?.user.appMetadata['provider']}');
        debugPrint('=====================');
        
        // User is signed in, navigate to home
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  

  // Google Sign In method
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      const webClientId = '943843600625-adrds4q3n75kpm4pbs5nfot4ge83q8d1.apps.googleusercontent.com';
      const iosClientId = '943843600625-ja3jh6k8ggcpoc25vosd5o4srsc5mlgc.apps.googleusercontent.com';

      debugPrint('=== Starting Google Sign In ===');
      
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;

      unawaited(
        googleSignIn.initialize(
          clientId: iosClientId, 
          serverClientId: webClientId
        )
      );

      debugPrint('GoogleSignIn initialized');
      debugPrint('Attempting to authenticate...');

      final googleAccount = await googleSignIn.authenticate();
      
      debugPrint('Google account obtained: ${googleAccount.email}');
      
      final googleAuthorization = await googleAccount.authorizationClient.authorizationForScopes([
        'email',
        'profile',
        'openid',
      ]);
      
      debugPrint('Authorization obtained');
      
      final googleAuthentication = googleAccount.authentication;
      final idToken = googleAuthentication.idToken;
      final accessToken = googleAuthorization?.accessToken;

      debugPrint('ID Token: ${idToken != null ? "Available" : "NULL"}');
      debugPrint('Access Token: ${accessToken != null ? "Available" : "NULL"}');

      if (idToken == null) {
        throw 'No ID Token found.';
      }

      debugPrint('Signing in to Supabase...');

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      // Debug: Print Google sign-in success
      final user = supabase.auth.currentUser;
      debugPrint('=== Google Sign In Success ===');
      debugPrint('User ID: ${user?.id}');
      debugPrint('Email: ${user?.email}');
      debugPrint('Name: ${user?.userMetadata?['full_name']}');
      debugPrint('==============================');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully signed in with Google!')),
        );
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (error, stackTrace) {
      debugPrint('=== Google Sign In Error ===');
      debugPrint('Error: $error');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('============================');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing in: $error'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Email/Password Sign In method
  Future<void> _signInWithEmailPassword() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Debug: Print email sign-in success
      final user = supabase.auth.currentUser;
      debugPrint('=== Email Sign In Success ===');
      debugPrint('User ID: ${user?.id}');
      debugPrint('Email: ${user?.email}');
      debugPrint('=============================');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully signed in!')),
        );
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Background Image
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/image/signup.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Content
          SafeArea(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Back button
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: Container(
                              margin: const EdgeInsets.all(16),
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Color(0xFFD9D9D9),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Iconify(
                                  Ep.arrow_left_bold,
                                  color: Colors.black,
                                  size: 30,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Logo + Text
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Iconify(
                              FaSolid.swimmer,
                              size: 40,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'swiMate',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // Content Card
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 25,
                      ),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0x80000000),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Login',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 32),

                          _buildTextField(
                            label: "Email",
                            icon: Icons.email,
                            controller: _emailController,
                          ),

                          const SizedBox(height: 24),

                          _buildTextField(
                            label: "Password",
                            icon: Icons.lock,
                            obscure: obscurePassword,
                            controller: _passwordController,
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey[700],
                              ),
                              onPressed: () {
                                setState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signInWithEmailPassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1976D2),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Login',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Sign In Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Or Sign in with',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: _isLoading ? null : _signInWithGoogle,
                                child: Container(
                                  margin: const EdgeInsets.all(8),
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: _isLoading 
                                        ? const Color(0xFFBDBDBD)
                                        : const Color(0xFFD9D9D9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 25,
                                            height: 25,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Image.asset(
                                            'assets/icon/google_icon.png',
                                            width: 35,
                                            height: 35,
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Doesn't have an Account? ",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, '/signup');
                          },
                          child: const Text(
                            "Sign Up",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextEditingController? controller,
  }) {
    return SizedBox(
      width: double.infinity,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: label,
          prefixIcon: Icon(icon, color: Colors.grey[700]),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.85),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
          labelStyle: const TextStyle(color: Colors.black87),
        ),
      ),
    );
  }
}