import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coremicron_crm_app/common/api_service.dart';
import 'package:coremicron_crm_app/screens/home.dart';
import 'package:coremicron_crm_app/common/theme.dart';

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
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;

  @override
  void initState() {
    super.initState();
    _masterAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _logoFade = CurvedAnimation(
      parent: _masterAnim,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );
    _heroFade = CurvedAnimation(
      parent: _masterAnim,
      curve: const Interval(0.2, 0.55, curve: Curves.easeOut),
    );
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _masterAnim,
      curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
    ));
    _cardFade = CurvedAnimation(
      parent: _masterAnim,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _masterAnim,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
    ));
    _masterAnim.forward();
  }

  @override
  void dispose() {
    _masterAnim.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

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
      final url = Uri.parse('${ApiService.baseUrl}/auth/login.php');
      final body = jsonEncode({'username': username, 'password': password});

      debugPrint('─────────────────────────────────────────');
      debugPrint('📤  [LOGIN] Request');
      debugPrint('   🌐  URL : $url');
      debugPrint('   📦  Body: $body');
      debugPrint('─────────────────────────────────────────');

      final response = await ApiService.post(url, body: body)
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      debugPrint('📥  [LOGIN] Status: ${response.statusCode}');
      debugPrint('📥  [LOGIN] Body  : ${response.body}');

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        final token = data['token']?.toString() ?? '';
        final user = data['user'] as Map? ?? {};
        final wsId = user['ws_id']?.toString() ?? '';

        await prefs.setString(kTokenKey, token);
        await prefs.setString(kWsIdKey, wsId);
        await prefs.setString(kUsernameKey, username);

        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => HomePage(username: username)),
          (route) => false,
        );
      } else {
        setState(() => _isLoading = false);
        final String errorMsg =
            data['error'] ?? data['message'] ?? 'Invalid credentials.';
        _showSnack('Login Failed: $errorMsg', isError: true);
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final hPad = AppSpacing.horizontalPadding(isTablet, size.width);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: isTablet ? 48 : 32),

                  // ── Logo ──────────────────────────────────────────────────
                  FadeTransition(
                    opacity: _logoFade,
                    child: _buildLogo(),
                  ),

                  const SizedBox(height: 36),

                  // ── Hero Text ─────────────────────────────────────────────
                  FadeTransition(
                    opacity: _heroFade,
                    child: SlideTransition(
                      position: _heroSlide,
                      child: _buildHeroSection(),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Login Card ────────────────────────────────────────────
                  FadeTransition(
                    opacity: _cardFade,
                    child: SlideTransition(
                      position: _cardSlide,
                      child: _buildLoginCard(),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Footer ────────────────────────────────────────────────
                  FadeTransition(
                    opacity: _cardFade,
                    child: Text(
                      '© ${DateTime.now().year} Coremicron Enterprises LLP',
                      style: AppTextStyles.footer,
                    ),
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Logo ───────────────────────────────────────────────────────────────────
  Widget _buildLogo() {
    return Center(
      child: Image.asset(
        'assets/images/cm_logo.png',
        height: 72,
        fit: BoxFit.contain,
      ),
    );
  }

  // ── Hero Section ───────────────────────────────────────────────────────────
  Widget _buildHeroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Manage every customer\nrelationship in one place.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Streamline your pipeline, automate follow-ups,\nand close deals faster.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.6,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ── Login Card ─────────────────────────────────────────────────────────────
  Widget _buildLoginCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          const Text(
            'Welcome back',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Sign in to your account to continue',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 28),

          // ── Unified Fields Container ───────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight, width: 1),
            ),
            child: Column(
              children: [
                // Username field
                _buildUnifiedField(
                  controller: _usernameController,
                  focusNode: _usernameFocus,
                  hint: 'Username',
                  icon: Icons.person_outline_rounded,
                  obscure: false,
                  nextFocus: _passwordFocus,
                  isFirst: true,
                  isLast: false,
                ),

                // Divider between fields
                Container(
                  height: 1,
                  color: AppColors.borderLight,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                ),

                // Password field
                _buildUnifiedField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  hint: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscurePassword,
                  isPassword: true,
                  isFirst: false,
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Sign In Button ─────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A56DB),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    const Color(0xFF1A56DB).withOpacity(0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 15),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Unified Field (inside the shared container) ────────────────────────────
  Widget _buildUnifiedField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    required bool obscure,
    required bool isFirst,
    required bool isLast,
    bool isPassword = false,
    FocusNode? nextFocus,
  }) {
    final radius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(14) : Radius.zero,
      bottom: isLast ? const Radius.circular(14) : Radius.zero,
    );

    return Focus(
      onFocusChange: (_) => setState(() {}),
      child: Builder(
        builder: (ctx) {
          final focused = Focus.of(ctx).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: focused ? Colors.white : Colors.transparent,
              borderRadius: radius,
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
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: const Color(0xFF1A56DB),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    icon,
                    color: focused
                        ? const Color(0xFF1A56DB)
                        : AppColors.iconDefault,
                    size: 20,
                  ),
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
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 17,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}