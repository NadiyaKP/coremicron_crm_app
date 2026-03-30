import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/screens/home.dart';
import 'package:coremicron_crm_app/common/pagination.dart';
import 'package:coremicron_crm_app/common/string_extensions.dart';

// ── Attendance Model ───────────────────────────────────────────────────────
class _Attendance {
  final String id;
  final String employeeId;
  final String attendanceDate;
  final String attendanceTime;
  final String status;
  final String request;
  final String requestStatus;
  final String response;

  const _Attendance({
    required this.id,
    required this.employeeId,
    required this.attendanceDate,
    required this.attendanceTime,
    required this.status,
    required this.request,
    required this.requestStatus,
    required this.response,
  });

  factory _Attendance.fromJson(Map<String, dynamic> j) => _Attendance(
        id:             j['id']             ?? '',
        employeeId:     j['employee_id']    ?? '',
        attendanceDate: j['attendance_date'] ?? '',
        attendanceTime: j['attendance_time'] ?? '',
        status:         j['status']          ?? '',
        request:        j['request']         ?? '',
        requestStatus:  j['request_status']  ?? '',
        response:       j['response']        ?? '',
      );
}

// ── My Attendance Page ─────────────────────────────────────────────────────
class MyAttendancePage extends StatefulWidget {
  final String username;
  final String? highlightId;
  const MyAttendancePage({super.key, required this.username, this.highlightId});

  @override
  State<MyAttendancePage> createState() => _MyAttendancePageState();
}

class _MyAttendancePageState extends State<MyAttendancePage> {
  static const int _pageSize = 50;

  List<_Attendance> _all      = [];
  List<_Attendance> _filtered = [];
  bool              _isLoading = true;
  String?           _errorMessage;

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int    _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
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
      _filtered = _all.where((a) =>
          a.attendanceDate.contains(_searchQuery) ||
          a.attendanceTime.contains(_searchQuery) ||
          a.status.toLowerCase().contains(_searchQuery) ||
          a.requestStatus.toLowerCase().contains(_searchQuery)).toList();
    }
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchAttendance() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/attendance/list.php');

      debugPrint('📤  [MY ATTENDANCE] $url');
      final res = await ApiService.get(url)
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [MY ATTENDANCE] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        final list = data['attendance'] as List? ?? [];
        _all = list.map((e) => _Attendance.fromJson(e)).toList();
        _applyFilter();
      } else {
        _errorMessage =
            data['error'] ?? data['message'] ?? 'Failed to load attendance.';
      }
    } on http.ClientException {
      _errorMessage = 'Unable to reach the server. Check your connection.';
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Submit Request API ─────────────────────────────────────────────────────
  Future<void> _submitRequest({
    required String attendanceId,
    required String requestedDate,
    required String requestedTime,
    required String requestMessage,
  }) async {
    try {
      final url  = Uri.parse(
          '${ApiService.baseUrl}/api/attendance/request_create.php');
      final body = {
        'attendance_id':   attendanceId,
        'requested_date':  requestedDate,
        'requested_time':  requestedTime,
        'request_message': requestMessage,
      };

      debugPrint('📤  [SUBMIT REQUEST] $url  ${jsonEncode(body)}');
      final res = await ApiService.post(url, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [SUBMIT REQUEST] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Request submitted successfully.');
        _fetchAttendance();
      } else {
        AppSnackBar.show(
            context,
            data['error'] ?? data['message'] ?? 'Failed to submit request.',
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
  List<_Attendance> get _pageItems =>
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
    if (raw == null || raw.isEmpty || raw == 'null' || raw == '1000-01-01')
      return '—';
    try {
      final p = raw.trim().split('-');
      if (p.length == 3) return '${p[2]}-${p[1]}-${p[0]}';
    } catch (_) {}
    return raw;
  }

  String _fmtTime(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return '—';
    return raw.length >= 5 ? raw.substring(0, 5) : raw;
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'present':  return const Color(0xFF2E7D32);
      case 'absent':   return const Color(0xFFC62828);
      case 'late':     return const Color(0xFFE65100);
      default:         return AppColors.primary;
    }
  }

  Color _statusBg(String s) {
    switch (s.toLowerCase()) {
      case 'present':  return const Color(0xFFE8F5E9);
      case 'absent':   return const Color(0xFFFFF1F1);
      case 'late':     return const Color(0xFFFFF3E0);
      default:         return AppColors.primaryLight;
    }
  }

  Color _reqStatusColor(String s) {
    switch (s.toLowerCase()) {
      case 'approved':  return const Color(0xFF2E7D32);
      case 'rejected':  return const Color(0xFFC62828);
      case 'pending':   return const Color(0xFFE65100);
      default:          return AppColors.textMuted;
    }
  }

  Color _reqStatusBg(String s) {
    switch (s.toLowerCase()) {
      case 'approved':  return const Color(0xFFE8F5E9);
      case 'rejected':  return const Color(0xFFFFF1F1);
      case 'pending':   return const Color(0xFFFFF3E0);
      default:          return const Color(0xFFF5F5F5);
    }
  }

  // ── View Dialog ────────────────────────────────────────────────────────────
  void _showViewDialog(_Attendance a) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
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
                        borderRadius: BorderRadius.circular(11)),
                    child: const Icon(Icons.info_outline_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Attendance Details',
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

              // Request
              _dialogRow(Icons.notes_rounded, 'Request',
                  a.request.isEmpty ? '—' : a.request.capitalize()),
              const SizedBox(height: 8),

              // Response
              _dialogRow(Icons.reply_rounded, 'Response',
                  a.response.isEmpty ? '—' : a.response.capitalize()),
              const SizedBox(height: 8),

              // Request Status badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.flag_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 90,
                    child: Text('Request Status',
                        style: TextStyle(
                            color:      AppColors.textMuted,
                            fontSize:   12.5,
                            fontWeight: FontWeight.w500)),
                  ),
                  if (a.requestStatus.isEmpty)
                    const Text('—',
                        style: TextStyle(
                            color:      AppColors.textPrimary,
                            fontSize:   13,
                            fontWeight: FontWeight.w600))
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:        _reqStatusBg(a.requestStatus),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: _reqStatusColor(a.requestStatus)
                                .withOpacity(0.3),
                            width: 1),
                      ),
                      child: Text(a.requestStatus.capitalize(),
                          style: TextStyle(
                              color:      _reqStatusColor(a.requestStatus),
                              fontSize:   11,
                              fontWeight: FontWeight.w700)),
                    ),
                ],
              ),

              const SizedBox(height: 18),
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dCtx),
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
          width: 90,
          child: Text(label,
              style: const TextStyle(
                  color:      AppColors.textMuted,
                  fontSize:   12.5,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  color:      AppColors.textPrimary,
                  fontSize:   13,
                  fontWeight: FontWeight.w600,
                  height:     1.4)),
        ),
      ],
    );
  }

  // ── Submit Request Bottom Sheet ────────────────────────────────────────────
  void _showSubmitRequestSheet(_Attendance a) {
    DateTime? _reqDate;
    TimeOfDay? _reqTime;
    final messageCtrl = TextEditingController();
    bool isSaving = false;

    // Pre-fill from attendance record
    try {
      final dp = a.attendanceDate.split('-');
      if (dp.length == 3)
        _reqDate = DateTime(
            int.parse(dp[0]), int.parse(dp[1]), int.parse(dp[2]));
    } catch (_) {}
    try {
      final tp = a.attendanceTime.split(':');
      if (tp.length >= 2)
        _reqTime = TimeOfDay(
            hour: int.parse(tp[0]), minute: int.parse(tp[1]));
    } catch (_) {}

    final dateCtrl = TextEditingController(
        text: _reqDate != null ? _fmtDate(a.attendanceDate) : '');
    final timeCtrl = TextEditingController(
        text: _reqTime != null ? _fmtTime(a.attendanceTime) : '');

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
              initialDate: _reqDate ?? now,
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
                _reqDate      = picked;
                dateCtrl.text = _fmtDate(_toApiDate(picked));
              });
            }
          }

          Future<void> pickTime() async {
            final picked = await showTimePicker(
              context:     ctx,
              initialTime: _reqTime ?? TimeOfDay.now(),
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
                _reqTime      = picked;
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
                        child: Text('Submit Attendance Request',
                            style: TextStyle(
                                color:      AppColors.textPrimary,
                                fontSize:   15,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Requested Date
                  const Text('Requested Date',
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
                              color: _reqDate != null
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

                  const SizedBox(height: 14),

                  // Requested Time
                  const Text('Requested Time',
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
                              color: _reqTime != null
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

                  const SizedBox(height: 14),

                  // Request Message
                  const Text('Request Details',
                      style: TextStyle(
                          color:      AppColors.textLabel,
                          fontSize:   12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 7),
                  Container(
                    decoration: BoxDecoration(
                      color:        Colors.white,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                          color: AppColors.border, width: 1.2),
                    ),
                    child: TextField(
                      controller:  messageCtrl,
                      maxLines:    3,
                      minLines:    2,
                      cursorColor: AppColors.primary,
                      style: const TextStyle(
                          color:    AppColors.textPrimary,
                          fontSize: 13.5),
                      decoration: const InputDecoration(
                        hintText:
                            'Enter reason or details for the request…',
                        hintStyle: TextStyle(
                            color:    AppColors.textHint,
                            fontSize: 13),
                        border:         InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
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
                                  if (_reqDate == null) {
                                    AppSnackBar.show(context,
                                        'Please select a date.',
                                        isError: true);
                                    return;
                                  }
                                  if (_reqTime == null) {
                                    AppSnackBar.show(context,
                                        'Please select a time.',
                                        isError: true);
                                    return;
                                  }
                                  if (messageCtrl.text.trim().isEmpty) {
                                    AppSnackBar.show(context,
                                        'Please enter request details.',
                                        isError: true);
                                    return;
                                  }
                                  setS(() => isSaving = true);
                                  Navigator.pop(bCtx);
                                  await _submitRequest(
                                    attendanceId:   a.id,
                                    requestedDate:  _toApiDate(_reqDate!),
                                    requestedTime:  _toApiTime(_reqTime!),
                                    requestMessage: messageCtrl.text.trim(),
                                  );
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
                                    key:   ValueKey('sub-loader'),
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(
                                        color:       Colors.white,
                                        strokeWidth: 2.4))
                                : const Text('Submit',
                                    key: ValueKey('sub-label'),
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
                      '${_filtered.length} record'
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
              Text('My Attendance',
                  style: TextStyle(
                      color:         AppColors.textPrimary,
                      fontSize:      isTablet ? 20 : 17,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: -0.3)),
              const Text('Your attendance records',
                  style: TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 11.5)),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _fetchAttendance,
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
          hintText:  'Search by date, time, status…',
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
      itemBuilder: (_, i) => _attendanceCard(items[i]),
    );
  }

  // ── Card ───────────────────────────────────────────────────────────────────
  Widget _attendanceCard(_Attendance a) {
    final reqClr = _reqStatusColor(a.requestStatus);
    final reqBg  = _reqStatusBg(a.requestStatus);
    final bool isHighlighted = widget.highlightId == a.id;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          // ── Top row: date + request_status badge ──────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(_fmtDate(a.attendanceDate),
                      style: const TextStyle(
                          color:      AppColors.textPrimary,
                          fontSize:   13,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              if (a.requestStatus.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color:        reqBg,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                        color: reqClr.withOpacity(0.3), width: 1),
                  ),
                  child: Text(a.requestStatus.capitalize(),
                      style: TextStyle(
                          color:      reqClr,
                          fontSize:   10.5,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),

          const SizedBox(height: 6),

          // ── Time row ──────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.access_time_rounded,
                  size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(_fmtTime(a.attendanceTime),
                  style: const TextStyle(
                      color:      AppColors.textSecondary,
                      fontSize:   12.5,
                      fontWeight: FontWeight.w500)),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 7),

          // ── Bottom row: action buttons ────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // View
              _actionIcon(
                icon:    Icons.visibility_outlined,
                color:   AppColors.primary,
                bgColor: AppColors.primaryLight,
                onTap:   () => _showViewDialog(a),
              ),
              const SizedBox(width: 6),
              // Submit Request
              _actionIcon(
                icon:    Icons.send_outlined,
                color:   const Color(0xFF2E7D32),
                bgColor: const Color(0xFFE8F5E9),
                onTap:   () => _showSubmitRequestSheet(a),
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
            color: bgColor, borderRadius: BorderRadius.circular(7)),
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
              _shimmer(width: 100, height: 13, radius: 4),
              _shimmer(width: 56,  height: 20, radius: 5),
            ],
          ),
          const SizedBox(height: 7),
          _shimmer(width: 80, height: 12, radius: 4),
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
          const Icon(Icons.fingerprint_rounded,
              size: 56, color: AppColors.border),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No attendance records found',
            style: const TextStyle(
                color:      AppColors.textSecondary,
                fontSize:   14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Your attendance records will appear here',
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
            onPressed: _fetchAttendance,
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