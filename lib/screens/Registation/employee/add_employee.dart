import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService, kTokenKey;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/screens/Registation/employee/employee.dart' show Employee;

// ── Simple models for dropdowns ────────────────────────────────────────────
class _Department {
  final String id;
  final String name;
  _Department({required this.id, required this.name});
}

class _Machine {
  final String id;
  final String name;
  _Machine({required this.id, required this.name});
}

// ── Add / Edit Employee Page ───────────────────────────────────────────────
class AddEmployeePage extends StatefulWidget {
  final String    username;
  final Employee? employee; // null = add mode

  const AddEmployeePage({
    super.key,
    required this.username,
    this.employee,
  });

  @override
  State<AddEmployeePage> createState() => _AddEmployeePageState();
}

class _AddEmployeePageState extends State<AddEmployeePage> {
  bool get _isEdit => widget.employee != null;

  // ── Controllers ────────────────────────────────────────────────────────────
  final _employeeIdCtrl   = TextEditingController();
  final _employeeNameCtrl = TextEditingController();
  final _phoneCtrl        = TextEditingController();
  final _badgeCtrl        = TextEditingController();
  final _machineUserIdCtrl= TextEditingController();
  final _passwordCtrl     = TextEditingController();

  // ── Focus nodes ────────────────────────────────────────────────────────────
  final _employeeIdFocus    = FocusNode();
  final _employeeNameFocus  = FocusNode();
  final _phoneFocus         = FocusNode();
  final _badgeFocus         = FocusNode();
  final _machineUserIdFocus = FocusNode();
  final _passwordFocus      = FocusNode();

  // ── Dropdown state ─────────────────────────────────────────────────────────
  List<_Department> _departments       = [];
  List<_Machine>    _machines          = [];
  _Department?      _selectedDept;
  _Machine?         _selectedMachine;
  bool              _deptLoading       = false;
  bool              _machineLoading    = false;
  String?           _deptError;
  String?           _machineError;

  bool _obscurePassword = true;
  bool _isSaving        = false;

  @override
  void initState() {
    super.initState();
    // Listen for rebuilds on focus change
    for (final fn in [
      _employeeIdFocus, _employeeNameFocus, _phoneFocus,
      _badgeFocus, _machineUserIdFocus, _passwordFocus,
    ]) {
      fn.addListener(() => setState(() {}));
    }
    _fetchDepartments();
    _fetchMachines();
  }

  @override
  void dispose() {
    for (final c in [
      _employeeIdCtrl, _employeeNameCtrl, _phoneCtrl,
      _badgeCtrl, _machineUserIdCtrl, _passwordCtrl,
    ]) { c.dispose(); }
    for (final fn in [
      _employeeIdFocus, _employeeNameFocus, _phoneFocus,
      _badgeFocus, _machineUserIdFocus, _passwordFocus,
    ]) { fn.dispose(); }
    super.dispose();
  }

  // ── Pre-fill for edit mode (called after dropdowns load) ───────────────────
  void _preFill() {
    final e = widget.employee;
    if (e == null) return;
    _employeeIdCtrl.text    = e.employeeId;
    _employeeNameCtrl.text  = e.employeeName;
    _phoneCtrl.text         = e.phoneNumber;
    _badgeCtrl.text         = e.badgeNumber;
    _machineUserIdCtrl.text = e.machineUserId;
    // Match selected dept and machine by ID
    try {
      _selectedDept = _departments
          .firstWhere((d) => d.id == e.departmentId);
    } catch (_) {}
    try {
      _selectedMachine = _machines
          .firstWhere((m) => m.id == e.machineId);
    } catch (_) {}
    setState(() {});
  }

  // ── Fetch Departments ──────────────────────────────────────────────────────
  Future<void> _fetchDepartments() async {
    setState(() { _deptLoading = true; _deptError = null; });
    try {
      final url = Uri.parse('${ApiService.baseUrl}/api/department/list.php');
      final response = await ApiService.get(url).timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = jsonDecode(response.body);
      debugPrint('📥  [DEPT LIST] ${response.statusCode}  ${response.body}');

      if (response.statusCode == 200 && data['success'] == true) {
        final List list = data['data'] ?? [];
        _departments = list
            .map((e) => _Department(
                id: e['id'] ?? '', name: e['department_name'] ?? ''))
            .toList();
        // After depts load, try to pre-fill if in edit mode
        if (_isEdit && _machines.isNotEmpty) _preFill();
      } else {
        _deptError =
            data['error'] ?? data['message'] ?? 'Failed to load departments.';
      }
    } catch (_) {
      _deptError = 'Failed to load departments.';
    }
    if (mounted) setState(() => _deptLoading = false);
  }

  // ── Fetch Machines ─────────────────────────────────────────────────────────
  Future<void> _fetchMachines() async {
    setState(() { _machineLoading = true; _machineError = null; });
    try {
      final url = Uri.parse('${ApiService.baseUrl}/api/machine/list.php');
      final response = await ApiService.get(url).timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = jsonDecode(response.body);
      debugPrint(
          '📥  [MACHINE LIST] ${response.statusCode}  ${response.body}');

      if (response.statusCode == 200 && data['success'] == true) {
        final List list = data['data'] ?? [];
        _machines = list
            .map((e) =>
                _Machine(id: e['id'] ?? '', name: e['machine_name'] ?? ''))
            .toList();
        // After machines load, try to pre-fill if in edit mode
        if (_isEdit && _departments.isNotEmpty) _preFill();
      } else {
        _machineError =
            data['error'] ?? data['message'] ?? 'Failed to load machines.';
      }
    } catch (_) {
      _machineError = 'Failed to load machines.';
    }
    if (mounted) setState(() => _machineLoading = false);
  }

  // ── Submit (Create / Update) ───────────────────────────────────────────────
  Future<void> _submit() async {
    // Validate required fields
    if (_selectedDept == null) {
      AppSnackBar.show(context, 'Please select a department.', isError: true);
      return;
    }
    if (_employeeIdCtrl.text.trim().isEmpty) {
      AppSnackBar.show(context, 'Employee ID is required.', isError: true);
      return;
    }
    if (_employeeNameCtrl.text.trim().isEmpty) {
      AppSnackBar.show(context, 'Employee name is required.', isError: true);
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      AppSnackBar.show(context, 'Phone number is required.', isError: true);
      return;
    }
    if (_badgeCtrl.text.trim().isEmpty) {
      AppSnackBar.show(context, 'Badge number is required.', isError: true);
      return;
    }
    if (_selectedMachine == null) {
      AppSnackBar.show(context, 'Please select a machine.', isError: true);
      return;
    }
    if (_machineUserIdCtrl.text.trim().isEmpty) {
      AppSnackBar.show(context, 'Machine user ID is required.', isError: true);
      return;
    }
    if (!_isEdit && _passwordCtrl.text.trim().isEmpty) {
      AppSnackBar.show(context, 'Password is required.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final Uri url;
      final Map<String, dynamic> body;

      if (_isEdit) {
        url = Uri.parse('${ApiService.baseUrl}/api/employee/update.php');
        body = {
          'id':             widget.employee!.id,
          'department_id':  _selectedDept!.id,
          'machine_id':     _selectedMachine?.id ?? '',
          'employee_id':    _employeeIdCtrl.text.trim(),
          'employee_name':  _employeeNameCtrl.text.trim(),
          'phone_number':   _phoneCtrl.text.trim(),
          'badge_number':   _badgeCtrl.text.trim(),
          'machine_user_id':_machineUserIdCtrl.text.trim(),
          'password':       _passwordCtrl.text.trim(),
        };
      } else {
        url = Uri.parse('${ApiService.baseUrl}/api/employee/create.php');
        body = {
          'department_id':  _selectedDept!.id,
          'machine_id':     _selectedMachine?.id ?? '',
          'employee_id':    _employeeIdCtrl.text.trim(),
          'employee_name':  _employeeNameCtrl.text.trim(),
          'phone_number':   _phoneCtrl.text.trim(),
          'badge_number':   _badgeCtrl.text.trim(),
          'machine_user_id':_machineUserIdCtrl.text.trim(),
          'password':       _passwordCtrl.text.trim(),
        };
      }

      final response = await ApiService.post(url, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final Map<String, dynamic> data = jsonDecode(response.body);

      debugPrint('📥  [${_isEdit ? 'UPDATE' : 'CREATE'} EMPLOYEE] '
          '${response.statusCode}  ${response.body}');

      if (response.statusCode == 200 && data['success'] == true) {
        Navigator.pop(context, true);
      } else {
        AppSnackBar.show(
          context,
          data['error'] ??
              data['message'] ??
              (_isEdit ? 'Failed to update.' : 'Failed to create.'),
          isError: true,
        );
        setState(() => _isSaving = false);
      }
    } on http.ClientException {
      if (mounted) {
        AppSnackBar.show(context, 'Unable to reach the server.',
            isError: true);
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
            _buildAppBar(isTablet, hPad),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── 1. Department (required) ────────────────────────
                    _fieldLabel('Department', required: true),
                    const SizedBox(height: 8),
                    _buildDropdownField(
                      hint:       'Select department',
                      icon:       Icons.apartment_rounded,
                      isLoading:  _deptLoading,
                      errorText:  _deptError,
                      value:      _selectedDept?.name,
                      onTap:      () => _showDeptSheet(),
                    ),

                    const SizedBox(height: 16),

                    // ── 2. Employee ID (required) ───────────────────────
                    _fieldLabel('Employee ID', required: true),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller:      _employeeIdCtrl,
                      focusNode:       _employeeIdFocus,
                      hint:            'Enter employee ID',
                      icon:            Icons.badge_outlined,
                      nextFocus:       _employeeNameFocus,
                    ),

                    const SizedBox(height: 16),

                    // ── 3. Employee Name (required) ─────────────────────
                    _fieldLabel('Employee Name', required: true),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller:  _employeeNameCtrl,
                      focusNode:   _employeeNameFocus,
                      hint:        'Enter full name',
                      icon:        Icons.person_outline_rounded,
                      nextFocus:   _phoneFocus,
                    ),

                    const SizedBox(height: 16),

                    // ── 4. Phone Number (required) ──────────────────────
                    _fieldLabel('Phone Number', required: true),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller:  _phoneCtrl,
                      focusNode:   _phoneFocus,
                      hint:        'Enter phone number',
                      icon:        Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      nextFocus:   _badgeFocus,
                    ),

                    const SizedBox(height: 16),

                    // ── 5. Badge Number ─────────────────────────────────
                    _fieldLabel('Badge Number', required: true),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller:  _badgeCtrl,
                      focusNode:   _badgeFocus,
                      hint:        'Enter badge number',
                      icon:        Icons.credit_card_outlined,
                      nextFocus:   _machineUserIdFocus,
                    ),

                    const SizedBox(height: 16),

                    // ── 6. Machine (optional dropdown) ──────────────────
                    _fieldLabel('Machine', required: true),
                    const SizedBox(height: 8),
                    _buildDropdownField(
                      hint:       'Select machine',
                      icon:       Icons.fingerprint_rounded,
                      isLoading:  _machineLoading,
                      errorText:  _machineError,
                      value:      _selectedMachine?.name,
                      onTap:      () => _showMachineSheet(),
                    ),

                    const SizedBox(height: 16),

                    // ── 7. Machine User ID ──────────────────────────────
                    _fieldLabel('Machine User ID', required: true),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller:   _machineUserIdCtrl,
                      focusNode:    _machineUserIdFocus,
                      hint:         'Enter machine user ID',
                      icon:         Icons.tag_rounded,
                      keyboardType: TextInputType.number,
                      nextFocus:    _passwordFocus,
                    ),

                    const SizedBox(height: 16),

                    // ── 8. Username (info only) ─────────────────────────
                    _fieldLabel('Username'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color:        const Color(0xFFF0F6FF),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.25),
                            width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size:  16,
                              color: AppColors.primary.withOpacity(0.8)),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Phone number is used as the username',
                              style: TextStyle(
                                color:      AppColors.primary,
                                fontSize:   13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── 9. Password (required for create) ───────────────
                    _fieldLabel('Password',
                        required: true,
                        note: _isEdit
                            ? '(leave blank to keep current)'
                            : null),
                    const SizedBox(height: 8),
                    _buildPasswordField(),

                    const SizedBox(height: 32),

                    // ── Buttons ─────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving
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
                            onPressed: _isSaving ? null : _submit,
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
                              child: _isSaving
                                  ? const SizedBox(
                                      key: ValueKey('s-loader'),
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(
                                          color:       Colors.white,
                                          strokeWidth: 2.4))
                                  : Text(
                                      _isEdit ? 'Update' : 'Save',
                                      key: const ValueKey('s-label'),
                                      style: const TextStyle(
                                          color:      Colors.white,
                                          fontSize:   14,
                                          fontWeight: FontWeight.w700)),
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
          Text(
            _isEdit ? 'Edit Employee' : 'Add Employee',
            style: TextStyle(
                color:         AppColors.textPrimary,
                fontSize:      isTablet ? 20 : 17,
                fontWeight:    FontWeight.w800,
                letterSpacing: -0.3),
          ),
        ],
      ),
    );
  }

  // ── Field label ────────────────────────────────────────────────────────────
  Widget _fieldLabel(String label,
      {bool required = false, String? note}) {
    return Row(
      children: [
        Text(label.toUpperCase(),
            style: AppTextStyles.fieldLabel(false)),
        if (required) ...[
          const SizedBox(width: 2),
          const Text(' *',
              style: TextStyle(
                  color:      AppColors.error,
                  fontSize:   13,
                  fontWeight: FontWeight.w700)),
        ],
        if (note != null) ...[
          const SizedBox(width: 6),
          Text(note,
              style: const TextStyle(
                  color:     AppColors.textMuted,
                  fontSize:  11.5,
                  fontStyle: FontStyle.italic)),
        ],
      ],
    );
  }

  // ── Generic text field ─────────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode             focusNode,
    required String                hint,
    required IconData              icon,
    TextInputType   keyboardType = TextInputType.text,
    FocusNode?      nextFocus,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: focusNode.hasFocus
          ? AppDecorations.inputFocused
          : AppDecorations.inputIdle,
      child: TextField(
        controller:      controller,
        focusNode:       focusNode,
        keyboardType:    keyboardType,
        textInputAction: nextFocus != null
            ? TextInputAction.next
            : TextInputAction.done,
        onSubmitted: (_) {
          if (nextFocus != null) {
            FocusScope.of(context).requestFocus(nextFocus);
          }
        },
        cursorColor: AppColors.primary,
        style: const TextStyle(
            color:      AppColors.textPrimary,
            fontSize:   14,
            fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText:  hint,
          hintStyle: const TextStyle(
              color: AppColors.textHint, fontSize: 13.5),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(icon,
                size:  18,
                color: focusNode.hasFocus
                    ? AppColors.primary
                    : AppColors.iconDefault),
          ),
          border:         InputBorder.none,
          enabledBorder:  InputBorder.none,
          focusedBorder:  InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 15),
        ),
        // Mirror phone number into username display
        onChanged: (_) {},
      ),
    );
  }

  // ── Password field ─────────────────────────────────────────────────────────
  Widget _buildPasswordField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: _passwordFocus.hasFocus
          ? AppDecorations.inputFocused
          : AppDecorations.inputIdle,
      child: TextField(
        controller:      _passwordCtrl,
        focusNode:       _passwordFocus,
        obscureText:     _obscurePassword,
        textInputAction: TextInputAction.done,
        cursorColor:     AppColors.primary,
        style: const TextStyle(
            color:      AppColors.textPrimary,
            fontSize:   14,
            fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText:  'Enter password',
          hintStyle: const TextStyle(
              color: AppColors.textHint, fontSize: 13.5),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Icons.lock_outline_rounded,
                size:  18,
                color: _passwordFocus.hasFocus
                    ? AppColors.primary
                    : AppColors.iconDefault),
          ),
          suffixIcon: GestureDetector(
            onTap: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size:  18,
              color: AppColors.iconDefault,
            ),
          ),
          border:         InputBorder.none,
          enabledBorder:  InputBorder.none,
          focusedBorder:  InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 15),
        ),
      ),
    );
  }

  // ── Dropdown-style tappable field ─────────────────────────────────────────
  Widget _buildDropdownField({
    required String   hint,
    required IconData icon,
    required bool     isLoading,
    required String?  errorText,
    required String?  value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 50,
        decoration: AppDecorations.inputIdle,
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(icon, size: 18, color: AppColors.iconDefault),
            const SizedBox(width: 10),
            Expanded(
              child: isLoading
                  ? Row(
                      children: [
                        const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary),
                        ),
                        const SizedBox(width: 8),
                        Text('Loading…',
                            style: const TextStyle(
                                color:    AppColors.textHint,
                                fontSize: 13.5)),
                      ],
                    )
                  : errorText != null
                      ? GestureDetector(
                          onTap: icon == Icons.apartment_rounded
                              ? _fetchDepartments
                              : _fetchMachines,
                          child: Text(
                            'Retry: $errorText',
                            style: const TextStyle(
                                color:    AppColors.error,
                                fontSize: 13),
                          ),
                        )
                      : Text(
                          value ?? hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: value == null
                                ? AppColors.textHint
                                : AppColors.textPrimary,
                            fontSize:   14,
                            fontWeight: value == null
                                ? FontWeight.w400
                                : FontWeight.w500,
                          ),
                        ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  size: 20, color: AppColors.iconDefault),
            ),
          ],
        ),
      ),
    );
  }

  // ── Department bottom sheet ────────────────────────────────────────────────
  void _showDeptSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize:      0.85,
        minChildSize:      0.3,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color:        AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Select Department',
                    style: TextStyle(
                        color:      AppColors.textPrimary,
                        fontSize:   15,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderLight),
            Expanded(
              child: _departments.isEmpty
                  ? const Center(
                      child: Text('No departments available.',
                          style: TextStyle(color: AppColors.textMuted)))
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: _departments.length,
                      itemBuilder: (_, i) {
                        final dept = _departments[i];
                        final isSelected =
                            _selectedDept?.id == dept.id;
                        return ListTile(
                          onTap: () {
                            setState(() => _selectedDept = dept);
                            Navigator.pop(context);
                          },
                          leading: Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryLight
                                  : const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.apartment_rounded,
                                size:  16,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.iconDefault),
                          ),
                          title: Text(dept.name,
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize:   14,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400)),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded,
                                  color: AppColors.primary, size: 18)
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Machine bottom sheet ───────────────────────────────────────────────────
  void _showMachineSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize:      0.85,
        minChildSize:      0.3,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color:        AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Select Machine',
                    style: TextStyle(
                        color:      AppColors.textPrimary,
                        fontSize:   15,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderLight),
            Expanded(
              child: _machines.isEmpty
                  ? const Center(
                      child: Text('No machines available.',
                          style: TextStyle(color: AppColors.textMuted)))
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: _machines.length,
                      itemBuilder: (_, i) {
                        final machine = _machines[i];
                        final isSelected =
                            _selectedMachine?.id == machine.id;
                        return ListTile(
                          onTap: () {
                            setState(
                                () => _selectedMachine = machine);
                            Navigator.pop(context);
                          },
                          leading: Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryLight
                                  : const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.fingerprint_rounded,
                                size:  16,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.iconDefault),
                          ),
                          title: Text(machine.name,
                              style: TextStyle(
                                  color:      AppColors.textPrimary,
                                  fontSize:   14,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400)),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded,
                                  color: AppColors.primary, size: 18)
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}