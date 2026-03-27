import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService, kTokenKey;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/screens/login.dart' show kTokenKey;
import 'package:coremicron_crm_app/screens/home.dart';
import 'package:coremicron_crm_app/common/pagination.dart';
import 'package:coremicron_crm_app/common/string_extensions.dart';
import 'package:coremicron_crm_app/screens/to-do/my_assigned_leads/assigned_lead_view.dart';
import 'package:coremicron_crm_app/screens/to-do/my_assigned_leads/assign_lead_followups.dart';

// ── Follow-Up Model ────────────────────────────────────────────────────────
class _FollowUp {
  final String comId;
  final String enquiryId;
  final String enquiryNumber;
  final String title;
  final String customerName;
  final String phoneNumber;
  final String followUp;
  final String followupStatus;
  final String notes;
  final String dealsId;
  final String addedDate;
  final String dealsName;
  final String dealColor;

  const _FollowUp({
    required this.comId,
    required this.enquiryId,
    required this.enquiryNumber,
    required this.title,
    required this.customerName,
    required this.phoneNumber,
    required this.followUp,
    required this.followupStatus,
    required this.notes,
    required this.dealsId,
    required this.addedDate,
    required this.dealsName,
    required this.dealColor,
  });

  factory _FollowUp.fromJson(Map<String, dynamic> j) => _FollowUp(
        comId:          j['comid']           ?? '',
        enquiryId:      j['enquiry_id']      ?? '',
        enquiryNumber:  j['enquiry_number']  ?? '',
        title:          j['title']           ?? '',
        customerName:   j['customer_name']   ?? '',
        phoneNumber:    j['phone_number']    ?? '',
        followUp:       j['follow_up']       ?? '',
        followupStatus: j['followup_status'] ?? '',
        notes:          j['notes']           ?? '',
        dealsId:        j['deals_id']        ?? '',
        addedDate:      j['added_date']      ?? '',
        dealsName:      j['deals_name']      ?? '',
        dealColor:      j['deal_color']      ?? '',
      );
}

// ── Follow-Ups Page ────────────────────────────────────────────────────────
class FollowUpsPage extends StatefulWidget {
  final String username;
  const FollowUpsPage({super.key, required this.username});

  @override
  State<FollowUpsPage> createState() => _FollowUpsPageState();
}

class _FollowUpsPageState extends State<FollowUpsPage> {
  static const int _pageSize = 50;

  List<_FollowUp> _all      = [];
  List<_FollowUp> _filtered = [];
  bool            _isLoading = true;
  String?         _errorMessage;

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int    _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _fetchFollowUps();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    setState(() {
      _searchQuery = _searchCtrl.text.trim().toLowerCase();
      _currentPage = 1;
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filtered = List.from(_all);
    } else {
      _filtered = _all.where((f) =>
          f.enquiryNumber.toLowerCase().contains(_searchQuery) ||
          f.title.toLowerCase().contains(_searchQuery) ||
          f.customerName.toLowerCase().contains(_searchQuery) ||
          f.phoneNumber.contains(_searchQuery) ||
          f.dealsName.toLowerCase().contains(_searchQuery) ||
          f.followupStatus.toLowerCase().contains(_searchQuery)).toList();
    }
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchFollowUps() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/leads/followup_list.php');

      final res = await ApiService.get(url).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [FOLLOWUPS] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        final list = data['followups'] as List? ?? [];
        _all = list.map((e) => _FollowUp.fromJson(e)).toList();
        _applyFilter();
      } else {
        _errorMessage =
            data['error'] ?? data['message'] ?? 'Failed to load follow-ups.';
      }
    } on http.ClientException {
      _errorMessage = 'Unable to reach the server. Check your connection.';
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Mark complete ──────────────────────────────────────────────────────────
  Future<void> _markComplete(String comId) async {
    try {
      final url  = Uri.parse(
          '${ApiService.baseUrl}/api/leads/followup_complete.php');
      final body = {'comid': comId};

      final res = await ApiService.post(url, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint(
          '📥  [FOLLOWUP COMPLETE] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Follow-up marked as completed.');
        _fetchFollowUps();
      } else {
        AppSnackBar.show(
            context,
            data['error'] ?? data['message'] ?? 'Failed to update.',
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
  List<_FollowUp> get _pageItems =>
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

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return '—';
    try {
      final p = raw.trim().split('-');
      if (p.length == 3) return '${p[2]}-${p[1]}-${p[0]}';
    } catch (_) {}
    return raw;
  }

  Color _dealColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
      return Color(int.parse(clean, radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'completed': return const Color(0xFF2E7D32);
      case 'pending':   return const Color(0xFFE65100);
      default:          return AppColors.primary;
    }
  }

  Color _statusBg(String s) {
    switch (s.toLowerCase()) {
      case 'completed': return const Color(0xFFE8F5E9);
      case 'pending':   return const Color(0xFFFFF3E0);
      default:          return AppColors.primaryLight;
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
                      '${_filtered.length} follow-up'
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
                          : _buildList(hPad),
            ),

            if (!_isLoading &&
                _errorMessage == null &&
                _filtered.isNotEmpty)
              AppPagination(
                currentPage:       _currentPage,
                totalPages:        _totalPages,
                horizontalPadding: hPad,
                onPageChanged:
                    (p) => setState(() => _currentPage = p),
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
              Text('Follow-Ups',
                  style: TextStyle(
                      color:         AppColors.textPrimary,
                      fontSize:      isTablet ? 20 : 17,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: -0.3)),
              const Text('All follow-up records',
                  style: TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 11.5)),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _fetchFollowUps,
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
        cursorColor: AppColors.primary,
        style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 14),
        decoration: const InputDecoration(
          hintText:  'Search by enquiry, customer, deal, status…',
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

  // ── List ───────────────────────────────────────────────────────────────────
  Widget _buildList(double hPad) {
    final items = _pageItems;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _followUpCard(items[i]),
    );
  }

  // ── Card ───────────────────────────────────────────────────────────────────
  Widget _followUpCard(_FollowUp f) {
    final bg        = _dealColor(f.dealColor);
    final luminance = bg.computeLuminance();
    final chipText  = luminance > 0.45
        ? const Color(0xFF1A1A2E)
        : Colors.white;
    final statusClr   = _statusColor(f.followupStatus);
    final statusBg    = _statusBg(f.followupStatus);
    final isCompleted = f.followupStatus.toLowerCase() == 'completed';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
          // ── Top row: enquiry badge (left) + status badge (right) ─────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#${f.enquiryNumber}',
                  style: const TextStyle(
                      color:      AppColors.primary,
                      fontSize:   11,
                      fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color:        statusBg,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: statusClr.withOpacity(0.3), width: 1),
                ),
                child: Text(f.followupStatus.capitalize(),
                    style: TextStyle(
                        color:      statusClr,
                        fontSize:   10.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Deal chip ────────────────────────────────────────────────
          if (f.dealsName.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color:        bg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(f.dealsName.capitalize(),
                  style: TextStyle(
                      color:      chipText,
                      fontSize:   11,
                      fontWeight: FontWeight.w600)),
            ),

          const SizedBox(height: 6),

          // ── Customer + phone ──────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 11, color: AppColors.textMuted),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  f.customerName.capitalize(),
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
              Text(f.phoneNumber,
                  style: const TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 12)),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 7),

          // ── Bottom row: date (left) + buttons (right) ────────────────
          Row(
            children: [
              const Icon(Icons.event_outlined,
                  size: 12, color: AppColors.textMuted),
              const SizedBox(width: 3),
              Text(
                _fmtDate(f.followUp),
                style: const TextStyle(
                    color:      AppColors.textMuted,
                    fontSize:   11.5,
                    fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              // View
              _actionIcon(
                icon:    Icons.visibility_outlined,
                color:   const Color(0xFF2E7D32),
                bgColor: const Color(0xFFE8F5E9),
                onTap:   () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AssignLeadViewPage(
                      enquiryId:     f.enquiryId,
                      enquiryNumber: f.enquiryNumber,
                      dealName:      f.dealsName,
                      dealColor:     f.dealColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Message / follow-up
              _actionIcon(
                icon:    Icons.chat_bubble_outline_rounded,
                color:   AppColors.primary,
                bgColor: AppColors.primaryLight,
                onTap:   () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AssignLeadFollowUpPage(
                      enquiryId:     f.enquiryId,
                      enquiryNumber: f.enquiryNumber,
                      title:         f.title,
                    ),
                  ),
                ),
              ),
              // Tick — only when not completed
              if (!isCompleted) ...[
                const SizedBox(width: 6),
                _actionIcon(
                  icon:    Icons.check_circle_outline_rounded,
                  color:   const Color(0xFF2E7D32),
                  bgColor: const Color(0xFFE8F5E9),
                  onTap:   () => _showCompleteConfirm(f),
                ),
              ],
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
            color: bgColor, borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }

  // ── Complete confirm dialog ────────────────────────────────────────────────
  void _showCompleteConfirm(_FollowUp f) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.white,
        contentPadding: EdgeInsets.zero,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
        content: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color:        const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Color(0xFF2E7D32), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Mark as Completed',
                        style: TextStyle(
                            color:      AppColors.textPrimary,
                            fontSize:   14.5,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Are you sure you want to mark this follow-up as completed?',
                style: TextStyle(
                    color:    AppColors.textSecondary,
                    fontSize: 13,
                    height:   1.5),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.borderLight),
              const SizedBox(height: 10),
              // Enquiry number only
              Row(
                  children: [
                    const Icon(Icons.tag_rounded,
                        size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 5),
                    const Text('Enquiry No  ',
                        style: TextStyle(
                            color:      AppColors.textMuted,
                            fontSize:   12,
                            fontWeight: FontWeight.w500)),
                    Text(
                      f.enquiryNumber,
                      style: const TextStyle(
                          color:      AppColors.primary,
                          fontSize:   12.5,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              const SizedBox(height: 18),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dCtx),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: AppColors.border, width: 1.2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(
                              color:      AppColors.textLabel,
                              fontWeight: FontWeight.w600,
                              fontSize:   13.5)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dCtx);
                        _markComplete(f.comId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        elevation: 0,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Complete',
                          style: TextStyle(
                              color:      Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize:   13.5)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Skeleton ───────────────────────────────────────────────────────────────
  Widget _buildSkeletonList(double hPad) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
      itemCount: 7,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => _skeletonCard(),
    );
  }

  Widget _skeletonCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
              _shimmer(width: 44, height: 20, radius: 6),
              _shimmer(width: 68, height: 20, radius: 5),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _shimmer(width: 80, height: 22, radius: 6),
              const SizedBox(width: 8),
              _shimmer(width: 100, height: 12, radius: 4),
            ],
          ),
          const SizedBox(height: 7),
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
          const Icon(Icons.event_note_outlined,
              size: 56, color: AppColors.border),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No follow-ups found',
            style: const TextStyle(
                color:      AppColors.textSecondary,
                fontSize:   14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Follow-ups will appear here once added',
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
            onPressed: _fetchFollowUps,
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
      {required this.width, required this.height, required this.radius});

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