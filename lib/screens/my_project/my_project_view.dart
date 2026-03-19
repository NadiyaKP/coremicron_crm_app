import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../common/api_service.dart';
import '../../../common/theme.dart';
import '../login.dart' show kSessionKey;
import '../../../common/string_extensions.dart';

// ── Job Model ──────────────────────────────────────────────────────────────
class _Job {
  final String jobId;
  final String assignId;
  final String assignName;
  final String toDo;
  final String fixbyDate;
  final String completedDate;
  final String verifiedDate;
  final String status;

  const _Job({
    required this.jobId,
    required this.assignId,
    required this.assignName,
    required this.toDo,
    required this.fixbyDate,
    required this.completedDate,
    required this.verifiedDate,
    required this.status,
  });

  factory _Job.fromJson(Map<String, dynamic> j) => _Job(
        jobId:         j['job_id']          ?? '',
        assignId:      j['assign_id']        ?? '',
        assignName:    j['assign_name']      ?? '',
        toDo:          j['to_do']            ?? '',
        fixbyDate:     j['fixby_date']       ?? '',
        completedDate: j['completed_date']   ?? '',
        verifiedDate:  j['verified_date']    ?? '',
        status:        j['status']           ?? '',
      );
}

// ── My Project View Page ───────────────────────────────────────────────────
class MyProjectViewPage extends StatefulWidget {
  final String ticketId;
  final String ticketNumber;
  final String title;

  const MyProjectViewPage({
    super.key,
    required this.ticketId,
    required this.ticketNumber,
    this.title = '',
  });

  @override
  State<MyProjectViewPage> createState() => _MyProjectViewPageState();
}

class _MyProjectViewPageState extends State<MyProjectViewPage> {
  List<_Job> _jobs       = [];
  bool       _isLoading  = true;
  String?    _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchJobs();
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchJobs() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/ticket/job_list.php'
          '?ticket_id=${widget.ticketId}');

      debugPrint('📤  [PROJECT VIEW] $url');
      final res = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Accept':       'application/json',
        'X-Session-ID': sessionId,
        'Cookie':       'PHPSESSID=$sessionId',
      }).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [PROJECT VIEW] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        final list = data['jobs'] as List? ?? [];
        _jobs = list.map((e) => _Job.fromJson(e)).toList();
      } else {
        _errorMessage =
            data['error'] ?? data['message'] ?? 'Failed to load tasks.';
      }
    } on http.ClientException {
      _errorMessage = 'Unable to reach the server. Check your connection.';
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Job Action APIs ────────────────────────────────────────────────────────
  Future<void> _jobAction(String jobId, String action) async {
    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url  = Uri.parse(
          '${ApiService.baseUrl}/api/ticket/job_action.php');
      final body = {'job_id': jobId, 'action': action};

      debugPrint('📤  [JOB ACTION] $url  ${jsonEncode(body)}');
      final res = await http.post(url,
          headers: {
            'Content-Type': 'application/json',
            'Accept':       'application/json',
            'X-Session-ID': sessionId,
            'Cookie':       'PHPSESSID=$sessionId',
          },
          body: jsonEncode(body)).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [JOB ACTION] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context,
            'Task ${action == 'verify' ? 'verified' : action == 'reject' ? 'rejected' : 'extended'} successfully.');
        _fetchJobs();
      } else {
        AppSnackBar.show(
            context,
            data['error'] ?? data['message'] ?? 'Operation failed.',
            isError: true);
      }
    } on http.ClientException {
      if (mounted)
        AppSnackBar.show(context, 'Unable to reach the server.', isError: true);
    } catch (e) {
      if (mounted) AppSnackBar.show(context, 'Error: $e', isError: true);
    }
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
      case 'completed': return const Color(0xFF2E7D32);
      case 'verified':  return AppColors.primary;
      case 'pending':   return const Color(0xFFE65100);
      case 'rejected':  return const Color(0xFFC62828);
      default:          return AppColors.textMuted;
    }
  }

  Color _statusBg(String s) {
    switch (s.toLowerCase()) {
      case 'completed': return const Color(0xFFE8F5E9);
      case 'verified':  return AppColors.primaryLight;
      case 'pending':   return const Color(0xFFFFF3E0);
      case 'rejected':  return const Color(0xFFFFF1F1);
      default:          return const Color(0xFFF5F5F5);
    }
  }

  // ── Confirm dialogs ────────────────────────────────────────────────────────
  void _confirmAction(_Job job, String action) {
    final isVerify = action == 'verify';
    final isReject = action == 'reject';
    final isExtend = action == 'extend';

    final Color  confirmColor = isVerify
        ? const Color(0xFF2E7D32)
        : isReject
            ? AppColors.error
            : AppColors.primary;
    final String confirmLabel =
        isVerify ? 'Verify' : isReject ? 'Reject' : 'Extend';
    final String title =
        isVerify ? 'Verify Task' : isReject ? 'Reject Task' : 'Extend Task';
    final String subtitle = isVerify
        ? 'Are you sure you want to verify this task as completed?'
        : isReject
            ? 'Are you sure you want to reject this task?'
            : 'Are you sure you want to extend the deadline for this task?';

    bool isLoading = false;

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
                        color:        confirmColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        isVerify
                            ? Icons.check_circle_outline_rounded
                            : isReject
                                ? Icons.cancel_outlined
                                : Icons.update_rounded,
                        color: confirmColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              color:      AppColors.textPrimary,
                              fontSize:   15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13, height: 1.5)),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 12),
                _detailRow(Icons.person_outline_rounded,
                    'Assign To', job.assignName.capitalize()),
                const SizedBox(height: 7),
                _detailRow(Icons.task_alt_rounded,
                    'Task',
                    job.toDo.trim().isEmpty ? '—' : job.toDo.trim().capitalize()),
                const SizedBox(height: 7),
                _detailRow(Icons.event_outlined,
                    'Fix By', _fmtDate(job.fixbyDate)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isLoading
                            ? null
                            : () => Navigator.pop(dCtx),
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
                        onPressed: isLoading
                            ? null
                            : () async {
                                setS(() => isLoading = true);
                                Navigator.pop(dCtx);
                                await _jobAction(job.jobId, action);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: confirmColor,
                          disabledBackgroundColor:
                              confirmColor.withOpacity(0.5),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11)),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: isLoading
                              ? const SizedBox(
                                  key: ValueKey('loader'),
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      color:       Colors.white,
                                      strokeWidth: 2.3))
                              : Text(confirmLabel,
                                  key: const ValueKey('label'),
                                  style: const TextStyle(
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

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 8),
        SizedBox(
          width: 66,
          child: Text(label,
              style: const TextStyle(
                  color:      AppColors.textMuted,
                  fontSize:   12.5,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value.isEmpty ? '—' : value,
              style: const TextStyle(
                  color:      AppColors.textPrimary,
                  fontSize:   13,
                  fontWeight: FontWeight.w600)),
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
          children: [
            _buildAppBar(isTablet, hPad),
            Expanded(
              child: _isLoading
                  ? _buildSkeletonList(hPad)
                  : _errorMessage != null
                      ? _buildError()
                      : _jobs.isEmpty
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
                Text(
                  widget.title.isEmpty
                      ? 'Project Tasks'
                      : widget.title.capitalize(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color:         AppColors.textPrimary,
                      fontSize:      isTablet ? 19 : 16,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: -0.3),
                ),
                Text(
                  'Ticket #${widget.ticketNumber}',
                  style: const TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 12),
                ),
              ],
            ),
          ),
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

  // ── List ───────────────────────────────────────────────────────────────────
  Widget _buildList(double hPad) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 20),
      itemCount: _jobs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _jobCard(_jobs[i]),
    );
  }

  // ── Job Card ───────────────────────────────────────────────────────────────
  Widget _jobCard(_Job job) {
    final stClr = _statusColor(job.status);
    final stBg  = _statusBg(job.status);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(13),
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
          // ── Top row: status badge ──────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        stBg,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: stClr.withOpacity(0.3), width: 1),
                ),
                child: Text(job.status.capitalize(),
                    style: TextStyle(
                        color:      stClr,
                        fontSize:   10.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Assign To ─────────────────────────────────────────────────
          _infoRow(Icons.person_pin_outlined,
              'Assign To', job.assignName.capitalize()),

          const SizedBox(height: 6),

          // ── Fix By ────────────────────────────────────────────────────
          _infoRow(Icons.event_outlined,
              'Fix By', _fmtDate(job.fixbyDate),
              valueColor: const Color(0xFFE65100)),

          // ── Completed Date ────────────────────────────────────────────
          if (job.completedDate.isNotEmpty && job.completedDate != 'null') ...[
            const SizedBox(height: 6),
            _infoRow(Icons.check_circle_outline_rounded,
                'Completed', _fmtDate(job.completedDate),
                valueColor: const Color(0xFF2E7D32)),
          ],

          const SizedBox(height: 8),

          // ── To Do ─────────────────────────────────────────────────────
          if (job.toDo.trim().isNotEmpty) ...[
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
          ],

          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 8),

          // ── Action buttons ────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _textActionBtn(
                label:   'Verify',
                color:   const Color(0xFF2E7D32),
                bgColor: const Color(0xFFE8F5E9),
                icon:    Icons.verified_outlined,
                onTap:   () => _confirmAction(job, 'verify'),
              ),
              const SizedBox(width: 6),
              _textActionBtn(
                label:   'Reject',
                color:   AppColors.error,
                bgColor: const Color(0xFFFFF1F1),
                icon:    Icons.close_rounded,
                onTap:   () => _confirmAction(job, 'reject'),
              ),
              const SizedBox(width: 6),
              _textActionBtn(
                label:   'Extend',
                color:   AppColors.primary,
                bgColor: AppColors.primaryLight,
                icon:    Icons.update_rounded,
                onTap:   () => _confirmAction(job, 'extend'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 6),
        SizedBox(
          width: 72,
          child: Text(label,
              style: const TextStyle(
                  color:      AppColors.textMuted,
                  fontSize:   12,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: TextStyle(
                color:      valueColor ?? AppColors.textPrimary,
                fontSize:   12.5,
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _textActionBtn({
    required String       label,
    required Color        color,
    required Color        bgColor,
    required IconData     icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:        bgColor,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withOpacity(0.25), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color:      color,
                    fontSize:   11.5,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ── Skeleton ───────────────────────────────────────────────────────────────
  Widget _buildSkeletonList(double hPad) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 20),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => _skeletonCard(),
    );
  }

  Widget _skeletonCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _shimmer(width: 26, height: 26, radius: 7),
              const Spacer(),
              _shimmer(width: 60, height: 20, radius: 5),
            ],
          ),
          const SizedBox(height: 10),
          _shimmer(width: 140, height: 12, radius: 4),
          const SizedBox(height: 7),
          _shimmer(width: 110, height: 12, radius: 4),
          const SizedBox(height: 10),
          _shimmer(width: double.infinity, height: 44, radius: 8),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _shimmer(width: 64, height: 28, radius: 7),
              const SizedBox(width: 6),
              _shimmer(width: 64, height: 28, radius: 7),
              const SizedBox(width: 6),
              _shimmer(width: 64, height: 28, radius: 7),
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
        children: const [
          Icon(Icons.inbox_outlined, size: 56, color: AppColors.border),
          SizedBox(height: 14),
          Text('No tasks found for this project',
              style: TextStyle(
                  color:      AppColors.textSecondary,
                  fontSize:   14,
                  fontWeight: FontWeight.w500)),
          SizedBox(height: 6),
          Text('Tasks will appear here once assigned',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 12.5)),
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