import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.label,
    this.padding = const EdgeInsets.all(24),
  });

  final String? label;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: color,
              ),
            ),
            if (label != null) ...[
              const SizedBox(height: 12),
              Text(
                label!,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppMessageState extends StatelessWidget {
  const AppMessageState({
    super.key,
    required this.icon,
    required this.message,
    this.action,
    this.padding = const EdgeInsets.all(28),
  });

  final IconData icon;
  final String message;
  final Widget? action;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: color),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 14),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
