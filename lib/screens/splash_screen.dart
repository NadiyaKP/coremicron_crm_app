import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart' show kSessionKey, kUsernameKey;
import 'login.dart';
import 'home.dart';
import '../common/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _textFade;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _animController.forward();

    // Wait 3 seconds then check session
    _initSession();
  }

  Future<void> _initSession() async {
    // Run both in parallel: 3 sec delay + session check
    final results = await Future.wait([
      Future.delayed(const Duration(seconds: 3)),
      _checkAndPrintSession(),
    ]);

    if (!mounted) return;

    final bool hasSession = results[1] as bool;

    if (hasSession) {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString(kUsernameKey) ?? 'User';
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomePage(username: username)),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  /// Reads all stored SharedPreferences data and prints to debug console.
  /// Returns true if a valid session exists.
  Future<bool> _checkAndPrintSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString(kSessionKey);
    final username  = prefs.getString(kUsernameKey);

    // ── Debug print ────────────────────────────────────────────────────────
    debugPrint('─────────────────────────────────────────');
    debugPrint('📦  SharedPreferences stored data:');
    debugPrint('   🔑  session_id : ${sessionId ?? 'null (not found)'}');
    debugPrint('   👤  username   : ${username  ?? 'null (not found)'}');

    if (sessionId != null && sessionId.isNotEmpty) {
      debugPrint('✅  Session FOUND → navigating to Home');
    } else {
      debugPrint('🚫  No session found → navigating to Login');
    }
    debugPrint('─────────────────────────────────────────');

    return sessionId != null && sessionId.isNotEmpty;
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // ── Background gradient blob ─────────────────────────────────────
          Positioned(
            top: -size.height * 0.1,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 0.75,
              height: size.width * 0.75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -size.height * 0.08,
            left: -size.width * 0.15,
            child: Container(
              width: size.width * 0.60,
              height: size.width * 0.60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.05),
              ),
            ),
          ),

          // ── Main centered content ────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo icon
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Container(
                      width: isTablet ? 88 : 72,
                      height: isTablet ? 88 : 72,
                      decoration: AppDecorations.logoBox(isTablet),
                      child: Icon(
                        Icons.layers_rounded,
                        color: Colors.white,
                        size: isTablet ? 44 : 36,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: isTablet ? 24 : 20),

                // Brand name
                FadeTransition(
                  opacity: _textFade,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Core',
                          style: TextStyle(
                            color: const Color(0xFF0A0F1E),
                            fontSize: isTablet ? 32 : 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        TextSpan(
                          text: 'micron',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: isTablet ? 32 : 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: isTablet ? 10 : 8),

                // Tagline
                FadeTransition(
                  opacity: _textFade,
                  child: Text(
                    'Customer Relationship Management',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: isTablet ? 14 : 12.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),

                SizedBox(height: isTablet ? 56 : 48),

                // Loading dots
                FadeTransition(
                  opacity: _textFade,
                  child: const _PulsingDots(),
                ),
              ],
            ),
          ),

          // ── Version at bottom ────────────────────────────────────────────
          Positioned(
            bottom: 28,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _textFade,
              child: const Text(
                'v1.0.0',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFCCD3E0),
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pulsing loading dots ───────────────────────────────────────────────────
class _PulsingDots extends StatefulWidget {
  const _PulsingDots();

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];
  final List<Animation<double>> _anims = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 3; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      final anim = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: ctrl, curve: Curves.easeInOut),
      );
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) ctrl.repeat(reverse: true);
      });
      _controllers.add(ctrl);
      _anims.add(anim);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FadeTransition(
            opacity: _anims[i],
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1558E7),
              ),
            ),
          ),
        );
      }),
    );
  }
}