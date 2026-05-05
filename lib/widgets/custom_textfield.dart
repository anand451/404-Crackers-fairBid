import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextField extends StatefulWidget {
  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.obscureText = false,
    this.onToggleObscure,
    this.suffix,
    this.readOnly = false,
    this.onTap,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final Widget? suffix;
  final bool readOnly;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  FocusNode? _internalFocusNode;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant CustomTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_handleFocusChange);
      _internalFocusNode?.removeListener(_handleFocusChange);
      _focusNode.addListener(_handleFocusChange);
    }
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = _focusNode.hasFocus;
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isFocused ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isFocused
                  ? const Color(0xFFFFC107)
                  : Colors.white.withValues(alpha: 0.16),
              width: isFocused ? 1.6 : 1.0,
            ),
            boxShadow: [
              if (isFocused)
                BoxShadow(
                  color: const Color(0xFFFFC107).withValues(alpha: 0.18),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            validator: widget.validator,
            onChanged: widget.onChanged,
            obscureText: widget.obscureText,
            readOnly: widget.readOnly,
            onTap: widget.onTap,
            inputFormatters: widget.inputFormatters,
            textCapitalization: widget.textCapitalization,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            cursorColor: const Color(0xFFFFC107),
            decoration: InputDecoration(
              filled: false,
              fillColor: Colors.transparent,
              icon: Icon(
                widget.icon,
                color: isFocused
                    ? const Color(0xFFFFD54F)
                    : Colors.white.withValues(alpha: 0.78),
              ),
              labelText: widget.label,
              labelStyle: TextStyle(
                color: isFocused
                    ? const Color(0xFFFFE082)
                    : Colors.white.withValues(alpha: 0.68),
              ),
              floatingLabelStyle: const TextStyle(color: Color(0xFFFFE082)),
              errorStyle: const TextStyle(
                color: Color(0xFFFFD5D5),
                fontWeight: FontWeight.w600,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
              border: InputBorder.none,
              suffixIcon: widget.onToggleObscure != null
                  ? IconButton(
                      onPressed: widget.onToggleObscure,
                      icon: Icon(
                        widget.obscureText
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    )
                  : widget.suffix,
            ),
          ),
        ),
      ),
    );
  }
}
