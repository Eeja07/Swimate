import 'package:flutter/material.dart';

class WeightPickerDialog extends StatefulWidget {
  final int initialWeight;
  final void Function(int weight) onSave;

  const WeightPickerDialog({
    super.key,
    required this.initialWeight,
    required this.onSave,
  });

  @override
  State<WeightPickerDialog> createState() => _WeightPickerDialogState();
}

class _WeightPickerDialogState extends State<WeightPickerDialog> {
  static const int minWeight = 30;
  static const int maxWeight = 200;

  late PageController _pageController;
  late int selectedWeight;

  @override
  void initState() {
    super.initState();
    selectedWeight = widget.initialWeight;
    _pageController = PageController(
      initialPage: selectedWeight - minWeight,
      viewportFraction: 0.3,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F0F0F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        height: 330,
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              "Edit Weight",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),

            // Weight selector
            SizedBox(
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    bottom: 10,
                    child: Icon(Icons.arrow_drop_down,
                        size: 40, color: Colors.blue),
                  ),
                  PageView.builder(
                    controller: _pageController,
                    itemCount: maxWeight - minWeight + 1,
                    onPageChanged: (i) {
                      setState(() {
                        selectedWeight = minWeight + i;
                      });
                    },
                    itemBuilder: (context, i) {
                      final weight = minWeight + i;
                      final isSelected = weight == selectedWeight;
                      return Center(
                        child: Text(
                          "$weight",
                          style: TextStyle(
                            fontSize: isSelected ? 38 : 28,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade600,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  child: const Text("Cancel"),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                  ),
                  child: const Text("Save"),
                  onPressed: () {
                    widget.onSave(selectedWeight);
                    Navigator.pop(context);
                  },
                )
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
