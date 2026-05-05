import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _introDuration = Duration(milliseconds: 3000);
  static const _soundDelay = Duration(milliseconds: 180);
  static const _whooshVolume = 0.28;
  static const _whooshAssetPath = 'sounds/whoosh.mp3';

  late final AnimationController _introController;
  late final AnimationController _ambientController;
  late final AudioPlayer _audioPlayer;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _textFadeAnimation;
  late final Animation<double> _reflectionFadeAnimation;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _shineOffsetAnimation;
  bool _hasTriggeredCompletion = false;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: _introDuration,
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _audioPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

    _fadeAnimation = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.32, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.76, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.08, 0.54, curve: Curves.easeOutBack),
      ),
    );
    _textFadeAnimation = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.44, 0.84, curve: Curves.easeIn),
    );
    _reflectionFadeAnimation = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.26, 0.68, curve: Curves.easeOut),
    );
    _pulseAnimation = Tween<double>(begin: 0.985, end: 1.035).animate(
      CurvedAnimation(
        parent: _ambientController,
        curve: Curves.easeInOutSine,
      ),
    );
    _glowAnimation = Tween<double>(begin: 0.7, end: 1.1).animate(
      CurvedAnimation(
        parent: _ambientController,
        curve: Curves.easeInOut,
      ),
    );
    _shineOffsetAnimation = Tween<double>(begin: -1.25, end: 1.35).animate(
      CurvedAnimation(
        parent: _ambientController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _introController.addStatusListener(_handleIntroStatusChange);
    _introController.forward();
    _ambientController.repeat(reverse: true);
    unawaited(_prepareWhoosh());
  }

  Future<void> _prepareWhoosh() async {
    try {
      await _audioPlayer.setVolume(_whooshVolume);
      await _audioPlayer.setSource(AssetSource(_whooshAssetPath));
    } catch (_) {
      // The sound is optional at runtime so the splash still completes smoothly
      // if the asset has not been added yet.
    }
  }

  void _handleIntroStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      unawaited(_runCompletionSequence());
    }
  }

  Future<void> _runCompletionSequence() async {
    if (_hasTriggeredCompletion) {
      return;
    }
    _hasTriggeredCompletion = true;

    _ambientController.stop();
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(_soundDelay);
    await _playWhoosh();

    if (!mounted) {
      return;
    }

    _navigateToHome();
  }

  Future<void> _playWhoosh() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(_whooshVolume);
      await _audioPlayer.play(AssetSource(_whooshAssetPath));
    } catch (_) {
      // Audio failure should never block the splash flow or navigation.
    }
  }

  void _navigateToHome() {
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, __, ___) => const AuthGate(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          final scale = Tween<double>(begin: 0.98, end: 1.0).animate(fade);

          return FadeTransition(
            opacity: fade,
            child: ScaleTransition(scale: scale, child: child),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _introController.removeStatusListener(_handleIntroStatusChange);
    _introController.dispose();
    _ambientController.dispose();
    unawaited(_audioPlayer.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final logoSize = math.min(screenWidth * 0.44, 210.0);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF030303),
              Color(0xFF12071D),
              Color(0xFF08152D),
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _SplashBackdrop(),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _introController,
                      _ambientController,
                    ]),
                    builder: (context, child) {
                      final compositeScale =
                          _scaleAnimation.value * _pulseAnimation.value;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: _fadeAnimation.value,
                            child: Transform.scale(
                              scale: compositeScale,
                              child: _LogoShowcase(
                                size: logoSize,
                                glowStrength: _glowAnimation.value,
                                reflectionOpacity:
                                    _reflectionFadeAnimation.value,
                                shineOffset: _shineOffsetAnimation.value,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          FadeTransition(
                            opacity: _textFadeAnimation,
                            child: Text(
                              'FAIRBID',
                              style: GoogleFonts.orbitron(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 6,
                                color: const Color(0xFFB7C7FF),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          FadeTransition(
                            opacity: _textFadeAnimation,
                            child: const _TaglineTyping(),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashBackdrop extends StatelessWidget {
  const _SplashBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned(
          top: -120,
          left: -70,
          child: _BlurOrb(
            size: 250,
            colors: [Color(0xFF6A00F4), Color(0x002F80ED)],
          ),
        ),
        const Positioned(
          bottom: -120,
          right: -60,
          child: _BlurOrb(
            size: 280,
            colors: [Color(0xFF0EA5E9), Color(0x004F46E5)],
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.02),
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.015),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BlurOrb extends StatelessWidget {
  const _BlurOrb({
    required this.size,
    required this.colors,
  });

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
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

class _LogoShowcase extends StatelessWidget {
  const _LogoShowcase({
    required this.size,
    required this.glowStrength,
    required this.reflectionOpacity,
    required this.shineOffset,
  });

  final double size;
  final double glowStrength;
  final double reflectionOpacity;
  final double shineOffset;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size * 1.35,
          height: size * 1.12,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size * 0.9,
                height: size * 0.9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6)
                          .withValues(alpha: 0.28 * glowStrength),
                      blurRadius: 50 * glowStrength,
                      spreadRadius: 8 * glowStrength,
                    ),
                    BoxShadow(
                      color: const Color(0xFF38BDF8)
                          .withValues(alpha: 0.18 * glowStrength),
                      blurRadius: 70 * glowStrength,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
              Hero(
                tag: 'fairbid-logo',
                child: Container(
                  width: size,
                  height: size,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size * 0.24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                      width: 1.2,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.03),
                      ],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(size * 0.18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain,
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: size * 0.28,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.18),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        _ShineSweep(offset: shineOffset),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -14),
          child: _LogoReflection(
            size: size * 0.86,
            opacity: reflectionOpacity * 0.42,
          ),
        ),
      ],
    );
  }
}

class _ShineSweep extends StatelessWidget {
  const _ShineSweep({required this.offset});

  final double offset;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.translate(
        offset: Offset(offset * 120, 0),
        child: Transform.rotate(
          angle: -0.35,
          child: Container(
            width: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.75),
                  Colors.white.withValues(alpha: 0.0),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoReflection extends StatelessWidget {
  const _LogoReflection({
    required this.size,
    required this.opacity,
  });

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: opacity),
              Colors.white.withValues(alpha: opacity * 0.55),
              Colors.transparent,
            ],
          ).createShader(bounds),
          child: Opacity(
            opacity: opacity,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(1, -1, 1),
              child: Image.asset(
                'assets/logo.png',
                width: size,
                height: size * 0.46,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: size * 1.05,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.10),
                    Colors.white.withValues(alpha: 0.02),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TaglineTyping extends StatelessWidget {
  const _TaglineTyping();

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.orbitron(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.5,
      height: 1.3,
      color: Colors.white,
      shadows: [
        Shadow(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.8),
          blurRadius: 24,
        ),
        Shadow(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
          blurRadius: 14,
        ),
      ],
    );

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0xFFF8FAFC),
          Color(0xFFC4B5FD),
          Color(0xFF67E8F9),
        ],
      ).createShader(bounds),
      child: SizedBox(
        height: 70,
        child: Center(
          child: AnimatedTextKit(
            isRepeatingAnimation: false,
            totalRepeatCount: 1,
            displayFullTextOnTap: true,
            animatedTexts: [
              TypewriterAnimatedText(
                'Your Trustful App',
                textStyle: textStyle,
                speed: const Duration(milliseconds: 85),
                cursor: '',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
