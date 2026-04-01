import 'dart:async';
import 'dart:convert';
import 'package:coremicron_crm_app/screens/ticket/amc_ticket.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService, kTokenKey;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/screens/login.dart' show kTokenKey;
import 'package:coremicron_crm_app/screens/ticket/tickets.dart' show Ticket;
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
  _Employee(
      {required this.id,
      required this.name,
      required this.phone,
      required this.employeeId});
}

// ── New Ticket Page ────────────────────────────────────────────────────────
class NewTicketPage extends StatefulWidget {
  final String  username;
  final Ticket? ticket; // null = add, non-null = edit

  const NewTicketPage({super.key, required this.username, this.ticket});

  @override
  State<NewTicketPage> createState() => _NewTicketPageState();
}

class _NewTicketPageState extends State<NewTicketPage> {
  bool get _isEdit => widget.ticket != null;

  // ── Ticket type radio ──────────────────────────────────────────────────────
  String? _ticketType; // null = nothing selected yet

  // ── Priority dropdown ──────────────────────────────────────────────────────
  String _priority = 'low';
  final List<String> _priorities = ['low', 'medium', 'high'];

  // ── Controllers ────────────────────────────────────────────────────────────
  final _titleCtrl    = TextEditingController();
  final _customerCtrl = TextEditingController();
  final _employeeCtrl = TextEditingController();
  final _notesCtrl    = TextEditingController();

  // ── Focus nodes ────────────────────────────────────────────────────────────
  final _titleFocus    = FocusNode();
  final _customerFocus = FocusNode();
  final _employeeFocus = FocusNode();
  final _notesFocus    = FocusNode();

  // ── Selected values ────────────────────────────────────────────────────────
  _Customer? _selectedCustomer;
  _Employee? _selectedEmployee;

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

  // ── Overlay links ──────────────────────────────────────────────────────────
  final _customerLayerLink = LayerLink();
  final _employeeLayerLink = LayerLink();
  OverlayEntry? _customerOverlay;
  OverlayEntry? _employeeOverlay;

  @override
  void initState() {
    super.initState();
    for (final fn in [
      _titleFocus, _customerFocus, _employeeFocus, _notesFocus
    ]) {
      fn.addListener(() => setState(() {}));
    }
    _customerFocus.addListener(_onCustomerFocusChange);
    _employeeFocus.addListener(_onEmployeeFocusChange);

    if (_isEdit) _preFill();
  }

  @override
  void dispose() {
    _removeCustomerOverlay();
    _removeEmployeeOverlay();
    _customerDebounce?.cancel();
    _employeeDebounce?.cancel();
    for (final c in [
      _titleCtrl, _customerCtrl, _employeeCtrl, _notesCtrl
    ]) { c.dispose(); }
    for (final fn in [
      _titleFocus, _customerFocus, _employeeFocus, _notesFocus
    ]) { fn.dispose(); }
    super.dispose();
  }

  // ── Pre-fill for edit ──────────────────────────────────────────────────────
  void _preFill() {
    final t = widget.ticket!;
    _titleCtrl.text    = t.title;
    _notesCtrl.text    = t.notes;
    _ticketType        = t.typeOfTickets.toLowerCase() == 'new works'
        ? 'New Works'
        : 'Complaints';
    _priority          = t.priority.toLowerCase();
    _customerCtrl.text = t.customerName.capitalize();
    _employeeCtrl.text = t.taskHandlerName.capitalize();
    _selectedCustomer  = _Customer(
        id: t.customerId, name: t.customerName, phone: t.phoneNumber);
    if (t.taskHandlerName.isNotEmpty) {
      _selectedEmployee = _Employee(
          id: t.taskHandlerId, name: t.taskHandlerName,
          phone: '', employeeId: '');
    }
  }

  // ── Focus listeners ────────────────────────────────────────────────────────
  void _onCustomerFocusChange() {
    if (!_customerFocus.hasFocus) {
      Future.delayed(const Duration(milliseconds: 150),
          _removeCustomerOverlay);
    }
  }

  void _onEmployeeFocusChange() {
    if (!_employeeFocus.hasFocus) {
      Future.delayed(const Duration(milliseconds: 150),
          _removeEmployeeOverlay);
    }
  }

  // ── Load customers (once) ──────────────────────────────────────────────────
  Future<void> _loadCustomers() async {
    if (_customersLoaded) return;
    try {
      final url = Uri.parse('${ApiService.baseUrl}/api/customer/list.php?view=dropdown');
      final res = await ApiService.get(url).timeout(const Duration(seconds: 15));
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

  // ── Load employees (once) ──────────────────────────────────────────────────
  Future<void> _loadEmployees() async {
    if (_employeesLoaded) return;
    try {
      final url = Uri.parse('${ApiService.baseUrl}/api/employee/list.php?view=dropdown');
      final res = await ApiService.get(url).timeout(const Duration(seconds: 15));
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
    _customerDebounce =
        Timer(const Duration(milliseconds: 250), () async {
      await _loadCustomers();
      final q = query.trim().toLowerCase();
      if (q.isEmpty) { _removeCustomerOverlay(); return; }
      _customerSuggestions = _allCustomers
          .where((c) =>
              c.name.toLowerCase().contains(q) || c.phone.contains(q))
          .toList();
      if (_customerSuggestions.isNotEmpty) {
        _showCustomerDropdown();
      } else {
        _removeCustomerOverlay();
      }
    });
  }

  // ── Employee search ────────────────────────────────────────────────────────
  void _onEmployeeChanged(String query) {
    _selectedEmployee = null;
    _employeeDebounce?.cancel();
    _employeeDebounce =
        Timer(const Duration(milliseconds: 250), () async {
      await _loadEmployees();
      final q = query.trim().toLowerCase();
      if (q.isEmpty) { _removeEmployeeOverlay(); return; }
      _employeeSuggestions = _allEmployees
          .where((e) =>
              e.name.toLowerCase().contains(q) ||
              e.phone.contains(q) ||
              e.employeeId.toLowerCase().contains(q))
          .toList();
      if (_employeeSuggestions.isNotEmpty) {
        _showEmployeeDropdown();
      } else {
        _removeEmployeeOverlay();
      }
    });
  }

  // ── Overlays ───────────────────────────────────────────────────────────────
  void _showCustomerDropdown() {
    _removeCustomerOverlay();
    _customerOverlay = _buildOverlay(
      link:        _customerLayerLink,
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
      _selectedCustomer = c;
      _customerCtrl.text = c.name.capitalize();
    });
    FocusScope.of(context).requestFocus(_employeeFocus);
  }

  void _showEmployeeDropdown() {
    _removeEmployeeOverlay();
    _employeeOverlay = _buildOverlay(
      link:        _employeeLayerLink,
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
      _selectedEmployee = e;
      _employeeCtrl.text = e.name.capitalize();
    });
    FocusScope.of(context).requestFocus(_notesFocus);
  }

  // ── Generic overlay builder ────────────────────────────────────────────────
  OverlayEntry _buildOverlay({
    required LayerLink            link,
    required List<dynamic>        items,
    required Widget Function(dynamic) itemBuilder,
  }) {
    return OverlayEntry(
      builder: (_) => Positioned(
        width: link.leaderSize?.width ?? 300,
        child: CompositedTransformFollower(
          link:             link,
          showWhenUnlinked: false,
          offset:
              Offset(0, (link.leaderSize?.height ?? 48) + 4),
          child: Material(
            elevation:    6,
            borderRadius: BorderRadius.circular(12),
            color:        Colors.white,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxHeight: 220),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.separated(
                  padding:     EdgeInsets.zero,
                  shrinkWrap:  true,
                  itemCount:   items.length,
                  separatorBuilder: (_, __) => const Divider(
                      height: 1, color: AppColors.borderLight),
                  itemBuilder: (_, i) => itemBuilder(items[i]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Customer tile ──────────────────────────────────────────────────────────
  Widget _customerTile(_Customer c) {
    return InkWell(
      onTap: () => _selectCustomer(c),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  c.name.isNotEmpty
                      ? c.name[0].toUpperCase()
                      : 'C',
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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  e.name.isNotEmpty
                      ? e.name[0].toUpperCase()
                      : 'E',
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
                      if (e.employeeId.isNotEmpty) ...[
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

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_ticketType == null) {
      AppSnackBar.show(context, 'Please select a ticket type.', isError: true);
      return;
    }
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
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kTokenKey) ?? '';

      final Uri url;
      final Map<String, dynamic> body;

      if (_isEdit) {
        url  = Uri.parse(
            '${ApiService.baseUrl}/api/ticket/update.php');
        body = {
          'ticket_id':       widget.ticket!.ticketId,
          'customer_id':     _selectedCustomer!.id,
          'task_handler_id': _selectedEmployee?.id ?? '',
          'type':            _ticketType!,
          'title':           _titleCtrl.text.trim(),
          'notes':           _notesCtrl.text.trim(),
          'priority':        _priority,
        };
      } else {
        url  = Uri.parse(
            '${ApiService.baseUrl}/api/ticket/create.php');
        body = {
          'customer_id':     _selectedCustomer!.id,
          'task_handler_id': _selectedEmployee?.id ?? '',
          'type':            _ticketType!,
          'title':           _titleCtrl.text.trim(),
          'notes':           _notesCtrl.text.trim(),
          'priority':        _priority,
        };
      }

      debugPrint('─────────────────────────────────────────');
      debugPrint(
          '📤  [${_isEdit ? 'UPDATE' : 'CREATE'} TICKET] Request');
      debugPrint('   🌐  URL  : $url');
      debugPrint('   📦  Body : ${jsonEncode(body)}');
      debugPrint('─────────────────────────────────────────');

      final response = await ApiService.post(url, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      debugPrint('📥  [${_isEdit ? 'UPDATE' : 'CREATE'} TICKET] '
          '${response.statusCode}  ${response.body}');

      if (response.statusCode == 200 && data['success'] == true) {
        Navigator.pop(context, true);
      } else {
        AppSnackBar.show(
          context,
          data['error'] ??
              data['message'] ??
              (_isEdit
                  ? 'Failed to update ticket.'
                  : 'Failed to create ticket.'),
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
        AppSnackBar.show(context, 'Something went wrong.',
            isError: true);
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
                padding:
                    EdgeInsets.fromLTRB(hPad, 20, hPad, 32),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── 1. Ticket Type ──────────────────────────────────
                    _fieldLabel('Type of Ticket', required: true),
                    const SizedBox(height: 8),
                    _buildTypeSelector(),

                    const SizedBox(height: 16),

                    // ── 2. Title ────────────────────────────────────────
                    _fieldLabel('Title', required: true),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _titleCtrl,
                      focusNode:  _titleFocus,
                      hint:       'Enter ticket title',
                      icon:       Icons.title_rounded,
                      nextFocus:  _customerFocus,
                    ),

                    const SizedBox(height: 16),

                    // ── 3. Customer Name ────────────────────────────────
                    _fieldLabel('Customer Name', required: true),
                    const SizedBox(height: 8),
                    CompositedTransformTarget(
                      link: _customerLayerLink,
                      child: _buildSearchField(
                        controller: _customerCtrl,
                        focusNode:  _customerFocus,
                        hint:
                            'Type here to search existing customer…',
                        icon:       Icons.person_search_outlined,
                        onChanged:  _onCustomerChanged,
                        isSelected: _selectedCustomer != null,
                        onClear: () => setState(
                            () => _selectedCustomer = null),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── 4. Project Manager / Team Leader ────────────────
                    _fieldLabel('Project Manager / Team Leader'),
                    const SizedBox(height: 8),
                    CompositedTransformTarget(
                      link: _employeeLayerLink,
                      child: _buildSearchField(
                        controller: _employeeCtrl,
                        focusNode:  _employeeFocus,
                        hint:
                            'Type to search employee (name, phone, code)…',
                        icon:       Icons.manage_accounts_outlined,
                        onChanged:  _onEmployeeChanged,
                        isSelected: _selectedEmployee != null,
                        onClear: () => setState(
                            () => _selectedEmployee = null),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── 5. Notes ────────────────────────────────────────
                    _fieldLabel('Notes'),
                    const SizedBox(height: 8),
                    _buildMultilineField(),

                    const SizedBox(height: 16),

                    // ── 6. Priority dropdown ────────────────────────────
                    _fieldLabel('Priority', required: true),
                    const SizedBox(height: 8),
                    _buildPriorityDropdown(),

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
                                  color: AppColors.border,
                                  width: 1.3),
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
                            onPressed:
                                _isSaving ? null : _submit,
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
                              duration:
                                  const Duration(milliseconds: 200),
                              child: _isSaving
                                  ? const SizedBox(
                                      key: ValueKey('s-loader'),
                                      width:  20,
                                      height: 20,
                                      child:
                                          CircularProgressIndicator(
                                              color:       Colors.white,
                                              strokeWidth: 2.4))
                                  : Text(
                                      _isEdit ? 'Update' : 'Save',
                                      key: const ValueKey('s-label'),
                                      style: const TextStyle(
                                          color:      Colors.white,
                                          fontSize:   14,
                                          fontWeight:
                                              FontWeight.w700)),
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

  // ── App bar ────────────────────────────────────────────────────────────────
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
                border: Border.all(
                    color: AppColors.border, width: 1.2),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 15, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _isEdit ? 'Edit Ticket' : 'New Ticket',
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
      ],
    );
  }

  // ── Ticket type radio selector ─────────────────────────────────────────────
  Widget _buildTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Row(
        children: [
          _typeOption('Complaints', Icons.report_problem_outlined),
          Container(width: 1, height: 48, color: AppColors.borderLight),
          _typeOption('New Works', Icons.construction_outlined),
          Container(width: 1, height: 48, color: AppColors.borderLight),
          _typeOption('AMC', Icons.history_rounded),
        ],
      ),
    );
  }

  Widget _typeOption(String value, IconData icon) {
    final selected = _ticketType == value;
    return Expanded(
      child: InkWell(
        onTap: () async {
          if (value == 'AMC') {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AmcTicketPage(username: widget.username),
              ),
            );
            if (result == true) {
              Navigator.pop(context, true);
            }
          } else {
            setState(() => _ticketType = value);
          }
        },
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withOpacity(0.07)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 13,
                  color: selected
                      ? AppColors.primary
                      : AppColors.iconDefault),
              const SizedBox(width: 3),
              Flexible(
                child: Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textLabel,
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500)),
              ),
              const SizedBox(width: 3),
              Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : AppColors.border,
                      width: 1.5),
                  color: selected
                      ? AppColors.primary
                      : Colors.transparent,
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        size: 8, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Priority dropdown ──────────────────────────────────────────────────────
  Widget _buildPriorityDropdown() {
    Color priorityColor(String p) {
      switch (p) {
        case 'high':   return const Color(0xFFD32F2F);
        case 'medium': return const Color(0xFFE65100);
        default:       return const Color(0xFF2E7D32);
      }
    }

    Color priorityBg(String p) {
      switch (p) {
        case 'high':   return const Color(0xFFFFF1F1);
        case 'medium': return const Color(0xFFFFF3E0);
        default:       return const Color(0xFFE8F5E9);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value:        _priority,
          isExpanded:   true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.iconDefault),
          items: _priorities.map((p) {
            final clr = priorityColor(p);
            final bg  = priorityBg(p);
            return DropdownMenuItem(
              value: p,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:        bg,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                          color: clr.withOpacity(0.3), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag_outlined,
                            size: 12, color: clr),
                        const SizedBox(width: 4),
                        Text(
                          '${p[0].toUpperCase()}${p.substring(1)}',
                          style: TextStyle(
                              color:      clr,
                              fontSize:   13,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _priority = v);
          },
        ),
      ),
    );
  }

  // ── Search field (autocomplete) ────────────────────────────────────────────
  Widget _buildSearchField({
    required TextEditingController controller,
    required FocusNode             focusNode,
    required String                hint,
    required IconData              icon,
    required ValueChanged<String>  onChanged,
    required bool                  isSelected,
    required VoidCallback          onClear,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: isSelected
          ? BoxDecoration(
              color:        AppColors.successBg,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: AppColors.success.withOpacity(0.5),
                  width: 1.4),
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
          suffixIcon: isSelected
              ? GestureDetector(
                  onTap: () {
                    onClear();
                    controller.clear();
                  },
                  child: const Icon(Icons.check_circle_rounded,
                      size: 18, color: AppColors.success),
                )
              : null,
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
    FocusNode? nextFocus,
    TextInputType keyboardType = TextInputType.text,
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

  // ── Multi-line notes field ─────────────────────────────────────────────────
  Widget _buildMultilineField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: _notesFocus.hasFocus
          ? AppDecorations.inputFocused
          : AppDecorations.inputIdle,
      child: TextField(
        controller:      _notesCtrl,
        focusNode:       _notesFocus,
        maxLines:        4,
        minLines:        4,
        cursorColor:     AppColors.primary,
        textInputAction: TextInputAction.newline,
        style: const TextStyle(
            color:      AppColors.textPrimary,
            fontSize:   14,
            fontWeight: FontWeight.w400),
        decoration: const InputDecoration(
          hintText:  'Enter notes…',
          hintStyle: TextStyle(
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