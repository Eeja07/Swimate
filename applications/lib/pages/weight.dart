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
        colorScheme: const ColorScheme.dark(surface: Color(0xFF000000)),
      ),
      home: const WeightPickerScreen(),
    );
  }
}

class WeightPickerScreen extends StatefulWidget {
  const WeightPickerScreen({super.key});

  @override
  State<WeightPickerScreen> createState() => _WeightPickerScreenState();
}

class _WeightPickerScreenState extends State<WeightPickerScreen> {
  // ==================== CONFIGURATION ====================

  late PageController _pageController;
  static const defaultWeight = 70;
  static const int minWeight = 30;
  static const int maxWeight = 200;

  // ==================== STATE VARIABLES ====================
  int selectedWeight = defaultWeight;
  bool isUpdating = false;

  // ==================== SUPABASE ====================
  final SupabaseClient supabase = Supabase.instance.client;
  String? get currentUserId => supabase.auth.currentUser?.id;

  // ==================== LIFECYCLE ====================

  @override
  void initState() {
    super.initState();
    _initializePageController();
    _loadCurrentWeight();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ==================== INITIALIZATION ====================

  void _initializePageController() {
    _pageController = PageController(
      initialPage: selectedWeight - minWeight,
      viewportFraction: 0.3,
    );
  }

  // ==================== DATA LOADING ====================

  Future<void> _loadCurrentWeight() async {
    if (currentUserId == null) {
      _showError('User not logged in');
      return;
    }

    try {
      final response = await supabase
          .from('profiles')
          .select('weight')
          .eq('id', currentUserId!)
          .single();

      if (response['weight'] != null) {
        final weight = response['weight'] as int;

        if (mounted) {
          setState(() {
            selectedWeight = weight;
          });
          // Animate to the loaded weight
          _pageController.animateToPage(
            weight - minWeight,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading weight: $e');
    }
  }

  // ==================== WEIGHT UPDATE ====================

  Future<void> _updateWeightInDatabase(int weight) async {
    if (currentUserId == null) return;
    if (isUpdating) return;

    setState(() => isUpdating = true);

    try {
      await supabase
          .from('profiles')
          .update({'weight': weight})
          .eq('id', currentUserId!);
      debugPrint('Weight updated successfully: $weight');
    } catch (e) {
      debugPrint('Error Updating weight: $e');
      _showError('Failed to update weight');
    } finally {
      if (mounted) {
        setState(() => isUpdating = false);
      }
    }
  }

  // ==================== EVENT HANDLERS ====================

  void _onWeightChanged(int index) {
    final newWeight = minWeight + index;

    setState(() {
      selectedWeight = newWeight;
    });

    _updateWeightInDatabase(newWeight);
  }

  void _handleNextButton() {
    if (!mounted) return;
    _showSuccessMessage('Weight saved: $selectedWeight kg');

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      Navigator.pushNamed(context, '/dashboard');
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Back button
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 20),
            // Title
            const Center(
              child: Text(
                'What is your Weight',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Subtitle
            Center(
              child: Text(
                'This help us create your\npersonalized info',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ),
            const Spacer(),
            // Weight Picker
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Arrow indicator
                  Positioned(
                    bottom: 30,
                    child: Image.asset(
                      'assets/icon/weight_arrow.png',
                      width: 40,
                      height: 40,
                      color: const Color(0xFF006AFF),
                    ),
                  ),
                  // PageView for weight selection
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onWeightChanged,
                    itemCount: maxWeight - minWeight + 1,
                    itemBuilder: (context, index) {
                      final weight = minWeight + index;
                      final isSelected = weight == selectedWeight;

                      return Center(
                        child: Text(
                          '$weight',
                          style: TextStyle(
                            fontSize: isSelected ? 40 : 32,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),
            // Next Button
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 50),
                child: ElevatedButton(
                  onPressed: isUpdating ? null : _handleNextButton,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[800],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 60,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: isUpdating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Next',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}