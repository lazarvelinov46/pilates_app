import 'package:flutter/material.dart';


class ConfirmButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const ConfirmButton({
    super.key,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        child: const Text("Confirm Booking"),
      ),
    );
  }
}
