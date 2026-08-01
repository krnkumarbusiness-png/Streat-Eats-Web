// lib/widgets/disclaimer_widget.dart
import 'package:flutter/material.dart';

class DisclaimerWidget extends StatelessWidget {
  const DisclaimerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Text(
        'We are an independent delivery platform. We are not officially affiliated with or endorsed by the restaurants listed above. All brand names are property of their respective owners.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          height: 1.6,
          color: const Color(0xFF1A1814).withOpacity(0.28),
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
