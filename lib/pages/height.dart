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
      home: const HeightPickerScreen(),
    );
  }
}

class HeightPickerScreen extends StatefulWidget {
  const HeightPickerScreen({super.key});

  @override
  State<HeightPickerScreen> createState() => _HeightPickerScreenState();
}

class _HeightPickerScreenState extends State<HeightPickerScreen> {
  // ==================== CONFIGURATION ====================
  
  static const int minHeight = 55;
  static const int maxHeight = 270;
  static const int defaultHeight = 175;
  
  // ==================== STATE VARIABLES ====================
  
  late FixedExtentScrollController _scrollController;
  int selectedHeight = defaultHeight;
  bool isUpdating = false;
  
  // ==================== SUPABASE ====================
  
  final SupabaseClient supabase = Supabase.instance.client;
  
  String? get currentUserId => supabase.auth.currentUser?.id;

  // ==================== LIFECYCLE ====================
  
  @override
  void initState() {
    super.initState();
    _initializeScrollController();
    _loadCurrentHeight();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ==================== INITIALIZATION ====================
  
  void _initializeScrollController() {
    _scrollController = FixedExtentScrollController(
      initialItem: selectedHeight - minHeight,
    );
  }

  // ==================== DATA LOADING ====================
  
  Future<void> _loadCurrentHeight() async {
    if (currentUserId == null) {
      _showError('User not logged in');
      return;
    }

    try {
      final response = await supabase
          .from('profiles')
          .select('height')
          .eq('id', currentUserId!)
          .single();

      if (response['height'] != null) {
        final height = response['height'] as int;
        
        if (mounted) {
          setState(() {
            selectedHeight = height;
            // Update scroll position to match loaded height
            _scrollController.jumpToItem(height - minHeight);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading height: $e');
      // Keep default height if loading fails
    }
  }

  // ==================== HEIGHT UPDATE ====================
  
  Future<void> _updateHeightInDatabase(int height) async {
    if (currentUserId == null) return;
    if (isUpdating) return; // Prevent multiple simultaneous updates

    setState(() => isUpdating = true);

    try {
      await supabase
          .from('profiles')
          .update({'height': height})
          .eq('id', currentUserId!);

      debugPrint('Height updated successfully: $height');
    } catch (e) {
      debugPrint('Error updating height: $e');
      _showError('Failed to update height');
    } finally {
      if (mounted) {
        setState(() => isUpdating = false);
      }
    }
  }

  // ==================== EVENT HANDLERS ====================
  
  void _onHeightChanged(int index) {
    final newHeight = minHeight + index;
    
    setState(() {
      selectedHeight = newHeight;
    });

    // Auto-update to database
    _updateHeightInDatabase(newHeight);
  }

  void _handleNextButton() {
    if (!mounted) return;

    _showSuccessMessage('Height saved: $selectedHeight');

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      Navigator.pushNamed(context, '/weight');
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
            _buildHeightPicker(),
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
          'What is your Height',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Feel free to access this app',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildHeightPicker() {
    return Expanded(
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildSelectionIndicator(),
          _buildScrollableHeightList(),
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

  Widget _buildScrollableHeightList() {
    return ListWheelScrollView.useDelegate(
      controller: _scrollController,
      itemExtent: 60,
      perspective: 0.003,
      diameterRatio: 1.5,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: _onHeightChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: maxHeight - minHeight + 1,
        builder: (context, index) {
          final height = minHeight + index;
          return _buildHeightItem(height);
        },
      ),
    );
  }

  Widget _buildHeightItem(int height) {
    final isSelected = height == selectedHeight;
    
    return Center(
      child: Text(
        '$height cm',
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