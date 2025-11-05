import 'package:flutter/material.dart';

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
  late PageController _pageController;
  int selectedWeight = 70;
  final int minWeight = 30;
  final int maxWeight = 200;

  @override
  void initState() {
    super.initState();
    // Set initial position to weight 70
    _pageController = PageController(
      initialPage: selectedWeight - minWeight,
      viewportFraction: 0.2,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleNextButton() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected weight: $selectedWeight kg'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF2A2A2A),
        ),
      );
    }

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return; 
      Navigator.pushNamed(context, '/dashboard');
    });
  }

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
                  // Handle back actio
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
                  Positioned(
                    bottom: 30,
                    child: Image.asset(
                      'assets/icon/weight_arrow.png',
                      width: 40,
                      height: 40,
                      color: const Color(0xFF006AFF),
                    ),
                  ),
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        selectedWeight = minWeight + index;
                      });
                    },
                    itemCount: maxWeight - minWeight + 1,
                    itemBuilder: (context, index) {
                      final weight = minWeight + index;
                      final isSelected = weight == selectedWeight;
                      
                      return Center(
                        child: Text(
                          '$weight',
                          style: TextStyle(
                            fontSize: isSelected ? 40 : 32,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected 
                                ? Colors.white 
                                : Colors.grey[700],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 50),
                child: ElevatedButton(
                  onPressed: _handleNextButton,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}