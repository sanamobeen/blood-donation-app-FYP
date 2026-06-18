import 'package:flutter/material.dart';

/// Urgency levels for blood requests
enum UrgencyLevel {
  normal,
  urgent,
  critical,
}

/// An urgency tag widget following the LifeDrop design system.
///
/// Features:
/// - Normal: Pink background
/// - Urgent: Orange-red background
/// - Critical: Deep red background
/// - Rounded pill shape with small text
class UrgencyTag extends StatelessWidget {
  const UrgencyTag({
    super.key,
    required this.level,
  });

  final UrgencyLevel level;

  static const Map<UrgencyLevel, Color> _backgroundColor = {
    UrgencyLevel.normal: Color(0xFFFFD6CC),
    UrgencyLevel.urgent: Color(0xFFE85D04),
    UrgencyLevel.critical: Color(0xFF8B0000),
  };

  static const Map<UrgencyLevel, Color> _textColor = {
    UrgencyLevel.normal: Color(0xFF8B0000),
    UrgencyLevel.urgent: Colors.white,
    UrgencyLevel.critical: Colors.white,
  };

  static const Map<UrgencyLevel, String> _label = {
    UrgencyLevel.normal: 'Normal',
    UrgencyLevel.urgent: 'Urgent',
    UrgencyLevel.critical: 'Critical',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _backgroundColor[level]!,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        _label[level]!,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _textColor[level],
        ),
      ),
    );
  }
}
