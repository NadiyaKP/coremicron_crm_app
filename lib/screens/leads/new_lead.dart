import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService, kTokenKey;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/screens/login.dart' show kTokenKey;
import 'package:coremicron_crm_app/screens/leads/leads.dart' show Lead;
import 'package:coremicron_crm_app/common/string_extensions.dart';

// ── Simple models ──────────────────────────────────────────────────────────
class _Customer {
  final String id;
  final String name;
  final String phone;
  _Customer({required this.id, required this.name, required this.phone});
}

class _Employee {
  final String id;
  final String name;
  final String phone;
  final String employeeId;
  _Employee({
    required this.id,
    required this.name,
    required this.phone,
    required this.employeeId,
  });
}

// ── New Lead Page ──────────────────────────────────────────────────────────
class NewLeadPage extends StatefulWidget {
  final String username;
  final Lead?  lead;

  const NewLeadPage({super.key, required this.username, this.lead});

  @override
  State<NewLeadPage> createState() => _NewLeadPageState();
}

class _NewLeadPageState extends State<NewLeadPage> {
  bool get _isEdit => widget.lead != null;

  // ── Controllers ────────────────────────────────────────────────────────────
  final _customerCtrl    = TextEditingController();
  final _phoneCtrl       = TextEditingController();
  final _titleCtrl       = TextEditingController();
  final _leadDetailsCtrl = TextEditingController();
  final _assignCtrl      = TextEditingController();

  // ── Focus nodes ────────────────────────────────────────────────────────────
  final _customerFocus    = FocusNode();
  final _phoneFocus       = FocusNode();
  final _titleFocus       = FocusNode();
  final _leadDetailsFocus = FocusNode();
  final _assignFocus      = FocusNode();

  // ── GlobalKeys for keyboard-aware dropdown positioning ─────────────────────
  final _customerFieldKey = GlobalKey();
  final _employeeFieldKey = GlobalKey();

  // ── Selected values ────────────────────────────────────────────────────────
  _Customer?      _selectedCustomer;
  List<_Employee> _selectedEmployees = [];

  // ── Customer autocomplete ──────────────────────────────────────────────────
  List<_Customer> _allCustomers        = [];
  List<_Customer> _customerSuggestions = [];
  bool            _customersLoaded     = false;
  Timer?          _customerDebounce;

  // ── Employee autocomplete ──────────────────────────────────────────────────
  List<_Employee> _allEmployees        = [];
  List<_Employee> _employeeSuggestions = [];
  bool            _employeesLoaded     = false;
  Timer?          _employeeDebounce;

  bool _isSaving = false;

  // ── Layer links for overlays ───────────────────────────────────────────────
  final _customerLayerLink = LayerLink();
  final _employeeLayerLink = LayerLink();
  OverlayEntry? _customerOverlay;
  OverlayEntry? _employeeOverlay;

  @override
  void initState() {
    super.initState();
    for (final fn in [
      _customerFocus, _phoneFocus, _titleFocus,
      _leadDetailsFocus, _assignFocus,
    ]) {
      fn.addListener(() => setState(() {}));
    }
    _customerFocus.addListener(_onCustomerFocusChange);
    _assignFocus.addListener(_onEmployeeFocusChange);

    if (_isEdit) {
      final l = widget.lead!;
      _customerCtrl.text    = l.customerName.capitalize();
      _phoneCtrl.text       = l.customerPhone;
      _titleCtrl.text       = l.title;
      _leadDetailsCtrl.text = l.enquiry;

      _selectedCustomer = _Customer(
          id: l.customerId, name: l.customerName, phone: l.customerPhone);
// WITH this clean version:
if (l.assignedEmployees.isNotEmpty) {
  final names = l.assignedEmployees
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  _selectedEmployees = names.asMap().entries.map((entry) {
    return _Employee(
      id:         entry.key < l.assignedEmployeeIds.length
                      ? l.assignedEmployeeIds[entry.key]
                      : entry.key.toString(), // fallback unique id
      name:       entry.value,
      phone:      '',
      employeeId: '',
    );
  }).toList();
}
    }
  }

  @override
  void dispose() {
    _removeCustomerOverlay();
    _removeEmployeeOverlay();
    _customerDebounce?.cancel();
    _employeeDebounce?.cancel();
    for (final c in [
      _customerCtrl, _phoneCtrl, _titleCtrl,
      _leadDetailsCtrl, _assignCtrl,
    ]) { c.dispose(); }
    for (final fn in [
      _customerFocus, _phoneFocus, _titleFocus,
      _leadDetailsFocus, _assignFocus,
    ]) { fn.dispose(); }
    super.dispose();
  }

  // ── Focus listeners ────────────────────────────────────────────────────────
  void _onCustomerFocusChange() {
    if (!_customerFocus.hasFocus) {
      Future.delayed(const Duration(milliseconds: 150), _removeCustomerOverlay);
    }
  }

  void _onEmployeeFocusChange() {
    if (!_assignFocus.hasFocus) {
      Future.delayed(const Duration(milliseconds: 150), _removeEmployeeOverlay);
    }
  }

  // ── Load customers ─────────────────────────────────────────────────────────
  Future<void> _loadCustomers() async {
    if (_customersLoaded) return;
    try {
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/customer/list.php?view=dropdown');
      final res =
          await ApiService.get(url).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        final list = data['data'] as List? ?? [];
        _allCustomers = list
            .map((e) => _Customer(
                  id:    e['id']            ?? '',
                  name:  e['customer_name'] ?? '',
                  phone: e['phone_number']  ?? '',
                ))
            .toList();
        _customersLoaded = true;
      }
    } catch (_) {}
  }

  // ── Load employees ─────────────────────────────────────────────────────────
  Future<void> _loadEmployees() async {
    if (_employeesLoaded) return;
    try {
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/employee/list.php?view=dropdown');
      final res =
          await ApiService.get(url).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        final list = data['data'] as List? ?? [];
        _allEmployees = list
            .map((e) => _Employee(
                  id:         e['id']            ?? '',
                  name:       e['employee_name'] ?? '',
                  phone:      e['phone_number']  ?? '',
                  employeeId: e['employee_id']   ?? '',
                ))
            .toList();
        _employeesLoaded = true;
      }
    } catch (_) {}
  }

  // ── Customer search ────────────────────────────────────────────────────────
  void _onCustomerChanged(String query) {
    _selectedCustomer = null;
    _customerDebounce?.cancel();
    _customerDebounce = Timer(const Duration(milliseconds: 250), () async {
      await _loadCustomers();
      final q = query.trim().toLowerCase();
      if (q.isEmpty) { _removeCustomerOverlay(); return; }
      _customerSuggestions = _allCustomers
          .where((c) =>
              c.name.toLowerCase().contains(q) || c.phone.contains(q))
          .toList();
      _customerSuggestions.isNotEmpty
          ? _showCustomerDropdown()
          : _removeCustomerOverlay();
    });
  }

  // ── Employee search ────────────────────────────────────────────────────────
  void _onEmployeeChanged(String query) {
    _employeeDebounce?.cancel();
    _employeeDebounce = Timer(const Duration(milliseconds: 250), () async {
      await _loadEmployees();
      final q = query.trim().toLowerCase();
      if (q.isEmpty) { _removeEmployeeOverlay(); return; }
      final selectedIds = _selectedEmployees.map((e) => e.id).toSet();
      _employeeSuggestions = _allEmployees
          .where((e) =>
              !selectedIds.contains(e.id) &&
              (e.name.toLowerCase().contains(q) ||
               e.phone.contains(q) ||
               e.employeeId.toLowerCase().contains(q)))
          .toList();
      _employeeSuggestions.isNotEmpty
          ? _showEmployeeDropdown()
          : _removeEmployeeOverlay();
    });
  }

  // ── Customer overlay ───────────────────────────────────────────────────────
  void _showCustomerDropdown() {
    _removeCustomerOverlay();
    _customerOverlay = _buildOverlay(
      link:        _customerLayerLink,
      fieldKey:    _customerFieldKey,
      items:       _customerSuggestions,
      itemBuilder: (c) => _customerTile(c as _Customer),
    );
    Overlay.of(context).insert(_customerOverlay!);
  }

  void _removeCustomerOverlay() {
    _customerOverlay?.remove();
    _customerOverlay = null;
  }

  void _selectCustomer(_Customer c) {
    _removeCustomerOverlay();
    setState(() {
      _selectedCustomer  = c;
      _customerCtrl.text = c.name.capitalize();
      if (_phoneCtrl.text.trim().isEmpty) _phoneCtrl.text = c.phone;
    });
    FocusScope.of(context).requestFocus(_titleFocus);
  }

  // ── Employee overlay ───────────────────────────────────────────────────────
  void _showEmployeeDropdown() {
    _removeEmployeeOverlay();
    _employeeOverlay = _buildOverlay(
      link:        _employeeLayerLink,
      fieldKey:    _employeeFieldKey,
      items:       _employeeSuggestions,
      itemBuilder: (e) => _employeeTile(e as _Employee),
    );
    Overlay.of(context).insert(_employeeOverlay!);
  }

  void _removeEmployeeOverlay() {
    _employeeOverlay?.remove();
    _employeeOverlay = null;
  }

  void _selectEmployee(_Employee e) {
    _removeEmployeeOverlay();
    setState(() {
      if (!_selectedEmployees.any((s) => s.id == e.id)) {
        _selectedEmployees.add(e);
      }
      _assignCtrl.clear();
    });
  }

  void _removeEmployee(String id) {
    setState(() => _selectedEmployees.removeWhere((e) => e.id == id));
  }

  // ── Keyboard-aware overlay builder ─────────────────────────────────────────
  OverlayEntry _buildOverlay({
    required LayerLink             link,
    required GlobalKey             fieldKey,
    required List<dynamic>         items,
    required Widget Function(dynamic) itemBuilder,
  }) {
    return OverlayEntry(
      builder: (overlayContext) {
        final mq             = MediaQuery.of(overlayContext);
        final keyboardHeight = mq.viewInsets.bottom;
        final screenHeight   = mq.size.height;
        final fieldWidth     = link.leaderSize?.width  ?? 300.0;
        final fieldHeight    = link.leaderSize?.height ?? 48.0;

        // ── Resolve field's global Y via GlobalKey ──────────────────────────
        double fieldTop = 0;
        final rb =
            fieldKey.currentContext?.findRenderObject() as RenderBox?;
        if (rb != null && rb.hasSize) {
          fieldTop = rb.localToGlobal(Offset.zero).dy;
        }
        final fieldBottom = fieldTop + fieldHeight;

        // ── Decide: show above or below ─────────────────────────────────────
        final spaceBelow = screenHeight - keyboardHeight - fieldBottom - 8;
        final spaceAbove = fieldTop - 8;
        final showAbove  = spaceBelow < 150 && spaceAbove > spaceBelow;

        final maxH =
            (showAbove ? spaceAbove : spaceBelow).clamp(80.0, 220.0);

        return Positioned(
          width: fieldWidth,
          child: CompositedTransformFollower(
            link:             link,
            showWhenUnlinked: false,
            offset: showAbove
                ? Offset(0, -(maxH + 6))       // flip above
                : Offset(0, fieldHeight + 4),  // normal below
            child: Material(
              elevation:    8,
              borderRadius: BorderRadius.circular(12),
              color:        Colors.white,
              shadowColor:  Colors.black.withOpacity(0.12),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ListView.separated(
                    padding:          EdgeInsets.zero,
                    shrinkWrap:       true,
                    itemCount:        items.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1, color: AppColors.borderLight),
                    itemBuilder: (_, i) => itemBuilder(items[i]),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Customer tile ──────────────────────────────────────────────────────────
  Widget _customerTile(_Customer c) {
    return InkWell(
      onTap: () => _selectCustomer(c),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color:        AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                  style: const TextStyle(
                      color:      AppColors.primary,
                      fontSize:   13,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name.capitalize(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color:      AppColors.textPrimary,
                          fontSize:   13.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(c.phone,
                      style: const TextStyle(
                          color:    AppColors.textSecondary,
                          fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Employee tile ──────────────────────────────────────────────────────────
  Widget _employeeTile(_Employee e) {
    return InkWell(
      onTap: () => _selectEmployee(e),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color:        AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  e.name.isNotEmpty ? e.name[0].toUpperCase() : 'E',
                  style: const TextStyle(
                      color:      AppColors.primary,
                      fontSize:   13,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.name.capitalize(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color:      AppColors.textPrimary,
                          fontSize:   13.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(e.phone,
                          style: const TextStyle(
                              color:    AppColors.textSecondary,
                              fontSize: 12)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color:        AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ID: ${e.employeeId}',
                          style: const TextStyle(
                              color:      AppColors.primary,
                              fontSize:   10.5,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Selected employee chips ────────────────────────────────────────────────
  Widget _buildAssignedChips() {
    if (_selectedEmployees.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing:    8,
        runSpacing: 8,
        children: _selectedEmployees.map((e) {
          return Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
            decoration: BoxDecoration(
              color:        AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.25), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20, height: 20,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      e.name.isNotEmpty ? e.name[0].toUpperCase() : 'E',
                      style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  e.name.capitalize(),
                  style: const TextStyle(
                      color:      AppColors.primary,
                      fontSize:   12.5,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _removeEmployee(e.id),
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 11, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_selectedCustomer == null) {
      AppSnackBar.show(context,
          'Please select a customer from the suggestions.',
          isError: true);
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      AppSnackBar.show(context, 'Please enter a title.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final assignIds = _selectedEmployees.map((e) => e.id).toList();
      final Uri url;
      final Map<String, dynamic> body;

      if (_isEdit) {
        url  = Uri.parse('${ApiService.baseUrl}/api/leads/update.php');
        body = {
          'enquiry_id':  widget.lead!.enquiryId,
          'customer_id': _selectedCustomer!.id,
          'assign_ids':  assignIds,
          'title':       _titleCtrl.text.trim(),
          'lead':        _leadDetailsCtrl.text.trim(),
        };
      } else {
        url  = Uri.parse('${ApiService.baseUrl}/api/leads/create.php');
        body = {
          'customer_id': _selectedCustomer!.id,
          'assign_ids':  assignIds,
          'title':       _titleCtrl.text.trim(),
          'lead':        _leadDetailsCtrl.text.trim(),
        };
      }

      final response = await ApiService.post(url, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      debugPrint('📥  [${_isEdit ? 'UPDATE' : 'CREATE'} LEAD] '
          '${response.statusCode}  ${response.body}');

      if (response.statusCode == 200 && data['success'] == true) {
        Navigator.pop(context, true);
      } else {
        AppSnackBar.show(
          context,
          data['error'] ?? data['message'] ??
              (_isEdit ? 'Failed to update lead.' : 'Failed to create lead.'),
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
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── 1. Customer Name ──────────────────────────────────
                    _fieldLabel('Customer Name', required: true),
                    const SizedBox(height: 8),
                    CompositedTransformTarget(
                      link: _customerLayerLink,
                      child: KeyedSubtree(
                        key: _customerFieldKey,
                        child: _buildSearchField(
                          controller: _customerCtrl,
                          focusNode:  _customerFocus,
                          hint:       'Type to search existing customers…',
                          icon:       Icons.person_search_outlined,
                          onChanged:  _onCustomerChanged,
                          isSelected: _selectedCustomer != null,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── 2. Phone Number ───────────────────────────────────
                    _fieldLabel('Phone Number'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller:   _phoneCtrl,
                      focusNode:    _phoneFocus,
                      hint:         'Phone number',
                      icon:         Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      nextFocus:    _titleFocus,
                    ),

                    const SizedBox(height: 16),

                    // ── 3. Title ──────────────────────────────────────────
                    _fieldLabel('Title', required: true),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _titleCtrl,
                      focusNode:  _titleFocus,
                      hint:       'Enter lead title',
                      icon:       Icons.title_rounded,
                      nextFocus:  _leadDetailsFocus,
                    ),

                    const SizedBox(height: 16),

                    // ── 4. Lead Details ───────────────────────────────────
                    _fieldLabel('Lead Details'),
                    const SizedBox(height: 8),
                    _buildMultilineField(),

                    const SizedBox(height: 16),

                    // ── 5. Assign To ──────────────────────────────────────
                    _fieldLabel('Assign To'),
                    const SizedBox(height: 8),
                    CompositedTransformTarget(
                      link: _employeeLayerLink,
                      child: KeyedSubtree(
                        key: _employeeFieldKey,
                        child: _buildSearchField(
                          controller: _assignCtrl,
                          focusNode:  _assignFocus,
                          hint:       'Search by name, phone or code…',
                          icon:       Icons.person_pin_outlined,
                          onChanged:  _onEmployeeChanged,
                          isSelected: false,
                        ),
                      ),
                    ),

                    // ── Selected employee chips ────────────────────────────
                    _buildAssignedChips(),

                    const SizedBox(height: 32),

                    // ── Buttons ───────────────────────────────────────────
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
                                  borderRadius: BorderRadius.circular(11)),
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
                                  borderRadius: BorderRadius.circular(11)),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _isSaving
                                  ? const SizedBox(
                                      key:   ValueKey('s-loader'),
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(
                                          color:       Colors.white,
                                          strokeWidth: 2.4))
                                  : Text(
                                      _isEdit ? 'Update' : 'Save',
                                      key: ValueKey('s-label'),
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
                border: Border.all(color: AppColors.border, width: 1.2),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 15, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _isEdit ? 'Edit Lead' : 'New Lead',
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
  Widget _fieldLabel(String label, {bool required = false}) {
    return Row(
      children: [
        Text(label.toUpperCase(), style: AppTextStyles.fieldLabel(false)),
        if (required) ...[
          const SizedBox(width: 2),
          const Text(' *',
              style: TextStyle(
                  color:      AppColors.error,
                  fontSize:   13,
                  fontWeight: FontWeight.w700)),
        ],
      ],
    );
  }

  // ── Search field ───────────────────────────────────────────────────────────
  Widget _buildSearchField({
    required TextEditingController controller,
    required FocusNode             focusNode,
    required String                hint,
    required IconData              icon,
    required ValueChanged<String>  onChanged,
    required bool                  isSelected,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: isSelected
          ? BoxDecoration(
              color:        AppColors.successBg,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: AppColors.success.withOpacity(0.5), width: 1.4),
            )
          : focusNode.hasFocus
              ? AppDecorations.inputFocused
              : AppDecorations.inputIdle,
      child: TextField(
        controller:      controller,
        focusNode:       focusNode,
        textInputAction: TextInputAction.next,
        cursorColor:     AppColors.primary,
        onChanged:       onChanged,
        style: const TextStyle(
            color:      AppColors.textPrimary,
            fontSize:   14,
            fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText:  hint,
          hintStyle: const TextStyle(
              color: AppColors.textHint, fontSize: 13),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(icon,
                size:  18,
                color: isSelected
                    ? AppColors.success
                    : focusNode.hasFocus
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
    );
  }

  // ── Generic text field ─────────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode             focusNode,
    required String                hint,
    required IconData              icon,
    TextInputType keyboardType = TextInputType.text,
    FocusNode?    nextFocus,
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
      ),
    );
  }

  // ── Multi-line field ───────────────────────────────────────────────────────
  Widget _buildMultilineField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: _leadDetailsFocus.hasFocus
          ? AppDecorations.inputFocused
          : AppDecorations.inputIdle,
      child: TextField(
        controller:      _leadDetailsCtrl,
        focusNode:       _leadDetailsFocus,
        maxLines:        4,
        minLines:        4,
        cursorColor:     AppColors.primary,
        textInputAction: TextInputAction.newline,
        style: const TextStyle(
            color:      AppColors.textPrimary,
            fontSize:   14,
            fontWeight: FontWeight.w400),
        decoration: const InputDecoration(
          hintText:       'Enter lead details…',
          hintStyle:      TextStyle(
              color: AppColors.textHint, fontSize: 13.5),
          border:         InputBorder.none,
          enabledBorder:  InputBorder.none,
          focusedBorder:  InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
              horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}