import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../common/api_service.dart';
import '../../../common/theme.dart';
import '../../login.dart' show kSessionKey;
import '../../home.dart';
import '../../../common/pagination.dart';

// ── Attendance Machine Model ───────────────────────────────────────────────
class AttendanceMachine {
  final String id;
  final String machineName;
  final String serialNumber;
  final String status;
  final String confirm;

  const AttendanceMachine({
    required this.id,
    required this.machineName,
    required this.serialNumber,
    required this.status,
    required this.confirm,
  });

  factory AttendanceMachine.fromJson(Map<String, dynamic> json) =>
      AttendanceMachine(
        id:           json['id']            ?? '',
        machineName:  json['machine_name']  ?? '',
        serialNumber: json['serial_number'] ?? '',
        status:       json['status']        ?? '',
        confirm:      json['confirm']       ?? '',
      );
}

// ── Attendance Machine Page ────────────────────────────────────────────────
class AttendanceMachinePage extends StatefulWidget {
  final String username;

  const AttendanceMachinePage({super.key, required this.username});

  @override
  State<AttendanceMachinePage> createState() => _AttendanceMachinePageState();
}

class _AttendanceMachinePageState extends State<AttendanceMachinePage> {
  static const int _pageSize = 50;

  List<AttendanceMachine> _allMachines = [];
  List<AttendanceMachine> _filtered    = [];
  bool                    _isLoading   = true;
  String?                 _errorMessage;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int    _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _fetchMachines();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchCtrl.text.trim().toLowerCase();
      _currentPage = 1;
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filtered = List.from(_allMachines);
    } else {
      _filtered = _allMachines
          .where((m) =>
              m.machineName.toLowerCase().contains(_searchQuery) ||
              m.serialNumber.toLowerCase().contains(_searchQuery))
          .toList();
    }
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchMachines() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url       = Uri.parse('${ApiService.baseUrl}/api/machine/list.php');
      debugPrint('📤  [MACHINE LIST] $url');
      final response  = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Accept':       'application/json',
        'X-Session-ID': sessionId,
        'Cookie':       'PHPSESSID=$sessionId',
      }).timeout(const Duration(seconds: 15));
      final Map<String, dynamic> data = jsonDecode(response.body);
      debugPrint('📥  [MACHINE LIST] ${response.statusCode} ${response.body}');
      if (response.statusCode == 200 && data['success'] == true) {
        final List list = data['data'] ?? [];
        _allMachines = list.map((e) => AttendanceMachine.fromJson(e)).toList();
        _applyFilter();
      } else {
        _errorMessage = data['message'] ?? 'Failed to load machines.';
      }
    } on http.ClientException {
      _errorMessage = 'Unable to reach the server. Check your connection.';
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Create ─────────────────────────────────────────────────────────────────
  Future<void> _createMachine(String machineName, String serialNumber) async {
    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url       = Uri.parse('${ApiService.baseUrl}/api/machine/create.php');
      final body      = {'machine_name': machineName, 'serial_number': serialNumber};
      debugPrint('📤  [CREATE MACHINE] $url  ${jsonEncode(body)}');
      final response  = await http.post(url,
          headers: {
            'Content-Type': 'application/json',
            'Accept':       'application/json',
            'X-Session-ID': sessionId,
            'Cookie':       'PHPSESSID=$sessionId',
          },
          body: jsonEncode(body)).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      final Map<String, dynamic> data = jsonDecode(response.body);
      debugPrint('📥  [CREATE MACHINE] ${response.statusCode} ${response.body}');
      if (response.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Machine added successfully.');
        _fetchMachines();
      } else {
        AppSnackBar.show(context, data['message'] ?? 'Failed to create.', isError: true);
      }
    } on http.ClientException {
      if (mounted) AppSnackBar.show(context, 'Unable to reach the server.', isError: true);
    } catch (_) {
      if (mounted) AppSnackBar.show(context, 'Something went wrong.', isError: true);
    }
  }

  // ── Update ─────────────────────────────────────────────────────────────────
  Future<void> _updateMachine(String id, String machineName, String serialNumber) async {
    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url       = Uri.parse('${ApiService.baseUrl}/api/machine/update.php');
      final body      = {'id': id, 'machine_name': machineName, 'serial_number': serialNumber};
      debugPrint('📤  [UPDATE MACHINE] $url  ${jsonEncode(body)}');
      final response  = await http.post(url,
          headers: {
            'Content-Type': 'application/json',
            'Accept':       'application/json',
            'X-Session-ID': sessionId,
            'Cookie':       'PHPSESSID=$sessionId',
          },
          body: jsonEncode(body)).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      final Map<String, dynamic> data = jsonDecode(response.body);
      debugPrint('📥  [UPDATE MACHINE] ${response.statusCode} ${response.body}');
      if (response.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Machine updated successfully.');
        _fetchMachines();
      } else {
        AppSnackBar.show(context, data['message'] ?? 'Failed to update.', isError: true);
      }
    } on http.ClientException {
      if (mounted) AppSnackBar.show(context, 'Unable to reach the server.', isError: true);
    } catch (_) {
      if (mounted) AppSnackBar.show(context, 'Something went wrong.', isError: true);
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  Future<void> _deleteMachine(String id, String reason) async {
    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url       = Uri.parse('${ApiService.baseUrl}/api/machine/delete.php');
      final body      = {'id': id, 'reason': reason};
      debugPrint('📤  [DELETE MACHINE] $url  ${jsonEncode(body)}');
      final response  = await http.post(url,
          headers: {
            'Content-Type': 'application/json',
            'Accept':       'application/json',
            'X-Session-ID': sessionId,
            'Cookie':       'PHPSESSID=$sessionId',
          },
          body: jsonEncode(body)).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      final Map<String, dynamic> data = jsonDecode(response.body);
      debugPrint('📥  [DELETE MACHINE] ${response.statusCode} ${response.body}');
      if (response.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Machine deleted successfully.');
        _fetchMachines();
      } else {
        AppSnackBar.show(context, data['message'] ?? 'Failed to delete.', isError: true);
      }
    } on http.ClientException {
      if (mounted) AppSnackBar.show(context, 'Unable to reach the server.', isError: true);
    } catch (_) {
      if (mounted) AppSnackBar.show(context, 'Something went wrong.', isError: true);
    }
  }

  // ── Pagination helpers ─────────────────────────────────────────────────────
  int get _totalPages => paginationTotalPages(_filtered.length, _pageSize);
  List<AttendanceMachine> get _pageItems =>
      paginationPageItems(_filtered, _currentPage, _pageSize);

  void _goBackToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomePage(username: widget.username, openDrawerOnLoad: true),
      ),
      (route) => false,
    );
  }

  // ── View Dialog ────────────────────────────────────────────────────────────
  void _showViewDialog(AttendanceMachine m) {
    final isActive = m.status.toLowerCase() == 'active';
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 20, 24),
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
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.visibility_outlined,
                        color: Color(0xFF2E7D32), size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Machine Details',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(dialogCtx),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border, width: 1.1),
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: AppColors.textLabel),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Machine Name
              _detailRow(icon: Icons.fingerprint_rounded,
                  label: 'Machine Name',
                  value: m.machineName.isNotEmpty ? m.machineName : '—'),
              const SizedBox(height: 12),

              // Serial Number
              _detailRow(icon: Icons.tag_rounded,
                  label: 'Serial Number',
                  value: m.serialNumber.isNotEmpty ? m.serialNumber : '—'),
              const SizedBox(height: 12),

              // Status
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderLight, width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle,
                        size: 16,
                        color: isActive
                            ? AppColors.success
                            : const Color(0xFF856404)),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Status',
                            style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.successBg
                                : const Color(0xFFFFF3CD),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            m.status.isNotEmpty ? m.status : '—',
                            style: TextStyle(
                              color: isActive
                                  ? AppColors.success
                                  : const Color(0xFF856404),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3)),
                const SizedBox(height: 3),
                Text(value,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Add / Edit Dialog ──────────────────────────────────────────────────────
  void _showAddEditDialog({AttendanceMachine? machine}) {
    final isEdit      = machine != null;
    final nameCtrl    = TextEditingController(text: isEdit ? machine.machineName : '');
    final serialCtrl  = TextEditingController(text: isEdit ? machine.serialNumber : '');
    final nameFocus   = FocusNode();
    final serialFocus = FocusNode();
    bool  isSaving    = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          nameFocus.addListener(() => setDialogState(() {}));
          serialFocus.addListener(() => setDialogState(() {}));

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 20, 24),
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
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isEdit ? Icons.edit_outlined : Icons.fingerprint_rounded,
                            color: AppColors.primary, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(isEdit ? 'Edit Machine' : 'Add Machine',
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                        ),
                        GestureDetector(
                          onTap: isSaving ? null : () => Navigator.pop(dialogCtx),
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border, width: 1.1),
                            ),
                            child: const Icon(Icons.close_rounded,
                                size: 16, color: AppColors.textLabel),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Machine Name
                    Text('MACHINE NAME', style: AppTextStyles.fieldLabel(false)),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: nameFocus.hasFocus
                          ? AppDecorations.inputFocused
                          : AppDecorations.inputIdle,
                      child: TextField(
                        controller: nameCtrl,
                        focusNode: nameFocus,
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                        cursorColor: AppColors.primary,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'Enter machine name',
                          hintStyle: const TextStyle(
                              color: AppColors.textHint, fontSize: 13.5),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.fingerprint_rounded,
                                size: 18,
                                color: nameFocus.hasFocus
                                    ? AppColors.primary
                                    : AppColors.iconDefault),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 15),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Serial Number
                    Text('SERIAL NUMBER', style: AppTextStyles.fieldLabel(false)),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: serialFocus.hasFocus
                          ? AppDecorations.inputFocused
                          : AppDecorations.inputIdle,
                      child: TextField(
                        controller: serialCtrl,
                        focusNode: serialFocus,
                        textInputAction: TextInputAction.done,
                        cursorColor: AppColors.primary,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'Enter serial number',
                          hintStyle: const TextStyle(
                              color: AppColors.textHint, fontSize: 13.5),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.tag_rounded,
                                size: 18,
                                color: serialFocus.hasFocus
                                    ? AppColors.primary
                                    : AppColors.iconDefault),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 15),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Save / Update
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final name   = nameCtrl.text.trim();
                                  final serial = serialCtrl.text.trim();
                                  if (name.isEmpty) {
                                    AppSnackBar.show(context,
                                        'Please enter a machine name.',
                                        isError: true);
                                    return;
                                  }
                                  if (serial.isEmpty) {
                                    AppSnackBar.show(context,
                                        'Please enter a serial number.',
                                        isError: true);
                                    return;
                                  }
                                  setDialogState(() => isSaving = true);
                                  Navigator.pop(dialogCtx);
                                  if (isEdit) {
                                    await _updateMachine(machine.id, name, serial);
                                  } else {
                                    await _createMachine(name, serial);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor:
                                AppColors.primary.withOpacity(0.45),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 11),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: isSaving
                                ? const SizedBox(
                                    key: ValueKey('s-loader'),
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.2))
                                : Text(isEdit ? 'Update' : 'Save',
                                    key: const ValueKey('s-label'),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Delete Dialog ──────────────────────────────────────────────────────────
  void _showDeleteDialog(AttendanceMachine m) {
    final reasonCtrl  = TextEditingController();
    final reasonFocus = FocusNode();
    bool  isDeleting  = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          reasonFocus.addListener(() => setDialogState(() {}));

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Red icon
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.error, size: 26),
                    ),

                    const SizedBox(height: 16),

                    const Text('Delete Machine',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),

                    const SizedBox(height: 10),

                    Text(
                      'Are you sure you want to delete\n"${m.machineName}"?\nThis action cannot be undone.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.5,
                          height: 1.55),
                    ),

                    const SizedBox(height: 16),

                    // Reason label
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('REASON', style: AppTextStyles.fieldLabel(false)),
                    ),
                    const SizedBox(height: 8),

                    // Reason input
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: reasonFocus.hasFocus
                          ? AppDecorations.inputFocused
                          : AppDecorations.inputIdle,
                      child: TextField(
                        controller: reasonCtrl,
                        focusNode: reasonFocus,
                        maxLines: 3,
                        minLines: 3,
                        cursorColor: AppColors.primary,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500),
                        decoration: const InputDecoration(
                          hintText: 'Enter reason for deletion…',
                          hintStyle: TextStyle(
                              color: AppColors.textHint, fontSize: 13),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isDeleting
                                ? null
                                : () => Navigator.pop(dialogCtx),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppColors.border, width: 1.3),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11)),
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: const Text('Cancel',
                                style: TextStyle(
                                    color: AppColors.textLabel,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isDeleting
                                ? null
                                : () async {
                                    final reason = reasonCtrl.text.trim();
                                    if (reason.isEmpty) {
                                      AppSnackBar.show(context,
                                          'Please enter a reason.',
                                          isError: true);
                                      return;
                                    }
                                    setDialogState(() => isDeleting = true);
                                    Navigator.pop(dialogCtx);
                                    await _deleteMachine(m.id, reason);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              disabledBackgroundColor:
                                  AppColors.error.withOpacity(0.5),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11)),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: isDeleting
                                  ? const SizedBox(
                                      key: ValueKey('del-loader'),
                                      width: 18, height: 18,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2.3))
                                  : const Text('Delete',
                                      key: ValueKey('del-label'),
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 0),
              child: Row(
                children: [
                  if (!_isLoading)
                    Text(
                      '${_filtered.length} machine${_filtered.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500),
                    ),
                  const Spacer(),
                  _addMachineButton(),
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
                          : _buildMachineList(hPad),
            ),

            if (!_isLoading && _errorMessage == null && _filtered.isNotEmpty)
              AppPagination(
                currentPage:       _currentPage,
                totalPages:        _totalPages,
                horizontalPadding: hPad,
                onPageChanged: (page) => setState(() => _currentPage = page),
              ),
          ],
        ),
      ),
    );
  }

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
                color: AppColors.background,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.border, width: 1.2),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 15, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Text('Attendance Machines',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: isTablet ? 20 : 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3)),
          const Spacer(),
          GestureDetector(
            onTap: _fetchMachines,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.background,
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

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        cursorColor: AppColors.primary,
        decoration: const InputDecoration(
          hintText: 'Search machines…',
          hintStyle: TextStyle(color: AppColors.textHint, fontSize: 13.5),
          prefixIcon: Icon(Icons.search_rounded,
              color: AppColors.iconDefault, size: 19),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _addMachineButton() {
    return ElevatedButton.icon(
      onPressed: () => _showAddEditDialog(),
      icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
      label: const Text('Add Machine',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    );
  }

  Widget _buildMachineList(double hPad) {
    final items = _pageItems;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _machineCard(items[i]),
    );
  }

  // ── Machine card (no status badge) ─────────────────────────────────────────
  Widget _machineCard(AttendanceMachine m) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight, width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Icon avatar
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.fingerprint_rounded,
                color: AppColors.primary, size: 17),
          ),

          const SizedBox(width: 12),

          // Name + serial number only — no status badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.machineName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.tag_rounded,
                        size: 11, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(m.serialNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // View + Edit + Delete
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _actionIcon(
                icon:    Icons.visibility_outlined,
                color:   const Color(0xFF2E7D32),
                bgColor: const Color(0xFFE8F5E9),
                onTap:   () => _showViewDialog(m),
              ),
              const SizedBox(width: 6),
              _actionIcon(
                icon:    Icons.edit_outlined,
                color:   AppColors.primary,
                bgColor: AppColors.primaryLight,
                onTap:   () => _showAddEditDialog(machine: m),
              ),
              const SizedBox(width: 6),
              _actionIcon(
                icon:    Icons.delete_outline_rounded,
                color:   AppColors.error,
                bgColor: const Color(0xFFFFF1F1),
                onTap:   () => _showDeleteDialog(m),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionIcon({
    required IconData icon,
    required Color color,
    required Color bgColor,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Row(
        children: [
          _shimmer(width: 36, height: 36, radius: 9),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmer(width: double.infinity, height: 13, radius: 4),
                const SizedBox(height: 6),
                _shimmer(width: 120, height: 11, radius: 4),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
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

  Widget _shimmer({required double width, required double height, required double radius}) =>
      _ShimmerBox(width: width, height: height, radius: radius);

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.fingerprint_rounded, size: 56, color: AppColors.border),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No machines found',
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Tap "Add Machine" to get started',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 52, color: AppColors.border),
          const SizedBox(height: 14),
          Text(
            _errorMessage ?? 'Something went wrong.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchMachines,
            icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
            label: const Text('Retry',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shimmer box ────────────────────────────────────────────────────────────
class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({required this.width, required this.height, required this.radius});

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
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EDF5),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
}