import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService, kTokenKey;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/common/string_extensions.dart';

// ── Job Model ──────────────────────────────────────────────────────────────
class _Job {
  final String  jobId;
  final String  assignId;
  final String  assignName;
  final String  toDo;
  final String  fixbyDate;
  final String  completedDate;
  final String  verifiedDate;
  final String? image;
  final String  status;

  const _Job({
    required this.jobId,
    required this.assignId,
    required this.assignName,
    required this.toDo,
    required this.fixbyDate,
    required this.completedDate,
    required this.verifiedDate,
    this.image,
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
        image:         j['image'] as String?,
        status:        j['status']           ?? '',
      );
}

class MyProjectViewPage extends StatefulWidget {
  final String ticketId;
  final String ticketNumber;
  final String title;
  final String? highlightId;
  final String typeOfTicket;

  const MyProjectViewPage({
    super.key,
    required this.ticketId,
    required this.ticketNumber,
    this.title = '',
    this.highlightId,
    this.typeOfTicket = '',
  });

  @override
  State<MyProjectViewPage> createState() => _MyProjectViewPageState();
}

class _MyProjectViewPageState extends State<MyProjectViewPage> {
  List<_Job> _jobs        = [];
  bool       _isLoading   = true;
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
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/ticket/job_list.php'
          '?ticket_id=${widget.ticketId}');

      final res = await ApiService.get(url).timeout(const Duration(seconds: 15));

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
    } catch (e) {
      debugPrint('❌  [_fetchJobs] Error: $e');
      _errorMessage = 'Something went wrong. Please try again.';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Verify API ─────────────────────────────────────────────────────────────
  Future<void> _verifyJob(String jobId) async {
    try {
      final url  = Uri.parse(
          '${ApiService.baseUrl}/api/ticket/job_verify.php');
      final body = {'job_id': jobId, 'action': 'verify'};

      final res = await ApiService.post(url, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [JOB VERIFY] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Task verified successfully.');
        _fetchJobs();
      } else {
        AppSnackBar.show(
            context,
            data['error'] ?? data['message'] ?? 'Failed to verify.',
            isError: true);
      }
    } on http.ClientException {
      if (mounted)
        AppSnackBar.show(context, 'Unable to reach the server.', isError: true);
    } catch (e) {
      if (mounted) AppSnackBar.show(context, 'Error: $e', isError: true);
    }
  }

  // ── Reject API ─────────────────────────────────────────────────────────────
  Future<void> _rejectJob(String jobId, String reason) async {
    try {
      final url  = Uri.parse(
          '${ApiService.baseUrl}/api/ticket/job_verify.php');
      final body = {'job_id': jobId, 'action': 'reject', 'reason': reason};

      final res = await ApiService.post(url, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [JOB REJECT] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Task rejected.');
        _fetchJobs();
      } else {
        AppSnackBar.show(
            context,
            data['error'] ?? data['message'] ?? 'Failed to reject.',
            isError: true);
      }
    } on http.ClientException {
      if (mounted)
        AppSnackBar.show(context, 'Unable to reach the server.', isError: true);
    } catch (e) {
      if (mounted) AppSnackBar.show(context, 'Error: $e', isError: true);
    }
  }

  // ── Extend API ─────────────────────────────────────────────────────────────
  Future<void> _extendJob(String jobId, String newFixbyDate) async {
    try {
      final url  = Uri.parse(
          '${ApiService.baseUrl}/api/ticket/job_extend.php');
      final body = {'job_id': jobId, 'new_fixby_date': newFixbyDate};

      final res = await ApiService.post(url, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [JOB EXTEND] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Fix-by date extended successfully.');
        _fetchJobs();
      } else {
        AppSnackBar.show(
            context,
            data['error'] ?? data['message'] ?? 'Failed to extend.',
            isError: true);
      }
    } on http.ClientException {
      if (mounted)
        AppSnackBar.show(context, 'Unable to reach the server.', isError: true);
    } catch (e) {
      if (mounted) AppSnackBar.show(context, 'Error: $e', isError: true);
    }
  }

  // ── Verify Dialog ──────────────────────────────────────────────────────────
  void _showVerifyDialog(_Job job) {
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
                        color:        const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.verified_outlined,
                          color: Color(0xFF2E7D32), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Verify Task',
                          style: TextStyle(
                              color:      AppColors.textPrimary,
                              fontSize:   15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Before verifying, please make sure the work has been completed and notes are given. Do you want to proceed with verification?',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isLoading
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
                        onPressed: isLoading
                            ? null
                            : () async {
                                setS(() => isLoading = true);
                                Navigator.pop(dCtx);
                                await _verifyJob(job.jobId);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          disabledBackgroundColor:
                              const Color(0xFF2E7D32).withOpacity(0.5),
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
                                  key: ValueKey('v-loader'),
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.3))
                              : const Text('Verify',
                                  key: ValueKey('v-label'),
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

  // ── Reject Dialog ──────────────────────────────────────────────────────────
  void _showRejectDialog(_Job job) {
    final reasonCtrl = TextEditingController();
    bool isLoading   = false;
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
          content: SingleChildScrollView(
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
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: AppColors.error, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Reject Task',
                          style: TextStyle(
                              color:      AppColors.textPrimary,
                              fontSize:   15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Are you sure you want to reject?',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 12),
                // Ticket number
                Row(
                  children: [
                    const Icon(Icons.tag_rounded,
                        size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    const Text('Ticket No  ',
                        style: TextStyle(
                            color:      AppColors.textMuted,
                            fontSize:   12,
                            fontWeight: FontWeight.w500)),
                    Text(
                      '#${widget.ticketNumber}',
                      style: const TextStyle(
                          color:      AppColors.primary,
                          fontSize:   12.5,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Reason field
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
                        onPressed: isLoading
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
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (reasonCtrl.text.trim().isEmpty) {
                                  AppSnackBar.show(context,
                                      'Please enter a reason.',
                                      isError: true);
                                  return;
                                }
                                setS(() => isLoading = true);
                                Navigator.pop(dCtx);
                                await _rejectJob(
                                    job.jobId,
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
                          child: isLoading
                              ? const SizedBox(
                                  key: ValueKey('r-loader'),
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.3))
                              : const Text('Reject',
                                  key: ValueKey('r-label'),
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

  // ── Extend Dialog ──────────────────────────────────────────────────────────
  void _showExtendDialog(_Job job) {
    DateTime? _newDate;
    final dateCtrl = TextEditingController();
    bool isLoading = false;

    String _toApiDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
          content: SingleChildScrollView(
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
                        color:        AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.update_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Extend Deadline',
                          style: TextStyle(
                              color:      AppColors.textPrimary,
                              fontSize:   15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 12),
                // Ticket number
                Row(
                  children: [
                    const Icon(Icons.tag_rounded,
                        size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    const Text('Ticket No  ',
                        style: TextStyle(
                            color:      AppColors.textMuted,
                            fontSize:   12,
                            fontWeight: FontWeight.w500)),
                    Text('#${widget.ticketNumber}',
                        style: const TextStyle(
                            color:      AppColors.primary,
                            fontSize:   12.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                // Current fix by date
                Row(
                  children: [
                    const Icon(Icons.event_outlined,
                        size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    const Text('Current Fix By  ',
                        style: TextStyle(
                            color:      AppColors.textMuted,
                            fontSize:   12,
                            fontWeight: FontWeight.w500)),
                    Text(_fmtDate(job.fixbyDate),
                        style: const TextStyle(
                            color:      Color(0xFFE65100),
                            fontSize:   12.5,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 16),
                // New fix by date picker
                const Text('New Fix By Date *',
                    style: TextStyle(
                        color:      AppColors.textLabel,
                        fontSize:   12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 7),
                GestureDetector(
                  onTap: () async {
                    final now    = DateTime.now();
                    final picked = await showDatePicker(
                      context:     ctx,
                      initialDate: _newDate ?? now,
                      firstDate:   now,
                      lastDate:    DateTime(now.year + 5),
                      builder: (c, child) => Theme(
                        data: Theme.of(c).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary:   AppColors.primary,
                            onPrimary: Colors.white,
                            surface:   Colors.white,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setS(() {
                        _newDate      = picked;
                        dateCtrl.text = _fmtDate(_toApiDate(picked));
                      });
                    }
                  },
                  child: AbsorbPointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color:        Colors.white,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                            color: _newDate != null
                                ? AppColors.primary
                                : AppColors.border,
                            width: 1.2),
                      ),
                      child: TextField(
                        controller: dateCtrl,
                        style: const TextStyle(
                            color:      AppColors.textPrimary,
                            fontSize:   14,
                            fontWeight: FontWeight.w500),
                        decoration: const InputDecoration(
                          hintText:  'DD-MM-YYYY',
                          hintStyle: TextStyle(
                              color:    AppColors.textHint,
                              fontSize: 13.5),
                          prefixIcon: Icon(
                              Icons.calendar_today_outlined,
                              size: 17,
                              color: AppColors.iconDefault),
                          border:         InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isLoading
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
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (_newDate == null) {
                                  AppSnackBar.show(context,
                                      'Please select a new date.',
                                      isError: true);
                                  return;
                                }
                                setS(() => isLoading = true);
                                Navigator.pop(dCtx);
                                await _extendJob(
                                    job.jobId,
                                    _toApiDate(_newDate!));
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor:
                              AppColors.primary.withOpacity(0.5),
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
                                  key: ValueKey('e-loader'),
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.3))
                              : const Text('Extend',
                                  key: ValueKey('e-label'),
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
                  'Ticket #${widget.ticketNumber.isEmpty ? widget.ticketId : widget.ticketNumber}',
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
    final stClr       = _statusColor(job.status);
    final stBg        = _statusBg(job.status);
    final isVerified  = job.status.toLowerCase() == 'verified';
    final isRejected  = job.status.toLowerCase() == 'rejected';
    final hasImage    = job.image != null && job.image!.isNotEmpty;

    final bool isHighlighted = widget.highlightId == job.jobId;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isHighlighted ? AppColors.primary : AppColors.borderLight,
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
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              ),
            ),
          Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: fix-by (left) + status badge (right) ─────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.event_outlined,
                  size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('Fix by: ${_fmtDate(job.fixbyDate)}',
                  style: const TextStyle(
                      color:      Color(0xFFE65100),
                      fontSize:   12,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                  // Attachment link if image present
                  if (hasImage) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _showImageDialog(job.image!),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.attach_file_rounded,
                              size: 13,
                              color: AppColors.primary),
                          SizedBox(width: 4),
                          Text('attachment',
                              style: TextStyle(
                                  color:      AppColors.primary,
                                  fontSize:   12,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline)),
                        ],
                      ),
                    ),
                  ],
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
              // Verify — shown only when status is "Completed"
              if (job.status.toLowerCase() == 'completed')
                _textActionBtn(
                  label:   'Verify',
                  color:   const Color(0xFF2E7D32),
                  bgColor: const Color(0xFFE8F5E9),
                  icon:    Icons.verified_outlined,
                  onTap:   () => _showVerifyDialog(job),
                ),
              if (job.status.toLowerCase() == 'completed') const SizedBox(width: 6),
              // Reject — hidden when already rejected
              if (!isRejected)
                _textActionBtn(
                  label:   'Reject',
                  color:   AppColors.error,
                  bgColor: const Color(0xFFFFF1F1),
                  icon:    Icons.close_rounded,
                  onTap:   () => _showRejectDialog(job),
                ),
              if (!isRejected) const SizedBox(width: 6),
              // Extend — hidden for AMC
              if (widget.typeOfTicket.toUpperCase() != 'AMC')
                _textActionBtn(
                  label:   'Extend',
                  color:   AppColors.primary,
                  bgColor: AppColors.primaryLight,
                  icon:    Icons.update_rounded,
                  onTap:   () => _showExtendDialog(job),
                ),
            ],
          ),
        ],
      ),
        ],
      ),
    );
    
  }

  // ── Image Dialog ───────────────────────────────────────────────────────────
  void _showImageDialog(String imageUrl) {
    final fullUrl = imageUrl.startsWith('http')
        ? imageUrl
        : '${ApiService.baseUrl}/$imageUrl';

    showDialog(
      context: context,
      builder: (dCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  fullUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        color:        Colors.white,
                        borderRadius: BorderRadius.circular(14)),
                    child: const Text('Unable to load image.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  loadingBuilder: (_, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      decoration: BoxDecoration(
                          color:        Colors.white,
                          borderRadius: BorderRadius.circular(14)),
                      child: const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary, strokeWidth: 2.5),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(dCtx),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Close',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
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
              _shimmer(width: 90, height: 14, radius: 4),
              const Spacer(),
              _shimmer(width: 60, height: 20, radius: 5),
            ],
          ),
          const SizedBox(height: 10),
          _shimmer(width: 140, height: 12, radius: 4),
          const SizedBox(height: 10),
          _shimmer(width: double.infinity, height: 50, radius: 8),
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