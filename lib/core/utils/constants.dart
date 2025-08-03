import 'dart:ui';

import 'package:flutter/material.dart';

class Background extends StatelessWidget {
  const Background({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/background4.jpg', fit: BoxFit.cover),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(color: Colors.transparent),
        ),
        //Opacity(opacity: 0.85, child: AnimatedLinearGradientBackground()),
      ],
    );
  }
}

class AnimatedLinearGradientBackground extends StatefulWidget {
  const AnimatedLinearGradientBackground({super.key});

  @override
  State<AnimatedLinearGradientBackground> createState() =>
      _AnimatedLinearGradientBackgroundState();
}

class _AnimatedLinearGradientBackgroundState
    extends State<AnimatedLinearGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  final List<List<Color>> _gradientColors = [
    [const Color(0xFF354975), const Color.fromARGB(255, 52, 92, 157)],
    [const Color(0xFF232B45), const Color.fromARGB(255, 138, 145, 160)],
  ];

  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _index = (_index + 1) % _gradientColors.length;
        });
        _controller.forward(from: 0);
      }
    });
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nextIndex = (_index + 1) % _gradientColors.length;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                  _gradientColors[_index][0],
                  _gradientColors[nextIndex][0],
                  _animation.value,
                )!,
                Color.lerp(
                  _gradientColors[_index][1],
                  _gradientColors[nextIndex][1],
                  _animation.value,
                )!,
              ],
            ),
          ),
        );
      },
    );
  }
}
