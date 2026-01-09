import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ObsiTitle extends StatelessWidget {
  const ObsiTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      ClipOval(
        child: Image.asset(
          'assets/images/icon.png', // Path to your app icon
          height: 24, // Adjust size as needed
        ),
      ),
      const SizedBox(width: 8),
      Text(
        "MD Bro",
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 24, // You can set other style properties here too
        ),
      )
    ]);
  }
}
