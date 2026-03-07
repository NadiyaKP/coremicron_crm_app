import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../common/api_service.dart';
import '../../common/theme.dart';
import '../login.dart' show kSessionKey;

// ── Add / Edit Customer Page ───────────────────────────────────────────────
class AddCustomerPage extends StatefulWidget {
  final Map<String, String>? customer; // keys: id, name, phone, email, address

  const AddCustomerPage({super.key, this.customer});

  @override
  State<AddCustomerPage> createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends State<AddCustomerPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;

  final FocusNode _nameFocus    = FocusNode();
  final FocusNode _phoneFocus   = FocusNode();
  final FocusNode _emailFocus   = FocusNode();
  final FocusNode _addressFocus = FocusNode();

  bool _isSaving = false;

  bool get _isEditMode => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameCtrl    = TextEditingController(text: c?['name']    ?? '');
    _phoneCtrl   = TextEditingController(text: c?['phone']   ?? '');
    _emailCtrl   = TextEditingController(text: c?['email']   ?? '');
    _addressCtrl = TextEditingController(text: c?['address'] ?? '');

    for (final fn in [_nameFocus, _phoneFocus, _emailFocus, _addressFocus]) {
      fn.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  // ── API: Create ────────────────────────────────────────────────────────────
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url       = Uri.parse('${ApiService.baseUrl}/api/customer/create.php');

      final requestBody = {
        'customer_name': _nameCtrl.text.trim(),
        'phone_number':  _phoneCtrl.text.trim(),
        'email':         _emailCtrl.text.trim(),
        'address':       _addressCtrl.text.trim(),
      };

      debugPrint('─────────────────────────────────────────');
      debugPrint('📤  [CREATE CUSTOMER] Request');
      debugPrint('   🌐  URL    : $url');
      debugPrint('   📦  Body   : ${jsonEncode(requestBody)}');
      debugPrint('─────────────────────────────────────────');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
          'X-Session-ID': sessionId,
          'Cookie':       'PHPSESSID=$sessionId',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final Map<String, dynamic> data = jsonDecode(response.body);

      debugPrint('─────────────────────────────────────────');
      debugPrint('📥  [CREATE CUSTOMER] Response');
      debugPrint('   🔢  Status : ${response.statusCode}');
      debugPrint('   📄  Body   : ${response.body}');
      debugPrint('─────────────────────────────────────────');

      if (response.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Customer added successfully.');
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        setState(() => _isSaving = false);
        AppSnackBar.show(
            context, data['message'] ?? 'Failed to save.', isError: true);
      }
    } on http.ClientException {
      setState(() => _isSaving = false);
      AppSnackBar.show(context, 'Unable to reach the server.', isError: true);
    } catch (_) {
      setState(() => _isSaving = false);
      AppSnackBar.show(context, 'Something went wrong.', isError: true);
    }
  }

  // ── API: Update ────────────────────────────────────────────────────────────
  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url       = Uri.parse('${ApiService.baseUrl}/api/customer/update.php');

      final requestBody = {
        'id':            widget.customer!['id'],
        'customer_name': _nameCtrl.text.trim(),
        'phone_number':  _phoneCtrl.text.trim(),
        'email':         _emailCtrl.text.trim(),
        'address':       _addressCtrl.text.trim(),
      };

      debugPrint('─────────────────────────────────────────');
      debugPrint('📤  [UPDATE CUSTOMER] Request');
      debugPrint('   🌐  URL    : $url');
      debugPrint('   📦  Body   : ${jsonEncode(requestBody)}');
      debugPrint('─────────────────────────────────────────');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
          'X-Session-ID': sessionId,
          'Cookie':       'PHPSESSID=$sessionId',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final Map<String, dynamic> data = jsonDecode(response.body);

      debugPrint('─────────────────────────────────────────');
      debugPrint('📥  [UPDATE CUSTOMER] Response');
      debugPrint('   🔢  Status : ${response.statusCode}');
      debugPrint('   📄  Body   : ${response.body}');
      debugPrint('─────────────────────────────────────────');

      if (response.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Customer updated successfully.');
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        setState(() => _isSaving = false);
        AppSnackBar.show(
            context, data['message'] ?? 'Failed to update.', isError: true);
      }
    } on http.ClientException {
      setState(() => _isSaving = false);
      AppSnackBar.show(context, 'Unable to reach the server.', isError: true);
    } catch (_) {
      setState(() => _isSaving = false);
      AppSnackBar.show(context, 'Something went wrong.', isError: true);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size     = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final hPad     = isTablet ? size.width * 0.08 : 20.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(isTablet, hPad),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subtitle
                      Text(
                        _isEditMode
                            ? 'Update the customer details below.'
                            : 'Fill in the details to add a new customer.',
                        style: AppTextStyles.subtitle(isTablet).copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Card wrapping all fields ───────────────────────
                      _buildFieldsCard(isTablet),

                      const SizedBox(height: 24),

                      // ── Buttons ────────────────────────────────────────
                      _buildButtons(isTablet),
                    ],
                  ),
                ),
              ),
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
        color: Colors.white,
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
            _isEditMode ? 'Edit Customer' : 'New Customer',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: isTablet ? 20 : 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Card with all 4 fields, each having its own visible box border ─────────
  Widget _buildFieldsCard(bool isTablet) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Customer Name ────────────────────────────────────────────
          _fieldLabel('CUSTOMER NAME', isTablet),
          const SizedBox(height: 7),
          _inputBox(
            ctrl:      _nameCtrl,
            focus:     _nameFocus,
            next:      _phoneFocus,
            hint:      'Enter customer name',
            icon:      Icons.person_outline_rounded,
            isTablet:  isTablet,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Customer name is required'
                : null,
          ),

          const SizedBox(height: 18),

          // ── Phone Number ─────────────────────────────────────────────
          _fieldLabel('PHONE NUMBER', isTablet),
          const SizedBox(height: 7),
          _inputBox(
            ctrl:         _phoneCtrl,
            focus:        _phoneFocus,
            next:         _emailFocus,
            hint:         'Enter phone number',
            icon:         Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            isTablet:     isTablet,
            validator:    (v) => (v == null || v.trim().isEmpty)
                ? 'Phone number is required'
                : null,
          ),

          const SizedBox(height: 18),

          // ── Email ────────────────────────────────────────────────────
          _fieldLabel('EMAIL', isTablet),
          const SizedBox(height: 7),
          _inputBox(
            ctrl:         _emailCtrl,
            focus:        _emailFocus,
            next:         _addressFocus,
            hint:         'Enter email address',
            icon:         Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            isTablet:     isTablet,
          ),

          const SizedBox(height: 18),

          // ── Address ──────────────────────────────────────────────────
          _fieldLabel('ADDRESS', isTablet),
          const SizedBox(height: 7),
          _inputBox(
            ctrl:     _addressCtrl,
            focus:    _addressFocus,
            hint:     'Enter address',
            icon:     Icons.location_on_outlined,
            isTablet: isTablet,
            maxLines: 3,
            isLast:   true,
          ),
        ],
      ),
    );
  }

  // ── Field label ────────────────────────────────────────────────────────────
  Widget _fieldLabel(String text, bool isTablet) => Text(
        text,
        style: AppTextStyles.fieldLabel(isTablet),
      );

  // ── Input box (each field has its own visible bordered box) ───────────────
  Widget _inputBox({
    required TextEditingController ctrl,
    required FocusNode focus,
    FocusNode? next,
    required String hint,
    required IconData icon,
    required bool isTablet,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool isLast  = false,
  }) {
    final focused = focus.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: focused
          ? AppDecorations.inputFocused
          : AppDecorations.inputIdle,
      child: TextFormField(
        controller:      ctrl,
        focusNode:       focus,
        keyboardType:    keyboardType,
        maxLines:        maxLines,
        textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
        onFieldSubmitted: (_) {
          if (next != null) {
            FocusScope.of(context).requestFocus(next);
          } else {
            FocusScope.of(context).unfocus();
          }
        },
        style:       AppTextStyles.body(isTablet),
        cursorColor: AppColors.primary,
        validator:   validator,
        decoration: InputDecoration(
          hintText:  hint,
          hintStyle: AppTextStyles.hint(isTablet),
          prefixIcon: maxLines == 1
              ? Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    icon,
                    size:  isTablet ? 21 : 19,
                    color: focused
                        ? AppColors.primary
                        : AppColors.iconDefault,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(left: 14, top: 14),
                  child: Icon(
                    icon,
                    size:  isTablet ? 21 : 19,
                    color: focused
                        ? AppColors.primary
                        : AppColors.iconDefault,
                  ),
                ),
          prefixIconConstraints: maxLines > 1
              ? const BoxConstraints(minWidth: 44, minHeight: 0)
              : null,
          border:             InputBorder.none,
          enabledBorder:      InputBorder.none,
          focusedBorder:      InputBorder.none,
          errorBorder:        InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          alignLabelWithHint: true,
          contentPadding: maxLines > 1
              ? const EdgeInsets.symmetric(horizontal: 14, vertical: 14)
              : EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: isTablet ? 18 : 15,
                ),
          errorStyle: const TextStyle(
            color:    AppColors.error,
            fontSize: 11.5,
            height:   1.4,
          ),
        ),
      ),
    );
  }

  // ── Right-aligned compact buttons ─────────────────────────────────────────
  Widget _buildButtons(bool isTablet) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Cancel
        OutlinedButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.border, width: 1.3),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            backgroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 24 : 20,
              vertical:   isTablet ? 13 : 11,
            ),
            minimumSize:   Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Cancel',
            style: TextStyle(
              color:      AppColors.textLabel,
              fontSize:   isTablet ? 14 : 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Save / Update
        ElevatedButton(
          onPressed: _isSaving
              ? null
              : (_isEditMode ? _handleUpdate : _handleSave),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withOpacity(0.45),
            elevation:    0,
            shadowColor:  Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 28 : 24,
              vertical:   isTablet ? 13 : 11,
            ),
            minimumSize:   Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isSaving
                ? const SizedBox(
                    key: ValueKey('loader'),
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.2),
                  )
                : Text(
                    _isEditMode ? 'Update' : 'Save',
                    key: const ValueKey('label'),
                    style: TextStyle(
                      color:      Colors.white,
                      fontSize:   isTablet ? 14 : 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}