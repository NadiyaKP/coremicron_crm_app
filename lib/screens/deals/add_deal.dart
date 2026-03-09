import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../common/api_service.dart';
import '../../common/theme.dart';
import '../login.dart' show kSessionKey;
import 'deals.dart' show Deal;

// ── Hex helpers (duplicated here — Dart private functions cannot be imported)
Color _hexToColor(String hex) {
  try {
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
    if (clean.length == 8) return Color(int.parse(clean, radix: 16));
  } catch (_) {}
  return const Color(0xFF6B7280);
}

String _colorToHex(Color c) =>
    '#${c.red.toRadixString(16).padLeft(2, '0')}'
    '${c.green.toRadixString(16).padLeft(2, '0')}'
    '${c.blue.toRadixString(16).padLeft(2, '0')}';

// ── Add / Edit Deal Page ───────────────────────────────────────────────────
class AddDealPage extends StatefulWidget {
  final String username;
  final Deal?  deal; // null = add mode, non-null = edit mode

  const AddDealPage({
    super.key,
    required this.username,
    this.deal,
  });

  @override
  State<AddDealPage> createState() => _AddDealPageState();
}

class _AddDealPageState extends State<AddDealPage> {
  bool get _isEdit => widget.deal != null;

  final TextEditingController _nameCtrl  = TextEditingController();
  final FocusNode             _nameFocus = FocusNode();

  Color _selectedColor = const Color(0xFF1E88E5);
  bool  _isSaving      = false;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameCtrl.text  = widget.deal!.dealsName;
      _selectedColor  = _hexToColor(widget.deal!.color);
    }
    _nameFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  // ── Save / Update ──────────────────────────────────────────────────────────
  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AppSnackBar.show(context, 'Please enter a deal name.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final colorHex  = _colorToHex(_selectedColor);

      final Uri    url;
      final Map<String, dynamic> body;

      if (_isEdit) {
        url  = Uri.parse('${ApiService.baseUrl}/api/deals/update.php');
        body = {
          'id':         widget.deal!.id,
          'deals_name': name,
          'color':      colorHex,
        };
      } else {
        url  = Uri.parse('${ApiService.baseUrl}/api/deals/create.php');
        body = {
          'deals_name': name,
          'color':      colorHex,
        };
      }

      debugPrint('─────────────────────────────────────────');
      debugPrint('📤  [${_isEdit ? 'UPDATE' : 'CREATE'} DEAL] Request');
      debugPrint('   🌐  URL  : $url');
      debugPrint('   📦  Body : ${jsonEncode(body)}');
      debugPrint('─────────────────────────────────────────');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
          'X-Session-ID': sessionId,
          'Cookie':       'PHPSESSID=$sessionId',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      final Map<String, dynamic> data = jsonDecode(response.body);

      debugPrint('📥  [${_isEdit ? 'UPDATE' : 'CREATE'} DEAL] '
          '${response.statusCode}  ${response.body}');

      if (response.statusCode == 200 && data['success'] == true) {
        // Return true so DealsPage knows to refresh
        Navigator.pop(context, true);
      } else {
        AppSnackBar.show(
          context,
          data['error'] ?? data['message'] ?? (_isEdit ? 'Failed to update.' : 'Failed to create.'),
          isError: true,
        );
        setState(() => _isSaving = false);
      }
    } on http.ClientException {
      if (mounted) {
        AppSnackBar.show(context, 'Unable to reach the server.', isError: true);
        setState(() => _isSaving = false);
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(context, 'Something went wrong.', isError: true);
        setState(() => _isSaving = false);
      }
    }
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
          children: [
            // ── App Bar ───────────────────────────────────────────────
            _buildAppBar(isTablet, hPad),

            // ── Scrollable body ───────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Deal Name ─────────────────────────────────────
                    Text('DEAL NAME',
                        style: AppTextStyles.fieldLabel(false)),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: _nameFocus.hasFocus
                          ? AppDecorations.inputFocused
                          : AppDecorations.inputIdle,
                      child: TextField(
                        controller:      _nameCtrl,
                        focusNode:       _nameFocus,
                        autofocus:       !_isEdit,
                        textInputAction: TextInputAction.done,
                        cursorColor:     AppColors.primary,
                        style: const TextStyle(
                            color:      AppColors.textPrimary,
                            fontSize:   14,
                            fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText:  'Enter deal name',
                          hintStyle: const TextStyle(
                              color:    AppColors.textHint,
                              fontSize: 13.5),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.handshake_outlined,
                                size:  18,
                                color: _nameFocus.hasFocus
                                    ? AppColors.primary
                                    : AppColors.iconDefault),
                          ),
                          border:         InputBorder.none,
                          enabledBorder:  InputBorder.none,
                          focusedBorder:  InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 15),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Deal Color label ──────────────────────────────
                    Text('DEAL COLOR',
                        style: AppTextStyles.fieldLabel(false)),
                    const SizedBox(height: 8),

                    // ── Selected color preview box ────────────────────
                    Container(
                      width:  double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color:        _selectedColor,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                            color: Colors.black.withOpacity(0.08),
                            width: 1),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Color picker ──────────────────────────────────
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color:        Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.borderLight, width: 1),
                        boxShadow: [
                          BoxShadow(
                              color:  Colors.black.withOpacity(0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2)),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: ColorPicker(
                        pickerColor:            _selectedColor,
                        onColorChanged:         (c) =>
                            setState(() => _selectedColor = c),
                        enableAlpha:            false,
                        displayThumbColor:      true,
                        labelTypes:             const [],
                        pickerAreaBorderRadius: BorderRadius.circular(10),
                        // pickerAreaHeightPercent controls the saturation/
                        // brightness square height relative to the widget width
                        pickerAreaHeightPercent: 0.55,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Submit button ─────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: _isSaving ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor:
                                AppColors.primary.withOpacity(0.45),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 11),
                            minimumSize:   Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _isSaving
                                ? const SizedBox(
                                    key: ValueKey('loader'),
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                        color:       Colors.white,
                                        strokeWidth: 2.2))
                                : Text(
                                    _isEdit ? 'Update' : 'Save',
                                    key: const ValueKey('label'),
                                    style: const TextStyle(
                                      color:      Colors.white,
                                      fontSize:   13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
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
              width: 36, height: 36,
              decoration: BoxDecoration(
                color:        AppColors.background,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.border, width: 1.2),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 15, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _isEdit ? 'Edit Deal' : 'Add Deal',
            style: TextStyle(
              color:         AppColors.textPrimary,
              fontSize:      isTablet ? 20 : 17,
              fontWeight:    FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}