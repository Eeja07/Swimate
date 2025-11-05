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
  late FixedExtentScrollController _scrollController;
  int selectedAge = 25;
  final int minAge = 10;
  final int maxAge = 120;

  @override
  void initState() {
    super.initState();
    // Set initial scroll position to age 25
    _scrollController = FixedExtentScrollController(
      initialItem: selectedAge - minAge,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleNextButton() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected age: $selectedAge'),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF2A2A2A),
      ),
    );

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return; // ✅ cek ulang setelah async gap
      Navigator.pushNamed(context, '/height');
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            // Title
            const Text(
              'What is your Age',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            // Subtitle
            Text(
              'You can always change it later',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 80),
            // Age Picker
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Selection indicator (yellow lines)
                  Positioned(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 120,
                          height: 3,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFA500),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 50),
                        Container(
                          width: 120,
                          height: 3,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFA500),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Scrollable age list
                  ListWheelScrollView.useDelegate(
                    controller: _scrollController,
                    itemExtent: 60,
                    perspective: 0.003,
                    diameterRatio: 1.5,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (index) {
                      setState(() {
                        selectedAge = minAge + index;
                      });
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: maxAge - minAge + 1,
                      builder: (context, index) {
                        final age = minAge + index;
                        final isSelected = age == selectedAge;
                        
                        return Center(
                          child: Text(
                            '$age',
                            style: TextStyle(
                              fontSize: isSelected ? 38 : 32,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected 
                                  ? Colors.white 
                                  : Colors.grey[700],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Next Button
            Padding(
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
          ],
        ),
      ),
    );
  }
}