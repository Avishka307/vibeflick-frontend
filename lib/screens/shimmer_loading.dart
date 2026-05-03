// lib/widgets/shimmer_loading.dart

import 'package:flutter/material.dart';

class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                const Color(0xFF1A1A1A),
                const Color(0xFF2A2A2A),
                const Color(0xFF1A1A1A),
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
            ),
          ),
        );
      },
    );
  }
}

class VideoGridShimmer extends StatelessWidget {
  const VideoGridShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemSize = (screenWidth - 32 - 8) / 3;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 0.67,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        return ShimmerLoading(
          width: itemSize,
          height: itemSize / 0.67,
          borderRadius: BorderRadius.circular(8),
        );
      },
    );
  }
}

class CreatorsShimmer extends StatelessWidget {
  const CreatorsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            width: 70,
            margin: const EdgeInsets.only(right: 16),
            child: Column(
              children: [
                ShimmerLoading(
                  width: 64,
                  height: 64,
                  borderRadius: BorderRadius.circular(32),
                ),
                const SizedBox(height: 6),
                ShimmerLoading(
                  width: 50,
                  height: 12,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}