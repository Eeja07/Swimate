import 'package:flutter/material.dart';

class HeightPickerDialog extends StatefulWidget {
  final int initialHeight;
  final void Function(int height) onSave;

  const HeightPickerDialog({
    super.key,
    required this.initialHeight,
    required this.onSave,
  });

  @override
  State<HeightPickerDialog> createState() => _HeightPickerDialogState();
}

class _HeightPickerDialogState extends State<HeightPickerDialog> {
  static const int minHeight = 55;
  static const int maxHeight = 270;

  late FixedExtentScrollController _controller;
  late int selectedHeight;

  @override
  void initState() {
    super.initState();
    selectedHeight = widget.initialHeight;
    _controller = FixedExtentScrollController(
      initialItem: selectedHeight - minHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F0F0F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        height: 360,
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              "Edit Height",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),

            // Wheel Picker
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _indicatorLine(),
                  ListWheelScrollView.useDelegate(
                    controller: _controller,
                    itemExtent: 50,
                    perspective: 0.003,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (i) {
                      setState(() {
                        selectedHeight = minHeight + i;
                      });
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: maxHeight - minHeight + 1,
                      builder: (context, i) {
                        final height = minHeight + i;
                        final isSelected = height == selectedHeight;
                        return Center(
                          child: Text(
                            "$height cm",
                            style: TextStyle(
                              fontSize: isSelected ? 32 : 26,
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
                  ),
                ],
              ),
            ),

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
                    widget.onSave(selectedHeight);
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

  Widget _indicatorLine() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 2, width: 100, color: Colors.orange),
        const SizedBox(height: 50),
        Container(height: 2, width: 100, color: Colors.orange),
      ],
    );
  }
}
