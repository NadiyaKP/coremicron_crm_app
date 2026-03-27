import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService, kTokenKey;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/screens/login.dart' show kTokenKey;
import 'package:coremicron_crm_app/common/string_extensions.dart';

// ── Pending Job Model ──────────────────────────────────────────────────────
class _PendingJob {
  final String jobId;
  final String ticketId;
  final String ticketNumber;
  final String title;
  final String assignId;
  final String assignName;
  final String fixbyDate;
  final String toDo;
  final String status;

  const _PendingJob({
    required this.jobId,
    required this.ticketId,
    required this.ticketNumber,
    required this.title,
    required this.assignId,
    required this.assignName,
    required this.fixbyDate,
    required this.toDo,
    required this.status,
  });

  factory _PendingJob.fromJson(Map<String, dynamic> j) => _PendingJob(
        jobId:        j['job_id']        ?? '',
        ticketId:     j['ticket_id']     ?? '',
        ticketNumber: j['ticket_number'] ?? '',
        title:        j['title']         ?? '',
        assignId:     j['assign_id']     ?? '',
        assignName:   j['assign_name']   ?? '',
        fixbyDate:    j['fixby_date']    ?? '',
        toDo:         j['to_do']         ?? '',
        status:       j['status']        ?? '',
      );
}

// ── Pending Tasks View Page ────────────────────────────────────────────────
class PendingTasksViewPage extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const PendingTasksViewPage({
    super.key,
    required this.employeeId,
    this.employeeName = '',
  });

  @override
  State<PendingTasksViewPage> createState() => _PendingTasksViewPageState();
}

class _PendingTasksViewPageState extends State<PendingTasksViewPage> {
  List<_PendingJob> _all      = [];
  List<_PendingJob> _filtered = [];
  bool              _isLoading = true;
  String?           _errorMessage;
  int               _totalPending = 0;

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchPendingJobs();
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
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filtered = List.from(_all);
    } else {
      _filtered = _all.where((j) =>
          j.ticketNumber.contains(_searchQuery) ||
          j.title.toLowerCase().contains(_searchQuery) ||
          j.toDo.toLowerCase().contains(_searchQuery) ||
          j.fixbyDate.contains(_searchQuery)).toList();
    }
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchPendingJobs() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/ticket/job_list.php'
          '?mode=employee_pending&employee_id=${widget.employeeId}');

      final res = await ApiService.get(url).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [PENDING TASKS] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        _totalPending = data['total_pending'] ?? 0;
        final list = data['jobs'] as List? ?? [];
        _all = list.map((e) => _PendingJob.fromJson(e)).toList();
        _applyFilter();
      } else {
        _errorMessage =
            data['error'] ?? data['message'] ?? 'Failed to load pending tasks.';
      }
    } on http.ClientException {
      _errorMessage = 'Unable to reach the server. Check your connection.';
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    }
    if (mounted) setState(() => _isLoading = false);
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
                  if (!_isLoading) ...[
                    Text(
                      '${_filtered.length} task'
                      '${_filtered.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color:      AppColors.textSecondary,
                          fontSize:   12.5,
                          fontWeight: FontWeight.w500),
                    ),
                    if (_searchQuery.isEmpty && _totalPending > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color:        const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                              color: const Color(0xFFE65100).withOpacity(0.3),
                              width: 1),
                        ),
                        child: Text(
                          '$_totalPending pending',
                          style: const TextStyle(
                              color:      Color(0xFFE65100),
                              fontSize:   11,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pending Tasks',
                    style: TextStyle(
                        color:         AppColors.textPrimary,
                        fontSize:      isTablet ? 20 : 17,
                        fontWeight:    FontWeight.w800,
                        letterSpacing: -0.3)),
                Text(
                  widget.employeeName.isNotEmpty
                      ? widget.employeeName.capitalize()
                      : 'Employee tasks',
                  style: const TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 11.5),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _fetchPendingJobs,
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
          hintText:  'Search by ticket, title, task…',
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
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 20),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _jobCard(_filtered[i]),
    );
  }

  // ── Card ───────────────────────────────────────────────────────────────────
  Widget _jobCard(_PendingJob j) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
          // ── Top row: ticket badge + fix-by date ────────────────────────
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
                  '#${j.ticketNumber}',
                  style: const TextStyle(
                      color:      AppColors.primary,
                      fontSize:   11,
                      fontWeight: FontWeight.w700),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_outlined,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text(
                    _fmtDate(j.fixbyDate),
                    style: const TextStyle(
                        color:      Color(0xFFE65100),
                        fontSize:   11.5,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Title ──────────────────────────────────────────────────────
          Text(
            j.title.isEmpty ? '(No title)' : j.title.capitalize(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:      j.title.isEmpty
                  ? AppColors.textMuted
                  : AppColors.textPrimary,
              fontSize:   13.5,
              fontWeight: FontWeight.w700,
              fontStyle:  j.title.isEmpty
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),

          // ── To Do ──────────────────────────────────────────────────────
          if (j.toDo.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.task_alt_rounded,
                    size: 13, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    j.toDo.trim().capitalize(),
                    style: const TextStyle(
                        color:    AppColors.textSecondary,
                        fontSize: 12.5,
                        height:   1.5),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Skeleton ───────────────────────────────────────────────────────────────
  Widget _buildSkeletonList(double hPad) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 20),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => _skeletonCard(),
    );
  }

  Widget _skeletonCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
              _shimmer(width: 80, height: 14, radius: 4),
            ],
          ),
          const SizedBox(height: 9),
          _shimmer(width: 160, height: 13, radius: 4),
          const SizedBox(height: 10),
          _shimmer(width: double.infinity, height: 11, radius: 4),
          const SizedBox(height: 5),
          _shimmer(width: double.infinity, height: 11, radius: 4),
          const SizedBox(height: 5),
          _shimmer(width: 200, height: 11, radius: 4),
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
          const Icon(Icons.task_alt_rounded,
              size: 56, color: AppColors.border),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No pending tasks found',
            style: const TextStyle(
                color:      AppColors.textSecondary,
                fontSize:   14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'All tasks are completed',
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
            onPressed: _fetchPendingJobs,
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