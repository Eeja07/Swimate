import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/fa_solid.dart';
import 'package:iconify_flutter/icons/ep.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  bool obscurePassword = true;
  bool _isLoading = false;
  
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();


  SupabaseClient get supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();

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
        // Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }

  Future<bool> _isNewUser(String userId) async {
    final response = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle(); // kalau kosong, hasilnya null

    // Kalau null artinya belum ada profil → user baru
    return response == null;
  }


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _signupWithGoogle() async {
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

      final user = supabase.auth.currentUser;

      debugPrint('=== Google Sign In Success ===');
      debugPrint('User ID: ${user?.id}');
      debugPrint('Email: ${user?.email}');
      debugPrint('Name: ${user?.userMetadata?['full_name']}');
      debugPrint('==============================');

      if (user != null) {
        final bool isNew = await _isNewUser(user.id);

        if (isNew) {
          debugPrint('User baru terdeteksi, buat data profil...');
          await supabase.from('profiles').insert({
            'id': user.id,
            'email': user.email,
            'name': user.userMetadata?['full_name'],
            'created_at': DateTime.now().toIso8601String(),
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Welcome! Please set up your age')),
            );
            Navigator.pushReplacementNamed(context, '/age');
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Welcome back!')),
            );
            Navigator.pushReplacementNamed(context, '/dashboard');
          }
        }
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


  Future<void> _signUpWithEmailPassword() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _usernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await supabase.auth.signOut(); // pastikan logout dulu

      final response = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = response.user;

      if (user != null) {
        // Buat profil default di tabel profiles
        await supabase.from('profiles').insert({
          'id': user.id,
          'name': _usernameController.text.trim(),
          'age': 0,
          'height': 0,
          'weight': 0,
          'created_at': DateTime.now().toIso8601String(),
          'email': _emailController.text.trim(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created! Please check your email to verify your account',
            ),
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.pushReplacementNamed(context, '/age');
      }
    } catch (error) {
      final errorMessage = error.toString();

      // Tangani kasus email sudah terdaftar
      if (errorMessage.contains('User already registered')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email already registered. Please sign in instead.'),
            ),
          );
          Navigator.pushReplacementNamed(context, '/signin');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $errorMessage')),
          );
        }
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

          // Content - Now fully scrollable
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
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context); // atau aksi lain
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

                        // Logo + Text di tengah layar
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
                            'Create an Account',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const Text(
                            'Welcome to SwiMate!!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 32),

                          _buildTextField(
                            label: "Username",
                            icon: Icons.person,
                            controller: _usernameController,
                          ),

                          const SizedBox(height: 24),

                          _buildTextField(
                            label: "Email",
                            icon: Icons.email,
                            controller: _emailController,
                          ),

                          const SizedBox(height: 24),

                          _buildTextField(
                            label: "Password",
                            icon: Icons.lock,
                            controller: _passwordController,
                            obscure: obscurePassword,
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

                          // Create Account Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signUpWithEmailPassword,
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
                              child: const Text(
                                'Create Account',
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
                                onTap: _isLoading ? null : _signupWithGoogle,
                                child: Container(
                                  margin: const EdgeInsets.all(8),
                                  width: 60,
                                  height: 60,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFD9D9D9), // abu-abu muda
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Image.asset(
                                      'assets/icon/google_icon.png', // path sesuai pubspec.yaml
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

                    const SizedBox(height: 40),
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
    TextEditingController? controller,
    bool obscure = false,
    Widget? suffixIcon,
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
