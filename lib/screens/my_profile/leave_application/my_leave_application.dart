import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/screens/home.dart';
import 'package:coremicron_crm_app/common/pagination.dart';
import 'package:coremicron_crm_app/common/string_extensions.dart';
import 'new_leave_application.dart';

// ── Leave Application Model ────────────────────────────────────────────────
class LeaveApplication {
  final String leaveId;
  final String employeeId;
  final String typeOfAbsence;
  final String reason;
  final String absenceFrom;
  final String absenceThrough;
  final String status;
  final String addedDate;
  final String addedTime;

  const LeaveApplication({
    required this.leaveId,
    required this.employeeId,
    required this.typeOfAbsence,
    required this.reason,
    required this.absenceFrom,
    required this.absenceThrough,
    required this.status,
    required this.addedDate,
    required this.addedTime,
  });

  factory LeaveApplication.fromJson(Map<String, dynamic> j) => LeaveApplication(
        leaveId:        j['leave_id']        ?? '',
        employeeId:     j['employee_id']     ?? '',
        typeOfAbsence:  j['type_of_absence'] ?? '',
        reason:         j['reason']          ?? '',
        absenceFrom:    j['absence_from']    ?? '',
        absenceThrough: j['absence_through'] ?? '',
        status:         j['status']          ?? '',
        addedDate:      j['added_date']      ?? '',
        addedTime:      j['added_time']      ?? '',
      );
}

// ── My Leave Application Page ──────────────────────────────────────────────
class MyLeaveApplicationPage extends StatefulWidget {
  final String username;
  const MyLeaveApplicationPage({super.key, required this.username});

  @override
  State<MyLeaveApplicationPage> createState() =>
      _MyLeaveApplicationPageState();
}

class _MyLeaveApplicationPageState extends State<MyLeaveApplicationPage> {
  static const int _pageSize = 50;

  List<LeaveApplication> _all      = [];
  List<LeaveApplication> _filtered = [];
  bool                   _isLoading = true;
  String?                _errorMessage;

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int    _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _fetchLeaves();
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
      _filtered = _all.where((l) =>
          l.typeOfAbsence.toLowerCase().contains(_searchQuery) ||
          l.reason.toLowerCase().contains(_searchQuery) ||
          l.status.toLowerCase().contains(_searchQuery) ||
          l.absenceFrom.contains(_searchQuery) ||
          l.absenceThrough.contains(_searchQuery)).toList();
    }
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchLeaves() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/attendance/leave_list.php');

      debugPrint('📤  [MY LEAVES] $url');
      final res = await ApiService.get(url)
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [MY LEAVES] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        final list = data['leave_applications'] as List? ?? [];
        _all = list.map((e) => LeaveApplication.fromJson(e)).toList();
        _applyFilter();
      } else {
        _errorMessage =
            data['error'] ?? data['message'] ?? 'Failed to load.';
      }
    } on http.ClientException {
      _errorMessage = 'Unable to reach the server. Check your connection.';
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Delete Leave API ───────────────────────────────────────────────────────
  Future<void> _deleteLeave(String leaveId) async {
    try {
      final url  = Uri.parse(
          '${ApiService.baseUrl}/api/attendance/leave_delete.php');
      final body = {'leave_id': leaveId};

      debugPrint('📤  [LEAVE DELETE] $url  ${jsonEncode(body)}');
      final res = await ApiService.post(url, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [LEAVE DELETE] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Leave application deleted.');
        _fetchLeaves();
      } else {
        AppSnackBar.show(
            context,
            data['error'] ?? data['message'] ?? 'Failed to delete.',
            isError: true);
      }
    } on http.ClientException {
      if (mounted)
        AppSnackBar.show(context, 'Unable to reach the server.', isError: true);
    } catch (e) {
      if (mounted) AppSnackBar.show(context, 'Error: $e', isError: true);
    }
  }

  // ── Pagination ─────────────────────────────────────────────────────────────
  int get _totalPages =>
      paginationTotalPages(_filtered.length, _pageSize);
  List<LeaveApplication> get _pageItems =>
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

  // ── Navigate to form ───────────────────────────────────────────────────────
  Future<void> _openNew() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => const NewLeaveApplicationPage()),
    );
    if (result == true && mounted) _fetchLeaves();
  }

  Future<void> _openEdit(LeaveApplication l) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NewLeaveApplicationPage(
          editData: LeaveEditData(
            leaveId:        l.leaveId,
            typeOfAbsence:  l.typeOfAbsence,
            reason:         l.reason,
            absenceFrom:    l.absenceFrom,
            absenceThrough: l.absenceThrough,
          ),
        ),
      ),
    );
    if (result == true && mounted) _fetchLeaves();
  }

  // ── Delete dialog ──────────────────────────────────────────────────────────
  void _showDeleteDialog(LeaveApplication l) {
    bool isDeleting = false;
    showDialog(
      context:            context,
      barrierDismissible: false,
      builder: (dCtx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 50),
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
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                          color:        const Color(0xFFFFF1F1),
                          borderRadius: BorderRadius.circular(11)),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.error, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Delete Leave',
                          style: TextStyle(
                              color:      AppColors.textPrimary,
                              fontSize:   15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Confirmation text
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        color:    AppColors.textSecondary,
                        fontSize: 13.5, height: 1.5),
                    children: [
                      const TextSpan(text: 'Are you sure you want to delete '),
                      TextSpan(
                        text: '"${l.typeOfAbsence.capitalize()}"',
                        style: const TextStyle(
                            color:      AppColors.textPrimary,
                            fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(
                          text: '? This action cannot be undone.'),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isDeleting
                            ? null : () => Navigator.pop(dCtx),
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
                                Navigator.pop(dCtx);
                                await _deleteLeave(l.leaveId);
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
                                  key: ValueKey('dl-loader'),
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      color:       Colors.white,
                                      strokeWidth: 2.3))
                              : const Text('Delete',
                                  key: ValueKey('dl-label'),
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

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return '—';
    try {
      final p = raw.trim().split('-');
      if (p.length == 3) return '${p[2]}-${p[1]}-${p[0]}';
    } catch (_) {}
    return raw;
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'approved':  return const Color(0xFF2E7D32);
      case 'rejected':  return const Color(0xFFC62828);
      case 'waiting':   return const Color(0xFFE65100);
      default:          return AppColors.primary;
    }
  }

  Color _statusBg(String s) {
    switch (s.toLowerCase()) {
      case 'approved':  return const Color(0xFFE8F5E9);
      case 'rejected':  return const Color(0xFFFFF1F1);
      case 'waiting':   return const Color(0xFFFFF3E0);
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

            // ── Search + New Leave button row ──────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 0),
              child: _buildSearchBar(),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 0),
              child: Row(
                children: [
                  if (!_isLoading)
                    Text(
                      '${_filtered.length} application'
                      '${_filtered.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color:      AppColors.textSecondary,
                          fontSize:   12.5,
                          fontWeight: FontWeight.w500),
                    ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _openNew,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color:        AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.add_rounded,
                              size: 15, color: Colors.white),
                          SizedBox(width: 4),
                          Text('New Leave',
                              style: TextStyle(
                                  color:      Colors.white,
                                  fontSize:   12.5,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
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

            if (!_isLoading && _errorMessage == null && _filtered.isNotEmpty)
              AppPagination(
                currentPage:       _currentPage,
                totalPages:        _totalPages,
                horizontalPadding: hPad,
                onPageChanged: (p) => setState(() => _currentPage = p),
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
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
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
                border: Border.all(color: AppColors.border, width: 1.2),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 15, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My Leave Applications',
                  style: TextStyle(
                      color:         AppColors.textPrimary,
                      fontSize:      isTablet ? 20 : 17,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: -0.3)),
              const Text('Your leave requests',
                  style: TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 11.5)),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _fetchLeaves,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color:        AppColors.background,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.border, width: 1.2),
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
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: const InputDecoration(
          hintText:  'Search by type, reason, status…',
          hintStyle: TextStyle(color: AppColors.textHint, fontSize: 12.5),
          prefixIcon: Icon(Icons.search_rounded,
              color: AppColors.iconDefault, size: 19),
          border:         InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
      itemBuilder: (_, i) => _leaveCard(items[i]),
    );
  }

  // ── Card ───────────────────────────────────────────────────────────────────
  Widget _leaveCard(LeaveApplication l) {
    final stClr = _statusColor(l.status);
    final stBg  = _statusBg(l.status);

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
          // ── Top row: type + status badge ──────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l.typeOfAbsence.capitalize(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color:      AppColors.textPrimary,
                      fontSize:   14,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color:        stBg,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: stClr.withOpacity(0.3), width: 1),
                ),
                child: Text(l.status.capitalize(),
                    style: TextStyle(
                        color:      stClr,
                        fontSize:   10.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),

          const SizedBox(height: 5),

          // ── Reason ────────────────────────────────────────────────────
          if (l.reason.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_rounded,
                    size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l.reason.capitalize(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color:    AppColors.textSecondary,
                        fontSize: 12.5,
                        height:   1.4),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 6),

          // ── Date range ────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.date_range_outlined,
                  size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                '${_fmtDate(l.absenceFrom)}  →  ${_fmtDate(l.absenceThrough)}',
                style: const TextStyle(
                    color:      AppColors.textMuted,
                    fontSize:   12,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 7),

          // ── Bottom row: action buttons ────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _actionIcon(
                icon:    Icons.edit_outlined,
                color:   const Color(0xFF0277BD),
                bgColor: const Color(0xFFE1F5FE),
                onTap:   () => _openEdit(l),
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
              _shimmer(width: 100, height: 14, radius: 4),
              _shimmer(width: 60,  height: 20, radius: 5),
            ],
          ),
          const SizedBox(height: 7),
          _shimmer(width: double.infinity, height: 11, radius: 4),
          const SizedBox(height: 5),
          _shimmer(width: 150, height: 11, radius: 4),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
          const Icon(Icons.beach_access_outlined,
              size: 56, color: AppColors.border),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No leave applications found',
            style: const TextStyle(
                color:      AppColors.textSecondary,
                fontSize:   14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Tap "+ New Leave" to submit a request',
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
            onPressed: _fetchLeaves,
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