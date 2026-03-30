import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService, kTokenKey;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/common/pagination.dart';
import 'package:coremicron_crm_app/screens/home.dart';
import 'package:coremicron_crm_app/common/string_extensions.dart';
import 'package:coremicron_crm_app/screens/to-do/leave_application/pending_tasks_view.dart';

// ── Leave Application Model ────────────────────────────────────────────────
class _LeaveApplication {
  final String leaveId;
  final String employeeId;
  final String employeeName;
  final String typeOfAbsence;
  final String reason;
  final String absenceFrom;
  final String absenceThrough;
  final String status;
  final String addedDate;
  final String addedTime;

  const _LeaveApplication({
    required this.leaveId,
    required this.employeeId,
    required this.employeeName,
    required this.typeOfAbsence,
    required this.reason,
    required this.absenceFrom,
    required this.absenceThrough,
    required this.status,
    required this.addedDate,
    required this.addedTime,
  });

  factory _LeaveApplication.fromJson(Map<String, dynamic> j) =>
      _LeaveApplication(
        leaveId:        j['leave_id']         ?? '',
        employeeId:     j['employee_id']       ?? '',
        employeeName:   j['employee_name']     ?? '',
        typeOfAbsence:  j['type_of_absence']   ?? '',
        reason:         j['reason']            ?? '',
        absenceFrom:    j['absence_from']      ?? '',
        absenceThrough: j['absence_through']   ?? '',
        status:         j['status']            ?? '',
        addedDate:      j['added_date']        ?? '',
        addedTime:      j['added_time']        ?? '',
      );
}

// ── Leave Applications Page ────────────────────────────────────────────────
class LeaveApplicationsPage extends StatefulWidget {
  final String username;
  final String? highlightId;
  const LeaveApplicationsPage({super.key, required this.username, this.highlightId});

  @override
  State<LeaveApplicationsPage> createState() => _LeaveApplicationsPageState();
}

class _LeaveApplicationsPageState extends State<LeaveApplicationsPage> {
  static const int _pageSize = 50;

  List<_LeaveApplication> _all      = [];
  List<_LeaveApplication> _filtered = [];
  bool                    _isLoading = true;
  String?                 _errorMessage;

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
          l.employeeName.toLowerCase().contains(_searchQuery) ||
          l.typeOfAbsence.toLowerCase().contains(_searchQuery) ||
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
          '${ApiService.baseUrl}/api/attendance/leave_list.php?mode=all');
      final res = await ApiService.get(url).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [LEAVE LIST] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        final list = data['leave_applications'] as List? ?? [];
        _all = list.map((e) => _LeaveApplication.fromJson(e)).toList();
        _applyFilter();
      } else {
        _errorMessage =
            data['error'] ?? data['message'] ?? 'Failed to load leave applications.';
      }
    } on http.ClientException {
      _errorMessage = 'Unable to reach the server. Check your connection.';
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Action APIs ────────────────────────────────────────────────────────────
  Future<void> _leaveAction(String leaveId, String action) async {
    try {
      final url  = Uri.parse(
          '${ApiService.baseUrl}/api/attendance/leave_action.php');
      final body = {'leave_id': leaveId, 'action': action};
      final res = await ApiService.post(url, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [LEAVE ACTION] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context,
            'Leave ${action == 'approve' ? 'approved' : 'rejected'} successfully.');
        _fetchLeaves();
      } else {
        AppSnackBar.show(
            context,
            data['error'] ?? data['message'] ?? 'Operation failed.',
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

  Future<void> _deleteLeave(String leaveId) async {
    try {
      final url  = Uri.parse(
          '${ApiService.baseUrl}/api/attendance/leave_delete.php');
      final body = {'leave_id': leaveId};
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
        AppSnackBar.show(context, 'Unable to reach the server.',
            isError: true);
    } catch (e) {
      if (mounted)
        AppSnackBar.show(context, 'Error: $e', isError: true);
    }
  }

  Future<void> _updateLeave(
      String leaveId, String absenceFrom, String absenceThrough) async {
    try {
      final url  = Uri.parse(
          '${ApiService.baseUrl}/api/attendance/leave_update.php');
      final body = {
        'leave_id':        leaveId,
        'absence_from':    absenceFrom,
        'absence_through': absenceThrough,
      };
      final res = await ApiService.post(url, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [LEAVE UPDATE] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Leave dates updated successfully.');
        _fetchLeaves();
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
  List<_LeaveApplication> get _pageItems =>
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
      case 'approved': return const Color(0xFF2E7D32);
      case 'rejected': return const Color(0xFFC62828);
      case 'waiting':  return const Color(0xFFE65100);
      default:         return AppColors.primary;
    }
  }

  Color _statusBg(String s) {
    switch (s.toLowerCase()) {
      case 'approved': return const Color(0xFFE8F5E9);
      case 'rejected': return const Color(0xFFFFF1F1);
      case 'waiting':  return const Color(0xFFFFF3E0);
      default:         return AppColors.primaryLight;
    }
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────
  void _showApproveDialog(_LeaveApplication l) {
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
                _dialogHeader(
                    icon:    Icons.check_circle_outline_rounded,
                    iconBg:  const Color(0xFFE8F5E9),
                    iconClr: const Color(0xFF2E7D32),
                    title:   'Approve Leave'),
                const SizedBox(height: 12),
                const Text(
                  'Are you sure you want to approve this leave application?',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 12),
                _dialogRow(Icons.person_outline_rounded,
                    'Employee', l.employeeName.capitalize()),
                const SizedBox(height: 7),
                _dialogRow(Icons.event_note_outlined,
                    'Type', l.typeOfAbsence.capitalize()),
                const SizedBox(height: 7),
                _dialogRow(Icons.date_range_outlined,
                    'Period',
                    '${_fmtDate(l.absenceFrom)}  →  ${_fmtDate(l.absenceThrough)}'),
                const SizedBox(height: 20),
                _dialogButtons(
                  dCtx:      dCtx,
                  isLoading: isLoading,
                  setS:      setS,
                  confirmLabel: 'Approve',
                  confirmColor: const Color(0xFF2E7D32),
                  onConfirm: () async {
                    setS(() => isLoading = true);
                    Navigator.pop(dCtx);
                    await _leaveAction(l.leaveId, 'approve');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRejectDialog(_LeaveApplication l) {
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
                _dialogHeader(
                    icon:    Icons.cancel_outlined,
                    iconBg:  const Color(0xFFFFF1F1),
                    iconClr: AppColors.error,
                    title:   'Reject Leave'),
                const SizedBox(height: 12),
                const Text(
                  'Are you sure you want to reject this leave application?',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 12),
                _dialogRow(Icons.person_outline_rounded,
                    'Employee', l.employeeName.capitalize()),
                const SizedBox(height: 7),
                _dialogRow(Icons.event_note_outlined,
                    'Type', l.typeOfAbsence.capitalize()),
                const SizedBox(height: 7),
                _dialogRow(Icons.date_range_outlined,
                    'Period',
                    '${_fmtDate(l.absenceFrom)}  →  ${_fmtDate(l.absenceThrough)}'),
                const SizedBox(height: 20),
                _dialogButtons(
                  dCtx:         dCtx,
                  isLoading:    isLoading,
                  setS:         setS,
                  confirmLabel: 'Reject',
                  confirmColor: AppColors.error,
                  onConfirm: () async {
                    setS(() => isLoading = true);
                    Navigator.pop(dCtx);
                    await _leaveAction(l.leaveId, 'reject');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(_LeaveApplication l) {
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
                _dialogHeader(
                    icon:    Icons.delete_outline_rounded,
                    iconBg:  const Color(0xFFFFF1F1),
                    iconClr: AppColors.error,
                    title:   'Delete Application'),
                const SizedBox(height: 12),
                const Text(
                  'Are you sure you want to delete this leave application? This action cannot be undone.',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 12),
                _dialogRow(Icons.person_outline_rounded,
                    'Employee', l.employeeName.capitalize()),
                const SizedBox(height: 7),
                _dialogRow(Icons.event_note_outlined,
                    'Type', l.typeOfAbsence.capitalize()),
                const SizedBox(height: 20),
                _dialogButtons(
                  dCtx:         dCtx,
                  isLoading:    isLoading,
                  setS:         setS,
                  confirmLabel: 'Delete',
                  confirmColor: AppColors.error,
                  onConfirm: () async {
                    setS(() => isLoading = true);
                    Navigator.pop(dCtx);
                    await _deleteLeave(l.leaveId);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showViewDialog(_LeaveApplication l) {
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
              _dialogHeader(
                  icon:    Icons.info_outline_rounded,
                  iconBg:  AppColors.primaryLight,
                  iconClr: AppColors.primary,
                  title:   'Leave Details'),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.borderLight),
              const SizedBox(height: 12),
              _dialogRow(Icons.person_outline_rounded,
                  'Employee', l.employeeName.capitalize()),
              const SizedBox(height: 8),
              _dialogRow(Icons.event_note_outlined,
                  'Type', l.typeOfAbsence.capitalize()),
              const SizedBox(height: 8),
              _dialogRow(Icons.calendar_today_outlined,
                  'From', _fmtDate(l.absenceFrom)),
              const SizedBox(height: 8),
              _dialogRow(Icons.calendar_today_outlined,
                  'Through', _fmtDate(l.absenceThrough)),
              if (l.reason.isNotEmpty) ...[
                const SizedBox(height: 8),
                _dialogRow(Icons.notes_rounded,
                    'Reason', l.reason),
              ],
              const SizedBox(height: 8),
              _dialogRow(Icons.access_time_rounded,
                  'Applied', '${_fmtDate(l.addedDate)}  ${l.addedTime.length >= 5 ? l.addedTime.substring(0, 5) : l.addedTime}'),
              const SizedBox(height: 8),
              // Status badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.flag_outlined,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 76,
                    child: const Text('Status',
                        style: TextStyle(
                            color:      AppColors.textMuted,
                            fontSize:   12.5,
                            fontWeight: FontWeight.w500)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:        _statusBg(l.status),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                          color: _statusColor(l.status).withOpacity(0.3),
                          width: 1),
                    ),
                    child: Text(l.status.capitalize(),
                        style: TextStyle(
                            color:      _statusColor(l.status),
                            fontSize:   11,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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

  // ── Edit bottom sheet ──────────────────────────────────────────────────────
  void _showEditBottomSheet(_LeaveApplication l) {
    // Parse stored YYYY-MM-DD into DateTime
    DateTime? _fromDate;
    DateTime? _throughDate;
    try {
      final fp = l.absenceFrom.split('-');
      if (fp.length == 3)
        _fromDate = DateTime(
            int.parse(fp[0]), int.parse(fp[1]), int.parse(fp[2]));
    } catch (_) {}
    try {
      final tp = l.absenceThrough.split('-');
      if (tp.length == 3)
        _throughDate = DateTime(
            int.parse(tp[0]), int.parse(tp[1]), int.parse(tp[2]));
    } catch (_) {}

    final fromCtrl    = TextEditingController(
        text: _fromDate != null ? _fmtDate(l.absenceFrom) : '');
    final throughCtrl = TextEditingController(
        text: _throughDate != null ? _fmtDate(l.absenceThrough) : '');
    bool isSaving = false;

    String _toApiDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (bCtx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> pickDate({required bool isFrom}) async {
            final now    = DateTime.now();
            final init   = isFrom
                ? (_fromDate ?? now)
                : (_throughDate ?? _fromDate ?? now);
            final picked = await showDatePicker(
              context:     ctx,
              initialDate: init,
              firstDate:   DateTime(now.year - 2),
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
                if (isFrom) {
                  _fromDate     = picked;
                  fromCtrl.text = _fmtDate(_toApiDate(picked));
                } else {
                  _throughDate     = picked;
                  throughCtrl.text = _fmtDate(_toApiDate(picked));
                }
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(22)),
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
                        child: Text('Edit Leave Application Dates',
                            style: TextStyle(
                                color:      AppColors.textPrimary,
                                fontSize:   15,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Absence From
                  const Text('Absence From',
                      style: TextStyle(
                          color:      AppColors.textLabel,
                          fontSize:   12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 7),
                  GestureDetector(
                    onTap: () => pickDate(isFrom: true),
                    child: AbsorbPointer(
                      child: Container(
                        decoration: BoxDecoration(
                          color:        Colors.white,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                              color: _fromDate != null
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: 1.2),
                        ),
                        child: TextField(
                          controller: fromCtrl,
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

                  // Absence Through
                  const Text('Absence Through',
                      style: TextStyle(
                          color:      AppColors.textLabel,
                          fontSize:   12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 7),
                  GestureDetector(
                    onTap: () => pickDate(isFrom: false),
                    child: AbsorbPointer(
                      child: Container(
                        decoration: BoxDecoration(
                          color:        Colors.white,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                              color: _throughDate != null
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: 1.2),
                        ),
                        child: TextField(
                          controller: throughCtrl,
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
                                  if (_fromDate == null) {
                                    AppSnackBar.show(context,
                                        'Please select Absence From date.',
                                        isError: true);
                                    return;
                                  }
                                  if (_throughDate == null) {
                                    AppSnackBar.show(context,
                                        'Please select Absence Through date.',
                                        isError: true);
                                    return;
                                  }
                                  setS(() => isSaving = true);
                                  Navigator.pop(bCtx);
                                  await _updateLeave(
                                      l.leaveId,
                                      _toApiDate(_fromDate!),
                                      _toApiDate(_throughDate!));
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

  // ── Dialog helper widgets ──────────────────────────────────────────────────
  Widget _dialogHeader({
    required IconData icon,
    required Color    iconBg,
    required Color    iconClr,
    required String   title,
  }) {
    return Row(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: iconBg, borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, color: iconClr, size: 20),
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
    );
  }

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

  Widget _dialogButtons({
    required BuildContext dCtx,
    required bool         isLoading,
    required StateSetter  setS,
    required String       confirmLabel,
    required Color        confirmColor,
    required Future<void> Function() onConfirm,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: isLoading ? null : () => Navigator.pop(dCtx),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border, width: 1.3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11)),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
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
            onPressed: isLoading ? null : onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor:        confirmColor,
              disabledBackgroundColor: confirmColor.withOpacity(0.5),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
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
                          color: Colors.white, strokeWidth: 2.3))
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
                      '${_filtered.length} application'
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
              Text('Leave Applications',
                  style: TextStyle(
                      color:         AppColors.textPrimary,
                      fontSize:      isTablet ? 20 : 17,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: -0.3)),
              const Text('All leave requests',
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
          hintText:  'Search by employee, type, status…',
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
  Widget _leaveCard(_LeaveApplication l) {
    final statusClr  = _statusColor(l.status);
    final statusBg   = _statusBg(l.status);
    final isApproved = l.status.toLowerCase() == 'approved';
    final isRejected = l.status.toLowerCase() == 'rejected';
    // waiting = show all icons; approved = view + reject only; rejected = view + approve only
    final showEdit    = !isApproved && !isRejected;
    final showDelete  = !isApproved && !isRejected;
    final showApprove = !isApproved;
    final showReject  = !isRejected;
    final showPending = !isApproved && !isRejected;
    final bool isHighlighted = widget.highlightId == l.leaveId;

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
          // ── Top row: employee name + status badge ──────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l.employeeName.capitalize(),
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
                child: Text(l.status.capitalize(),
                    style: TextStyle(
                        color:      statusClr,
                        fontSize:   10.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ── Type of absence ────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.event_note_outlined,
                  size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(l.typeOfAbsence.capitalize(),
                  style: const TextStyle(
                      color:      AppColors.textSecondary,
                      fontSize:   12.5,
                      fontWeight: FontWeight.w500)),
            ],
          ),

          const SizedBox(height: 5),

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

          // ── Bottom row: action buttons right-aligned ───────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // View
              _actionIcon(
                icon:    Icons.visibility_outlined,
                color:   AppColors.primary,
                bgColor: AppColors.primaryLight,
                onTap:   () => _showViewDialog(l),
              ),
              if (showEdit) ...[
                const SizedBox(width: 6),
                _actionIcon(
                  icon:    Icons.edit_outlined,
                  color:   const Color(0xFF0277BD),
                  bgColor: const Color(0xFFE1F5FE),
                  onTap:   () => _showEditBottomSheet(l),
                ),
              ],
              if (showDelete) ...[
                const SizedBox(width: 6),
                _actionIcon(
                  icon:    Icons.delete_outline_rounded,
                  color:   AppColors.error,
                  bgColor: const Color(0xFFFFF1F1),
                  onTap:   () => _showDeleteDialog(l),
                ),
              ],
              if (showApprove) ...[
                const SizedBox(width: 6),
                _actionIcon(
                  icon:    Icons.check_circle_outline_rounded,
                  color:   const Color(0xFF2E7D32),
                  bgColor: const Color(0xFFE8F5E9),
                  onTap:   () => _showApproveDialog(l),
                ),
              ],
              if (showReject) ...[
                const SizedBox(width: 6),
                _actionIcon(
                  icon:    Icons.cancel_outlined,
                  color:   AppColors.error,
                  bgColor: const Color(0xFFFFF1F1),
                  onTap:   () => _showRejectDialog(l),
                ),
              ],
              if (showPending) ...[
                const SizedBox(width: 6),
                _actionIcon(
                  icon:    Icons.hourglass_empty_rounded,
                  color:   const Color(0xFFE65100),
                  bgColor: const Color(0xFFFFF3E0),
                  onTap:   () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PendingTasksViewPage(
                        employeeId:   l.employeeId,
                        employeeName: l.employeeName,
                      ),
                    ),
                  ),
                ),
              ],
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
              _shimmer(width: 140, height: 14, radius: 4),
              _shimmer(width: 64,  height: 20, radius: 5),
            ],
          ),
          const SizedBox(height: 8),
          _shimmer(width: 100, height: 12, radius: 4),
          const SizedBox(height: 6),
          _shimmer(width: 160, height: 11, radius: 4),
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
          const Icon(Icons.event_busy_outlined,
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
                : 'Leave applications will appear here',
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