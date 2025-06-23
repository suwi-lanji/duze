// shared/widgets/custom_button.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final Icon? icon;
  final Color? color;
  final Gradient? gradient;
  final VoidCallback? onPressed;

  const CustomButton({
    super.key,
    required this.text,
    this.isLoading = false,
    this.icon,
    this.color,
    this.gradient,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? (color ?? AppColors.primary) : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Center(
              child: isLoading
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          icon!,
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            text,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}