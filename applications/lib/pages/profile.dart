import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/fa_solid.dart';
import 'package:iconify_flutter/icons/ep.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/height_picker_dialog.dart';
import '../widgets/weight_picker_dialog.dart';

// --- Konstanta Warna ---
const Color primaryColor = Color(0xFF1976D2); // Biru yang sudah ada
const Color accentColor = Color(0xFF4FC3F7); // Biru muda untuk highlight
const Color darkOverlayColor = Color(0xB3000000); // 70% opacity hitam untuk overlay
const Color lightTextColor = Colors.white; // Warna Putih (sesuai permintaan)
const Color fieldFillColor = Color(0xDDFFFFFF); // Putih dengan opasitas tinggi untuk input

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
    final int? height = int.tryParse(_heightController.text.trim());
    final int? weight = int.tryParse(_weightController.text.trim());

    final payload = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'age': age,
      'height': height,
      'weight': weight,
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.all(12.0),
            child: Iconify(Ep.arrow_left_bold, color: lightTextColor, size: 26),
          ),
        ),
        // PERUBAHAN: Teks 'Profile' dibuat warna putih
        title: const Text('Profile', style: TextStyle(color: lightTextColor)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _signOut,
            child: const Text('Sign Out', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
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
          Container(
            color: darkOverlayColor,
          ),
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: lightTextColor))
                : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xCC1E1E1E),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          spreadRadius: 0,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: primaryColor.withValues(alpha: 0.2),
                            child: const Iconify(
                              FaSolid.user,
                              color: primaryColor,
                              size: 50,
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        _buildTextField('Full Name', Icons.person, _nameController),
                        const SizedBox(height: 16),
                        _buildTextField('Email Address', Icons.email, _emailController, readOnly: true),
                        const SizedBox(height: 16),
                        _buildTextField('Age (years)', Icons.cake, _ageController, keyboardType: TextInputType.number),
                        const SizedBox(height: 16),

                        // Height Picker (dengan tombol Edit/ikon pensil)
                        _buildTextField(
                          'Height (cm)',
                          Icons.height,
                          _heightController,
                          disableKeyboard: true,
                          keyboardType: TextInputType.number,
                          // TOMBOL EDIT TETAP ADA
                          suffix: IconButton(
                            icon: const Icon(Icons.edit, color: primaryColor),
                            onPressed: () {
                              final double currentHeight = double.tryParse(_heightController.text) ?? 0;

                              showDialog(
                                context: context,
                                builder: (_) => HeightPickerDialog(
                                  initialHeight: currentHeight.toInt(),
                                  onSave: (newHeight) async {
                                    final user = supabase.auth.currentUser;
                                    if (user == null) return;

                                    await supabase
                                        .from('profiles')
                                        .update({'height': newHeight})
                                        .eq('id', user.id);

                                    setState(() {
                                      _heightController.text = newHeight.toString();
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Weight Picker (dengan tombol Edit/ikon pensil)
                        _buildTextField(
                          'Weight (kg)',
                          Icons.monitor_weight,
                          _weightController,
                          disableKeyboard: true,
                          keyboardType: TextInputType.number,
                          // TOMBOL EDIT TETAP ADA
                          suffix: IconButton(
                            icon: const Icon(Icons.edit, color: primaryColor),
                            onPressed: () {
                              final double currentWeight = double.tryParse(_weightController.text) ?? 0;

                              showDialog(
                                context: context,
                                builder: (_) => WeightPickerDialog(
                                  initialWeight: currentWeight.toInt(),
                                  onSave: (newWeight) async {
                                    final user = supabase.auth.currentUser;
                                    if (user == null) return;

                                    await supabase
                                        .from('profiles')
                                        .update({'weight': newWeight})
                                        .eq('id', user.id);

                                    setState(() {
                                      _weightController.text = newWeight.toString();
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Tombol Save
                        ElevatedButton(
                          onPressed: _saving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            disabledBackgroundColor: primaryColor.withValues(alpha: 0.5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 5,
                          ),
                          child: _saving
                              ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(color: lightTextColor, strokeWidth: 3),
                          )
                              : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: lightTextColor, // PERUBAHAN: Teks 'Save' dibuat warna putih
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      String hint,
      IconData icon,
      TextEditingController controller, {
        bool readOnly = false,
        bool disableKeyboard = false,
        TextInputType keyboardType = TextInputType.text,
        Widget? suffix,
      }) {
    final bool isEmailReadOnly = controller == _emailController && readOnly;

    return TextField(
      controller: controller,
      readOnly: readOnly || disableKeyboard,
      keyboardType: disableKeyboard ? TextInputType.none : keyboardType,
      onTap: disableKeyboard ? () {} : null,
      style: TextStyle(
        color: isEmailReadOnly ? Colors.grey[600] : Colors.black87,
        fontWeight: isEmailReadOnly ? FontWeight.w600 : FontWeight.normal,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isEmailReadOnly ? Colors.grey : Colors.grey[700]),
        prefixIcon: Icon(icon, color: primaryColor),
        suffixIcon: suffix,
        filled: true,
        fillColor: isEmailReadOnly ? fieldFillColor.withValues(alpha: 0.8) : fieldFillColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}