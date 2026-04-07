import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/screens/home.dart';
import 'package:coremicron_crm_app/common/pagination.dart';
import 'package:coremicron_crm_app/common/string_extensions.dart';
import 'package:coremicron_crm_app/screens/ticket/ticket_view.dart';

// ── Pending Job Model ──────────────────────────────────────────────────────
class _PendingJob {
  final String jobId;
  final String ticketId;
  final String ticketNumber;
  final String fixbyDate;
  final String customerName;
  final String toDo;
  final String priority;

  const _PendingJob({
    required this.jobId,
    required this.ticketId,
    required this.ticketNumber,
    required this.fixbyDate,
    required this.customerName,
    required this.toDo,
    required this.priority,
  });

  factory _PendingJob.fromJson(Map<String, dynamic> j) => _PendingJob(
        jobId:        j['job_id']        ?? '',
        ticketId:     j['ticket_id']     ?? '',
        ticketNumber: j['ticket_number'] ?? '',
        fixbyDate:    j['fixby_date']    ?? '',
        customerName: j['customer_name'] ?? '',
        toDo:         j['to_do']         ?? '',
        priority:     j['priority']      ?? '',
      );

  /// Returns positive number if overdue, negative if days remain, 0 if today.
  int get daysDiff {
    try {
      final parts = fixbyDate.split('-');
      if (parts.length != 3) return 0;
      final deadline = DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      return todayOnly.difference(deadline).inDays;
    } catch (_) {
      return 0;
    }
  }
}

// ── Pending Works Page ─────────────────────────────────────────────────────
class PendingWorksPage extends StatefulWidget {
  final String username;
  const PendingWorksPage({super.key, required this.username});

  @override
  State<PendingWorksPage> createState() => _PendingWorksPageState();
}

class _PendingWorksPageState extends State<PendingWorksPage> {
  static const int _pageSize = 50;

  List<_PendingJob> _all       = [];
  List<_PendingJob> _filtered  = [];
  bool              _isLoading  = true;
  String?           _errorMessage;

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
          j.customerName.toLowerCase().contains(_searchQuery) ||
          j.toDo.toLowerCase().contains(_searchQuery) ||
          j.priority.toLowerCase().contains(_searchQuery) ||
          j.fixbyDate.contains(_searchQuery)).toList();
    }
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchJobs() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/ticket/job_list.php?mode=my_pending');

      debugPrint('📤  [PENDING WORKS] $url');
      final res = await ApiService.get(url)
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [PENDING WORKS] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        final list = data['jobs'] as List? ?? [];
        _all = list.map((e) => _PendingJob.fromJson(e)).toList();
        _applyFilter();
      } else {
        _errorMessage =
            data['error'] ?? data['message'] ?? 'Failed to load pending works.';
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
  List<_PendingJob> get _pageItems =>
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

  Color _priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'high':   return const Color(0xFFC62828);
      case 'medium': return const Color(0xFFE65100);
      case 'low':    return const Color(0xFF2E7D32);
      default:       return AppColors.primary;
    }
  }

  Color _priorityBg(String p) {
    switch (p.toLowerCase()) {
      case 'high':   return const Color(0xFFFFF1F1);
      case 'medium': return const Color(0xFFFFF3E0);
      case 'low':    return const Color(0xFFE8F5E9);
      default:       return AppColors.primaryLight;
    }
  }

  /// Returns the day status label and color for a job.
  _DayStatus _getDayStatus(_PendingJob job) {
    final diff = job.daysDiff;
    if (diff > 0) {
      return _DayStatus(
        label: '$diff day${diff == 1 ? '' : 's'} overdue',
        color: const Color(0xFFC62828),
        bg:    const Color(0xFFFFF1F1),
        icon:  Icons.warning_amber_rounded,
      );
    } else if (diff == 0) {
      return _DayStatus(
        label: 'Due today',
        color: const Color(0xFFE65100),
        bg:    const Color(0xFFFFF3E0),
        icon:  Icons.schedule_rounded,
      );
    } else {
      final left = diff.abs();
      return _DayStatus(
        label: '$left day${left == 1 ? '' : 's'} left',
        color: const Color(0xFF2E7D32),
        bg:    const Color(0xFFE8F5E9),
        icon:  Icons.hourglass_bottom_rounded,
      );
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
              Text('Pending Works',
                  style: TextStyle(
                      color:         AppColors.textPrimary,
                      fontSize:      isTablet ? 20 : 17,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: -0.3)),
              const Text('Your pending tasks',
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
          hintText:  'Search by ticket, customer, task, priority…',
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
  Widget _jobCard(_PendingJob job) {
    final prClr     = _priorityColor(job.priority);
    final prBg      = _priorityBg(job.priority);
    final dayStatus = _getDayStatus(job);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
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
          // ── Top row: ticket badge + priority badge ─────────────────
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TicketViewPage(
                        ticketId:     job.ticketId,
                        ticketNumber: job.ticketNumber,
                        priority:     job.priority,
                        customerName: job.customerName,
                      ),
                    ),
                  );
                },
                child: Container(
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
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline)),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color:        prBg,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: prClr.withOpacity(0.3), width: 1),
                ),
                child: Text(job.priority.capitalize(),
                    style: TextStyle(
                        color:      prClr,
                        fontSize:   10.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Customer name ─────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 13, color: AppColors.textMuted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  job.customerName.capitalize(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color:      AppColors.textPrimary,
                      fontSize:   13.5,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

          // ── Task (to_do) ──────────────────────────────────────────
          if (job.toDo.trim().isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.task_alt_rounded,
                    size: 13, color: AppColors.textMuted),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    job.toDo.trim().capitalize(),
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

          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 8),

          // ── Bottom row: fix-by date + day status chip ─────────────
          Row(
            children: [
              // Fix by date
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_outlined,
                      size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text('Fix by  ',
                      style: const TextStyle(
                          color:    AppColors.textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500)),
                  Text(_fmtDate(job.fixbyDate),
                      style: const TextStyle(
                          color:      AppColors.textSecondary,
                          fontSize:   12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const Spacer(),
              // Day status chip
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:        dayStatus.bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: dayStatus.color.withOpacity(0.25),
                      width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(dayStatus.icon,
                        size: 12, color: dayStatus.color),
                    const SizedBox(width: 4),
                    Text(dayStatus.label,
                        style: TextStyle(
                            color:      dayStatus.color,
                            fontSize:   11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
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
              _shimmer(width: 56, height: 20, radius: 5),
            ],
          ),
          const SizedBox(height: 9),
          _shimmer(width: 160, height: 13, radius: 4),
          const SizedBox(height: 6),
          _shimmer(width: double.infinity, height: 11, radius: 4),
          const SizedBox(height: 4),
          _shimmer(width: 200, height: 11, radius: 4),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _shimmer(width: 100, height: 12, radius: 4),
              _shimmer(width: 90,  height: 24, radius: 6),
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
          const Icon(Icons.task_alt_rounded,
              size: 56, color: AppColors.border),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No pending works found',
            style: const TextStyle(
                color:      AppColors.textSecondary,
                fontSize:   14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'All your tasks are up to date!',
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

// ── Day Status ─────────────────────────────────────────────────────────────
class _DayStatus {
  final String  label;
  final Color   color;
  final Color   bg;
  final IconData icon;
  const _DayStatus({
    required this.label,
    required this.color,
    required this.bg,
    required this.icon,
  });
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