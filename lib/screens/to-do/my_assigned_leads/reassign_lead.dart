import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService, kTokenKey;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/screens/login.dart' show kTokenKey;
import 'package:coremicron_crm_app/common/string_extensions.dart';

// ── Employee model ─────────────────────────────────────────────────────────
class _Employee {
  final String id;
  final String name;
  final String phone;
  final String employeeId;
  final String department;

  _Employee({
    required this.id,
    required this.name,
    required this.phone,
    required this.employeeId,
    required this.department,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Reassign Lead Page ─────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════
class ReassignLeadPage extends StatefulWidget {
  final String enquiryId;
  final String enquiryNumber;
  final String currentAssigneeName;
  final String title;

  const ReassignLeadPage({
    super.key,
    required this.enquiryId,
    required this.enquiryNumber,
    this.currentAssigneeName = '',
    this.title               = '',
  });

  @override
  State<ReassignLeadPage> createState() => _ReassignLeadPageState();
}

class _ReassignLeadPageState extends State<ReassignLeadPage> {
  // ── Employee autocomplete ──────────────────────────────────────────────────
  List<_Employee> _allEmployees      = [];
  List<_Employee> _filteredEmployees = [];
  _Employee?      _selectedEmployee;
  bool            _showSuggestions   = false;
  bool            _loadingEmployees  = false;

  final _employeeCtrl  = TextEditingController();
  final _employeeFocus = FocusNode();

  // ── Reason ────────────────────────────────────────────────────────────────
  final _reasonCtrl  = TextEditingController();
  final _reasonFocus = FocusNode();

  // ── Submit ─────────────────────────────────────────────────────────────────
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
    _employeeFocus.addListener(() {
      if (!_employeeFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) setState(() => _showSuggestions = false);
        });
      }
      setState(() {});
    });
    _reasonFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _employeeCtrl.dispose();
    _employeeFocus.dispose();
    _reasonCtrl.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  // ── Fetch employees ────────────────────────────────────────────────────────
  Future<void> _fetchEmployees() async {
    setState(() => _loadingEmployees = true);
    try {
      final res = await ApiService.get(
        Uri.parse('${ApiService.baseUrl}/api/employee/list.php?view=dropdown'),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        final list = data['data'] as List? ?? [];
        _allEmployees = list.map((e) => _Employee(
              id:         e['id']             ?? '',
              name:       e['employee_name']  ?? '',
              phone:      e['phone_number']   ?? '',
              employeeId: e['employee_id']    ?? '',
              department: e['department_name'] ?? '',
            )).toList();
      }
    } catch (e) {
      debugPrint('⚠️  [EMPLOYEES] $e');
    }
    if (mounted) setState(() => _loadingEmployees = false);
  }

  void _onEmployeeSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _selectedEmployee = null;
      if (q.isEmpty) {
        _filteredEmployees = [];
        _showSuggestions   = false;
      } else {
        _filteredEmployees = _allEmployees.where((e) {
          return e.name.toLowerCase().contains(q) ||
              e.phone.contains(q) ||
              e.employeeId.toLowerCase().contains(q);
        }).toList();
        _showSuggestions = true;
      }
    });
  }

  void _selectEmployee(_Employee emp) {
    setState(() {
      _selectedEmployee  = emp;
      _showSuggestions   = false;
      _employeeCtrl.text = emp.name.capitalize();
    });
    _employeeFocus.unfocus();
  }

  // ── Reassign ───────────────────────────────────────────────────────────────
  Future<void> _reassign() async {
    if (_selectedEmployee == null) {
      AppSnackBar.show(context, 'Please select an employee.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final url  = Uri.parse('${ApiService.baseUrl}/api/leads/reassign.php');
      final body = {
        'lead_id':   widget.enquiryId,
        'assign_id': _selectedEmployee!.id,
        'reason':    _reasonCtrl.text.trim(),
      };

      final res = await ApiService.post(url, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [REASSIGN LEAD] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Lead reassigned successfully.');
        // Pop with true so caller can refresh
        Navigator.pop(context, true);
      } else {
        AppSnackBar.show(
            context,
            data['error'] ?? data['message'] ?? 'Failed to reassign lead.',
            isError: true);
      }
    } on http.ClientException {
      if (mounted)
        AppSnackBar.show(context, 'Unable to reach the server.', isError: true);
    } catch (e) {
      if (mounted)
        AppSnackBar.show(context, 'Error: $e', isError: true);
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ── Build ─────────────────────────────────────────────────────────────────
  // ═════════════════════════════════════════════════════════════════════════
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
            _buildAppBar(isTablet, hPad),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 32),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Lead info card ──────────────────────────────────
                    _buildInfoCard(),

                    const SizedBox(height: 20),

                    // ── New assignee search ─────────────────────────────
                    _fieldLabel('Search and Select Employee',
                        required: true),
                    const SizedBox(height: 8),
                    _buildEmployeeField(),

                    const SizedBox(height: 16),

                    // ── Reason ──────────────────────────────────────────
                    _fieldLabel('Reason for Reassignment'),
                    const SizedBox(height: 8),
                    _buildReasonField(),

                    const SizedBox(height: 28),

                    // ── Action buttons ──────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppColors.border, width: 1.3),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(11)),
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                            ),
                            child: const Text('Cancel',
                                style: TextStyle(
                                    color:      AppColors.textLabel,
                                    fontWeight: FontWeight.w600,
                                    fontSize:   14)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _reassign,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              disabledBackgroundColor:
                                  AppColors.primary.withOpacity(0.45),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(11)),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      key:   ValueKey('loader'),
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(
                                          color:       Colors.white,
                                          strokeWidth: 2.4))
                                  : const Text('Reassign',
                                      key: ValueKey('label'),
                                      style: TextStyle(
                                          color:      Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize:   14)),
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
        color: Colors.white,
        border:
            Border(bottom: BorderSide(color: AppColors.borderLight)),
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
                border:
                    Border.all(color: AppColors.border, width: 1.2),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 15, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reassign Lead',
                    style: TextStyle(
                        color:         AppColors.textPrimary,
                        fontSize:      isTablet ? 19 : 16,
                        fontWeight:    FontWeight.w800,
                        letterSpacing: -0.3)),
                Text(
                  '#${widget.enquiryNumber}',
                  style: const TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Info card ──────────────────────────────────────────────────────────────
  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.borderLight, width: 1),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset:     const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enquiry number
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color:        AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Enquiry #${widget.enquiryNumber}',
                  style: const TextStyle(
                      color:      AppColors.primary,
                      fontSize:   11.5,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),

          if (widget.title.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.title.capitalize(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color:      AppColors.textPrimary,
                  fontSize:   13.5,
                  fontWeight: FontWeight.w600),
            ),
          ],

          // Current assignee
          if (widget.currentAssigneeName.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_pin_outlined,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                const Text('Currently Assigned To',
                    style: TextStyle(
                        color:    AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.currentAssigneeName.capitalize(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color:      AppColors.textPrimary,
                        fontSize:   13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Field label ────────────────────────────────────────────────────────────
  Widget _fieldLabel(String label, {bool required = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                color:      AppColors.textLabel,
                fontSize:   12.5,
                fontWeight: FontWeight.w600)),
        if (required)
          const Text(' *',
              style: TextStyle(
                  color:      AppColors.error,
                  fontSize:   13,
                  fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ── Employee autocomplete field ────────────────────────────────────────────
  Widget _buildEmployeeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Input
        Container(
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: _employeeFocus.hasFocus
                    ? AppColors.primary
                    : AppColors.border,
                width: _employeeFocus.hasFocus ? 1.6 : 1.2),
            boxShadow: _employeeFocus.hasFocus
                ? [
                    BoxShadow(
                        color:      AppColors.primary.withOpacity(0.08),
                        blurRadius: 6,
                        offset:     const Offset(0, 2))
                  ]
                : [],
          ),
          child: TextField(
            controller:  _employeeCtrl,
            focusNode:   _employeeFocus,
            onChanged:   _onEmployeeSearch,
            cursorColor: AppColors.primary,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText:  'Search by name, phone or employee ID…',
              hintStyle: const TextStyle(
                  color: AppColors.textHint, fontSize: 13),
              prefixIcon: _loadingEmployees
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary)))
                  : const Icon(Icons.person_search_outlined,
                      color: AppColors.iconDefault, size: 19),
              suffixIcon: _employeeCtrl.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _employeeCtrl.clear();
                        setState(() {
                          _selectedEmployee  = null;
                          _showSuggestions   = false;
                          _filteredEmployees = [];
                        });
                      },
                      child: const Icon(Icons.close_rounded,
                          size: 17, color: AppColors.textMuted),
                    )
                  : null,
              border:         InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13),
            ),
          ),
        ),

        // Dropdown suggestions
        if (_showSuggestions)
          Container(
            margin:      const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(11),
              border:
                  Border.all(color: AppColors.borderLight, width: 1),
              boxShadow: [
                BoxShadow(
                    color:      Colors.black.withOpacity(0.08),
                    blurRadius: 14,
                    offset:     const Offset(0, 4)),
              ],
            ),
            child: _filteredEmployees.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: const [
                        Icon(Icons.search_off_rounded,
                            size:  16,
                            color: AppColors.textMuted),
                        SizedBox(width: 8),
                        Text('No employees found',
                            style: TextStyle(
                                color:    AppColors.textMuted,
                                fontSize: 13)),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap:       true,
                    padding:          EdgeInsets.zero,
                    itemCount:        _filteredEmployees.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1, color: AppColors.borderLight),
                    itemBuilder: (_, i) {
                      final emp = _filteredEmployees[i];
                      return InkWell(
                        onTap: () => _selectEmployee(emp),
                        borderRadius: BorderRadius.circular(11),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                              12, 10, 12, 10),
                          child: Row(
                            children: [
                              Container(
                                width: 34, height: 34,
                                decoration: BoxDecoration(
                                  color:        AppColors.primaryLight,
                                  borderRadius:
                                      BorderRadius.circular(9),
                                ),
                                child: Center(
                                  child: Text(
                                    emp.name.isNotEmpty
                                        ? emp.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color:      AppColors.primary,
                                        fontSize:   14,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(emp.name.capitalize(),
                                        style: const TextStyle(
                                            color:      AppColors.textPrimary,
                                            fontSize:   13.5,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone_outlined,
                                            size:  11,
                                            color: AppColors.textMuted),
                                        const SizedBox(width: 3),
                                        Text(emp.phone,
                                            style: const TextStyle(
                                                color:    AppColors.textMuted,
                                                fontSize: 11.5)),
                                        if (emp.department.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          const Text('•',
                                              style: TextStyle(
                                                  color:    AppColors.textMuted,
                                                  fontSize: 10)),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(emp.department,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    color:    AppColors.textMuted,
                                                    fontSize: 11)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  size:  16,
                                  color: AppColors.textMuted),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

        // Selected employee chip
        if (_selectedEmployee != null && !_showSuggestions)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
              decoration: BoxDecoration(
                color:        const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF2E7D32).withOpacity(0.3),
                    width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      size: 14, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 6),
                  Text(
                    _selectedEmployee!.name.capitalize(),
                    style: const TextStyle(
                        color:      Color(0xFF2E7D32),
                        fontSize:   12.5,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Reason field ───────────────────────────────────────────────────────────
  Widget _buildReasonField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: _reasonFocus.hasFocus
          ? AppDecorations.inputFocused
          : AppDecorations.inputIdle,
      child: TextField(
        controller:  _reasonCtrl,
        focusNode:   _reasonFocus,
        maxLines:    4,
        minLines:    3,
        cursorColor: AppColors.primary,
        style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 14),
        decoration: const InputDecoration(
          hintText:  'Enter reason for the reassignment…',
          hintStyle: TextStyle(
              color: AppColors.textHint, fontSize: 13.5),
          border:         InputBorder.none,
          enabledBorder:  InputBorder.none,
          focusedBorder:  InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
        ),
      ),
    );
  }
}