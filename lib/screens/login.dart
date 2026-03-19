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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: AppSpacing.topPadding(isTablet)),

                // ── Logo ─────────────────────────────────────────────────
                FadeTransition(
                  opacity: _logoFade,
                  child: _buildLogo(isTablet),
                ),

                SizedBox(height: isTablet ? 36 : 28),

                // ── Hero Card ─────────────────────────────────────────────
                FadeTransition(
                  opacity: _cardFade,
                  child: SlideTransition(
                    position: _cardSlide,
                    child: _buildHeroCard(isTablet),
                  ),
                ),

                SizedBox(height: AppSpacing.sectionGap(isTablet)),

                // ── Form ──────────────────────────────────────────────────
                FadeTransition(
                  opacity: _formFade,
                  child: SlideTransition(
                    position: _formSlide,
                    child: _buildForm(isTablet),
                  ),
                ),

                SizedBox(height: isTablet ? 32 : 24),
              ],
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
          width: AppSpacing.logoSize(isTablet),
          height: AppSpacing.logoSize(isTablet),
          decoration: AppDecorations.logoBox(isTablet),
          child: Icon(
            Icons.layers_rounded,
            color: Colors.white,
            size: AppSpacing.logoIconSize(isTablet),
          ),
        ),
        const SizedBox(width: 11),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(text: 'Core',   style: AppTextStyles.brandCore(isTablet)),
              TextSpan(text: 'micron', style: AppTextStyles.brandMicron(isTablet)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Hero Card ──────────────────────────────────────────────────────────────
  Widget _buildHeroCard(bool isTablet) {
    return Container(
      width: double.infinity,
      decoration: AppDecorations.heroCard,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: isTablet ? 160 : 130,
                height: isTablet ? 160 : 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            Positioned(
              left: -30,
              bottom: -30,
              child: Container(
                width: isTablet ? 100 : 80,
                height: isTablet ? 100 : 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              right: isTablet ? 60 : 44,
              bottom: isTablet ? 28 : 22,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.35),
                ),
              ),
            ),
            Positioned(
              right: isTablet ? 36 : 26,
              top: isTablet ? 40 : 32,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.25),
                ),
              ),
            ),

            // Content
            Padding(
              padding: EdgeInsets.all(isTablet ? 30 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Manage every\ncustomer ',
                          style: AppTextStyles.heroHeadline(isTablet),
                        ),
                        TextSpan(
                          text: 'relationship',
                          style: AppTextStyles.heroAccent(isTablet),
                        ),
                        TextSpan(
                          text: '\nin one place.',
                          style: AppTextStyles.heroHeadline(isTablet),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isTablet ? 12 : 10),
                  Container(
                    width: 36,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.40),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  SizedBox(height: isTablet ? 12 : 10),
                  Text(
                    'Automate follow-ups, and close deals\nfaster with Coremicron CRM.',
                    style: AppTextStyles.heroSubtitle(isTablet),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Form ───────────────────────────────────────────────────────────────────
  Widget _buildForm(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome back', style: AppTextStyles.headline(isTablet)),
        const SizedBox(height: 4),
        Text(
          'Sign in to your account to continue',
          style: AppTextStyles.subtitle(isTablet),
        ),

        SizedBox(height: isTablet ? 28 : 22),

        // Username
        _buildLabel('USERNAME', isTablet),
        const SizedBox(height: 7),
        _buildInputField(
          controller: _usernameController,
          focusNode: _usernameFocus,
          hint: 'Enter your username',
          icon: Icons.person_outline_rounded,
          obscure: false,
          isTablet: isTablet,
          nextFocus: _passwordFocus,
        ),

        SizedBox(height: AppSpacing.fieldGap(isTablet)),

        // Password
        _buildLabel('PASSWORD', isTablet),
        const SizedBox(height: 7),
        _buildInputField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          hint: 'Enter your password',
          icon: Icons.lock_outline_rounded,
          obscure: _obscurePassword,
          isPassword: true,
          isTablet: isTablet,
        ),

        const SizedBox(height: 10),

        // Forgot password
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {
              // TODO: Handle forgot password
            },
            child: Text(
              'Forgot password?',
              style: AppTextStyles.link(isTablet),
            ),
          ),
        ),

        SizedBox(height: isTablet ? 28 : 22),

        // Sign In Button
        SizedBox(
          width: double.infinity,
          height: AppSpacing.buttonHeight(isTablet),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSignIn,
            style: AppButtonStyles.primary,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isLoading
                  ? const SizedBox(
                      key: ValueKey('loader'),
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      'Sign In',
                      key: const ValueKey('label'),
                      style: AppTextStyles.button(isTablet),
                    ),
            ),
          ),
        ),

        SizedBox(height: isTablet ? 36 : 28),

        // Footer
        Center(
          child: Text(
            '© ${DateTime.now().year} Coremicron · Privacy · Terms',
            style: AppTextStyles.footer,
          ),
        ),

        SizedBox(height: isTablet ? 28 : 20),
      ],
    );
  }

  // ── Field Label ────────────────────────────────────────────────────────────
  Widget _buildLabel(String text, bool isTablet) =>
      Text(text, style: AppTextStyles.fieldLabel(isTablet));

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
            decoration: focused
                ? AppDecorations.inputFocused
                : AppDecorations.inputIdle,
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
              style: AppTextStyles.body(isTablet),
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTextStyles.hint(isTablet),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    icon,
                    color: focused
                        ? AppColors.primary
                        : AppColors.iconDefault,
                    size: isTablet ? 21 : 19,
                  ),
                ),
                suffixIcon: isPassword
                    ? IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.iconDefault,
                          size: isTablet ? 21 : 19,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: isTablet ? 18 : 15,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}