import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService;
import 'package:coremicron_crm_app/common/theme.dart';

class ApiUrlPage extends StatefulWidget {
  const ApiUrlPage({super.key});

  @override
  State<ApiUrlPage> createState() => _ApiUrlPageState();
}

class _ApiUrlPageState extends State<ApiUrlPage> {
  final TextEditingController _erpUrlCtrl = TextEditingController();

  bool    _isLoading  = true;
  bool    _isUpdating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUrls();
  }

  @override
  void dispose() {
    _erpUrlCtrl.dispose();
    super.dispose();
  }

  // ── Fetch URLs ─────────────────────────────────────────────────────────────
  Future<void> _fetchUrls() async {
    setState(() {
      _isLoading    = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse('${ApiService.baseUrl}/api/user/urls_view.php');

      debugPrint('──── API REQUEST ────────────────────────────────────────');
      debugPrint('GET ${url.toString()}');

      final response = await ApiService.get(url)
          .timeout(const Duration(seconds: 15));

      debugPrint('──── API RESPONSE ───────────────────────────────────────');
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Body:   ${response.body}');
      debugPrint('─────────────────────────────────────────────────────────');

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _erpUrlCtrl.text = data['erp_url'] ?? '';
      } else {
        _errorMessage = data['message'] ?? 'Failed to load URL settings.';
      }
    } on http.ClientException {
      _errorMessage = 'Unable to reach the server. Check your connection.';
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ── Update URL ─────────────────────────────────────────────────────────────
  Future<void> _updateUrls() async {
    final erpUrl = _erpUrlCtrl.text.trim();

    if (erpUrl.isEmpty) {
      AppSnackBar.show(context, 'ERP URL cannot be empty.', isError: true);
      return;
    }

    setState(() => _isUpdating = true);

    try {
      final url  = Uri.parse('${ApiService.baseUrl}/api/user/urls_update.php');
      final body = jsonEncode({'erp_url': erpUrl});

      debugPrint('──── API REQUEST ────────────────────────────────────────');
      debugPrint('POST ${url.toString()}');
      debugPrint('Body:   $body');

      final response = await ApiService.post(url, body: body)
          .timeout(const Duration(seconds: 15));

      debugPrint('──── API RESPONSE ───────────────────────────────────────');
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Body:   ${response.body}');
      debugPrint('─────────────────────────────────────────────────────────');

      if (!mounted) return;
      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'URL updated successfully.');
        _fetchUrls();
      } else {
        AppSnackBar.show(
          context,
          data['message'] ?? 'Failed to update URL.',
          isError: true,
        );
      }
    } on http.ClientException {
      if (mounted) {
        AppSnackBar.show(context, 'Unable to reach the server.', isError: true);
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(context, 'Something went wrong.', isError: true);
      }
    }

    if (mounted) setState(() => _isUpdating = false);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size     = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final hPad     = isTablet ? size.width * 0.06 : 16.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAppBar(isTablet, hPad),

            Expanded(
              child: _isLoading
                  ? _buildSkeleton(hPad)
                  : _errorMessage != null
                      ? _buildError()
                      : _buildForm(hPad),
            ),
          ],
        ),
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────────
  Widget _buildAppBar(bool isTablet, double hPad) {
    return Container(
      padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 13),
      decoration: const BoxDecoration(
        color:  Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.border, width: 1.2),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 15, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'API URL Settings',
            style: TextStyle(
              color:         AppColors.textPrimary,
              fontSize:      isTablet ? 20 : 17,
              fontWeight:    FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _fetchUrls,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color:        AppColors.background,
                borderRadius: BorderRadius.circular(9),
                border:       Border.all(color: AppColors.border, width: 1.2),
              ),
              child: const Icon(Icons.refresh_rounded,
                  size: 18, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Form ───────────────────────────────────────────────────────────────────
  Widget _buildForm(double hPad) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section card ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(14),
              border:       Border.all(color: AppColors.borderLight, width: 1),
              boxShadow: [
                BoxShadow(
                    color:      Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset:     const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card header
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color:        AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.link_rounded,
                          color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'URL Configuration',
                      style: TextStyle(
                        color:      AppColors.textPrimary,
                        fontSize:   14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                const Divider(color: AppColors.borderLight, height: 1),
                const SizedBox(height: 18),

                // ERP URL field
                Text('ERP URL', style: AppTextStyles.fieldLabel(false)),
                const SizedBox(height: 7),
                _buildUrlField(
                  controller: _erpUrlCtrl,
                  hint:       'Enter ERP URL',
                  icon:       Icons.public_rounded,
                ),

                const SizedBox(height: 22),

                // Update button — full width
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isUpdating ? null : _updateUrls,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation:       0,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11)),
                      disabledBackgroundColor:
                          AppColors.primary.withOpacity(0.5),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _isUpdating
                          ? const SizedBox(
                              key:    ValueKey('upd-loader'),
                              width:  18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color:       Colors.white,
                                  strokeWidth: 2.3),
                            )
                          : const Row(
                              key:             ValueKey('upd-label'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save_outlined,
                                    color: Colors.white, size: 17),
                                SizedBox(width: 8),
                                Text(
                                  'Update',
                                  style: TextStyle(
                                      color:      Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize:   14.5),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── URL text field ─────────────────────────────────────────────────────────
  Widget _buildUrlField({
    required TextEditingController controller,
    required String                hint,
    required IconData              icon,
  }) {
    return StatefulBuilder(
      builder: (ctx, setFieldState) {
        return Focus(
          onFocusChange: (_) => setFieldState(() {}),
          child: Builder(builder: (focusCtx) {
            final focused = Focus.of(focusCtx).hasFocus;
            return AnimatedContainer(
              duration:   const Duration(milliseconds: 180),
              decoration: focused
                  ? AppDecorations.inputFocused
                  : AppDecorations.inputIdle,
              child: TextField(
                controller:   controller,
                keyboardType: TextInputType.url,
                cursorColor:  AppColors.primary,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText:   hint,
                  hintStyle:  const TextStyle(
                      color: AppColors.textHint, fontSize: 13),
                  prefixIcon: Icon(icon,
                      color: AppColors.iconDefault, size: 18),
                  border:          InputBorder.none,
                  contentPadding:  const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // ── Skeleton ───────────────────────────────────────────────────────────────
  Widget _buildSkeleton(double hPad) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: AppColors.borderLight, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ShimmerBox(width: 36, height: 36, radius: 9),
                const SizedBox(width: 10),
                _ShimmerBox(width: 140, height: 14, radius: 4),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(color: AppColors.borderLight, height: 1),
            const SizedBox(height: 18),
            _ShimmerBox(width: 70, height: 11, radius: 4),
            const SizedBox(height: 7),
            _ShimmerBox(width: double.infinity, height: 46, radius: 10),
            const SizedBox(height: 22),
            _ShimmerBox(width: double.infinity, height: 48, radius: 11),
          ],
        ),
      ),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 52, color: AppColors.border),
          const SizedBox(height: 14),
          Text(
            _errorMessage ?? 'Something went wrong.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13.5),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchUrls,
            icon: const Icon(Icons.refresh_rounded,
                size: 16, color: Colors.white),
            label: const Text('Retry',
                style: TextStyle(
                    color:      Colors.white,
                    fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation:       0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shimmer box ────────────────────────────────────────────────────────────
class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox(
      {required this.width, required this.height, required this.radius});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: Container(
          width:  widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color:        const Color(0xFFE8EDF5),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
}