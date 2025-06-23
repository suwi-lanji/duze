
// shared/widgets/custom_card.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_colors.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final bool glassEffect;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final double elevation;

  const CustomCard({
    super.key,
    required this.child,
    this.glassEffect = false,
    this.margin = const EdgeInsets.all(8),
    this.padding = const EdgeInsets.all(8),
    this.elevation = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (elevation > 0)
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: elevation * 2,
              offset: Offset(0, elevation),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: glassEffect ? ImageFilter.blur(sigmaX: 10, sigmaY: 10) : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color:  AppColors.glassBackground ,
              border: glassEffect ? Border.all(color: AppColors.glassBorder) : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
