import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coremicron_crm_app/common/api_service.dart';
import 'package:coremicron_crm_app/screens/home.dart';
import 'package:coremicron_crm_app/common/theme.dart';

// ── Session keys (shared across the app) ────────────────────────────────────
// kTokenKey and kWsIdKey are now imported from common/api_service.dart
const String kUsernameKey = 'username';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;

  late AnimationController _masterAnim;
  late Animation<double> _logoFade;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _formFade;
  late Animation<Offset> _formSlide;

  // ── initState ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _masterAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _logoFade = CurvedAnimation(
      parent: _masterAnim,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );
    _cardFade = CurvedAnimation(
      parent: _masterAnim,
      curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _masterAnim,
      curve: const Interval(0.2, 0.65, curve: Curves.easeOut),
    ));
    _formFade = CurvedAnimation(
      parent: _masterAnim,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );
    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _masterAnim,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    ));
    _masterAnim.forward();
  }

  // ── dispose ────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _masterAnim.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ── Sign In Handler ────────────────────────────────────────────────────────
  Future<void> _handleSignIn() async {
    FocusScope.of(context).unfocus();

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showSnack('Please fill in all fields.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ── POST to /auth/login.php ────────────────────────────────────────
      final url = Uri.parse('${ApiService.baseUrl}/auth/login.php');
      final body = jsonEncode({
        'username': username,
        'password': password,
      });

      debugPrint('─────────────────────────────────────────');
      debugPrint('📤  [LOGIN] Request');
      debugPrint('   🌐  URL : $url');
      debugPrint('   📦  Body: $body');
      debugPrint('─────────────────────────────────────────');

      final response = await ApiService.post(
        url,
        body: body,
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      debugPrint('📥  [LOGIN] Status: ${response.statusCode}');
      debugPrint('📥  [LOGIN] Body  : ${response.body}');

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // ── Save Auth Data to SharedPreferences ──────────────────────────
        final prefs = await SharedPreferences.getInstance();
        final token = data['token']?.toString()      ?? '';
        final user  = data['user'] as Map?           ?? {};
        final wsId  = user['ws_id']?.toString()     ?? '';

        await prefs.setString(kTokenKey,    token);
        await prefs.setString(kWsIdKey,     wsId);
        await prefs.setString(kUsernameKey, username);

        if (!mounted) return;

        // ── Navigate to Home, clear back stack ─────────────────────────
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => HomePage(username: username)),
          (route) => false,
        );
      } else {
        setState(() => _isLoading = false);
        final String errorMsg = data['error'] ?? data['message'] ?? 'Invalid credentials.';
        _showSnack(
          'Login Failed: $errorMsg',
          isError: true,
        );
      }
    } on http.ClientException {
      setState(() => _isLoading = false);
      _showSnack('Unable to reach the server. Check your connection.',
          isError: true);
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('❌  [LOGIN] Error: $e');
      _showSnack('Something went wrong: $e', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) =>
      AppSnackBar.show(context, message, isError: isError);

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final hPad = AppSpacing.horizontalPadding(isTablet, size.width);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: isTablet ? 40 : 20),

                  // ── Logo ─────────────────────────────────────────────────
                  FadeTransition(
                    opacity: _logoFade,
                    child: _buildLogo(isTablet),
                  ),

                  const SizedBox(height: 32),

                  // ── Hero Section ──────────────────────────────────────────
                  FadeTransition(
                    opacity: _cardFade,
                    child: SlideTransition(
                      position: _cardSlide,
                      child: _buildHeroSection(isTablet),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ── Form ──────────────────────────────────────────────────
                  FadeTransition(
                    opacity: _formFade,
                    child: SlideTransition(
                      position: _formSlide,
                      child: _buildForm(isTablet),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Footer
                  Center(
                    child: Text(
                      '© ${DateTime.now().year} Coremicron CRM',
                      style: AppTextStyles.footer,
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Logo ───────────────────────────────────────────────────────────────────
  Widget _buildLogo(bool isTablet) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderLight, width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), 
                  blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: const Center(
            child: Icon(Icons.blur_on_rounded, color: AppColors.primary, size: 28),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'CRM System',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  // ── Hero Section (Branding) ────────────────────────────────────────────────
  Widget _buildHeroSection(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Manage every\ncustomer relationship\nin one place.',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Streamline your pipeline, automate follow-ups,\nand close deals faster with Coremicron CRM.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            height: 1.6,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Form ───────────────────────────────────────────────────────────────────
  Widget _buildForm(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Welcome back', 
            style: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 6),
        const Text(
          'Sign in to your account to continue',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
        ),

        const SizedBox(height: 38),

        // Username
        _buildLabel('USERNAME', isTablet),
        const SizedBox(height: 10),
        _buildInputField(
          controller: _usernameController,
          focusNode: _usernameFocus,
          hint: 'Enter your username',
          icon: Icons.person_outline_rounded,
          obscure: false,
          isTablet: isTablet,
          nextFocus: _passwordFocus,
        ),

        const SizedBox(height: 18),

        // Password
        _buildLabel('PASSWORD', isTablet),
        const SizedBox(height: 10),
        _buildInputField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          hint: 'Enter your password',
          icon: Icons.lock_outline_rounded,
          obscure: _obscurePassword,
          isPassword: true,
          isTablet: isTablet,
        ),

        const SizedBox(height: 12),

        // Forgot password
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {},
            child: const Text('Forgot password?',
              style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Sign In Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSignIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFF4A90E2).withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ),
        ),
      ],
    );
  }

  // ── Field Label ────────────────────────────────────────────────────────────
  Widget _buildLabel(String text, bool isTablet) =>
      Text(text, style: const TextStyle(color: AppColors.textLabel, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5));

  // ── Input Field ────────────────────────────────────────────────────────────
  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    required bool obscure,
    required bool isTablet,
    bool isPassword = false,
    FocusNode? nextFocus,
  }) {
    return Focus(
      onFocusChange: (_) => setState(() {}),
      child: Builder(
        builder: (ctx) {
          final focused = Focus.of(ctx).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: focused ? const Color(0xFF4A90E2) : AppColors.border,
                width: focused ? 1.5 : 1,
              ),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: obscure,
              textInputAction: nextFocus != null
                  ? TextInputAction.next
                  : TextInputAction.done,
              onSubmitted: (_) {
                if (nextFocus != null) {
                  FocusScope.of(context).requestFocus(nextFocus);
                } else {
                  _handleSignIn();
                }
              },
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
              cursorColor: const Color(0xFF4A90E2),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14, fontWeight: FontWeight.w400),
                prefixIcon: Icon(
                  icon,
                  color: focused ? const Color(0xFF4A90E2) : AppColors.iconDefault,
                  size: 20,
                ),
                suffixIcon: isPassword
                    ? IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.iconDefault,
                          size: 20,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}