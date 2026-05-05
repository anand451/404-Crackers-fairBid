import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../utils/auth_validators.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/toggle_switch.dart';

enum _AuthMode { login, register }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _panController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _loginEmailFocus = FocusNode();
  final _loginPasswordFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _registerEmailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _aadhaarFocus = FocusNode();
  final _panFocus = FocusNode();
  final _registerPasswordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  _AuthMode _authMode = _AuthMode.login;
  AutovalidateMode _loginAutovalidate = AutovalidateMode.disabled;
  AutovalidateMode _registerAutovalidate = AutovalidateMode.disabled;
  bool _loginPasswordObscured = true;
  bool _registerPasswordObscured = true;
  bool _confirmPasswordObscured = true;
  DateTime? _selectedDateOfBirth;
  final String _selectedUserType = 'Buyer';

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _fullNameController.dispose();
    _registerEmailController.dispose();
    _phoneController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    _dateOfBirthController.dispose();
    _registerPasswordController.dispose();
    _confirmPasswordController.dispose();
    _loginEmailFocus.dispose();
    _loginPasswordFocus.dispose();
    _nameFocus.dispose();
    _registerEmailFocus.dispose();
    _phoneFocus.dispose();
    _aadhaarFocus.dispose();
    _panFocus.dispose();
    _registerPasswordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _switchMode(_AuthMode mode) async {
    if (_authMode == mode) {
      return;
    }
    await HapticFeedback.lightImpact();
    if (!mounted) {
      return;
    }
    FocusScope.of(context).unfocus();
    context.read<AuthProvider>().clearFeedback();
    setState(() {
      _authMode = mode;
    });
  }

  Future<void> _pickDateOfBirth() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 21, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0FAF9A),
              secondary: Color(0xFFFFC107),
            ),
          ),
          child: child!,
        );
      },
    );

    if (selected != null) {
      setState(() {
        _selectedDateOfBirth = selected;
        _dateOfBirthController.text =
            DateFormat('dd MMM yyyy').format(selected);
      });
    }
  }

  Future<void> _submitLogin() async {
    setState(() {
      _loginAutovalidate = AutovalidateMode.onUserInteraction;
    });

    if (!_loginFormKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      email: _loginEmailController.text.trim(),
      password: _loginPasswordController.text,
    );

    if (!mounted) {
      return;
    }

    if (!success && authProvider.authError != null) {
      _showSnackBar(authProvider.authError!, isError: true);
    }
  }

  Future<void> _submitRegister() async {
    setState(() {
      _registerAutovalidate = AutovalidateMode.onUserInteraction;
    });

    final isValid = _registerFormKey.currentState!.validate() &&
        AuthValidators.dateOfBirth(_selectedDateOfBirth) == null;
    if (!isValid) {
      setState(() {});
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      fullName: _fullNameController.text.trim(),
      email: _registerEmailController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      aadhaarNumber: _aadhaarController.text.trim(),
      panNumber: _panController.text.trim().toUpperCase(),
      dateOfBirth: _selectedDateOfBirth!,
      password: _registerPasswordController.text,
      userType: _selectedUserType,
    );

    if (!mounted) {
      return;
    }

    _showSnackBar(
      success
          ? 'Account created. Verification email sent to ${_registerEmailController.text.trim()}.'
          : authProvider.authError ?? 'Could not create your account.',
      isError: !success,
    );
  }

  Future<void> _showResetPasswordSheet() async {
    final controller = TextEditingController(text: _loginEmailController.text);
    final formKey = GlobalKey<FormState>();

    final resetEmail = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E213E).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reset password',
                        style: GoogleFonts.sora(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'We will send a secure reset link to your email address.',
                        style: GoogleFonts.manrope(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 22),
                      CustomTextField(
                        controller: controller,
                        label: 'Email',
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: AuthValidators.email,
                      ),
                      const SizedBox(height: 20),
                      _GlowButton(
                        label: 'Send reset link',
                        onPressed: () {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }
                          Navigator.of(
                            sheetContext,
                          ).pop(controller.text.trim());
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    controller.dispose();

    if (resetEmail == null || !mounted) {
      return;
    }

    final provider = context.read<AuthProvider>();
    final success = await provider.sendPasswordReset(resetEmail);
    final errorMessage = provider.authError;

    if (!mounted) {
      return;
    }

    _showSnackBar(
      success
          ? 'Reset link sent. Check your inbox.'
          : errorMessage ?? 'Could not send reset link.',
      isError: !success,
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
            isError ? const Color(0xFFB3261E) : const Color(0xFF0FAF9A),
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.sora(
      fontSize: 32,
      fontWeight: FontWeight.w800,
      color: Colors.white,
      letterSpacing: -0.8,
    );
    final subtitleStyle = GoogleFonts.manrope(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: Colors.white.withValues(alpha: 0.72),
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF16B6A3),
                Color(0xFF0D5C95),
                Color(0xFF081B3A),
              ],
            ),
          ),
          child: Stack(
            children: [
              const _AuthBackdrop(),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      24,
                      20,
                      MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        children: [
                          Hero(
                            tag: 'fairbid-logo',
                            child: Container(
                              width: 108,
                              height: 108,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFFC107,
                                    ).withValues(alpha: 0.22),
                                    blurRadius: 30,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Image.asset('assets/logo.png'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text('Welcome Back', style: titleStyle),
                          const SizedBox(height: 10),
                          Text('Ready for Auction!', style: subtitleStyle),
                          const SizedBox(height: 28),
                          _GlassShell(
                            child: Consumer<AuthProvider>(
                              builder: (context, authProvider, child) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ToggleSwitch(
                                      labels: const ['Login', 'Register'],
                                      selectedIndex:
                                          _authMode == _AuthMode.login ? 0 : 1,
                                      onChanged: (index) => _switchMode(
                                        index == 0
                                            ? _AuthMode.login
                                            : _AuthMode.register,
                                      ),
                                    ),
                                    AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 260),
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      transitionBuilder: (child, animation) {
                                        final offsetAnimation = Tween<Offset>(
                                          begin: const Offset(0.08, 0),
                                          end: Offset.zero,
                                        ).animate(animation);
                                        return FadeTransition(
                                          opacity: animation,
                                          child: SlideTransition(
                                            position: offsetAnimation,
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        key: ValueKey(_authMode),
                                        padding: const EdgeInsets.only(top: 26),
                                        child: _authMode == _AuthMode.login
                                            ? _buildLoginForm(authProvider)
                                            : _buildRegisterForm(authProvider),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(AuthProvider authProvider) {
    return Form(
      key: _loginFormKey,
      autovalidateMode: _loginAutovalidate,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FeedbackBanner(
            message: authProvider.authError,
            color: const Color(0xFFFF6B6B),
          ),
          const SizedBox(height: 2),
          Text(
            'Secure access to your live auctions and verified bids.',
            style: GoogleFonts.manrope(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          CustomTextField(
            controller: _loginEmailController,
            label: 'Email',
            icon: Icons.alternate_email_rounded,
            focusNode: _loginEmailFocus,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: AuthValidators.email,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _loginPasswordController,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            focusNode: _loginPasswordFocus,
            obscureText: _loginPasswordObscured,
            validator: AuthValidators.password,
            onToggleObscure: () {
              setState(() {
                _loginPasswordObscured = !_loginPasswordObscured;
              });
            },
            onChanged: (_) => context.read<AuthProvider>().clearFeedback(),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: authProvider.isResetPasswordLoading
                  ? null
                  : _showResetPasswordSheet,
              child: Text(
                'Forgot password?',
                style: GoogleFonts.manrope(
                  color: const Color(0xFFFFD54F),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _GlowButton(
            label: authProvider.isLoginLoading ? 'Signing in...' : 'Login',
            onPressed: authProvider.isLoginLoading ? null : _submitLogin,
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(AuthProvider authProvider) {
    final dateError = AuthValidators.dateOfBirth(_selectedDateOfBirth);

    return Form(
      key: _registerFormKey,
      autovalidateMode: _registerAutovalidate,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FeedbackBanner(
            message: authProvider.authError,
            color: const Color(0xFFFF6B6B),
          ),
          const SizedBox(height: 2),
          Text(
            'Create your verified FairBid profile in a few secure steps.',
            style: GoogleFonts.manrope(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          CustomTextField(
            controller: _fullNameController,
            label: 'Full Name',
            icon: Icons.person_outline_rounded,
            focusNode: _nameFocus,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: AuthValidators.fullName,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: _registerEmailController,
            label: 'Email',
            icon: Icons.alternate_email_rounded,
            focusNode: _registerEmailFocus,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: AuthValidators.email,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: _phoneController,
            label: 'Phone Number',
            icon: Icons.phone_iphone_rounded,
            focusNode: _phoneFocus,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            validator: AuthValidators.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: _aadhaarController,
            label: 'Aadhaar Number',
            icon: Icons.badge_outlined,
            focusNode: _aadhaarFocus,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            validator: AuthValidators.aadhaar,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12),
            ],
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: _panController,
            label: 'PAN Number',
            icon: Icons.credit_card_rounded,
            focusNode: _panFocus,
            textInputAction: TextInputAction.next,
            validator: AuthValidators.pan,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              LengthLimitingTextInputFormatter(10),
              UpperCaseTextFormatter(),
            ],
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: _dateOfBirthController,
            label: 'Date of Birth',
            icon: Icons.cake_outlined,
            readOnly: true,
            onTap: _pickDateOfBirth,
            validator: (_) => dateError,
            suffix: Icon(
              Icons.calendar_month_rounded,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: _registerPasswordController,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            focusNode: _registerPasswordFocus,
            obscureText: _registerPasswordObscured,
            validator: AuthValidators.password,
            onToggleObscure: () {
              setState(() {
                _registerPasswordObscured = !_registerPasswordObscured;
              });
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          CustomTextField(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            icon: Icons.verified_user_outlined,
            focusNode: _confirmPasswordFocus,
            obscureText: _confirmPasswordObscured,
            validator: (value) => AuthValidators.confirmPassword(
              value,
              _registerPasswordController.text,
            ),
            onToggleObscure: () {
              setState(() {
                _confirmPasswordObscured = !_confirmPasswordObscured;
              });
            },
          ),
          const SizedBox(height: 20),
          _GlowButton(
            label: authProvider.isRegisterLoading
                ? 'Creating account...'
                : 'Register',
            onPressed: authProvider.isRegisterLoading ? null : _submitRegister,
          ),
        ],
      ),
    );
  }
}

class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned(
          top: -120,
          left: -80,
          child: _GlowOrb(
            size: 240,
            colors: [Color(0xB230D5C8), Color(0x0016B6A3)],
          ),
        ),
        Positioned(
          right: -90,
          top: 220,
          child: _GlowOrb(
            size: 220,
            colors: [Color(0x80FFC107), Color(0x00FFC107)],
          ),
        ),
        Positioned(
          bottom: -130,
          right: -70,
          child: _GlowOrb(
            size: 280,
            colors: [Color(0xA0156BFF), Color(0x00156BFF)],
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.colors,
  });

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}

class _GlassShell extends StatelessWidget {
  const _GlassShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.08),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({
    required this.message,
    required this.color,
  });

  final String? message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: message == null
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(message),
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.26)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: color, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message!,
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _GlowButton extends StatefulWidget {
  const _GlowButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton> {
  double _scale = 1;

  void _setScale(double scale) {
    if (mounted) {
      setState(() {
        _scale = scale;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;

    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTapDown: isEnabled ? (_) => _setScale(0.98) : null,
        onTapUp: isEnabled ? (_) => _setScale(1) : null,
        onTapCancel: isEnabled ? () => _setScale(1) : null,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                if (isEnabled)
                  BoxShadow(
                    color: const Color(0xFFFFC107).withValues(alpha: 0.32),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
              ],
            ),
            child: ElevatedButton(
              onPressed: widget.onPressed,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: const Color(0xFF11213A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                widget.label,
                style: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
