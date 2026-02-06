import 'package:flutter/material.dart';


class ConfirmButton extends StatelessWidget {
  final bool enabled;
  final bool isLoading;
  final bool isFull;
  final bool alreadyBooked;
  final VoidCallback onPressed;

  const ConfirmButton({
    super.key,
    required this.enabled,
    required this.onPressed,
    this.isLoading=false,
    this.isFull=false,
    this.alreadyBooked=false
  });

  String _label() {
    if (alreadyBooked) return 'Already booked';
    if (isFull) return 'Session full';
    return 'Confirm Booking';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (enabled && !isLoading) ? onPressed : null,
        child: isLoading
            // 🔹 NEW: loading indicator prevents double booking
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(_label()),
      ),
    );
  }
}
