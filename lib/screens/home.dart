import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coremicron_crm_app/screens/login.dart' show LoginPage, kUsernameKey;
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService, kTokenKey;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/common/side_drawer.dart';
import 'package:coremicron_crm_app/screens/chat/chat_list.dart';
import 'package:coremicron_crm_app/common/chat_websocket_service.dart';

class HomePage extends StatefulWidget {
  final String username;
  final bool openDrawerOnLoad;

  const HomePage({
    super.key,
    required this.username,
    this.openDrawerOnLoad = false,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  String? _sessionId;

  @override
  void initState() {
    super.initState();
    ChatWebSocketService().connect();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
    _animController.forward();
    _loadSession();

    // Open drawer on load if requested (e.g. back from a sub-page)
    if (widget.openDrawerOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scaffoldKey.currentState?.openDrawer();
      });
    }
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(kTokenKey);
    if (mounted) setState(() => _sessionId = id);
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
    final hPad = isTablet ? size.width * 0.12 : 24.0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,

      // ── Side Drawer ────────────────────────────────────────────────────────
      drawer: AppSideDrawer(
        username: widget.username,
        registrationExpanded: widget.openDrawerOnLoad,
      ),

      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: isTablet ? 48 : 36),

                    // ── Top Bar ──────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Hamburger + "Home" title
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  _scaffoldKey.currentState?.openDrawer(),
                              child: Container(
                                width: isTablet ? 42 : 38,
                                height: isTablet ? 42 : 38,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.border,
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.menu_rounded,
                                  color: AppColors.textPrimary,
                                  size: isTablet ? 22 : 19,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Home',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: isTablet ? 22 : 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                        // Chat Button
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ChatListPage(
                                    username: widget.username)),
                          ),
                          child: Container(
                            width: isTablet ? 42 : 38,
                            height: isTablet ? 42 : 38,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.border,
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: AppColors.primary,
                              size: isTablet ? 20 : 17,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: isTablet ? 44 : 36),

                    // ── Welcome Card ──────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isTablet ? 32 : 26),
                      decoration: AppDecorations.heroCard,
                      child: Stack(
                        children: [
                          Positioned(
                            right: -36,
                            top: -36,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.07),
                              ),
                            ),
                          ),
                          Positioned(
                            left: -24,
                            bottom: -24,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.05),
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, ${widget.username} 👋',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isTablet ? 26 : 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Welcome back to Coremicron CRM.\nYou\'re all set to manage your pipeline.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: isTablet ? 14 : 13,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isTablet ? 32 : 26),

                    // ── Session Info Card ─────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isTablet ? 24 : 20),
                      decoration: AppDecorations.card,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.verified_user_outlined,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Active Session',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: isTablet ? 16 : 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.successBg,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  '● Live',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _infoRow(
                            icon: Icons.person_outline_rounded,
                            label: 'Username',
                            value: widget.username,
                            isTablet: isTablet,
                          ),
                          const SizedBox(height: 10),
                          _infoRow(
                            icon: Icons.key_outlined,
                            label: 'Session ID',
                            value: _sessionId != null
                                ? '${_sessionId!.substring(0, _sessionId!.length.clamp(0, 16))}••••'
                                : 'Loading...',
                            isTablet: isTablet,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isTablet ? 40 : 32),

                    // ── Footer ────────────────────────────────────────────
                    Center(
                      child: Text(
                        '© ${DateTime.now().year} Coremicron · Privacy · Terms',
                        style: AppTextStyles.footer,
                      ),
                    ),

                    SizedBox(height: isTablet ? 32 : 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Info Row ───────────────────────────────────────────────────────────────
  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isTablet,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.iconDefault),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: isTablet ? 13 : 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: isTablet ? 13 : 12,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}