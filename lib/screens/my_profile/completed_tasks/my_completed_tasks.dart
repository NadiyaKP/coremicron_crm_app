import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/screens/home.dart';
import 'package:coremicron_crm_app/common/pagination.dart';
import 'package:coremicron_crm_app/common/string_extensions.dart';

// ── Completed Job Model ────────────────────────────────────────────────────
class _CompletedJob {
  final String jobId;
  final String ticketId;
  final String ticketNumber;
  final String title;
  final String assignId;
  final String assignName;
  final String toDo;
  final String fixbyDate;
  final String completedDate;
  final String verifiedDate;
  final String status;

  const _CompletedJob({
    required this.jobId,
    required this.ticketId,
    required this.ticketNumber,
    required this.title,
    required this.assignId,
    required this.assignName,
    required this.toDo,
    required this.fixbyDate,
    required this.completedDate,
    required this.verifiedDate,
    required this.status,
  });

  factory _CompletedJob.fromJson(Map<String, dynamic> j) => _CompletedJob(
        jobId:         j['job_id']         ?? '',
        ticketId:      j['ticket_id']      ?? '',
        ticketNumber:  j['ticket_number']  ?? '',
        title:         j['title']          ?? '',
        assignId:      j['assign_id']      ?? '',
        assignName:    j['assign_name']    ?? '',
        toDo:          j['to_do']          ?? '',
        fixbyDate:     j['fixby_date']     ?? '',
        completedDate: j['completed_date'] ?? '',
        verifiedDate:  j['verified_date']  ?? '',
        status:        j['status']         ?? '',
      );
}

// ── My Completed Tasks Page ────────────────────────────────────────────────
class MyCompletedTasksPage extends StatefulWidget {
  final String username;
  const MyCompletedTasksPage({super.key, required this.username});

  @override
  State<MyCompletedTasksPage> createState() => _MyCompletedTasksPageState();
}

class _MyCompletedTasksPageState extends State<MyCompletedTasksPage> {
  static const int _pageSize = 50;

  List<_CompletedJob> _all      = [];
  List<_CompletedJob> _filtered = [];
  bool                _isLoading = true;
  String?             _errorMessage;

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int    _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _fetchJobs();
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
      _filtered = _all.where((j) =>
          j.ticketNumber.contains(_searchQuery) ||
          j.title.toLowerCase().contains(_searchQuery) ||
          j.assignName.toLowerCase().contains(_searchQuery) ||
          j.toDo.toLowerCase().contains(_searchQuery) ||
          j.status.toLowerCase().contains(_searchQuery) ||
          j.fixbyDate.contains(_searchQuery) ||
          j.completedDate.contains(_searchQuery)).toList();
    }
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchJobs() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/ticket/job_list.php?mode=my_completed');

      debugPrint('📤  [COMPLETED TASKS] $url');
      final res = await ApiService.get(url)
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [COMPLETED TASKS] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        final list = data['jobs'] as List? ?? [];
        _all = list.map((e) => _CompletedJob.fromJson(e)).toList();
        _applyFilter();
      } else {
        _errorMessage =
            data['error'] ?? data['message'] ?? 'Failed to load completed tasks.';
      }
    } on http.ClientException {
      _errorMessage = 'Unable to reach the server. Check your connection.';
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Pagination ─────────────────────────────────────────────────────────────
  int get _totalPages =>
      paginationTotalPages(_filtered.length, _pageSize);
  List<_CompletedJob> get _pageItems =>
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

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'verified':  return AppColors.primary;
      case 'completed': return const Color(0xFF2E7D32);
      case 'rejected':  return const Color(0xFFC62828);
      default:          return AppColors.textMuted;
    }
  }

  Color _statusBg(String s) {
    switch (s.toLowerCase()) {
      case 'verified':  return AppColors.primaryLight;
      case 'completed': return const Color(0xFFE8F5E9);
      case 'rejected':  return const Color(0xFFFFF1F1);
      default:          return const Color(0xFFF5F5F5);
    }
  }

  IconData _statusIcon(String s) {
    switch (s.toLowerCase()) {
      case 'verified':  return Icons.verified_rounded;
      case 'completed': return Icons.check_circle_outline_rounded;
      case 'rejected':  return Icons.cancel_outlined;
      default:          return Icons.info_outline_rounded;
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
                      '${_filtered.length} task'
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
              Text('Completed Tasks',
                  style: TextStyle(
                      color:         AppColors.textPrimary,
                      fontSize:      isTablet ? 20 : 17,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: -0.3)),
              const Text('Your finished work',
                  style: TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 11.5)),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _fetchJobs,
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
          hintText:  'Search by ticket, name, task, status…',
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
      itemBuilder: (_, i) => _jobCard(items[i]),
    );
  }

  // ── Card ───────────────────────────────────────────────────────────────────
  Widget _jobCard(_CompletedJob job) {
    final stClr = _statusColor(job.status);
    final stBg  = _statusBg(job.status);
    final stIco = _statusIcon(job.status);

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
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
          // ── Top row: ticket badge + status badge ───────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('#${job.ticketNumber}',
                    style: const TextStyle(
                        color:      AppColors.primary,
                        fontSize:   11,
                        fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color:        stBg,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: stClr.withOpacity(0.3), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(stIco, size: 11, color: stClr),
                    const SizedBox(width: 3),
                    Text(job.status.capitalize(),
                        style: TextStyle(
                            color:      stClr,
                            fontSize:   10.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Task (to_do) ──────────────────────────────────────────
          if (job.toDo.trim().isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color:        AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.borderLight, width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.task_alt_rounded,
                      size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      job.toDo.trim().capitalize(),
                      style: const TextStyle(
                          color:    AppColors.textSecondary,
                          fontSize: 12.5,
                          height:   1.5),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 9),

          // ── Date grid: fix by + completed + verified ──────────────
          Row(
            children: [
              Expanded(
                child: _dateCell(
                  label: 'Fix By',
                  value: _fmtDate(job.fixbyDate),
                  icon:  Icons.event_outlined,
                  color: const Color(0xFFE65100),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dateCell(
                  label: 'Completed',
                  value: _fmtDate(job.completedDate),
                  icon:  Icons.check_circle_outline_rounded,
                  color: const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dateCell(
                  label: 'Verified',
                  value: _fmtDate(job.verifiedDate),
                  icon:  Icons.verified_outlined,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 8),

          // ── Bottom: verified by ───────────────────────────────────
          Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 13, color: AppColors.textMuted),
              const SizedBox(width: 5),
              const Text('Verified by  ',
                  style: TextStyle(
                      color:      AppColors.textMuted,
                      fontSize:   12,
                      fontWeight: FontWeight.w500)),
              Expanded(
                child: Text(
                  job.assignName.isEmpty
                      ? '—'
                      : job.assignName.capitalize(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color:      AppColors.textPrimary,
                      fontSize:   12.5,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateCell({
    required String   label,
    required String   value,
    required IconData icon,
    required Color    color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    color:      color,
                    fontSize:   10.5,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(
                color:      AppColors.textPrimary,
                fontSize:   12,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ── Skeleton ───────────────────────────────────────────────────────────────
  Widget _buildSkeletonList(double hPad) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => _skeletonCard(),
    );
  }

  Widget _skeletonCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
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
          const SizedBox(height: 9),
          _shimmer(width: double.infinity, height: 44, radius: 8),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _shimmer(
                  width: double.infinity, height: 30, radius: 6)),
              const SizedBox(width: 8),
              Expanded(child: _shimmer(
                  width: double.infinity, height: 30, radius: 6)),
              const SizedBox(width: 8),
              Expanded(child: _shimmer(
                  width: double.infinity, height: 30, radius: 6)),
            ],
          ),
          const SizedBox(height: 10),
          _shimmer(width: 140, height: 12, radius: 4),
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
          const Icon(Icons.check_circle_outline_rounded,
              size: 56, color: AppColors.border),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No completed tasks yet',
            style: const TextStyle(
                color:      AppColors.textSecondary,
                fontSize:   14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Completed tasks will appear here',
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
            onPressed: _fetchJobs,
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