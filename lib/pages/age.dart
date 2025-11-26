import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF000000),
        ),
      ),
      home: const AgePickerScreen(),
    );
  }
}

class AgePickerScreen extends StatefulWidget {
  const AgePickerScreen({super.key});

  @override
  State<AgePickerScreen> createState() => _AgePickerScreenState();
}

class _AgePickerScreenState extends State<AgePickerScreen> {
  // ==================== CONFIGURATION ====================
  
  static const int minAge = 10;
  static const int maxAge = 120;
  static const int defaultAge = 25;
  
  // ==================== STATE VARIABLES ====================
  
  late FixedExtentScrollController _scrollController;
  int selectedAge = defaultAge;
  bool isUpdating = false;
  
  // ==================== SUPABASE ====================
  
  final SupabaseClient supabase = Supabase.instance.client;
  
  String? get currentUserId => supabase.auth.currentUser?.id;

  // ==================== LIFECYCLE ====================
  
  @override
  void initState() {
    super.initState();
    _initializeScrollController();
    _loadCurrentAge();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ==================== INITIALIZATION ====================
  
  void _initializeScrollController() {
    _scrollController = FixedExtentScrollController(
      initialItem: selectedAge - minAge,
    );
  }

  // ==================== DATA LOADING ====================
  
  Future<void> _loadCurrentAge() async {
    if (currentUserId == null) {
      _showError('User not logged in');
      return;
    }

    try {
      final response = await supabase
          .from('profiles')
          .select('age')
          .eq('id', currentUserId!)
          .single();

      if (response['age'] != null) {
        final age = response['age'] as int;
        
        if (mounted) {
          setState(() {
            selectedAge = age;
            // Update scroll position to match loaded age
            _scrollController.jumpToItem(age - minAge);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading age: $e');
      // Keep default age if loading fails
    }
  }

  // ==================== AGE UPDATE ====================
  
  Future<void> _updateAgeInDatabase(int age) async {
    if (currentUserId == null) return;
    if (isUpdating) return; // Prevent multiple simultaneous updates

    setState(() => isUpdating = true);

    try {
      await supabase
          .from('profiles')
          .update({'age': age})
          .eq('id', currentUserId!);

      debugPrint('Age updated successfully: $age');
    } catch (e) {
      debugPrint('Error updating age: $e');
      _showError('Failed to update age');
    } finally {
      if (mounted) {
        setState(() => isUpdating = false);
      }
    }
  }

  // ==================== EVENT HANDLERS ====================
  
  void _onAgeChanged(int index) {
    final newAge = minAge + index;
    
    setState(() {
      selectedAge = newAge;
    });

    // Auto-update to database
    _updateAgeInDatabase(newAge);
  }

  void _handleNextButton() {
    if (!mounted) return;

    _showSuccessMessage('Age saved: $selectedAge');

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      Navigator.pushNamed(context, '/height');
    });
  }

  // ==================== UI HELPERS ====================
  
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF2A2A2A),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red[900],
      ),
    );
  }

  // ==================== BUILD METHODS ====================
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            _buildHeader(),
            const SizedBox(height: 80),
            _buildAgePicker(),
            _buildNextButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text(
          'What is your Age',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You can always change it later',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildAgePicker() {
    return Expanded(
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildSelectionIndicator(),
          _buildScrollableAgeList(),
          if (isUpdating) _buildLoadingIndicator(),
        ],
      ),
    );
  }

  Widget _buildSelectionIndicator() {
    return Positioned(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIndicatorLine(),
          const SizedBox(height: 50),
          _buildIndicatorLine(),
        ],
      ),
    );
  }

  Widget _buildIndicatorLine() {
    return Container(
      width: 120,
      height: 3,
      decoration: BoxDecoration(
        color: const Color(0xFFFFA500),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildScrollableAgeList() {
    return ListWheelScrollView.useDelegate(
      controller: _scrollController,
      itemExtent: 60,
      perspective: 0.003,
      diameterRatio: 1.5,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: _onAgeChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: maxAge - minAge + 1,
        builder: (context, index) {
          final age = minAge + index;
          return _buildAgeItem(age);
        },
      ),
    );
  }

  Widget _buildAgeItem(int age) {
    final isSelected = age == selectedAge;
    
    return Center(
      child: Text(
        '$age',
        style: TextStyle(
          fontSize: isSelected ? 38 : 32,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? Colors.white : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Positioned(
      top: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFA500)),
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Saving...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 50),
      child: ElevatedButton(
        onPressed: isUpdating ? null : _handleNextButton,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B35),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[800],
          disabledForegroundColor: Colors.grey[600],
          padding: const EdgeInsets.symmetric(
            horizontal: 60,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Next',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}