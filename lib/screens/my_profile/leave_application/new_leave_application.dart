import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/common/string_extensions.dart';

// ── Leave Data passed when editing ────────────────────────────────────────
class LeaveEditData {
  final String leaveId;
  final String typeOfAbsence;
  final String reason;
  final String absenceFrom;
  final String absenceThrough;

  const LeaveEditData({
    required this.leaveId,
    required this.typeOfAbsence,
    required this.reason,
    required this.absenceFrom,
    required this.absenceThrough,
  });
}

// ── New / Edit Leave Application Page ─────────────────────────────────────
class NewLeaveApplicationPage extends StatefulWidget {
  /// Pass [editData] to pre-fill form for editing. Null = new application.
  final LeaveEditData? editData;

  const NewLeaveApplicationPage({super.key, this.editData});

  @override
  State<NewLeaveApplicationPage> createState() =>
      _NewLeaveApplicationPageState();
}

class _NewLeaveApplicationPageState extends State<NewLeaveApplicationPage> {
  static const List<String> _absenceTypes = [
    'Sick',
    'Maternity/Paternity',
    'Personal Leave',
    'Time off without payment',
    'Bereavement',
    'Other',
  ];

  String?   _selectedType;
  DateTime? _fromDate;
  DateTime? _throughDate;
  bool      _isLoading = false;

  final _reasonCtrl   = TextEditingController();
  final _fromCtrl     = TextEditingController();
  final _throughCtrl  = TextEditingController();

  bool get _isEditing => widget.editData != null;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  void _prefill() {
    final d = widget.editData;
    if (d == null) return;

    _selectedType      = _absenceTypes.contains(d.typeOfAbsence)
        ? d.typeOfAbsence
        : _absenceTypes.last;
    _reasonCtrl.text   = d.reason;

    try {
      final fp = d.absenceFrom.split('-');
      if (fp.length == 3) {
        _fromDate      = DateTime(
            int.parse(fp[0]), int.parse(fp[1]), int.parse(fp[2]));
        _fromCtrl.text = _fmtDisplay(d.absenceFrom);
      }
    } catch (_) {}

    try {
      final tp = d.absenceThrough.split('-');
      if (tp.length == 3) {
        _throughDate      = DateTime(
            int.parse(tp[0]), int.parse(tp[1]), int.parse(tp[2]));
        _throughCtrl.text = _fmtDisplay(d.absenceThrough);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _fromCtrl.dispose();
    _throughCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _fmtDisplay(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final p = raw.trim().split('-');
      if (p.length == 3) return '${p[2]}-${p[1]}-${p[0]}';
    } catch (_) {}
    return raw;
  }

  String _toApiDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate({required bool isFrom}) async {
    final now    = DateTime.now();
    final init   = isFrom
        ? (_fromDate ?? now)
        : (_throughDate ?? _fromDate ?? now);
    final picked = await showDatePicker(
      context:     context,
      initialDate: init,
      firstDate:   DateTime(now.year - 2),
      lastDate:    DateTime(now.year + 2),
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.light(
            primary:   AppColors.primary,
            onPrimary: Colors.white,
            surface:   Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isFrom) {
          _fromDate      = picked;
          _fromCtrl.text = _fmtDisplay(_toApiDate(picked));
        } else {
          _throughDate      = picked;
          _throughCtrl.text = _fmtDisplay(_toApiDate(picked));
        }
      });
    }
  }

  // ── Submit / Update ────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_selectedType == null) {
      AppSnackBar.show(context, 'Please select a type of absence.',
          isError: true);
      return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      AppSnackBar.show(context, 'Please enter a reason.', isError: true);
      return;
    }
    if (_fromDate == null) {
      AppSnackBar.show(context, 'Please select the absence from date.',
          isError: true);
      return;
    }
    if (_throughDate == null) {
      AppSnackBar.show(context, 'Please select the absence through date.',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final Uri    url;
      final Map<String, String> body;

      if (_isEditing) {
        url  = Uri.parse(
            '${ApiService.baseUrl}/api/attendance/leave_update.php');
        body = {
          'leave_id':        widget.editData!.leaveId,
          'type_of_absence': _selectedType!,
          'absence_from':    _toApiDate(_fromDate!),
          'absence_through': _toApiDate(_throughDate!),
          'reason':          _reasonCtrl.text.trim(),
        };
      } else {
        url  = Uri.parse(
            '${ApiService.baseUrl}/api/attendance/leave_create.php');
        body = {
          'type_of_absence': _selectedType!,
          'absence_from':    _toApiDate(_fromDate!),
          'absence_through': _toApiDate(_throughDate!),
          'reason':          _reasonCtrl.text.trim(),
        };
      }

      debugPrint('📤  [LEAVE ${_isEditing ? "UPDATE" : "CREATE"}] '
          '$url  ${jsonEncode(body)}');

      final res = await ApiService.post(url, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [LEAVE ${_isEditing ? "UPDATE" : "CREATE"}] '
          '${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        // Return true → triggers refresh in list page
        Navigator.pop(context, true);
      } else {
        AppSnackBar.show(
            context,
            data['error'] ?? data['message'] ?? 'Operation failed.',
            isError: true);
      }
    } on http.ClientException {
      if (mounted)
        AppSnackBar.show(context, 'Unable to reach the server.', isError: true);
    } catch (e) {
      if (mounted) AppSnackBar.show(context, 'Error: $e', isError: true);
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
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                    bottom: BorderSide(color: AppColors.borderLight)),
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
                      Text(
                        _isEditing
                            ? 'Edit Leave Application'
                            : 'New Leave Application',
                        style: TextStyle(
                            color:         AppColors.textPrimary,
                            fontSize:      isTablet ? 20 : 17,
                            fontWeight:    FontWeight.w800,
                            letterSpacing: -0.3),
                      ),
                      Text(
                        _isEditing
                            ? 'Update your leave request'
                            : 'Submit a leave request',
                        style: const TextStyle(
                            color:    AppColors.textSecondary,
                            fontSize: 11.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Form body ──────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Type of Absence ──────────────────────────────
                    _sectionLabel('Type of Absence *'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color:        Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.borderLight, width: 1),
                      ),
                      child: Column(
                        children: List.generate(
                          (_absenceTypes.length / 2).ceil(),
                          (rowIdx) {
                            final leftIdx  = rowIdx * 2;
                            final rightIdx = leftIdx + 1;
                            final hasRight =
                                rightIdx < _absenceTypes.length;
                            final isLastRow =
                                rowIdx == (_absenceTypes.length / 2).ceil() - 1;

                            return Column(
                              children: [
                                IntrinsicHeight(
                                  child: Row(
                                    children: [
                                      // Left cell
                                      Expanded(
                                        child: _radioCell(
                                          type:       _absenceTypes[leftIdx],
                                          isTopLeft:  rowIdx == 0,
                                          isTopRight: false,
                                          isBotLeft:  isLastRow,
                                          isBotRight: false,
                                        ),
                                      ),
                                      // Vertical divider
                                      Container(
                                          width: 1,
                                          color: AppColors.borderLight),
                                      // Right cell
                                      Expanded(
                                        child: hasRight
                                            ? _radioCell(
                                                type:       _absenceTypes[rightIdx],
                                                isTopLeft:  false,
                                                isTopRight: rowIdx == 0,
                                                isBotLeft:  false,
                                                isBotRight: isLastRow,
                                              )
                                            : const SizedBox(),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isLastRow)
                                  const Divider(
                                      height: 1,
                                      color: AppColors.borderLight),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Reason ────────────────────────────────────────
                    _sectionLabel('Reason *'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color:        Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.border, width: 1.2),
                      ),
                      child: TextField(
                        controller:  _reasonCtrl,
                        maxLines:    4,
                        minLines:    3,
                        cursorColor: AppColors.primary,
                        style: const TextStyle(
                            color:    AppColors.textPrimary,
                            fontSize: 13.5),
                        decoration: const InputDecoration(
                          hintText:  'Enter reason for your leave…',
                          hintStyle: TextStyle(
                              color:    AppColors.textHint,
                              fontSize: 13),
                          border:         InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Date row ──────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('Absence From *'),
                              const SizedBox(height: 8),
                              _datePicker(
                                ctrl:   _fromCtrl,
                                filled: _fromDate != null,
                                onTap:  () => _pickDate(isFrom: true),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('Absence Through *'),
                              const SizedBox(height: 8),
                              _datePicker(
                                ctrl:   _throughCtrl,
                                filled: _throughDate != null,
                                onTap:  () => _pickDate(isFrom: false),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Certification text ────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color:        const Color(0xFFF8FAFF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.borderLight, width: 1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 15, color: AppColors.primary),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Certification: I hereby request leave/approved absence from duty as indicated above and certify that such leave/absence is requested for the purpose(s) indicated. I understand that falsification on this form may be grounds for disciplinary action.',
                              style: TextStyle(
                                  color:    AppColors.textSecondary,
                                  fontSize: 12,
                                  height:   1.6),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Action buttons ────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppColors.border, width: 1.3),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 15),
                            ),
                            child: const Text('Cancel',
                                style: TextStyle(
                                    color:      AppColors.textLabel,
                                    fontWeight: FontWeight.w600,
                                    fontSize:   15)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              disabledBackgroundColor:
                                  AppColors.primary.withOpacity(0.45),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                            child: AnimatedSwitcher(
                              duration:
                                  const Duration(milliseconds: 200),
                              child: _isLoading
                                  ? const SizedBox(
                                      key:   ValueKey('btn-loader'),
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(
                                          color:       Colors.white,
                                          strokeWidth: 2.4))
                                  : Text(
                                      _isEditing ? 'Update' : 'Submit',
                                      key: const ValueKey('btn-label'),
                                      style: const TextStyle(
                                          color:      Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize:   15)),
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

  // ── Widgets ────────────────────────────────────────────────────────────────
  Widget _radioCell({
    required String type,
    required bool   isTopLeft,
    required bool   isTopRight,
    required bool   isBotLeft,
    required bool   isBotRight,
  }) {
    final selected = _selectedType == type;
    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      borderRadius: BorderRadius.only(
        topLeft:     isTopLeft  ? const Radius.circular(12) : Radius.zero,
        topRight:    isTopRight ? const Radius.circular(12) : Radius.zero,
        bottomLeft:  isBotLeft  ? const Radius.circular(12) : Radius.zero,
        bottomRight: isBotRight ? const Radius.circular(12) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 4),
        child: Row(
          children: [
            Radio<String>(
              value:    type,
              groupValue: _selectedType,
              onChanged: (v) =>
                  setState(() => _selectedType = v),
              activeColor: AppColors.primary,
              materialTapTargetSize:
                  MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                type,
                style: TextStyle(
                    color:      selected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    fontSize:   13,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.w400),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            color:      AppColors.textPrimary,
            fontSize:   13.5,
            fontWeight: FontWeight.w700),
      );

  Widget _datePicker({
    required TextEditingController ctrl,
    required bool                  filled,
    required VoidCallback          onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: Container(
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: filled ? AppColors.primary : AppColors.border,
                width: 1.2),
          ),
          child: TextField(
            controller: ctrl,
            style: const TextStyle(
                color:      AppColors.textPrimary,
                fontSize:   13.5,
                fontWeight: FontWeight.w500),
            decoration: const InputDecoration(
              hintText:  'DD-MM-YYYY',
              hintStyle: TextStyle(
                  color:    AppColors.textHint, fontSize: 13),
              suffixIcon: Icon(Icons.calendar_today_outlined,
                  size: 17, color: AppColors.iconDefault),
              border:         InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14),
            ),
          ),
        ),
      ),
    );
  }
}