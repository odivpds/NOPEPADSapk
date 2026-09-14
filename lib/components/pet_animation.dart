import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class PetAnimation extends StatelessWidget {
  const PetAnimation({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Lottie.asset('assets/lottie/pet.json',
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.pets, size: 50),
      ),
    );
  }
}
