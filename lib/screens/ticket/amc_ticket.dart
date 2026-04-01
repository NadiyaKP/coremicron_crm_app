import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService, kTokenKey;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/screens/ticket/tickets.dart' show Ticket;
import 'package:coremicron_crm_app/common/string_extensions.dart';

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

class AmcSchedule {
  String serviceTitle;
  DateTime scheduledDate;
  final TextEditingController titleCtrl;
  final TextEditingController dateCtrl;
  final TextEditingController employeeNameCtrl;
  final TextEditingController employeeIdCtrl;

  AmcSchedule({
    required this.serviceTitle,
    required this.scheduledDate,
  })  : titleCtrl = TextEditingController(text: serviceTitle),
        dateCtrl = TextEditingController(
          text: '${scheduledDate.day.toString().padLeft(2, '0')}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.year}',
        ),
        employeeNameCtrl = TextEditingController(),
        employeeIdCtrl = TextEditingController();

  void dispose() {
    titleCtrl.dispose();
    dateCtrl.dispose();
    employeeNameCtrl.dispose();
    employeeIdCtrl.dispose();
  }

  Map<String, String> toJson() => {
        'service_title': titleCtrl.text.trim(),
        'scheduled_date':
            '${scheduledDate.year}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}',
        'employee_id': employeeIdCtrl.text.trim(),
        'employee_name': employeeNameCtrl.text.trim(),
      };
}

class AmcTicketPage extends StatefulWidget {
  final String username;
  final Ticket? ticket;
  const AmcTicketPage({super.key, required this.username, this.ticket});

  @override
  State<AmcTicketPage> createState() => _AmcTicketPageState();
}

class _AmcTicketPageState extends State<AmcTicketPage> {
  bool get _isEdit => widget.ticket != null;

  final _titleCtrl = TextEditingController();
  final _customerCtrl = TextEditingController();
  final _employeeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final _titleFocus = FocusNode();
  final _customerFocus = FocusNode();
  final _employeeFocus = FocusNode();
  final _notesFocus = FocusNode();

  _Customer? _selectedCustomer;
  _Employee? _selectedEmployee;
  List<_Customer> _allCustomers = [];
  List<_Customer> _customerSuggestions = [];
  bool _customersLoaded = false;
  Timer? _customerDebounce;

  List<_Employee> _allEmployees = [];
  List<_Employee> _employeeSuggestions = [];
  bool _employeesLoaded = false;
  Timer? _employeeDebounce;

  final _customerLayerLink = LayerLink();
  final _employeeLayerLink = LayerLink();
  OverlayEntry? _customerOverlay;
  OverlayEntry? _employeeOverlay;

  // Scheduling
  int _selectedInterval = 1; // Months
  DateTime? _startDate;
  final _startDateCtrl = TextEditingController();
  List<AmcSchedule> _schedules = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(() => setState(() {}));
    _customerFocus.addListener(() => setState(() {}));
    _employeeFocus.addListener(() => setState(() {}));
    _notesFocus.addListener(() => setState(() {}));
    _customerFocus.addListener(_onCustomerFocusChange);
    _employeeFocus.addListener(_onEmployeeFocusChange);

    if (_isEdit) _preFill();
  }

  void _preFill() {
    final t = widget.ticket!;
    _titleCtrl.text = t.title;
    _notesCtrl.text = t.notes;
    _selectedCustomer = _Customer(id: t.customerId, name: t.customerName, phone: t.phoneNumber);
    _customerCtrl.text = t.customerName.capitalize();
  }

  @override
  void dispose() {
    _removeCustomerOverlay();
    _removeEmployeeOverlay();
    _customerDebounce?.cancel();
    _employeeDebounce?.cancel();
    _titleCtrl.dispose();
    _customerCtrl.dispose();
    _employeeCtrl.dispose();
    _notesCtrl.dispose();
    _startDateCtrl.dispose();
    _titleFocus.dispose();
    _customerFocus.dispose();
    _employeeFocus.dispose();
    _notesFocus.dispose();
    for (var s in _schedules) {
      s.dispose();
    }
    super.dispose();
  }

  void _onCustomerFocusChange() {
    if (!_customerFocus.hasFocus) {
      Future.delayed(const Duration(milliseconds: 150), _removeCustomerOverlay);
    }
  }

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
                  id: e['id'] ?? '',
                  name: e['customer_name'] ?? '',
                  phone: e['phone_number'] ?? '',
                ))
            .toList();
        _customersLoaded = true;
      }
    } catch (_) {}
  }

  void _onCustomerChanged(String query) {
    _selectedCustomer = null;
    _customerDebounce?.cancel();
    _customerDebounce = Timer(const Duration(milliseconds: 250), () async {
      await _loadCustomers();
      final q = query.trim().toLowerCase();
      if (q.isEmpty) {
        _removeCustomerOverlay();
        return;
      }
      _customerSuggestions = _allCustomers
          .where((c) => c.name.toLowerCase().contains(q) || c.phone.contains(q))
          .toList();
      if (_customerSuggestions.isNotEmpty) {
        _showCustomerDropdown();
      } else {
        _removeCustomerOverlay();
      }
    });
  }

  void _showCustomerDropdown() {
    _removeCustomerOverlay();
    _customerOverlay = _buildOverlayGeneric(
      link: _customerLayerLink,
      suggestions: _customerSuggestions,
      tileBuilder: (c) => _customerTile(c as _Customer),
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
  }

  Widget _customerTile(_Customer c) {
    return InkWell(
      onTap: () => _selectCustomer(c),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                  style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700),
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
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(c.phone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onEmployeeFocusChange() {
    if (!_employeeFocus.hasFocus) {
      Future.delayed(const Duration(milliseconds: 150), _removeEmployeeOverlay);
    }
  }

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
                  id: e['id'] ?? '',
                  name: e['employee_name'] ?? '',
                  phone: e['phone_number'] ?? '',
                  employeeId: e['employee_id'] ?? '',
                ))
            .toList();
        _employeesLoaded = true;
      }
    } catch (_) {}
  }

  void _onEmployeeChanged(String query) {
    _selectedEmployee = null;
    _employeeDebounce?.cancel();
    _employeeDebounce = Timer(const Duration(milliseconds: 250), () async {
      await _loadEmployees();
      final q = query.trim().toLowerCase();
      if (q.isEmpty) {
        _removeEmployeeOverlay();
        return;
      }
      _employeeSuggestions = _allEmployees
          .where((e) =>
              e.name.toLowerCase().contains(q) || e.phone.contains(q) || e.employeeId.toLowerCase().contains(q))
          .toList();
      if (_employeeSuggestions.isNotEmpty) {
        _showEmployeeDropdown();
      } else {
        _removeEmployeeOverlay();
      }
    });
  }

  void _showEmployeeDropdown() {
    _removeEmployeeOverlay();
    _employeeOverlay = _buildOverlayGeneric(
      link: _employeeLayerLink,
      suggestions: _employeeSuggestions,
      tileBuilder: (e) => _employeeTile(e as _Employee),
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
  }

  OverlayEntry _buildOverlayGeneric({
    required LayerLink link,
    required List<dynamic> suggestions,
    required Widget Function(dynamic) tileBuilder,
  }) {
    return OverlayEntry(
      builder: (_) => Positioned(
        width: link.leaderSize?.width ?? 300,
        child: CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false,
          offset: Offset(0, (link.leaderSize?.height ?? 48) + 4),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: suggestions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderLight),
                  itemBuilder: (_, i) => tileBuilder(suggestions[i]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _employeeTile(_Employee e) {
    return InkWell(
      onTap: () => _selectEmployee(e),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  e.name.isNotEmpty ? e.name[0].toUpperCase() : 'E',
                  style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700),
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
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('ID: ${e.employeeId} · ${e.phone}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _generateSchedules() {
    if (_startDate == null) {
      AppSnackBar.show(context, 'Please select a start date.', isError: true);
      return;
    }
    setState(() {
      for (var s in _schedules) {
        s.dispose();
      }
      _schedules.clear();
      int rowCount = 12 ~/ _selectedInterval;
      for (int i = 0; i < rowCount; i++) {
        DateTime date = DateTime(_startDate!.year, _startDate!.month + (i * _selectedInterval), _startDate!.day);
        String ordinal = (i + 1 == 1) ? 'st' : (i + 1 == 2) ? 'nd' : (i + 1 == 3) ? 'rd' : 'th';
        String title = '${i + 1}$ordinal Service';
        _schedules.add(AmcSchedule(serviceTitle: title, scheduledDate: date));
      }
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _startDateCtrl.text = '${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}';
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedCustomer == null) {
      AppSnackBar.show(context, 'Please select a customer.', isError: true);
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      AppSnackBar.show(context, 'Please enter a title.', isError: true);
      return;
    }
    if (!_isEdit && _schedules.isEmpty) {
      AppSnackBar.show(context, 'Please generate schedules.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final url = Uri.parse(_isEdit
          ? '${ApiService.baseUrl}/api/ticket/update.php'
          : '${ApiService.baseUrl}/api/ticket/create.php');
      final body = {
        if (_isEdit) 'ticket_id': widget.ticket!.ticketId,
        'customer_id': _selectedCustomer!.id,
        'type': 'AMC',
        'title': _titleCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
        if (!_isEdit) ...{
          'task_handler_id': _selectedEmployee?.id ?? '',
          'priority': 'low',
          'schedules': _schedules.map((s) => s.toJson()).toList(),
        }
      };

      debugPrint('--- AMC API Call Request ---');
      debugPrint('Mode: ${_isEdit ? 'Update' : 'Create'}');
      debugPrint('URL: $url');
      debugPrint('Body: ${jsonEncode(body)}');
      debugPrint('-----------------------------');

      final res = await ApiService.post(url, body: jsonEncode(body)).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      debugPrint('--- AMC API Call Response ---');
      debugPrint('Status Code: ${res.statusCode}');
      debugPrint('Response Body: ${res.body}');
      debugPrint('------------------------------');

      if (res.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(null, _isEdit ? 'AMC Ticket updated successfully.' : 'AMC Ticket created successfully.');
        Navigator.pop(context, true);
      } else {
        AppSnackBar.show(context, data['message'] ?? 'Failed to ${_isEdit ? 'update' : 'create'} AMC ticket.', isError: true);
      }
    } catch (_) {
      AppSnackBar.show(context, 'Something went wrong.', isError: true);
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final hPad = isTablet ? size.width * 0.06 : 16.0;

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
                    _fieldLabel('Title', required: true),
                    const SizedBox(height: 8),
                    _buildTextField(controller: _titleCtrl, focusNode: _titleFocus, hint: 'Enter ticket title'),
                    const SizedBox(height: 16),
                    _fieldLabel('Customer Name', required: true),
                    const SizedBox(height: 8),
                    CompositedTransformTarget(
                      link: _customerLayerLink,
                      child: _buildSearchField(
                        controller: _customerCtrl,
                        focusNode: _customerFocus,
                        hint: 'Search customer...',
                        onChanged: _onCustomerChanged,
                        isSelected: _selectedCustomer != null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_isEdit) ...[
                      const Divider(color: AppColors.borderLight),
                      const SizedBox(height: 16),
                      const Text('SCHEDULE',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _fieldLabel('Interval'),
                                const SizedBox(height: 8),
                                _buildIntervalDropdown(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _fieldLabel('Start Date'),
                                const SizedBox(height: 8),
                                _buildDatePickerField(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _generateSchedules,
                          icon: const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
                          label: const Text('Generate Schedules', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                    if (!_isEdit && _schedules.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _schedules.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _buildScheduleRow(_schedules[i], i),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Divider(color: AppColors.borderLight),
                    const SizedBox(height: 16),
                    _fieldLabel('Notes'),
                    const SizedBox(height: 8),
                    _buildMultilineField(),
                    const SizedBox(height: 32),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          const Text('New AMC Ticket', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label, {bool required = false}) {
    return Row(
      children: [
        Text(label.toUpperCase(), style: AppTextStyles.fieldLabel(false)),
        if (required) ...[
          const SizedBox(width: 2),
          const Text(' *',
              style: TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ],
      ],
    );
  }

  Widget _buildTextField({required TextEditingController controller, required FocusNode focusNode, required String hint}) {
    return Container(
      decoration: focusNode.hasFocus ? AppDecorations.inputFocused : AppDecorations.inputIdle,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        cursorColor: AppColors.primary,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13.5),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSearchField(
      {required TextEditingController controller,
      required FocusNode focusNode,
      required String hint,
      required Function(String) onChanged,
      required bool isSelected,
      IconData icon = Icons.person_search_rounded}) {
    return Container(
      decoration: focusNode.hasFocus ? AppDecorations.inputFocused : AppDecorations.inputIdle,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        cursorColor: AppColors.primary,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13.5),
          prefixIcon: Icon(icon, size: 18, color: focusNode.hasFocus ? AppColors.primary : AppColors.iconDefault),
          suffixIcon: isSelected ? const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildIntervalDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: AppDecorations.inputIdle,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedInterval,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.iconDefault),
          items: List.generate(12, (index) => index + 1).map((i) {
            return DropdownMenuItem<int>(
              value: i,
              child: Text('$i Month${i > 1 ? 's' : ''}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5)),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedInterval = v!),
        ),
      ),
    );
  }

  Widget _buildDatePickerField() {
    return GestureDetector(
      onTap: _pickStartDate,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: AppDecorations.inputIdle,
        child: Row(
          children: [
            Expanded(
              child: Text(_startDateCtrl.text.isEmpty ? 'Select Date' : _startDateCtrl.text,
                  style: TextStyle(color: _startDateCtrl.text.isEmpty ? AppColors.textHint : AppColors.textPrimary, fontSize: 13.5)),
            ),
            const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.iconDefault),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleRow(AmcSchedule s, int index) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: s.titleCtrl,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: 'Service Title'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)),
              child: Text(s.dateCtrl.text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultilineField() {
    return Container(
      decoration: _notesFocus.hasFocus ? AppDecorations.inputFocused : AppDecorations.inputIdle,
      child: TextField(
        controller: _notesCtrl,
        focusNode: _notesFocus,
        maxLines: 4,
        cursorColor: AppColors.primary,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
        decoration: const InputDecoration(
          hintText: 'Enter any additional notes...',
          hintStyle: TextStyle(color: AppColors.textHint, fontSize: 13),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border, width: 1.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textLabel, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            ),
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_isEdit ? 'Update' : 'Save', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
