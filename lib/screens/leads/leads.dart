import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService, kTokenKey;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/screens/login.dart' show kTokenKey;
import 'package:coremicron_crm_app/screens/home.dart';
import 'package:coremicron_crm_app/common/pagination.dart';
import 'package:coremicron_crm_app/screens/leads/lead_view.dart';
import 'package:coremicron_crm_app/screens/leads/new_lead.dart';
import 'package:coremicron_crm_app/screens/leads/bulk_add.dart';
import 'package:coremicron_crm_app/screens/Registation/customer/contact_list.dart';
import 'package:coremicron_crm_app/common/string_extensions.dart';

// ── Lead Model ─────────────────────────────────────────────────────────────
class Lead {
  final String       enquiryId;
  final String       title;
  final String       enquiryNumber;
  final String       enquiry;
  final String       customerId;
  final String       assignId;
  final String       addedDate;
  final String       addedTime;
  final String       status;
  final String       customerName;
  final String       customerPhone;
  final String       assignedEmployees;
  final List<String> assignedEmployeeIds;
  final String       dealName;
  final String       dealColor;
  final List<Map<String, dynamic>>? assignedEmployeesList;

  const Lead({
    required this.enquiryId,
    required this.title,
    required this.enquiryNumber,
    required this.enquiry,
    required this.customerId,
    required this.assignId,
    required this.addedDate,
    required this.addedTime,
    required this.status,
    required this.customerName,
    required this.customerPhone,
    required this.assignedEmployees,
    required this.assignedEmployeeIds,
    required this.dealName,
    required this.dealColor,
    this.assignedEmployeesList,
  });

  factory Lead.fromJson(Map<String, dynamic> json) {
    final rawIds = json['assigned_employee_ids'];
    final List<String> empIds = rawIds is List
        ? rawIds.map((e) => e.toString()).toList()
        : [];

    final String empNamesStr = json['assigned_employees'] ?? '';
    final List<String> empNames = empNamesStr.isNotEmpty
        ? empNamesStr.split(',').map((e) => e.trim()).toList()
        : [];

    final List<Map<String, dynamic>> empList = [];
    for (int i = 0; i < empIds.length; i++) {
      empList.add({
        'id':          empIds[i],
        'name':        i < empNames.length ? empNames[i] : '',
        'phone':       '',
        'employee_id': '',
      });
    }

    return Lead(
      enquiryId:            json['enquiry_id']      ?? '',
      title:                json['title']            ?? '',
      enquiryNumber:        json['enquiry_number']   ?? '',
      enquiry:              json['enquiry']          ?? '',
      customerId:           json['customer_id']      ?? '',
      assignId:             json['added_id']         ?? '',
      addedDate:            json['added_date']       ?? '',
      addedTime:            json['added_time']       ?? '',
      status:               json['status']           ?? '',
      customerName:         json['customer_name']    ?? '',
      customerPhone:        json['customer_phone']   ?? '',
      assignedEmployees:    empNamesStr,
      assignedEmployeeIds:  empIds,
      dealName:             json['deal_name']        ?? '',
      dealColor:            json['deal_color']       ?? '',
      assignedEmployeesList: empList,
    );
  }
}

// ── Leads Page ─────────────────────────────────────────────────────────────
class LeadsPage extends StatefulWidget {
  final String  username;
  final String? highlightId;
  const LeadsPage({super.key, required this.username, this.highlightId});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  static const int _pageSize = 50;

  List<Lead> _allLeads  = [];
  List<Lead> _filtered  = [];
  bool       _isLoading = true;
  String?    _errorMessage;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int    _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _fetchLeads();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchCtrl.text.trim().toLowerCase();
      _currentPage = 1;
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filtered = List.from(_allLeads);
    } else {
      _filtered = _allLeads.where((l) {
        return l.enquiryNumber.toLowerCase().contains(_searchQuery) ||
            l.title.toLowerCase().contains(_searchQuery)            ||
            l.customerName.toLowerCase().contains(_searchQuery)     ||
            l.customerPhone.toLowerCase().contains(_searchQuery)    ||
            l.addedDate.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchLeads() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final url      = Uri.parse('${ApiService.baseUrl}/api/leads/list.php');
      final response = await ApiService.get(url)
          .timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = jsonDecode(response.body);
      debugPrint('📥  [LEADS LIST] ${response.statusCode}  ${response.body}');

      if (response.statusCode == 200 && data['success'] == true) {
        final List list = data['enquiries'] ?? [];
        _allLeads = list.map((e) => Lead.fromJson(e)).toList();
        _applyFilter();
      } else {
        _errorMessage =
            data['error'] ?? data['message'] ?? 'Failed to load leads.';
      }
    } on http.ClientException {
      _errorMessage = 'Unable to reach the server. Check your connection.';
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  Future<void> _deleteLead(String enquiryId) async {
    try {
      final url  = Uri.parse('${ApiService.baseUrl}/api/leads/delete.php');
      final body = {'enquiry_id': enquiryId};

      final response = await ApiService.post(url, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final Map<String, dynamic> data = jsonDecode(response.body);
      debugPrint('📥  [DELETE LEAD] ${response.statusCode}  ${response.body}');

      if (response.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Lead deleted successfully.');
        _fetchLeads();
      } else {
        AppSnackBar.show(
            context,
            data['error'] ?? data['message'] ?? 'Failed to delete.',
            isError: true);
      }
    } on http.ClientException {
      if (mounted)
        AppSnackBar.show(context, 'Unable to reach the server.',
            isError: true);
    } catch (_) {
      if (mounted)
        AppSnackBar.show(context, 'Something went wrong.', isError: true);
    }
  }

  // ── Pagination ─────────────────────────────────────────────────────────────
  int get _totalPages =>
      paginationTotalPages(_filtered.length, _pageSize);
  List<Lead> get _pageItems =>
      paginationPageItems(_filtered, _currentPage, _pageSize);

  void _goBackToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            HomePage(username: widget.username, openDrawerOnLoad: true),
      ),
      (route) => false,
    );
  }

  // ── Assigned employees popup ───────────────────────────────────────────────
  void _showAssignedEmployeesPopup(
      BuildContext context, String assignedEmployees) {
    final names = assignedEmployees
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color:        AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.people_alt_rounded,
                        size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Assigned Employees',
                        style: TextStyle(
                            color:      AppColors.textPrimary,
                            fontSize:   15,
                            fontWeight: FontWeight.w700)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color:        AppColors.background,
                        borderRadius: BorderRadius.circular(7),
                        border:
                            Border.all(color: AppColors.border, width: 1),
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 15, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.borderLight),
              const SizedBox(height: 14),

              // ── Employee list ────────────────────────────────────────────
              if (names.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No employees assigned.',
                    style: TextStyle(
                        color:     AppColors.textMuted,
                        fontSize:  13,
                        fontStyle: FontStyle.italic),
                  ),
                )
              else
                ...names.asMap().entries.map((entry) {
                  final index = entry.key;
                  final name  = entry.value;
                  final List<Color> avatarColors = [
                    const Color(0xFF1558E7),
                    const Color(0xFF0277BD),
                    const Color(0xFF2E7D32),
                    const Color(0xFF6A1B9A),
                    const Color(0xFFC62828),
                    const Color(0xFFE65100),
                  ];
                  final color = avatarColors[
                      (name.isNotEmpty ? name.codeUnitAt(0) : 0) %
                          avatarColors.length];
                  return Padding(
                    padding: EdgeInsets.only(
                        bottom: index < names.length - 1 ? 12 : 0),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color:  color.withOpacity(0.12),
                            shape:  BoxShape.circle,
                            border: Border.all(
                                color: color.withOpacity(0.25),
                                width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              name.isNotEmpty
                                  ? name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                  color:      color,
                                  fontSize:   14,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name.capitalize(),
                            style: const TextStyle(
                                color:      AppColors.textPrimary,
                                fontSize:   13.5,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  // ── Delete dialog ──────────────────────────────────────────────────────────
  void _showDeleteDialog(Lead l) {
    bool isDeleting = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color:        const Color(0xFFFFF1F1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.error, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Delete Lead',
                          style: TextStyle(
                              color:      AppColors.textPrimary,
                              fontSize:   15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Are you sure you want to delete this lead?',
                  style: TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 13.5,
                      height:   1.5),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 12),
                _deleteDialogRow(
                    Icons.tag_rounded, 'Lead No', l.enquiryNumber),
                const SizedBox(height: 8),
                _deleteDialogRow(Icons.person_outline_rounded,
                    'Customer', l.customerName.capitalize()),
                const SizedBox(height: 8),
                _deleteDialogRow(
                    Icons.phone_outlined, 'Phone', l.customerPhone),
                const SizedBox(height: 8),
                _deleteDialogRow(
                    Icons.title_rounded,
                    'Title',
                    l.title.isEmpty
                        ? '(No title)'
                        : l.title.capitalize()),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isDeleting
                            ? null
                            : () => Navigator.pop(dialogCtx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.border, width: 1.3),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11)),
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 13),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(
                                color:      AppColors.textLabel,
                                fontWeight: FontWeight.w600,
                                fontSize:   14)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isDeleting
                            ? null
                            : () async {
                                setS(() => isDeleting = true);
                                Navigator.pop(dialogCtx);
                                await _deleteLead(l.enquiryId);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          disabledBackgroundColor:
                              AppColors.error.withOpacity(0.5),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11)),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: isDeleting
                              ? const SizedBox(
                                  key:    ValueKey('del-loader'),
                                  width:  18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      color:       Colors.white,
                                      strokeWidth: 2.3))
                              : const Text('Delete',
                                  key: ValueKey('del-label'),
                                  style: TextStyle(
                                      color:      Colors.white,
                                      fontWeight: FontWeight.w600,
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
      ),
    );
  }

  Widget _deleteDialogRow(
      IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(label,
              style: const TextStyle(
                  color:      AppColors.textMuted,
                  fontSize:   12.5,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(
                color:      AppColors.textPrimary,
                fontSize:   13,
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
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

            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 0),
              child: _buildSearchBar(),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 0),
              child: Row(
                children: [
                  if (!_isLoading)
                    Text(
                      '${_filtered.length} lead'
                      '${_filtered.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color:      AppColors.textSecondary,
                          fontSize:   12.5,
                          fontWeight: FontWeight.w500),
                    ),
                  const Spacer(),
                  _actionButton(
                    icon:  Icons.add_rounded,
                    label: 'New Lead',
                    color: AppColors.primary,
                    onTap: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              NewLeadPage(username: widget.username),
                        ),
                      );
                      if (result == true) _fetchLeads();
                    },
                  ),
                  const SizedBox(width: 8),
                  _actionButton(
                    icon:  Icons.upload_file_rounded,
                    label: 'Bulk Add',
                    color: const Color(0xFF2E7D32),
                    onTap: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              BulkAddPage(username: widget.username),
                        ),
                      );
                      if (result == true) _fetchLeads();
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: _isLoading
                  ? _buildSkeletonList(hPad)
                  : _errorMessage != null
                      ? _buildError()
                      : _filtered.isEmpty
                          ? _buildEmpty()
                          : _buildLeadList(hPad),
            ),

            if (!_isLoading &&
                _errorMessage == null &&
                _filtered.isNotEmpty)
              AppPagination(
                currentPage:       _currentPage,
                totalPages:        _totalPages,
                horizontalPadding: hPad,
                onPageChanged:
                    (page) => setState(() => _currentPage = page),
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
            onTap: _goBackToHome,
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
          Text('Leads',
              style: TextStyle(
                  color:         AppColors.textPrimary,
                  fontSize:      isTablet ? 20 : 17,
                  fontWeight:    FontWeight.w800,
                  letterSpacing: -0.3)),
          const Spacer(),
          GestureDetector(
            onTap: _fetchLeads,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color:        AppColors.background,
                borderRadius: BorderRadius.circular(9),
                border:
                    Border.all(color: AppColors.border, width: 1.2),
              ),
              child: const Icon(Icons.refresh_rounded,
                  size: 18, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset:     const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller:  _searchCtrl,
        style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 14),
        cursorColor: AppColors.primary,
        decoration: const InputDecoration(
          hintText:  'Search by number, title, customer, phone…',
          hintStyle: TextStyle(
              color: AppColors.textHint, fontSize: 12.5),
          prefixIcon: Icon(Icons.search_rounded,
              color: AppColors.iconDefault, size: 19),
          border:         InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  // ── Action button ──────────────────────────────────────────────────────────
  Widget _actionButton({
    required IconData     icon,
    required String       label,
    required Color        color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon:  Icon(icon, size: 15, color: Colors.white),
      label: Text(label,
          style: const TextStyle(
              color:      Colors.white,
              fontWeight: FontWeight.w600,
              fontSize:   12.5)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
            horizontal: 11, vertical: 9),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9)),
      ),
    );
  }

  // ── Lead list ──────────────────────────────────────────────────────────────
  Widget _buildLeadList(double hPad) {
    final items = _pageItems;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _leadCard(items[i]),
    );
  }

  // ── Lead card ──────────────────────────────────────────────────────────────
  Widget _leadCard(Lead l) {
    final bool isHighlighted = widget.highlightId == l.enquiryId;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted
              ? AppColors.primary
              : AppColors.borderLight,
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset:     const Offset(0, 2)),
        ],
      ),
      child: Stack(
        children: [
          if (isHighlighted)
            Positioned(
              top: 0, left: 0,
              child: Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Row 1: date + enquiry number (deal badge removed) ──────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 11, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(l.addedDate,
                          style: const TextStyle(
                              color:    AppColors.textMuted,
                              fontSize: 11)),
                    ],
                  ),
                  // ── Enquiry number badge only ──────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:        AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(l.enquiryNumber,
                        style: const TextStyle(
                            color:      AppColors.primary,
                            fontSize:   11,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // ── Row 2: title ───────────────────────────────────────────
              Text(
                l.title.isEmpty ? '(No title)' : l.title.capitalize(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:      l.title.isEmpty
                      ? AppColors.textMuted
                      : AppColors.textPrimary,
                  fontSize:   13.5,
                  fontWeight: FontWeight.w600,
                  fontStyle:  l.title.isEmpty
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),

              const SizedBox(height: 5),

              // ── Row 3: customer + phone ────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 11, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ContactListPage(
                            customerId:   l.customerId,
                            customerName: l.customerName,
                            readOnly:     true,
                          ),
                        ),
                      ),
                      child: Text(
                        l.customerName.capitalize(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color:      AppColors.primary,
                            fontSize:   12,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.phone_outlined,
                      size: 11, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text(l.customerPhone,
                      style: const TextStyle(
                          color:    AppColors.textSecondary,
                          fontSize: 12)),
                ],
              ),

              // ── Row 4: Assign To tap button ────────────────────────────
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _showAssignedEmployeesPopup(
                    context, l.assignedEmployees),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.badge_outlined,
                        size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    const Text(
                      'Assign To',
                      style: TextStyle(
                          color:      AppColors.primary,
                          fontSize:   12,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 3),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 10, color: AppColors.primary),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              const Divider(height: 1, color: AppColors.borderLight),
              const SizedBox(height: 7),

              // ── Action icons ───────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _actionIcon(
                    icon:    Icons.visibility_outlined,
                    color:   const Color(0xFF2E7D32),
                    bgColor: const Color(0xFFE8F5E9),
                    onTap:   () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LeadViewPage(
                          enquiryId:     l.enquiryId,
                          enquiryNumber: l.enquiryNumber,
                          dealName:      l.dealName,
                          dealColor:     l.dealColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _actionIcon(
                    icon:    Icons.edit_outlined,
                    color:   AppColors.primary,
                    bgColor: AppColors.primaryLight,
                    onTap:   () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NewLeadPage(
                              username: widget.username, lead: l),
                        ),
                      );
                      if (result == true) _fetchLeads();
                    },
                  ),
                  const SizedBox(width: 6),
                  _actionIcon(
                    icon:    Icons.delete_outline_rounded,
                    color:   AppColors.error,
                    bgColor: const Color(0xFFFFF1F1),
                    onTap:   () => _showDeleteDialog(l),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionIcon({
    required IconData     icon,
    required Color        color,
    required Color        bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
            color:        bgColor,
            borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }

  // ── Skeleton ───────────────────────────────────────────────────────────────
  Widget _buildSkeletonList(double hPad) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => _skeletonCard(),
    );
  }

  Widget _skeletonCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _shimmer(width: 70,  height: 11, radius: 4),
              _shimmer(width: 40,  height: 20, radius: 6),
            ],
          ),
          const SizedBox(height: 8),
          _shimmer(width: 160,             height: 13, radius: 4),
          const SizedBox(height: 6),
          _shimmer(width: double.infinity, height: 11, radius: 4),
          const SizedBox(height: 6),
          _shimmer(width: 80,              height: 11, radius: 4),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _shimmer(width: 30, height: 30, radius: 7),
              const SizedBox(width: 6),
              _shimmer(width: 30, height: 30, radius: 7),
              const SizedBox(width: 6),
              _shimmer(width: 30, height: 30, radius: 7),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shimmer({
    required double width,
    required double height,
    required double radius,
  }) =>
      _ShimmerBox(width: width, height: height, radius: radius);

  // ── Empty ──────────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.format_list_bulleted_rounded,
              size: 56, color: AppColors.border),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No leads found',
            style: const TextStyle(
                color:      AppColors.textSecondary,
                fontSize:   14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Tap "New Lead" to get started',
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 12.5),
          ),
        ],
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
            onPressed: _fetchLeads,
            icon: const Icon(Icons.refresh_rounded,
                size: 16, color: Colors.white),
            label: const Text('Retry',
                style: TextStyle(
                    color:      Colors.white,
                    fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
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

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
  });

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
        vsync:    this,
        duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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