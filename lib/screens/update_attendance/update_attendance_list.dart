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

// ── Attendance Request Model ───────────────────────────────────────────────
class _AttendanceRequest {
  final String requestId;
  final String attendanceId;
  final String employeeId;
  final String employeeName;
  final String requestedDate;
  final String requestedTime;
  final String requestMessage;
  final String status;
  final String adminResponse;
  final String createdAt;
  final String originalDate;
  final String originalTime;

  const _AttendanceRequest({
    required this.requestId,
    required this.attendanceId,
    required this.employeeId,
    required this.employeeName,
    required this.requestedDate,
    required this.requestedTime,
    required this.requestMessage,
    required this.status,
    required this.adminResponse,
    required this.createdAt,
    required this.originalDate,
    required this.originalTime,
  });

  factory _AttendanceRequest.fromJson(Map<String, dynamic> j) =>
      _AttendanceRequest(
        requestId:      j['request_id']      ?? '',
        attendanceId:   j['attendance_id']   ?? '',
        employeeId:     j['employee_id']     ?? '',
        employeeName:   j['employee_name']   ?? '',
        requestedDate:  j['requested_date']  ?? '',
        requestedTime:  j['requested_time']  ?? '',
        requestMessage: j['request_message'] ?? '',
        status:         j['status']          ?? '',
        adminResponse:  j['admin_response']  ?? '',
        createdAt:      j['created_at']      ?? '',
        originalDate:   j['original_date']   ?? '',
        originalTime:   j['original_time']   ?? '',
      );
}

// ── Update Attendance Page ─────────────────────────────────────────────────
class UpdateAttendancePage extends StatefulWidget {
  final String username;
  const UpdateAttendancePage({super.key, required this.username});

  @override
  State<UpdateAttendancePage> createState() => _UpdateAttendancePageState();
}

class _UpdateAttendancePageState extends State<UpdateAttendancePage> {
  static const int _pageSize = 50;

  List<_AttendanceRequest> _all      = [];
  List<_AttendanceRequest> _filtered = [];
  bool                     _isLoading = true;
  String?                  _errorMessage;

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int    _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
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
      _filtered = _all.where((r) =>
          r.employeeName.toLowerCase().contains(_searchQuery) ||
          r.requestMessage.toLowerCase().contains(_searchQuery) ||
          r.status.toLowerCase().contains(_searchQuery) ||
          r.originalDate.contains(_searchQuery) ||
          r.originalTime.contains(_searchQuery)).toList();
    }
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchRequests() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/attendance/request_list.php');

      final res = await ApiService.get(url).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [ATTENDANCE REQUESTS] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        final list = data['requests'] as List? ?? [];
        _all = list.map((e) => _AttendanceRequest.fromJson(e)).toList();
        _applyFilter();
      } else {
        _errorMessage =
            data['error'] ?? data['message'] ?? 'Failed to load requests.';
      }
    } on http.ClientException {
      _errorMessage = 'Unable to reach the server. Check your connection.';
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Action APIs ────────────────────────────────────────────────────────────
  Future<void> _requestAction(
      String requestId, String action, String reason) async {
    try {
      final url  = Uri.parse(
          '${ApiService.baseUrl}/api/attendance/request_action.php');
      final body = {
        'request_id': requestId,
        'reason':     reason,
        'action':     action,
      };

      final res = await ApiService.post(url, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [ATTENDANCE ACTION] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context,
            'Request ${action == 'reject' ? 'rejected' : 'deleted'} successfully.');
        _fetchRequests();
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

  Future<void> _updateRequest(
      String requestId, String approvedDate, String approvedTime) async {
    try {
      final url  = Uri.parse(
          '${ApiService.baseUrl}/api/attendance/request_update.php');
      final body = {
        'request_id':    requestId,
        'approved_date': approvedDate,
        'approved_time': approvedTime,
      };

      final res = await ApiService.post(url, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [ATTENDANCE UPDATE] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Attendance updated successfully.');
        _fetchRequests();
      } else {
        AppSnackBar.show(
            context,
            data['error'] ?? data['message'] ?? 'Failed to update.',
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
  List<_AttendanceRequest> get _pageItems =>
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

  String _fmtTime(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    return raw.length >= 5 ? raw.substring(0, 5) : raw;
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'approved':  return const Color(0xFF2E7D32);
      case 'rejected':  return const Color(0xFFC62828);
      case 'deleted':   return const Color(0xFF6A1B9A);
      case 'pending':   return const Color(0xFFE65100);
      default:          return AppColors.primary;
    }
  }

  Color _statusBg(String s) {
    switch (s.toLowerCase()) {
      case 'approved':  return const Color(0xFFE8F5E9);
      case 'rejected':  return const Color(0xFFFFF1F1);
      case 'deleted':   return const Color(0xFFF3E5F5);
      case 'pending':   return const Color(0xFFFFF3E0);
      default:          return AppColors.primaryLight;
    }
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────
  void _showViewDialog(_AttendanceRequest r) {
    showDialog(
      context: context,
      builder: (dCtx) => _PunchTableDialog(
        request:       r,
        fmtDate:       _fmtDate,
        fmtTime:       _fmtTime,
        sessionKey:    kTokenKey,
        onClose:       () { Navigator.pop(dCtx); _fetchRequests(); },
      ),
    );
  }

  void _showRejectDialog(_AttendanceRequest r) {
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
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                          color:        const Color(0xFFFFF1F1),
                          borderRadius: BorderRadius.circular(11)),
                      child: const Icon(Icons.cancel_outlined,
                          color: AppColors.error, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Reject Request',
                          style: TextStyle(
                              color:      AppColors.textPrimary,
                              fontSize:   15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Are you sure you want to reject this attendance update request?',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 12),
                _dialogRow(Icons.person_outline_rounded,
                    'Employee', r.employeeName.capitalize()),
                const SizedBox(height: 7),
                _dialogRow(Icons.calendar_today_outlined,
                    'Att. Date', _fmtDate(r.originalDate)),
                const SizedBox(height: 7),
                _dialogRow(Icons.access_time_rounded,
                    'Att. Time', _fmtTime(r.originalTime)),
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
                                await _requestAction(
                                    r.requestId,
                                    'reject',
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

  void _showDeleteDialog(_AttendanceRequest r) {
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
                      child: Text('Delete Request',
                          style: TextStyle(
                              color:      AppColors.textPrimary,
                              fontSize:   15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Are you sure you want to delete this attendance update request? This cannot be undone.',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 12),
                _dialogRow(Icons.person_outline_rounded,
                    'Employee', r.employeeName.capitalize()),
                const SizedBox(height: 7),
                _dialogRow(Icons.calendar_today_outlined,
                    'Att. Date', _fmtDate(r.originalDate)),
                const SizedBox(height: 7),
                _dialogRow(Icons.access_time_rounded,
                    'Att. Time', _fmtTime(r.originalTime)),
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
                      hintText:  'Enter reason for deletion…',
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
                                await _requestAction(
                                    r.requestId,
                                    'delete',
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
                                  key: ValueKey('del-loader'),
                                  width: 18, height: 18,
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

  void _showEditBottomSheet(_AttendanceRequest r) {
    DateTime?  _newDate;
    TimeOfDay? _newTime;

    // Pre-fill from requestedDate / requestedTime
    try {
      final dp = r.requestedDate.split('-');
      if (dp.length == 3)
        _newDate = DateTime(
            int.parse(dp[0]), int.parse(dp[1]), int.parse(dp[2]));
    } catch (_) {}
    try {
      final tp = r.requestedTime.split(':');
      if (tp.length >= 2)
        _newTime = TimeOfDay(
            hour: int.parse(tp[0]), minute: int.parse(tp[1]));
    } catch (_) {}

    final dateCtrl = TextEditingController(
        text: _newDate != null ? _fmtDate(r.requestedDate) : '');
    final timeCtrl = TextEditingController(
        text: _newTime != null ? _fmtTime(r.requestedTime) : '');
    bool isSaving = false;

    String _toApiDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    String _toApiTime(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (bCtx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> pickDate() async {
            final now    = DateTime.now();
            final picked = await showDatePicker(
              context:     ctx,
              initialDate: _newDate ?? now,
              firstDate:   DateTime(now.year - 5),
              lastDate:    now,
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
          }

          Future<void> pickTime() async {
            final picked = await showTimePicker(
              context:     ctx,
              initialTime: _newTime ?? TimeOfDay.now(),
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
                _newTime      = picked;
                timeCtrl.text =
                    '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(22)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color:        AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Title
                  Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color:        AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.edit_calendar_outlined,
                            size: 18, color: AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Edit Attendance Request',
                            style: TextStyle(
                                color:      AppColors.textPrimary,
                                fontSize:   15,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Employee Name (readonly)
                  const Text('Employee Name',
                      style: TextStyle(
                          color:      AppColors.textLabel,
                          fontSize:   12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 7),
                  Container(
                    decoration: BoxDecoration(
                      color:        AppColors.background,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                          color: AppColors.borderLight, width: 1.2),
                    ),
                    child: TextField(
                      controller: TextEditingController(
                          text: r.employeeName.capitalize()),
                      readOnly:    true,
                      style: const TextStyle(
                          color:      AppColors.textSecondary,
                          fontSize:   14,
                          fontWeight: FontWeight.w500),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_outline_rounded,
                            size: 17, color: AppColors.iconDefault),
                        border:         InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Date
                  const Text('Date',
                      style: TextStyle(
                          color:      AppColors.textLabel,
                          fontSize:   12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 7),
                  GestureDetector(
                    onTap: pickDate,
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
                                size: 17, color: AppColors.iconDefault),
                            border:         InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Time
                  const Text('Time',
                      style: TextStyle(
                          color:      AppColors.textLabel,
                          fontSize:   12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 7),
                  GestureDetector(
                    onTap: pickTime,
                    child: AbsorbPointer(
                      child: Container(
                        decoration: BoxDecoration(
                          color:        Colors.white,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                              color: _newTime != null
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: 1.2),
                        ),
                        child: TextField(
                          controller: timeCtrl,
                          style: const TextStyle(
                              color:      AppColors.textPrimary,
                              fontSize:   14,
                              fontWeight: FontWeight.w500),
                          decoration: const InputDecoration(
                            hintText:  'HH:MM',
                            hintStyle: TextStyle(
                                color:    AppColors.textHint,
                                fontSize: 13.5),
                            prefixIcon: Icon(Icons.access_time_rounded,
                                size: 17, color: AppColors.iconDefault),
                            border:         InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSaving
                              ? null
                              : () => Navigator.pop(bCtx),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: AppColors.border, width: 1.3),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11)),
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                          ),
                          child: const Text('Cancel',
                              style: TextStyle(
                                  color:      AppColors.textLabel,
                                  fontWeight: FontWeight.w600,
                                  fontSize:   14)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (_newDate == null) {
                                    AppSnackBar.show(context,
                                        'Please select a date.',
                                        isError: true);
                                    return;
                                  }
                                  if (_newTime == null) {
                                    AppSnackBar.show(context,
                                        'Please select a time.',
                                        isError: true);
                                    return;
                                  }
                                  setS(() => isSaving = true);
                                  Navigator.pop(bCtx);
                                  await _updateRequest(
                                      r.requestId,
                                      _toApiDate(_newDate!),
                                      _toApiTime(_newTime!));
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor:
                                AppColors.primary.withOpacity(0.45),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11)),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: isSaving
                                ? const SizedBox(
                                    key:   ValueKey('upd-loader'),
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                        color:       Colors.white,
                                        strokeWidth: 2.4))
                                : const Text('Update',
                                    key: ValueKey('upd-label'),
                                    style: TextStyle(
                                        color:      Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize:   14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Dialog helper ──────────────────────────────────────────────────────────
  Widget _dialogRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 8),
        SizedBox(
          width: 76,
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
                      '${_filtered.length} request'
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
              Text('Update Attendance',
                  style: TextStyle(
                      color:         AppColors.textPrimary,
                      fontSize:      isTablet ? 20 : 17,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: -0.3)),
              const Text('Attendance update requests',
                  style: TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 11.5)),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _fetchRequests,
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
          hintText:  'Search by employee, message, status…',
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
      itemBuilder: (_, i) => _requestCard(items[i]),
    );
  }

  // ── Card ───────────────────────────────────────────────────────────────────
  Widget _requestCard(_AttendanceRequest r) {
    final statusClr = _statusColor(r.status);
    final statusBg  = _statusBg(r.status);

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
          // ── Top row: employee name + status badge ──────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  r.employeeName.capitalize(),
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
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        statusBg,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: statusClr.withOpacity(0.3), width: 1),
                ),
                child: Text(r.status.capitalize(),
                    style: TextStyle(
                        color:      statusClr,
                        fontSize:   10.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ── Att. Date + Att. Time ──────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('Att. Date  ',
                  style: const TextStyle(
                      color:    AppColors.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500)),
              Text(_fmtDate(r.originalDate),
                  style: const TextStyle(
                      color:      AppColors.textSecondary,
                      fontSize:   12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 14),
              const Icon(Icons.access_time_rounded,
                  size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('Att. Time  ',
                  style: const TextStyle(
                      color:    AppColors.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500)),
              Text(_fmtTime(r.originalTime),
                  style: const TextStyle(
                      color:      AppColors.textSecondary,
                      fontSize:   12,
                      fontWeight: FontWeight.w600)),
            ],
          ),

          // ── Request message ────────────────────────────────────────────
          if (r.requestMessage.trim().isNotEmpty) ...[
            const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_rounded,
                    size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    r.requestMessage.trim().capitalize(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color:    AppColors.textMuted,
                        fontSize: 12,
                        height:   1.4),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 7),

          // ── Bottom row: action buttons right-aligned ───────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // View
              _actionIcon(
                icon:    Icons.visibility_outlined,
                color:   AppColors.primary,
                bgColor: AppColors.primaryLight,
                onTap:   () => _showViewDialog(r),
              ),
              const SizedBox(width: 6),
              // Edit
              _actionIcon(
                icon:    Icons.edit_outlined,
                color:   const Color(0xFF0277BD),
                bgColor: const Color(0xFFE1F5FE),
                onTap:   () => _showEditBottomSheet(r),
              ),
              const SizedBox(width: 6),
              // Reject
              _actionIcon(
                icon:    Icons.cancel_outlined,
                color:   AppColors.error,
                bgColor: const Color(0xFFFFF1F1),
                onTap:   () => _showRejectDialog(r),
              ),
              const SizedBox(width: 6),
              // Delete
              _actionIcon(
                icon:    Icons.delete_outline_rounded,
                color:   AppColors.error,
                bgColor: const Color(0xFFFFF1F1),
                onTap:   () => _showDeleteDialog(r),
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
              _shimmer(width: 130, height: 14, radius: 4),
              _shimmer(width: 60,  height: 20, radius: 5),
            ],
          ),
          const SizedBox(height: 8),
          _shimmer(width: double.infinity, height: 12, radius: 4),
          const SizedBox(height: 6),
          _shimmer(width: 200, height: 11, radius: 4),
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
          const Icon(Icons.update_outlined,
              size: 56, color: AppColors.border),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No attendance requests found',
            style: const TextStyle(
                color:      AppColors.textSecondary,
                fontSize:   14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Attendance update requests will appear here',
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
            onPressed: _fetchRequests,
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

// ── Punch Table Dialog ─────────────────────────────────────────────────────
class _PunchTableDialog extends StatefulWidget {
  final _AttendanceRequest request;
  final String Function(String?) fmtDate;
  final String Function(String?) fmtTime;
  final String sessionKey;
  final VoidCallback onClose;

  const _PunchTableDialog({
    required this.request,
    required this.fmtDate,
    required this.fmtTime,
    required this.sessionKey,
    required this.onClose,
  });

  @override
  State<_PunchTableDialog> createState() => _PunchTableDialogState();
}

class _PunchTableDialogState extends State<_PunchTableDialog> {
  List<String> _punches  = [];
  bool         _loading  = true;
  String?      _error;

  @override
  void initState() {
    super.initState();
    _fetchPunches();
  }

  Future<void> _fetchPunches() async {
    setState(() { _loading = true; _error = null; });
    try {
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/attendance/request_view.php'
          '?date=${widget.request.originalDate}'
          '&employee_id=${widget.request.employeeId}');

      final res = await ApiService.get(url).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [ATTENDANCE VIEW] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        final list = data['punches'] as List? ?? [];
        _punches = list
            .map((e) => (e['attendance_time'] ?? '') as String)
            .toList();
      } else {
        _error = data['error'] ?? data['message'] ?? 'Failed to load.';
      }
    } on http.ClientException {
      _error = 'Unable to reach the server.';
    } catch (e) {
      _error = 'Error: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  String _fmtPunchTime(String raw) {
    if (raw.isEmpty) return '—';
    return raw.length >= 5 ? raw.substring(0, 5) : raw;
  }

  @override
  Widget build(BuildContext context) {
    final displayDate = widget.fmtDate(widget.request.originalDate);

    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      contentPadding: EdgeInsets.zero,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
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
                      borderRadius: BorderRadius.circular(11)),
                  child: const Icon(Icons.fingerprint_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Attendance Punches',
                      style: TextStyle(
                          color:      AppColors.textPrimary,
                          fontSize:   15,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Employee name
            Text(
              widget.request.employeeName.capitalize(),
              style: const TextStyle(
                  color:      AppColors.textSecondary,
                  fontSize:   13,
                  fontWeight: FontWeight.w500),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 12),

            // Body
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2.5),
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_error!,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 13)),
              )
            else if (_punches.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('No punch records found for this date.',
                      style: TextStyle(
                          color:    AppColors.textMuted,
                          fontSize: 13)),
                ),
              )
            else
              // Table
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.borderLight, width: 1),
                ),
                clipBehavior: Clip.hardEdge,
                child: Table(
                  columnWidths: const {
                    0: FixedColumnWidth(42),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(1),
                  },
                  border: TableBorder(
                    horizontalInside: BorderSide(
                        color: AppColors.borderLight, width: 1),
                  ),
                  children: [
                    // Header row
                    TableRow(
                      decoration: const BoxDecoration(
                          color: AppColors.primaryLight),
                      children: [
                        _tableCell('Sl.No', isHeader: true),
                        _tableCell('Date',  isHeader: true),
                        _tableCell('Time',  isHeader: true),
                      ],
                    ),
                    // Data rows
                    ..._punches.asMap().entries.map((entry) {
                      final i    = entry.key;
                      final time = entry.value;
                      return TableRow(
                        decoration: BoxDecoration(
                          color: i.isEven
                              ? Colors.white
                              : const Color(0xFFF8FAFF),
                        ),
                        children: [
                          _tableCell('${i + 1}'),
                          _tableCell(displayDate),
                          _tableCell(_fmtPunchTime(time)),
                        ],
                      );
                    }),
                  ],
                ),
              ),

            const SizedBox(height: 18),

            Center(
              child: ElevatedButton(
                onPressed: widget.onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 9),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
                child: const Text('Close',
                    style: TextStyle(
                        color:      Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize:   13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
            color:      isHeader
                ? AppColors.primary
                : AppColors.textPrimary,
            fontSize:   isHeader ? 11.5 : 12.5,
            fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500),
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