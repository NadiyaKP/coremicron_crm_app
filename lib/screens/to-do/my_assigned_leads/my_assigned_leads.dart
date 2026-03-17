import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../common/api_service.dart';
import '../../../common/theme.dart';
import '../../login.dart' show kSessionKey;
import '../../home.dart';
import '../../../common/pagination.dart';
import '../../../common/string_extensions.dart';
import '../my_assigned_leads/assigned_lead_view.dart';
import '../my_assigned_leads/assign_lead_followups.dart';
import 'reassign_lead.dart';

// ── Assigned Lead Model ────────────────────────────────────────────────────
class AssignedLead {
  final String enquiryId;
  final String title;
  final String enquiryNumber;
  final String enquiry;
  final String customerId;
  final String assignId;
  final String addedDate;
  final String addedTime;
  final String status;
  final String customerName;
  final String customerPhone;
  final String employeeName;
  final String dealName;
  final String dealColor;

  const AssignedLead({
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
    required this.employeeName,
    required this.dealName,
    required this.dealColor,
  });

  factory AssignedLead.fromJson(Map<String, dynamic> json) => AssignedLead(
        enquiryId:     json['enquiry_id']     ?? '',
        title:         json['title']          ?? '',
        enquiryNumber: json['enquiry_number'] ?? '',
        enquiry:       json['enquiry']        ?? '',
        customerId:    json['customer_id']    ?? '',
        assignId:      json['assign_id']      ?? '',
        addedDate:     json['added_date']     ?? '',
        addedTime:     json['added_time']     ?? '',
        status:        json['status']         ?? '',
        customerName:  json['customer_name']  ?? '',
        customerPhone: json['customer_phone'] ?? '',
        employeeName:  json['employee_name']  ?? '',
        dealName:      json['deal_name']      ?? '',
        dealColor:     json['deal_color']     ?? '',
      );
}

// ── My Assigned Leads Page ─────────────────────────────────────────────────
class MyAssignedLeadsPage extends StatefulWidget {
  final String username;
  const MyAssignedLeadsPage({super.key, required this.username});

  @override
  State<MyAssignedLeadsPage> createState() => _MyAssignedLeadsPageState();
}

class _MyAssignedLeadsPageState extends State<MyAssignedLeadsPage> {
  static const int _pageSize = 50;

  List<AssignedLead> _allLeads  = [];
  List<AssignedLead> _filtered  = [];
  bool               _isLoading = true;
  String?            _errorMessage;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int    _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _fetchAssignedLeads();
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
            l.title.toLowerCase().contains(_searchQuery) ||
            l.customerName.toLowerCase().contains(_searchQuery) ||
            l.customerPhone.toLowerCase().contains(_searchQuery) ||
            l.addedDate.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchAssignedLeads() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/leads/list.php?mode=my_assigned');

      debugPrint('─────────────────────────────────────────');
      debugPrint('📤  [MY ASSIGNED LEADS] Request  URL : $url');
      debugPrint('─────────────────────────────────────────');

      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Accept':       'application/json',
        'X-Session-ID': sessionId,
        'Cookie':       'PHPSESSID=$sessionId',
      }).timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = jsonDecode(response.body);
      debugPrint(
          '📥  [MY ASSIGNED LEADS] ${response.statusCode}  ${response.body}');

      if (response.statusCode == 200 && data['success'] == true) {
        final List list = data['enquiries'] ?? [];
        _allLeads = list.map((e) => AssignedLead.fromJson(e)).toList();
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

  // ── Action APIs ────────────────────────────────────────────────────────────
  Future<void> _rejectLead(String enquiryId, String reason) async {
    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url  = Uri.parse('${ApiService.baseUrl}/api/leads/reject.php');
      final body = {
        'enquiry_id': enquiryId,
        'reason':     reason,
      };

      debugPrint('📤  [REJECT LEAD] $url  ${jsonEncode(body)}');

      final response = await http.post(url,
          headers: {
            'Content-Type': 'application/json',
            'Accept':       'application/json',
            'X-Session-ID': sessionId,
            'Cookie':       'PHPSESSID=$sessionId',
          },
          body: jsonEncode(body)).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final Map<String, dynamic> data = jsonDecode(response.body);
      debugPrint(
          '📥  [REJECT LEAD] ${response.statusCode}  ${response.body}');

      if (response.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Lead rejected successfully.');
        _fetchAssignedLeads();
      } else {
        AppSnackBar.show(
            context,
            data['error'] ?? data['message'] ?? 'Failed to reject lead.',
            isError: true);
      }
    } on http.ClientException {
      if (mounted)
        AppSnackBar.show(context, 'Unable to reach the server.',
            isError: true);
    } catch (e) {
      if (mounted)
        AppSnackBar.show(context, 'Error: $e', isError: true);
    }
  }

  // ── Pagination ─────────────────────────────────────────────────────────────
  int get _totalPages =>
      paginationTotalPages(_filtered.length, _pageSize);
  List<AssignedLead> get _pageItems =>
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

  // ── Reject Dialog ──────────────────────────────────────────────────────────
  void _showRejectDialog(AssignedLead l) {
    final reasonCtrl = TextEditingController();
    bool isRejecting = false;
    showDialog(
      context:            context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          content: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color:        const Color(0xFFFFF1F1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: AppColors.error, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Reject Lead',
                          style: TextStyle(
                              color:      AppColors.textPrimary,
                              fontSize:   15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Are you sure you want to reject this lead?\nRejected leads will be removed from your assigned list.',
                  style: TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 13,
                      height:   1.5),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 12),
                _dialogRow(Icons.tag_rounded,
                    'Enquiry No', l.enquiryNumber),
                const SizedBox(height: 7),
                _dialogRow(Icons.person_outline_rounded,
                    'Customer', l.customerName.capitalize()),
                const SizedBox(height: 7),
                _dialogRow(Icons.phone_outlined,
                    'Phone', l.customerPhone),
                const SizedBox(height: 7),
                _dialogRow(Icons.title_rounded, 'Title',
                    l.title.isEmpty ? '(No title)' : l.title.capitalize()),
                const SizedBox(height: 14),
                const Text('Reason *',
                    style: TextStyle(
                        color:      AppColors.textLabel,
                        fontSize:   12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color:        Colors.white,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                        color: AppColors.border, width: 1.2),
                  ),
                  child: TextField(
                    controller:  reasonCtrl,
                    maxLines:    3,
                    minLines:    2,
                    cursorColor: AppColors.primary,
                    style: const TextStyle(
                        color:    AppColors.textPrimary,
                        fontSize: 13.5),
                    decoration: const InputDecoration(
                      hintText:  'Enter reason for rejection…',
                      hintStyle: TextStyle(
                          color:    AppColors.textHint,
                          fontSize: 13),
                      border:         InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isRejecting
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
                        onPressed: isRejecting
                            ? null
                            : () async {
                                if (reasonCtrl.text.trim().isEmpty) {
                                  AppSnackBar.show(
                                      context,
                                      'Please enter a reason.',
                                      isError: true);
                                  return;
                                }
                                setS(() => isRejecting = true);
                                Navigator.pop(dialogCtx);
                                await _rejectLead(
                                    l.enquiryId,
                                    reasonCtrl.text.trim());
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
                          child: isRejecting
                              ? const SizedBox(
                                  key: ValueKey('rej-loader'),
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      color:       Colors.white,
                                      strokeWidth: 2.3))
                              : const Text('Reject',
                                  key: ValueKey('rej-label'),
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

  Widget _dialogRow(IconData icon, String label, String value) {
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
              padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 0),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My Assigned Leads',
                  style: TextStyle(
                      color:         AppColors.textPrimary,
                      fontSize:      isTablet ? 20 : 17,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: -0.3)),
              const Text('Assigned to me',
                  style: TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 11.5)),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _fetchAssignedLeads,
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

  // ── Search Bar ─────────────────────────────────────────────────────────────
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

  // ── Lead List ──────────────────────────────────────────────────────────────
  Widget _buildLeadList(double hPad) {
    final items = _pageItems;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _leadCard(items[i]),
    );
  }

  // ── Lead Card ──────────────────────────────────────────────────────────────
  Widget _leadCard(AssignedLead l) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          // ── Top row: date + enquiry number badge ─────────────────────
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
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  l.enquiryNumber,
                  style: const TextStyle(
                      color:      AppColors.primary,
                      fontSize:   11,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ── Title ────────────────────────────────────────────────────
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

          // ── Customer + phone ──────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 11, color: AppColors.textMuted),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  l.customerName.capitalize(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 12),
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

          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 7),

          // ── Action buttons ────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // View
              _actionIcon(
                icon:    Icons.visibility_outlined,
                color:   const Color(0xFF2E7D32),
                bgColor: const Color(0xFFE8F5E9),
                onTap:   () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AssignLeadViewPage(
                      enquiryId:     l.enquiryId,
                      enquiryNumber: l.enquiryNumber,
                      dealName:      l.dealName,
                      dealColor:     l.dealColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Message
              _actionIcon(
                icon:    Icons.chat_bubble_outline_rounded,
                color:   AppColors.primary,
                bgColor: AppColors.primaryLight,
                onTap:   () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AssignLeadFollowUpPage(
                      enquiryId:     l.enquiryId,
                      enquiryNumber: l.enquiryNumber,
                      title:         l.title,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Reassign (person_add icon)
              _actionIcon(
                icon:    Icons.person_add_outlined,
                color:   const Color(0xFF6A1B9A),
                bgColor: const Color(0xFFF3E5F5),
                onTap:   () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReassignLeadPage(
                        enquiryId:           l.enquiryId,
                        enquiryNumber:       l.enquiryNumber,
                        currentAssigneeName: l.employeeName,
                        title:               l.title,
                      ),
                    ),
                  );
                  if (result == true) _fetchAssignedLeads();
                },
              ),
              const SizedBox(width: 6),
              // Reject
              _actionIcon(
                icon:    Icons.close_rounded,
                color:   AppColors.error,
                bgColor: const Color(0xFFFFF1F1),
                onTap:   () => _showRejectDialog(l),
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
              _shimmer(width: 70, height: 11, radius: 4),
              _shimmer(width: 40, height: 20, radius: 6),
            ],
          ),
          const SizedBox(height: 8),
          _shimmer(width: 160, height: 13, radius: 4),
          const SizedBox(height: 6),
          _shimmer(width: double.infinity, height: 11, radius: 4),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _shimmer(width: 30, height: 30, radius: 7),
              const SizedBox(width: 6),
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
          const Icon(Icons.assignment_outlined,
              size: 56, color: AppColors.border),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No assigned leads found',
            style: const TextStyle(
                color:      AppColors.textSecondary,
                fontSize:   14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Leads assigned to you will appear here',
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
            onPressed: _fetchAssignedLeads,
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

// ── Shimmer Box ────────────────────────────────────────────────────────────
class _ShimmerBox extends StatefulWidget {
  final double width, height, radius;
  const _ShimmerBox(
      {required this.width,
      required this.height,
      required this.radius});

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
  void dispose() { _ctrl.dispose(); super.dispose(); }

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