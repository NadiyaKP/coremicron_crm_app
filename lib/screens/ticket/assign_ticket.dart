import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService, kTokenKey;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/screens/login.dart' show kTokenKey;
import 'package:coremicron_crm_app/screens/ticket/tickets.dart' show Ticket;
import 'package:coremicron_crm_app/common/string_extensions.dart';

// ── Employee model ─────────────────────────────────────────────────────────
class _Employee {
  final String id;
  final String name;
  final String phone;
  final String employeeId;
  _Employee(
      {required this.id,
      required this.name,
      required this.phone,
      required this.employeeId});
}

// ── Job model ──────────────────────────────────────────────────────────────
class _Job {
  final String jobId;
  final String assignId;
  final String assignName;
  final String toDo;
  final String fixbyDate;
  final String? completedDate;
  final String? image;
  final String status;

  _Job({
    required this.jobId,
    required this.assignId,
    required this.assignName,
    required this.toDo,
    required this.fixbyDate,
    this.completedDate,
    this.image,
    required this.status,
  });

  factory _Job.fromJson(Map<String, dynamic> j) => _Job(
        jobId:         j['job_id']          ?? '',
        assignId:      j['assign_id']       ?? '',
        assignName:    j['assign_name']     ?? '',
        toDo:          j['to_do']           ?? '',
        fixbyDate:     j['fixby_date']      ?? '',
        completedDate: j['completed_date']?.toString(),
        image:         j['image']?.toString(),
        status:        j['status']          ?? '',
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Assign Ticket Page ─────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════
class AssignTicketPage extends StatefulWidget {
  final Ticket ticket;
  const AssignTicketPage({super.key, required this.ticket});

  @override
  State<AssignTicketPage> createState() => _AssignTicketPageState();
}

class _AssignTicketPageState extends State<AssignTicketPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // ── Section index: 0 = Assign Job, 1 = Job Assigns ────────────────────────
  // We use a TabController so switching is smooth
  int _activeTab = 0;

  // ─── Assign Job form state ─────────────────────────────────────────────────
  _Job?   _editingJob; // null = new, non-null = editing
  bool    _isSaving  = false;

  // Date
  DateTime? _fixByDate;
  final _fixByCtrl = TextEditingController();

  // Employee autocomplete
  final _employeeCtrl   = TextEditingController();
  final _employeeFocus  = FocusNode();
  _Employee?      _selectedEmployee;
  List<_Employee> _allEmployees        = [];
  List<_Employee> _employeeSuggestions = [];
  bool            _employeesLoaded     = false;
  Timer?          _employeeDebounce;
  final _employeeLayerLink = LayerLink();
  OverlayEntry?   _employeeOverlay;

  // Work / notes
  final _workCtrl  = TextEditingController();
  final _workFocus = FocusNode();

  // Speech to text
  final stt.SpeechToText _speech     = stt.SpeechToText();
  bool                   _isListening = false;
  bool                   _speechAvailable = false;
  String                 _baseSpeechText  = '';

  // Image upload
  File?   _pickedImage;
  String? _serverImage; // Network image for editing
  final   _picker = ImagePicker();

  // ─── Job Assigns list state ────────────────────────────────────────────────
  List<_Job> _jobs         = [];
  bool       _jobsLoading  = true;
  String?    _jobsError;
  String     _ticketNumber = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this)
      ..addListener(() {
        setState(() => _activeTab = _tabCtrl.index);
      });
    _employeeFocus.addListener(() {
      if (!_employeeFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 150),
            _removeEmployeeOverlay);
      }
      setState(() {});
    });
    _workFocus.addListener(() => setState(() {}));
    _initSpeech();
    _fetchJobs();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _removeEmployeeOverlay();
    _employeeDebounce?.cancel();
    _fixByCtrl.dispose();
    _employeeCtrl.dispose();
    _workCtrl.dispose();
    _employeeFocus.dispose();
    _workFocus.dispose();
    super.dispose();
  }

  // ─── Speech init ───────────────────────────────────────────────────────────
  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize();
    if (mounted) setState(() {});
  }

  void _startListening() async {
    if (!_speechAvailable) {
      AppSnackBar.show(context, 'Speech recognition not available.',
          isError: true);
      return;
    }

    // Save current text as base to append to
    _baseSpeechText = _workCtrl.text.trim();
    if (_baseSpeechText.isNotEmpty) {
      _baseSpeechText += ' ';
    }

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _workCtrl.text = _baseSpeechText + result.recognizedWords;
          _workCtrl.selection = TextSelection.fromPosition(
              TextPosition(offset: _workCtrl.text.length));
        });
      },
      listenFor:      const Duration(minutes: 1),
      pauseFor:       const Duration(seconds: 10), // Longer pause allowed
      localeId:       'en_US',
      cancelOnError:  false,
      partialResults: true,
    );

    _speech.statusListener = (status) {
      debugPrint('🎙️ Speech Status: $status');
      if (status == 'done' || status == 'notListening') {
        // Automatically restart if we haven't manually stopped
        if (_isListening && mounted) {
          _restartListening();
        }
      }
    };
  }

  void _stopListening() async {
    setState(() => _isListening = false);
    await _speech.stop();
  }

  void _restartListening() async {
    if (!_isListening || !mounted) return;
    
    // Update base text with current text before restarting
    _baseSpeechText = _workCtrl.text.trim();
    if (_baseSpeechText.isNotEmpty) {
      _baseSpeechText += ' ';
    }

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _workCtrl.text = _baseSpeechText + result.recognizedWords;
          _workCtrl.selection = TextSelection.fromPosition(
              TextPosition(offset: _workCtrl.text.length));
        });
      },
      listenFor:      const Duration(minutes: 1),
      pauseFor:       const Duration(seconds: 10),
      localeId:       'en_US',
      cancelOnError:  false,
      partialResults: true,
    );
  }

  // _toggleListening removed as it is replaced by _startListening and _stopListening

  // ─── Image picker ──────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final XFile? file =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) {
      final ext = file.path.split('.').last.toLowerCase();
      if (ext == 'png' || ext == 'jpg' || ext == 'jpeg') {
        setState(() {
          _pickedImage = File(file.path);
          _serverImage = null; // Clear server image if new one is picked
        });
      } else {
        if (mounted) {
          AppSnackBar.show(
              context, 'Invalid file type. Please select PNG, JPG, or JPEG.',
              isError: true);
        }
      }
    }
  }

  // ─── Employee autocomplete ─────────────────────────────────────────────────
  Future<void> _loadEmployees() async {
    if (_employeesLoaded) return;
    try {
      final url = Uri.parse('${ApiService.baseUrl}/api/employee/list.php?view=dropdown');
      final res = await ApiService.get(url).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        final list = data['data'] as List? ?? [];
        _allEmployees = list
            .map((e) => _Employee(
                  id:         e['id']            ?? '',
                  name:       e['employee_name'] ?? '',
                  phone:      e['phone_number']  ?? '',
                  employeeId: e['employee_id']   ?? '',
                ))
            .toList();
        _employeesLoaded = true;
      }
    } catch (_) {}
  }

  void _onEmployeeChanged(String query) {
    _selectedEmployee = null;
    _employeeDebounce?.cancel();
    _employeeDebounce =
        Timer(const Duration(milliseconds: 250), () async {
      await _loadEmployees();
      final q = query.trim().toLowerCase();
      if (q.isEmpty) { _removeEmployeeOverlay(); return; }
      _employeeSuggestions = _allEmployees
          .where((e) =>
              e.name.toLowerCase().contains(q) ||
              e.phone.contains(q) ||
              e.employeeId.toLowerCase().contains(q))
          .toList();
      _employeeSuggestions.isNotEmpty
          ? _showEmployeeDropdown()
          : _removeEmployeeOverlay();
    });
  }

  void _showEmployeeDropdown() {
    _removeEmployeeOverlay();
    _employeeOverlay = OverlayEntry(
      builder: (_) => Positioned(
        width: _employeeLayerLink.leaderSize?.width ?? 300,
        child: CompositedTransformFollower(
          link:             _employeeLayerLink,
          showWhenUnlinked: false,
          offset: Offset(
              0, (_employeeLayerLink.leaderSize?.height ?? 48) + 4),
          child: Material(
            elevation:    6,
            borderRadius: BorderRadius.circular(12),
            color:        Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.separated(
                  padding:    EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount:  _employeeSuggestions.length,
                  separatorBuilder: (_, __) => const Divider(
                      height: 1, color: AppColors.borderLight),
                  itemBuilder: (_, i) =>
                      _employeeTile(_employeeSuggestions[i]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_employeeOverlay!);
  }

  void _removeEmployeeOverlay() {
    _employeeOverlay?.remove();
    _employeeOverlay = null;
  }

  void _selectEmployee(_Employee e) {
    _removeEmployeeOverlay();
    setState(() {
      _selectedEmployee  = e;
      _employeeCtrl.text = e.name.capitalize();
    });
    FocusScope.of(context).requestFocus(_workFocus);
  }

  Widget _employeeTile(_Employee e) {
    return InkWell(
      onTap: () => _selectEmployee(e),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color:        AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  e.name.isNotEmpty ? e.name[0].toUpperCase() : 'E',
                  style: const TextStyle(
                      color:      AppColors.primary,
                      fontSize:   13,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.name.capitalize(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color:      AppColors.textPrimary,
                          fontSize:   13.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(e.phone,
                          style: const TextStyle(
                              color:    AppColors.textSecondary,
                              fontSize: 12)),
                      if (e.employeeId.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color:        AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('ID: ${e.employeeId}',
                              style: const TextStyle(
                                  color:      AppColors.primary,
                                  fontSize:   10.5,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Fetch jobs ────────────────────────────────────────────────────────────
  Future<void> _fetchJobs() async {
    setState(() { _jobsLoading = true; _jobsError = null; });
    try {
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/ticket/job_list.php'
          '?ticket_id=${widget.ticket.ticketId}');

      final res = await ApiService.get(url).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [JOB LIST] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        _ticketNumber = data['ticket_number']?.toString() ?? '';
        final list    = data['jobs'] as List? ?? [];
        _jobs = list.map((e) => _Job.fromJson(e)).toList();
      } else {
        _jobsError =
            data['error'] ?? data['message'] ?? 'Failed to load jobs.';
      }
    } on http.ClientException {
      _jobsError = 'Unable to reach the server.';
    } catch (_) {
      _jobsError = 'Something went wrong.';
    }
    if (mounted) setState(() => _jobsLoading = false);
  }

  // ─── Date picker ───────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final now  = DateTime.now();
    final picked = await showDatePicker(
      context:      context,
      initialDate:  _fixByDate ?? now,
      firstDate:    now,
      lastDate:     DateTime(now.year + 5),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary:   AppColors.primary,
            onPrimary: Colors.white,
            surface:   Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _fixByDate = picked;
        _fixByCtrl.text =
            '${picked.day.toString().padLeft(2, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.year}';
      });
    }
  }

  // ─── Submit assign / update job ────────────────────────────────────────────
  Future<void> _submit() async {
    if (_fixByDate == null) {
      AppSnackBar.show(context, 'Please select a fix by date.',
          isError: true);
      return;
    }
    if (_selectedEmployee == null) {
      AppSnackBar.show(context, 'Please select an employee.',
          isError: true);
      return;
    }
    if (_workCtrl.text.trim().isEmpty) {
      AppSnackBar.show(context, 'Please enter the work description.',
          isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final isUpdate = _editingJob != null;
      final url = Uri.parse(isUpdate
          ? '${ApiService.baseUrl}/api/ticket/job_update.php'
          : '${ApiService.baseUrl}/api/ticket/assign.php');

      final req = http.MultipartRequest('POST', url);

      if (isUpdate) req.fields['job_id'] = _editingJob!.jobId;
      req.fields['ticket_id']  = widget.ticket.ticketId;
      req.fields['assign_id']  = _selectedEmployee!.id;
      req.fields['fixby_date'] =
          '${_fixByDate!.year}-'
          '${_fixByDate!.month.toString().padLeft(2, '0')}-'
          '${_fixByDate!.day.toString().padLeft(2, '0')}';
      req.fields['to_do'] = _workCtrl.text.trim();

      if (_pickedImage != null) {
        final ext = _pickedImage!.path.split('.').last.toLowerCase();
        final mimeType = (ext == 'png') ? 'image/png' : 'image/jpeg';
        
        req.files.add(await http.MultipartFile.fromPath(
          'image', 
          _pickedImage!.path,
          contentType: MediaType.parse(mimeType),
        ));
      }

      final res = await ApiService.sendMultipart(req).timeout(
          const Duration(seconds: 30));

      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint(
          '📥  [${isUpdate ? 'UPDATE JOB' : 'ASSIGN TICKET'}] '
          '${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        _resetForm();
        await _fetchJobs();
        _tabCtrl.animateTo(1);
      } else {
        AppSnackBar.show(
            context,
            data['error'] ??
                data['message'] ??
                (isUpdate
                    ? 'Failed to update job.'
                    : 'Failed to assign ticket.'),
            isError: true);
        setState(() => _isSaving = false);
      }
    } on http.ClientException {
      if (mounted) {
        AppSnackBar.show(context, 'Unable to reach the server.',
            isError: true);
        setState(() => _isSaving = false);
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(context, 'Something went wrong.',
            isError: true);
        setState(() => _isSaving = false);
      }
    }
  }

  void _resetForm() {
    setState(() {
      _editingJob       = null;
      _fixByDate        = null;
      _fixByCtrl.clear();
      _employeeCtrl.clear();
      _workCtrl.clear();
      _selectedEmployee = null;
      _pickedImage      = null;
      _serverImage      = null;
      _isSaving         = false;
    });
  }

  void _startEdit(_Job job) async {
    // Load employees first so we can match by id
    await _loadEmployees();
    _Employee? emp;
    try {
      emp = _allEmployees.firstWhere((e) => e.id == job.assignId);
    } catch (_) {
      emp = _Employee(
          id:         job.assignId,
          name:       job.assignName,
          phone:      '',
          employeeId: '');
    }

    // Parse fixby_date  "YYYY-MM-DD" → DateTime
    DateTime? dt;
    try {
      final parts = job.fixbyDate.split('-');
      if (parts.length == 3) {
        dt = DateTime(int.parse(parts[0]),
            int.parse(parts[1]), int.parse(parts[2]));
      }
    } catch (_) {}

    setState(() {
      _editingJob       = job;
      _selectedEmployee = emp;
      _employeeCtrl.text = emp!.name;
      _fixByDate        = dt;
      _fixByCtrl.text   = dt != null
          ? '${dt.day.toString().padLeft(2, '0')}-'
            '${dt.month.toString().padLeft(2, '0')}-'
            '${dt.year}'
          : job.fixbyDate;
      _workCtrl.text    = job.toDo;
      _pickedImage      = null;
      _serverImage      = job.image;
    });
    _tabCtrl.animateTo(0);
  }

  // ─── Delete job ────────────────────────────────────────────────────────────
  void _showDeleteJobDialog(_Job job) {
    bool isDeleting = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Padding(
            padding: const EdgeInsets.all(24),
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
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.error, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Delete Job',
                          style: TextStyle(
                              color:      AppColors.textPrimary,
                              fontSize:   15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Are you sure you want to delete this job assignment?',
                  style: TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 13.5,
                      height:   1.5),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 12),
                _dialogRow(Icons.person_outline_rounded,
                    'Assigned To', job.assignName.capitalize()),
                const SizedBox(height: 8),
                _dialogRow(Icons.work_outline_rounded,
                    'Work',
                    job.toDo.length > 50
                        ? '${job.toDo.substring(0, 50)}…'
                        : job.toDo),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isDeleting
                            ? null
                            : () => Navigator.pop(dCtx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.border, width: 1.3),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(11)),
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
                                await _deleteJob(job.jobId);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          disabledBackgroundColor:
                              AppColors.error.withOpacity(0.5),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(11)),
                        ),
                        child: AnimatedSwitcher(
                          duration:
                              const Duration(milliseconds: 200),
                          child: isDeleting
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

  Future<void> _deleteJob(String jobId) async {
    try {
      final url =
          Uri.parse('${ApiService.baseUrl}/api/ticket/job_delete.php');
      final body = {'job_id': jobId};

      final res = await ApiService.post(url, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint(
          '📥  [DELETE JOB] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Job deleted successfully.');
        _fetchJobs();
      } else {
        AppSnackBar.show(
            context,
            data['error'] ?? data['message'] ?? 'Failed to delete job.',
            isError: true);
      }
    } on http.ClientException {
      if (mounted)
        AppSnackBar.show(context, 'Unable to reach the server.',
            isError: true);
    } catch (_) {
      if (mounted)
        AppSnackBar.show(context, 'Something went wrong.',
            isError: true);
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return '—';
    try {
      final p = raw.trim().split('-');
      if (p.length == 3) return '${p[2]}-${p[1]}-${p[0]}';
    } catch (_) {}
    return raw;
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'completed': return const Color(0xFF2E7D32);
      case 'verified':  return const Color(0xFF1565C0);
      case 'cancelled': return AppColors.error;
      default:          return const Color(0xFFE65100);
    }
  }

  Color _statusBg(String s) {
    switch (s.toLowerCase()) {
      case 'completed': return const Color(0xFFE8F5E9);
      case 'verified':  return const Color(0xFFE3F2FD);
      case 'cancelled': return const Color(0xFFFFF1F1);
      default:          return const Color(0xFFFFF3E0);
    }
  }

  Widget _dialogRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
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
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ── Build ─────────────────────────────────────────────────────────────────
  // ═════════════════════════════════════════════════════════════════════════
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
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildAssignJobTab(hPad),
                  _buildJobAssignsTab(hPad),
                ],
              ),
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
                  'Assign Ticket',
                  style: TextStyle(
                      color:         AppColors.textPrimary,
                      fontSize:      isTablet ? 19 : 16,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: -0.3),
                ),
                Text(
                  '${widget.ticket.title} · #${widget.ticket.ticketNumber}',
                  style: const TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab Bar ────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller:           _tabCtrl,
        labelColor:           AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor:       AppColors.primary,
        indicatorWeight:      2.5,
        labelStyle: const TextStyle(
            fontSize: 13.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
            fontSize: 13.5, fontWeight: FontWeight.w500),
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.assignment_outlined, size: 16),
                const SizedBox(width: 6),
                Text(_editingJob != null ? 'Edit Job' : 'Assign Job'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.list_alt_outlined, size: 16),
                const SizedBox(width: 6),
                const Text('Jobs'),
                if (_jobs.isNotEmpty) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color:        AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_jobs.length}',
                      style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ── Tab 1 : Assign Job ────────────────────────────────────────────────────
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildAssignJobTab(double hPad) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 32),
      keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          if (_editingJob != null)
            Container(
              width: double.infinity,
              margin:  const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:        AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_note_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Editing existing job assignment',
                        style: TextStyle(
                            color:      AppColors.primary,
                            fontSize:   12.5,
                            fontWeight: FontWeight.w600)),
                  ),
                  GestureDetector(
                    onTap: _resetForm,
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.primary),
                  ),
                ],
              ),
            ),

          // ── Fix By Date ───────────────────────────────────────────────
          _fieldLabel('Fix By Date', required: true),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickDate,
            child: AbsorbPointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: AppDecorations.inputIdle,
                child: TextField(
                  controller: _fixByCtrl,
                  style: const TextStyle(
                      color:      AppColors.textPrimary,
                      fontSize:   14,
                      fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    hintText:  'Select date',
                    hintStyle: TextStyle(
                        color:    AppColors.textHint,
                        fontSize: 13.5),
                    prefixIcon: Icon(Icons.calendar_today_outlined,
                        size: 18, color: AppColors.iconDefault),
                    border:         InputBorder.none,
                    enabledBorder:  InputBorder.none,
                    focusedBorder:  InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 14, vertical: 15),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Assign To ─────────────────────────────────────────────────
          _fieldLabel('Assign To', required: true),
          const SizedBox(height: 8),
          CompositedTransformTarget(
            link: _employeeLayerLink,
            child: _buildEmployeeSearchField(),
          ),

          const SizedBox(height: 16),

          // ── Work ──────────────────────────────────────────────────────
          _fieldLabel('Work', required: true),
          const SizedBox(height: 8),
          _buildWorkField(),

          const SizedBox(height: 16),

          // ── Image Upload ──────────────────────────────────────────────
          _fieldLabel('Attachment'),
          const SizedBox(height: 8),
          _buildImagePicker(),

          const SizedBox(height: 32),

          // ── Buttons ───────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          if (_editingJob != null) {
                            _resetForm();
                          } else {
                            Navigator.pop(context);
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: AppColors.border, width: 1.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11)),
                    backgroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    _editingJob != null ? 'Discard' : 'Cancel',
                    style: const TextStyle(
                        color:      AppColors.textLabel,
                        fontWeight: FontWeight.w600,
                        fontSize:   14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor:
                        AppColors.primary.withOpacity(0.45),
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11)),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isSaving
                        ? const SizedBox(
                            key: ValueKey('s-loader'),
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color:       Colors.white,
                                strokeWidth: 2.4))
                        : Text(
                            _editingJob != null ? 'Update' : 'Save',
                            key: const ValueKey('s-label'),
                            style: const TextStyle(
                                color:      Colors.white,
                                fontSize:   14,
                                fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Employee search field ──────────────────────────────────────────────────
  Widget _buildEmployeeSearchField() {
    final selected = _selectedEmployee != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: selected
          ? BoxDecoration(
              color:        AppColors.successBg,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: AppColors.success.withOpacity(0.5),
                  width: 1.4),
            )
          : _employeeFocus.hasFocus
              ? AppDecorations.inputFocused
              : AppDecorations.inputIdle,
      child: TextField(
        controller:      _employeeCtrl,
        focusNode:       _employeeFocus,
        cursorColor:     AppColors.primary,
        textInputAction: TextInputAction.next,
        onChanged:       _onEmployeeChanged,
        style: const TextStyle(
            color:      AppColors.textPrimary,
            fontSize:   14,
            fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText:  'Type to search employee…',
          hintStyle: const TextStyle(
              color: AppColors.textHint, fontSize: 13.5),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Icons.person_search_outlined,
                size:  18,
                color: selected
                    ? AppColors.success
                    : _employeeFocus.hasFocus
                        ? AppColors.primary
                        : AppColors.iconDefault),
          ),
          suffixIcon: selected
              ? GestureDetector(
                  onTap: () => setState(() {
                    _selectedEmployee = null;
                    _employeeCtrl.clear();
                  }),
                  child: const Icon(Icons.check_circle_rounded,
                      size: 18, color: AppColors.success),
                )
              : null,
          border:         InputBorder.none,
          enabledBorder:  InputBorder.none,
          focusedBorder:  InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 15),
        ),
      ),
    );
  }

  // ── Work field with speech button ──────────────────────────────────────────
  Widget _buildWorkField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: _workFocus.hasFocus
          ? AppDecorations.inputFocused
          : AppDecorations.inputIdle,
      child: Column(
        children: [
          TextField(
            controller:  _workCtrl,
            focusNode:   _workFocus,
            maxLines:    4,
            minLines:    4,
            cursorColor: AppColors.primary,
            style: const TextStyle(
                color:      AppColors.textPrimary,
                fontSize:   14,
                fontWeight: FontWeight.w400),
            decoration: const InputDecoration(
              hintText:  'Type or click speak button…',
              hintStyle: TextStyle(
                  color: AppColors.textHint, fontSize: 13.5),
              border:         InputBorder.none,
              enabledBorder:  InputBorder.none,
              focusedBorder:  InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(color: AppColors.borderLight)),
            ),
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isListening)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(
                              color:       AppColors.error,
                              strokeWidth: 2),
                        ),
                        SizedBox(width: 6),
                        Text('Listening…',
                            style: TextStyle(
                                color:    AppColors.error,
                                fontSize: 11.5)),
                      ],
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Start Button
                    GestureDetector(
                      onTap: _isListening ? null : _startListening,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: _isListening
                              ? AppColors.background
                              : AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              size:  16,
                              color: _isListening
                                  ? AppColors.textMuted
                                  : AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Start',
                              style: TextStyle(
                                  color: _isListening
                                      ? AppColors.textMuted
                                      : AppColors.primary,
                                  fontSize:   12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Stop Button
                    GestureDetector(
                      onTap: _isListening ? _stopListening : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: _isListening
                              ? AppColors.error
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.stop_rounded,
                              size:  16,
                              color: _isListening
                                  ? Colors.white
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Stop',
                              style: TextStyle(
                                  color: _isListening
                                      ? Colors.white
                                      : AppColors.textMuted,
                                  fontSize:   12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
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
    );
  }

  // ── Image picker widget ────────────────────────────────────────────────────
  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width:  double.infinity,
              height: (_pickedImage != null || (_serverImage != null && _serverImage!.isNotEmpty)) ? 160 : 70,
              decoration: BoxDecoration(
                color: (_pickedImage != null || (_serverImage != null && _serverImage!.isNotEmpty))
                    ? Colors.white
                    : AppColors.background,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: (_pickedImage != null || (_serverImage != null && _serverImage!.isNotEmpty))
                      ? AppColors.success.withOpacity(0.4)
                      : AppColors.border,
                  width: 1.3,
                ),
              ),
              child: (_pickedImage != null || (_serverImage != null && _serverImage!.isNotEmpty))
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _pickedImage != null
                              ? Image.file(_pickedImage!,
                                  width:  double.infinity,
                                  height: 160,
                                  fit:    BoxFit.cover)
                              : () {
                                final imageUrl = _serverImage!.startsWith('http')
                                    ? _serverImage!
                                    : '${ApiService.baseUrl}/uploads/${_serverImage!}';
                                debugPrint('🖼️  [IMAGE LOAD] URL: $imageUrl');
                                return Image.network(
                                  imageUrl,
                                  width:  double.infinity,
                                  height: 160,
                                  fit:    BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 160,
                                    color:  AppColors.background,
                                    child:  const Center(
                                      child: Icon(Icons.broken_image_rounded,
                                          color: AppColors.border, size: 30),
                                    ),
                                  ),
                                );
                              }(),
                        ),
                        Positioned(
                          top: 6, right: 6,
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _pickedImage = null;
                              _serverImage = null;
                            }),
                            child: Container(
                              width: 26, height: 26,
                              decoration: BoxDecoration(
                                color:        Colors.black.withOpacity(0.55),
                                shape:        BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.upload_rounded,
                            size: 20, color: AppColors.iconDefault),
                        SizedBox(width: 8),
                        Text('Upload Image',
                            style: TextStyle(
                                color:      AppColors.textLabel,
                                fontSize:   13.5,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
            ),
            if (_pickedImage != null || (_serverImage != null && _serverImage!.isNotEmpty)) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _pickImage,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.sync_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                        _pickedImage != null
                            ? 'Reupload Image'
                            : 'Change Image',
                        style: const TextStyle(
                            color:      AppColors.primary,
                            fontSize:   13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline)),
                  ],
                ),
              ),
            ],
          ],
        ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ── Tab 2 : Job Assigns ───────────────────────────────────────────────────
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildJobAssignsTab(double hPad) {
    if (_jobsLoading) {
      return ListView.builder(
        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 32),
        itemCount: 3,
        itemBuilder: (_, __) => _skeletonJobCard(),
      );
    }

    if (_jobsError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: AppColors.border),
            const SizedBox(height: 12),
            Text(_jobsError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13.5)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchJobs,
              icon: const Icon(Icons.refresh_rounded,
                  size: 15, color: Colors.white),
              label: const Text('Retry',
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, elevation: 0),
            ),
          ],
        ),
      );
    }

    if (_jobs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.work_outline_rounded,
                  size: 52, color: AppColors.border),
              SizedBox(height: 14),
              Text('No jobs assigned yet',
                  style: TextStyle(
                      color:      AppColors.textSecondary,
                      fontSize:   14,
                      fontWeight: FontWeight.w600)),
              SizedBox(height: 6),
              Text(
                'Use the "Assign Job" tab to create a new job assignment for this ticket',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color:    AppColors.textMuted,
                    fontSize: 12.5,
                    height:   1.5),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 32),
      children: [
        // Ticket header
        if (_ticketNumber.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color:        AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    'Ticket #$_ticketNumber',
                    style: const TextStyle(
                        color:      AppColors.primary,
                        fontSize:   12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_jobs.length} job${_jobs.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      color:    AppColors.textMuted,
                      fontSize: 12.5),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _fetchJobs,
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color:        AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.border, width: 1.1),
                    ),
                    child: const Icon(Icons.refresh_rounded,
                        size: 15, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),

        ..._jobs.map((job) => _jobCard(job)).toList(),
      ],
    );
  }

  Widget _jobCard(_Job job) {
    final statusClr = _statusColor(job.status);
    final statusBg  = _statusBg(job.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight, width: 1),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.03),
              blurRadius: 5,
              offset:     const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge + action icons
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color:        statusBg,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: statusClr.withOpacity(0.3), width: 1),
                ),
                child: Text(_capitalize(job.status),
                    style: TextStyle(
                        color:      statusClr,
                        fontSize:   10.5,
                        fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              // Edit
              GestureDetector(
                onTap: () => _startEdit(job),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color:        AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.edit_outlined,
                      size: 14, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 6),
              // Delete
              GestureDetector(
                onTap: () => _showDeleteJobDialog(job),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color:        const Color(0xFFFFF1F1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 14, color: AppColors.error),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Assigned to
          Row(
            children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color:        AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(
                  child: Text(
                    job.assignName.isNotEmpty
                        ? job.assignName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color:      AppColors.primary,
                        fontSize:   11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(job.assignName.capitalize(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color:      AppColors.textPrimary,
                        fontSize:   13,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),

          if (job.toDo.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.work_outline_rounded,
                    size: 13, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(job.toDo,
                      style: const TextStyle(
                          color:    AppColors.textSecondary,
                          fontSize: 12.5,
                          height:   1.4)),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 7),

          Row(
            children: [
              const Icon(Icons.event_outlined,
                  size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('Fix By: ',
                  style: const TextStyle(
                      color:    AppColors.textMuted,
                      fontSize: 11.5)),
              Text(
                _fmtDate(job.fixbyDate),
                style: const TextStyle(
                    color:      Color(0xFFE65100),
                    fontSize:   12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Field label ────────────────────────────────────────────────────────────
  Widget _fieldLabel(String label, {bool required = false}) {
    return Row(
      children: [
        Text(label.toUpperCase(),
            style: AppTextStyles.fieldLabel(false)),
        if (required) ...[
          const SizedBox(width: 2),
          const Text(' *',
              style: TextStyle(
                  color:      AppColors.error,
                  fontSize:   13,
                  fontWeight: FontWeight.w700)),
        ],
      ],
    );
  }

  // ── Skeleton job card ──────────────────────────────────────────────────────
  Widget _skeletonJobCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _shimmer(width: 70, height: 22, radius: 5),
              const Spacer(),
              _shimmer(width: 28, height: 28, radius: 7),
              const SizedBox(width: 6),
              _shimmer(width: 28, height: 28, radius: 7),
            ],
          ),
          const SizedBox(height: 10),
          _shimmer(width: 140, height: 13, radius: 4),
          const SizedBox(height: 8),
          _shimmer(width: double.infinity, height: 12, radius: 4),
          const SizedBox(height: 5),
          _shimmer(width: 200, height: 12, radius: 4),
          const SizedBox(height: 10),
          _shimmer(width: 100, height: 11, radius: 4),
        ],
      ),
    );
  }

  Widget _shimmer(
          {required double width,
          required double height,
          required double radius}) =>
      _ShimmerBox(width: width, height: height, radius: radius);
}

// ── Shimmer ────────────────────────────────────────────────────────────────
class _ShimmerBox extends StatefulWidget {
  final double width, height, radius;
  const _ShimmerBox(
      {required this.width,
      required this.height,
      required this.radius});

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