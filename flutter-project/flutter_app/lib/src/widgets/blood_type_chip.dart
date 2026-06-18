import 'package:flutter/material.dart';

/// A blood type selection chip following the LifeDrop design system.
///
/// Features:
/// - Circular pill shape
/// - Soft pink background when not selected
/// - Crimson background when selected
/// - White text when selected, crimson text when not
class BloodTypeChip extends StatelessWidget {
  const BloodTypeChip({
    super.key,
    required this.bloodType,
    required this.isSelected,
    required this.onSelected,
  });

  final String bloodType;
  final bool isSelected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        bloodType,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : const Color(0xFFD62828),
        ),
      ),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: const Color(0xFFD62828),
      backgroundColor: const Color(0xFFFFD6CC).withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide.none,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      labelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
