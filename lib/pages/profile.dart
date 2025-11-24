import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/fa_solid.dart';
import 'package:iconify_flutter/icons/ep.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  SupabaseClient get supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) Navigator.pushReplacementNamed(context, '/signin');
        return;
      }

      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response is Map) {
        final Map<String, dynamic> profile = (response as Map).cast<String, dynamic>();
        _nameController.text = profile['name']?.toString() ?? '';
        _emailController.text = profile['email']?.toString() ?? user.email ?? '';
        _ageController.text = profile['age']?.toString() ?? '';
        _heightController.text = profile['height']?.toString() ?? '';
        _weightController.text = profile['weight']?.toString() ?? '';
      } else {
        _emailController.text = user.email ?? '';
      }
    } catch (e, st) {
      debugPrint('Error loading profile: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No authenticated user')),
      );
      return;
    }

    setState(() => _saving = true);

    final int? age = int.tryParse(_ageController.text.trim());
    final double? height = double.tryParse(_heightController.text.trim());
    final double? weight = double.tryParse(_weightController.text.trim());

    final payload = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'age': age ?? 0,
      'height': height ?? 0,
      'weight': weight ?? 0,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await supabase.from('profiles').upsert({
        'id': user.id,
        ...payload,
      }, onConflict: 'id');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully')),
        );
      }
    } catch (e, st) {
      debugPrint('Error saving profile: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
      if (mounted) Navigator.pushReplacementNamed(context, '/signin');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.all(12.0),
            child: Iconify(Ep.arrow_left_bold, color: Colors.white, size: 26),
          ),
        ),
        title: const Text('Profile'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _signOut,
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/image/signup.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0x80000000),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),
                          Center(
                            child: CircleAvatar(
                              radius: 44,
                              backgroundColor: Colors.white24,
                              child: const Iconify(
                                FaSolid.user,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildTextField('Name', Icons.person, _nameController),
                          const SizedBox(height: 12),
                          _buildTextField('Email', Icons.email, _emailController, readOnly: true),
                          const SizedBox(height: 12),
                          _buildTextField('Age', Icons.cake, _ageController, keyboardType: TextInputType.number),
                          const SizedBox(height: 12),
                          _buildTextField('Height (cm)', Icons.height, _heightController, keyboardType: TextInputType.number),
                          const SizedBox(height: 12),
                          _buildTextField('Weight (kg)', Icons.monitor_weight, _weightController, keyboardType: TextInputType.number),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _saving ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1976D2),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

  Widget _buildTextField(String hint, IconData icon, TextEditingController controller,
      {bool readOnly = false, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey[700]),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.85),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
