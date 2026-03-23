import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService;
import 'package:coremicron_crm_app/common/theme.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _oldCtrl     = TextEditingController();
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showOld     = false;
  bool _showNew     = false;
  bool _showConfirm = false;
  bool _isLoading   = false;

  String? _oldError;
  String? _newError;
  String? _confirmError;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Validation ─────────────────────────────────────────────────────────────
  bool _validate() {
    bool valid = true;
    setState(() {
      _oldError     = null;
      _newError     = null;
      _confirmError = null;

      if (_oldCtrl.text.trim().isEmpty) {
        _oldError = 'Please enter your current password.';
        valid     = false;
      }

      if (_newCtrl.text.trim().isEmpty) {
        _newError = 'Please enter a new password.';
        valid     = false;
      } else if (_newCtrl.text.trim().length < 3) {
        _newError = 'Password must be at least 3 characters.';
        valid     = false;
      } else if (_newCtrl.text.trim() == _oldCtrl.text.trim()) {
        _newError = 'New password cannot be the same as the old password.';
        valid     = false;
      }

      if (_confirmCtrl.text.trim().isEmpty) {
        _confirmError = 'Please confirm your new password.';
        valid         = false;
      } else if (_confirmCtrl.text.trim() != _newCtrl.text.trim()) {
        _confirmError = 'Passwords do not match.';
        valid         = false;
      }
    });
    return valid;
  }

  // ── API Call ───────────────────────────────────────────────────────────────
  Future<void> _changePassword() async {
    if (!_validate()) return;

    setState(() => _isLoading = true);
    try {
      final url  = Uri.parse(
          '${ApiService.baseUrl}/api/user/change_password.php');
      final body = {
        'old_password': _oldCtrl.text.trim(),
        'new_password': _newCtrl.text.trim(),
      };

      debugPrint('📤  [CHANGE PASSWORD] $url  ${jsonEncode(body)}');
      final res = await ApiService.post(url, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [CHANGE PASSWORD] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Password updated successfully.');
        Navigator.pop(context);
      } else {
        final message =
            data['error'] ?? data['message'] ?? 'Failed to update password.';
        setState(() => _oldError = message);
      }
    } on http.ClientException {
      if (mounted)
        setState(() =>
            _oldError = 'Unable to reach the server. Check your connection.');
    } catch (e) {
      if (mounted) setState(() => _oldError = 'Error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size     = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final hPad     = isTablet ? size.width * 0.06 : 20.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── App Bar ────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 13),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                    bottom: BorderSide(
                        color: AppColors.borderLight, width: 1)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color:        AppColors.background,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                            color: AppColors.border, width: 1.2),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 15, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Change Password',
                          style: TextStyle(
                              color:         AppColors.textPrimary,
                              fontSize:      isTablet ? 20 : 17,
                              fontWeight:    FontWeight.w800,
                              letterSpacing: -0.3)),
                      const Text('Update your account password',
                          style: TextStyle(
                              color:    AppColors.textSecondary,
                              fontSize: 11.5)),
                    ],
                  ),
                ],
              ),
            ),

            // ── Form ──────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon banner
                    Center(
                      child: Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          color:        AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.lock_outline_rounded,
                            size: 34, color: AppColors.primary),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Old Password
                    _fieldLabel('Current Password'),
                    const SizedBox(height: 7),
                    _passwordField(
                      controller: _oldCtrl,
                      hint:       'Enter current password',
                      show:       _showOld,
                      error:      _oldError,
                      onToggle:   () =>
                          setState(() => _showOld = !_showOld),
                      onChanged:  (_) =>
                          setState(() => _oldError = null),
                    ),

                    const SizedBox(height: 18),

                    // New Password
                    _fieldLabel('New Password'),
                    const SizedBox(height: 7),
                    _passwordField(
                      controller: _newCtrl,
                      hint:       'Enter new password',
                      show:       _showNew,
                      error:      _newError,
                      onToggle:   () =>
                          setState(() => _showNew = !_showNew),
                      onChanged:  (_) =>
                          setState(() => _newError = null),
                    ),

                    const SizedBox(height: 18),

                    // Confirm Password
                    _fieldLabel('Confirm New Password'),
                    const SizedBox(height: 7),
                    _passwordField(
                      controller: _confirmCtrl,
                      hint:       'Re-enter new password',
                      show:       _showConfirm,
                      error:      _confirmError,
                      onToggle:   () =>
                          setState(() => _showConfirm = !_showConfirm),
                      onChanged:  (_) =>
                          setState(() => _confirmError = null),
                    ),

                    const SizedBox(height: 32),

                    // Update button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor:
                              AppColors.primary.withOpacity(0.5),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _isLoading
                              ? const SizedBox(
                                  key:   ValueKey('loader'),
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                      color:       Colors.white,
                                      strokeWidth: 2.4))
                              : const Text('Update Password',
                                  key: ValueKey('label'),
                                  style: TextStyle(
                                      color:      Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize:   15)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────
  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
            color:      AppColors.textPrimary,
            fontSize:   13.5,
            fontWeight: FontWeight.w600),
      );

  Widget _passwordField({
    required TextEditingController controller,
    required String                hint,
    required bool                  show,
    required String?               error,
    required VoidCallback          onToggle,
    required ValueChanged<String>  onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: error != null
                    ? AppColors.error
                    : AppColors.border,
                width: 1.2),
          ),
          child: TextField(
            controller:     controller,
            obscureText:    !show,
            cursorColor:    AppColors.primary,
            onChanged:      onChanged,
            style: const TextStyle(
                color:    AppColors.textPrimary,
                fontSize: 14),
            decoration: InputDecoration(
              hintText:  hint,
              hintStyle: const TextStyle(
                  color:    AppColors.textHint,
                  fontSize: 13.5),
              prefixIcon: const Icon(Icons.lock_outline_rounded,
                  size: 18, color: AppColors.iconDefault),
              suffixIcon: GestureDetector(
                onTap: onToggle,
                child: Icon(
                  show
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size:  18,
                  color: AppColors.iconDefault,
                ),
              ),
              border:         InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 13, color: AppColors.error),
              const SizedBox(width: 5),
              Expanded(
                child: Text(error,
                    style: const TextStyle(
                        color:    AppColors.error,
                        fontSize: 12)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}