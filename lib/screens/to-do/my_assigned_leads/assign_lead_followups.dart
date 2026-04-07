import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService, kTokenKey;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/screens/login.dart' show kTokenKey;
import 'package:coremicron_crm_app/common/string_extensions.dart';

// ── Deal model ─────────────────────────────────────────────────────────────
class _Deal {
  final String id;
  final String name;
  final String color;
  _Deal({required this.id, required this.name, required this.color});
}

// ── Follow-up model ────────────────────────────────────────────────────────
class _FollowUp {
  final String comId;
  final String enquiryId;
  final String enquiryNumber;
  final String title;
  final String customerName;
  final String phoneNumber;
  final String followUp;
  final String followupStatus;
  final String notes;
  final String dealsId;
  final String addedDate;
  final String dealsName;
  final String dealColor;

  _FollowUp({
    required this.comId,
    required this.enquiryId,
    required this.enquiryNumber,
    required this.title,
    required this.customerName,
    required this.phoneNumber,
    required this.followUp,
    required this.followupStatus,
    required this.notes,
    required this.dealsId,
    required this.addedDate,
    required this.dealsName,
    required this.dealColor,
  });

  factory _FollowUp.fromJson(Map<String, dynamic> j) => _FollowUp(
        comId:          j['comid']            ?? '',
        enquiryId:      j['enquiry_id']       ?? '',
        enquiryNumber:  j['enquiry_number']   ?? '',
        title:          j['title']            ?? '',
        customerName:   j['customer_name']    ?? '',
        phoneNumber:    j['phone_number']     ?? '',
        followUp:       j['follow_up']        ?? '',
        followupStatus: j['followup_status']  ?? '',
        notes:          j['notes']            ?? '',
        dealsId:        j['deals_id']         ?? '',
        addedDate:      j['added_date']       ?? '',
        dealsName:      j['deals_name']       ?? '',
        dealColor:      j['deal_color']       ?? '',
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Assign Lead Follow-Up Page ─────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════
class AssignLeadFollowUpPage extends StatefulWidget {
  final String enquiryId;
  final String enquiryNumber;
  final String title;

  const AssignLeadFollowUpPage({
    super.key,
    required this.enquiryId,
    required this.enquiryNumber,
    this.title = '',
  });

  @override
  State<AssignLeadFollowUpPage> createState() =>
      _AssignLeadFollowUpPageState();
}

class _AssignLeadFollowUpPageState extends State<AssignLeadFollowUpPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // ── Deals dropdown ─────────────────────────────────────────────────────────
  List<_Deal> _deals        = [];
  bool        _dealsLoading = false;
  _Deal?      _selectedDeal;
  bool        _dealDropdownOpen = false;

  // ── Form ───────────────────────────────────────────────────────────────────
  DateTime?         _followUpDate;
  final _dateCtrl   = TextEditingController();
  final _notesCtrl  = TextEditingController();
  final _notesFocus = FocusNode();

  // ── Edit state ─────────────────────────────────────────────────────────────
  _FollowUp? _editingFollowUp; // null = new

  // ── Submit ─────────────────────────────────────────────────────────────────
  bool _isSaving = false;

  // ── Speech ─────────────────────────────────────────────────────────────────
  final stt.SpeechToText _speech          = stt.SpeechToText();
  bool                   _isListening     = false;
  bool                   _speechAvailable = false;
  String                 _baseSpeechText  = '';

  // ── Follow-ups list ────────────────────────────────────────────────────────
  List<_FollowUp> _followUps      = [];
  bool            _fuLoading      = true;
  String?         _fuError;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _notesFocus.addListener(() => setState(() {}));
    _initSpeech();
    _loadDeals();
    _fetchFollowUps();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _dateCtrl.dispose();
    _notesCtrl.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  // ── Speech ─────────────────────────────────────────────────────────────────
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
    _baseSpeechText = _notesCtrl.text.trim();
    if (_baseSpeechText.isNotEmpty) _baseSpeechText += ' ';
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _notesCtrl.text = _baseSpeechText + result.recognizedWords;
          _notesCtrl.selection = TextSelection.fromPosition(
              TextPosition(offset: _notesCtrl.text.length));
        });
      },
      listenFor:      const Duration(minutes: 1),
      pauseFor:       const Duration(seconds: 10),
      localeId:       'en_US',
      cancelOnError:  false,
      partialResults: true,
    );
    _speech.statusListener = (status) {
      if ((status == 'done' || status == 'notListening') &&
          _isListening &&
          mounted) {
        _restartListening();
      }
    };
  }

  void _stopListening() async {
    setState(() => _isListening = false);
    await _speech.stop();
  }

  void _restartListening() async {
    if (!_isListening || !mounted) return;
    _baseSpeechText = _notesCtrl.text.trim();
    if (_baseSpeechText.isNotEmpty) _baseSpeechText += ' ';
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _notesCtrl.text = _baseSpeechText + result.recognizedWords;
          _notesCtrl.selection = TextSelection.fromPosition(
              TextPosition(offset: _notesCtrl.text.length));
        });
      },
      listenFor:      const Duration(minutes: 1),
      pauseFor:       const Duration(seconds: 10),
      localeId:       'en_US',
      cancelOnError:  false,
      partialResults: true,
    );
  }

  // ── Load deals ─────────────────────────────────────────────────────────────
  Future<void> _loadDeals() async {
    if (_deals.isNotEmpty) return;
    setState(() => _dealsLoading = true);
    try {
      final res = await ApiService.get(
        Uri.parse('${ApiService.baseUrl}/api/deals/list.php'),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        final list = data['data'] as List? ?? [];
        _deals = list
            .map((e) => _Deal(
                  id:    e['id']         ?? '',
                  name:  e['deals_name'] ?? '',
                  color: e['color']      ?? '',
                ))
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _dealsLoading = false);
  }

  // ── Fetch follow-ups ───────────────────────────────────────────────────────
  Future<void> _fetchFollowUps() async {
    setState(() { _fuLoading = true; _fuError = null; });
    try {
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/leads/followup_list.php');

      final res = await ApiService.get(url).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [FOLLOWUP LIST] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        final list = data['followups'] as List? ?? [];
        // Filter only this lead's follow-ups
        _followUps = list
            .map((e) => _FollowUp.fromJson(e))
            .where((f) => f.enquiryId == widget.enquiryId)
            .toList();
      } else {
        _fuError = data['error'] ?? data['message'] ?? 'Failed to load follow-ups.';
      }
    } on http.ClientException {
      _fuError = 'Unable to reach the server.';
    } catch (_) {
      _fuError = 'Something went wrong.';
    }
    if (mounted) setState(() => _fuLoading = false);
  }

  // ── Date picker ────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final now    = DateTime.now();
    final picked = await showDatePicker(
      context:     context,
      initialDate: _followUpDate ?? now,
      firstDate:   DateTime(now.year - 2),
      lastDate:    DateTime(now.year + 5),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
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
      setState(() {
        _followUpDate = picked;
        _dateCtrl.text =
            '${picked.day.toString().padLeft(2, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.year}';
      });
    }
  }

  // ── Save / Update ──────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_selectedDeal == null) {
      AppSnackBar.show(context, 'Please select a deal.', isError: true);
      return;
    }
    if (_notesCtrl.text.trim().isEmpty) {
      AppSnackBar.show(context, 'Please enter notes.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final isUpdate  = _editingFollowUp != null;
      final url       = Uri.parse(isUpdate
          ? '${ApiService.baseUrl}/api/leads/followup_update.php'
          : '${ApiService.baseUrl}/api/leads/followup_add.php');

      final String? formattedDate = _followUpDate != null
          ? '${_followUpDate!.year}-'
            '${_followUpDate!.month.toString().padLeft(2, '0')}-'
            '${_followUpDate!.day.toString().padLeft(2, '0')}'
          : null;

      final Map<String, dynamic> body = isUpdate
          ? {
              'comid':    _editingFollowUp!.comId,
              'deals_id': _selectedDeal!.id,
              'notes':    _notesCtrl.text.trim(),
              if (formattedDate != null) 'follow_up': formattedDate,
            }
          : {
              'enquiry_id': widget.enquiryId,
              'deals_id':   _selectedDeal!.id,
              'notes':      _notesCtrl.text.trim(),
              if (formattedDate != null) 'follow_up': formattedDate,
            };

      final res = await ApiService.post(url, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [FOLLOWUP ${isUpdate ? 'UPDATE' : 'ADD'}] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context,
            isUpdate ? 'Follow-up updated.' : 'Follow-up saved.');
        _resetForm();
        await _fetchFollowUps();
        _tabCtrl.animateTo(1);
      } else {
        AppSnackBar.show(
            context,
            data['error'] ?? data['message'] ?? 'Failed to save.',
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
    if (mounted) setState(() => _isSaving = false);
  }

  void _resetForm() {
    setState(() {
      _editingFollowUp = null;
      _selectedDeal    = null;
      _followUpDate    = null;
      _dateCtrl.clear();
      _notesCtrl.clear();
      _isSaving        = false;
    });
  }

  void _startEdit(_FollowUp fu) async {
    await _loadDeals();
    _Deal? deal;
    try {
      deal = _deals.firstWhere((d) => d.id == fu.dealsId);
    } catch (_) {
      if (fu.dealsId.isNotEmpty) {
        deal = _Deal(
            id: fu.dealsId, name: fu.dealsName, color: fu.dealColor);
      }
    }

    DateTime? dt;
    try {
      final parts = fu.followUp.split('-');
      if (parts.length == 3) {
        dt = DateTime(int.parse(parts[0]), int.parse(parts[1]),
            int.parse(parts[2]));
      }
    } catch (_) {}

    setState(() {
      _editingFollowUp = fu;
      _selectedDeal    = deal;
      _followUpDate    = dt;
      _dateCtrl.text   = dt != null
          ? '${dt.day.toString().padLeft(2, '0')}-'
            '${dt.month.toString().padLeft(2, '0')}-'
            '${dt.year}'
          : fu.followUp;
      _notesCtrl.text  = fu.notes;
    });
    _tabCtrl.animateTo(0);
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  void _showDeleteDialog(_FollowUp fu) {
    final reasonCtrl  = TextEditingController();
    bool  isDeleting  = false;

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
              const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          content: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
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
                      child: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.error, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Delete Follow-Up',
                          style: TextStyle(
                              color:      AppColors.textPrimary,
                              fontSize:   15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Text(
                  'Are you sure you want to delete this follow-up?',
                  style: TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 13.5,
                      height:   1.5),
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 12),

                // Details
                _dialogRow(Icons.handshake_outlined,
                    'Deal', fu.dealsName.capitalize()),
                const SizedBox(height: 8),
                _dialogRow(Icons.event_outlined,
                    'Follow Up', _fmtDate(fu.followUp)),

                const SizedBox(height: 14),

                // Reason text field
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

                // Buttons
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
                        onPressed: isDeleting
                            ? null
                            : () async {
                                if (reasonCtrl.text.trim().isEmpty) {
                                  AppSnackBar.show(
                                      context,
                                      'Please enter a reason.',
                                      isError: true);
                                  return;
                                }
                                setS(() => isDeleting = true);
                                Navigator.pop(dCtx);
                                await _deleteFollowUp(
                                    fu.comId, reasonCtrl.text.trim());
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
                          child: isDeleting
                              ? const SizedBox(
                                  key:   ValueKey('del-loader'),
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

  Future<void> _deleteFollowUp(String comId, String reason) async {
    try {
      final url  = Uri.parse(
          '${ApiService.baseUrl}/api/leads/followup_delete.php');
      final body = {'comid': comId, 'reason': reason};

      final res = await ApiService.post(url, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [FOLLOWUP DELETE] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Follow-up deleted.');
        _fetchFollowUps();
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

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return '—';
    try {
      final p = raw.trim().split('-');
      if (p.length == 3) return '${p[2]}-${p[1]}-${p[0]}';
    } catch (_) {}
    return raw;
  }

  Color _dealColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
      return Color(int.parse(clean, radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'completed': return const Color(0xFF2E7D32);
      case 'pending':   return const Color(0xFFE65100);
      default:          return AppColors.primary;
    }
  }

  Color _statusBg(String s) {
    switch (s.toLowerCase()) {
      case 'completed': return const Color(0xFFE8F5E9);
      case 'pending':   return const Color(0xFFFFF3E0);
      default:          return AppColors.primaryLight;
    }
  }

  Widget _dialogRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(label,
              style: const TextStyle(
                  color:      AppColors.textMuted,
                  fontSize:   12.5,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(
                color:      AppColors.textPrimary,
                fontSize:   13,
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String label, {bool required = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                color:      AppColors.textLabel,
                fontSize:   12,
                fontWeight: FontWeight.w600)),
        if (required)
          const Text(' *',
              style: TextStyle(
                  color:      AppColors.error,
                  fontSize:   13,
                  fontWeight: FontWeight.w700)),
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
                  _buildFormTab(hPad),
                  _buildFollowUpsTab(hPad),
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
        border:
            Border(bottom: BorderSide(color: AppColors.borderLight)),
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
                border:
                    Border.all(color: AppColors.border, width: 1.2),
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
                  'Follow-Ups',
                  style: TextStyle(
                      color:         AppColors.textPrimary,
                      fontSize:      isTablet ? 19 : 16,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: -0.3),
                ),
                Text(
                  '#${widget.enquiryNumber}',
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
        controller:              _tabCtrl,
        labelColor:              AppColors.primary,
        unselectedLabelColor:    AppColors.textSecondary,
        indicatorColor:          AppColors.primary,
        indicatorWeight:         2.5,
        labelStyle: const TextStyle(
            fontSize: 13.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
            fontSize: 13.5, fontWeight: FontWeight.w500),
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_task_rounded, size: 16),
                const SizedBox(width: 6),
                Text(_editingFollowUp != null
                    ? 'Edit Follow-Up'
                    : 'Add Follow-Up'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history_rounded, size: 16),
                const SizedBox(width: 6),
                const Text('Follow-Ups'),
                if (!_fuLoading && _followUps.isNotEmpty) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color:        AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_followUps.length}',
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
  // ── Tab 1 : Add / Edit Follow-Up ─────────────────────────────────────────
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildFormTab(double hPad) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 32),
      keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Edit banner
          if (_editingFollowUp != null)
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
                    child: Text('Editing existing follow-up',
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

          // ── Deal dropdown ─────────────────────────────────────────────
          _fieldLabel('Select a Deal', required: true),
          const SizedBox(height: 8),
          _buildDealDropdown(),

          const SizedBox(height: 16),

          // ── Follow Up Date ────────────────────────────────────────────
          _fieldLabel('Follow Up Date'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickDate,
            child: AbsorbPointer(
              child: Container(
                decoration: BoxDecoration(
                  color:        Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                      color: _followUpDate != null
                          ? AppColors.primary
                          : AppColors.border,
                      width: 1.2),
                ),
                child: TextField(
                  controller: _dateCtrl,
                  style: const TextStyle(
                      color:      AppColors.textPrimary,
                      fontSize:   14,
                      fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    hintText:  'DD-MM-YYYY',
                    hintStyle: TextStyle(
                        color: AppColors.textHint, fontSize: 13.5),
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

          // ── Notes ─────────────────────────────────────────────────────
          _fieldLabel('Notes', required: true),
          const SizedBox(height: 8),
          _buildNotesField(),

          const SizedBox(height: 28),

          // ── Buttons ───────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          if (_editingFollowUp != null) {
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
                    _editingFollowUp != null ? 'Discard' : 'Cancel',
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
                  onPressed: _isSaving ? null : _save,
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
                            key:   ValueKey('s-loader'),
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color:       Colors.white,
                                strokeWidth: 2.4))
                        : Text(
                            _editingFollowUp != null
                                ? 'Update'
                                : 'Save',
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

  // ── Deal Dropdown ──────────────────────────────────────────────────────────
  Widget _buildDealDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () async {
            await _loadDeals();
            setState(() => _dealDropdownOpen = !_dealDropdownOpen);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: _selectedDeal != null
                      ? AppColors.primary
                      : AppColors.border,
                  width: 1.2),
            ),
            child: Row(
              children: [
                if (_selectedDeal != null)
                  Container(
                    width: 14, height: 14,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color:  _dealColor(_selectedDeal!.color),
                      shape:  BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Text(
                    _selectedDeal != null
                        ? _selectedDeal!.name.capitalize()
                        : 'Select a deal',
                    style: TextStyle(
                        color: _selectedDeal != null
                            ? AppColors.textPrimary
                            : AppColors.textHint,
                        fontSize:   14,
                        fontWeight: _selectedDeal != null
                            ? FontWeight.w500
                            : FontWeight.w400),
                  ),
                ),
                _dealsLoading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary))
                    : AnimatedRotation(
                        turns:    _dealDropdownOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size:  20,
                            color: AppColors.iconDefault),
                      ),
              ],
            ),
          ),
        ),

        // Dropdown list
        if (_dealDropdownOpen && _deals.isNotEmpty)
          Container(
            margin:      const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(11),
              border:
                  Border.all(color: AppColors.borderLight, width: 1),
              boxShadow: [
                BoxShadow(
                    color:      Colors.black.withOpacity(0.08),
                    blurRadius: 14,
                    offset:     const Offset(0, 4)),
              ],
            ),
            child: ListView.separated(
              shrinkWrap:       true,
              padding:          EdgeInsets.zero,
              itemCount:        _deals.length,
              separatorBuilder: (_, __) => const Divider(
                  height: 1, color: AppColors.borderLight),
              itemBuilder: (_, i) {
                final deal = _deals[i];
                final bg   = _dealColor(deal.color);
                return InkWell(
                  onTap: () => setState(() {
                    _selectedDeal    = deal;
                    _dealDropdownOpen = false;
                  }),
                  borderRadius: BorderRadius.circular(11),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                    child: Row(
                      children: [
                        Container(
                          width: 12, height: 12,
                          decoration: BoxDecoration(
                              color: bg, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(deal.name.capitalize(),
                              style: const TextStyle(
                                  color:      AppColors.textPrimary,
                                  fontSize:   13.5,
                                  fontWeight: FontWeight.w500)),
                        ),
                        if (_selectedDeal?.id == deal.id)
                          const Icon(Icons.check_rounded,
                              size: 16, color: AppColors.primary),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ── Notes field with speech ────────────────────────────────────────────────
  Widget _buildNotesField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: _notesFocus.hasFocus
          ? AppDecorations.inputFocused
          : AppDecorations.inputIdle,
      child: Column(
        children: [
          TextField(
            controller:  _notesCtrl,
            focusNode:   _notesFocus,
            maxLines:    5,
            minLines:    4,
            cursorColor: AppColors.primary,
            style: const TextStyle(
                color:    AppColors.textPrimary,
                fontSize: 14),
            decoration: const InputDecoration(
              hintText:
                  'Enter notes or click microphone to speak…',
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
              border:
                  Border(top: BorderSide(color: AppColors.borderLight)),
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
                // Start button
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
                        Icon(Icons.play_arrow_rounded,
                            size:  16,
                            color: _isListening
                                ? AppColors.textMuted
                                : AppColors.primary),
                        const SizedBox(width: 4),
                        Text('Start',
                            style: TextStyle(
                                color: _isListening
                                    ? AppColors.textMuted
                                    : AppColors.primary,
                                fontSize:   12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Stop button
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
                        Icon(Icons.stop_rounded,
                            size:  16,
                            color: _isListening
                                ? Colors.white
                                : AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text('Stop',
                            style: TextStyle(
                                color: _isListening
                                    ? Colors.white
                                    : AppColors.textMuted,
                                fontSize:   12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ── Tab 2 : Follow-Ups List ───────────────────────────────────────────────
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildFollowUpsTab(double hPad) {
    if (_fuLoading) {
      return ListView.builder(
        padding:     EdgeInsets.fromLTRB(hPad, 20, hPad, 32),
        itemCount:   4,
        itemBuilder: (_, __) => _skeletonCard(),
      );
    }

    if (_fuError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 48, color: AppColors.border),
              const SizedBox(height: 12),
              Text(_fuError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 13.5)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchFollowUps,
                icon: const Icon(Icons.refresh_rounded,
                    size: 15, color: Colors.white),
                label: const Text('Retry',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation:       0),
              ),
            ],
          ),
        ),
      );
    }

    if (_followUps.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.history_rounded,
                size: 52, color: AppColors.border),
            SizedBox(height: 14),
            Text('No follow-ups yet',
                style: TextStyle(
                    color:      AppColors.textSecondary,
                    fontSize:   14,
                    fontWeight: FontWeight.w500)),
            SizedBox(height: 6),
            Text('Add a follow-up from the form tab',
                style: TextStyle(
                    color:    AppColors.textMuted,
                    fontSize: 12.5)),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 32),
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Text(
                '${_followUps.length} follow-up'
                '${_followUps.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    color:      AppColors.textSecondary,
                    fontSize:   12.5,
                    fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _fetchFollowUps,
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
        ..._followUps.map((fu) => _followUpCard(fu)).toList(),
      ],
    );
  }

  Widget _followUpCard(_FollowUp fu) {
    final bg        = _dealColor(fu.dealColor);
    final luminance = bg.computeLuminance();
    final chipText  = luminance > 0.45
        ? const Color(0xFF1A1A2E)
        : Colors.white;

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
          // ── Top row: enquiry badge + action icons ───────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#${fu.enquiryNumber}',
                  style: const TextStyle(
                      color:      AppColors.primary,
                      fontSize:   11,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              // Edit
              GestureDetector(
                onTap: () => _startEdit(fu),
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
                onTap: () => _showDeleteDialog(fu),
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

          // ── Deal chip + follow-up date on the same row ───────────────
          Row(
            children: [
              if (fu.dealsName.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color:        bg,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(fu.dealsName.capitalize(),
                      style: TextStyle(
                          color:      chipText,
                          fontSize:   12,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
              ],
              const Spacer(),
              const Icon(Icons.event_outlined,
                  size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                _fmtDate(fu.followUp),
                style: const TextStyle(
                    color:      AppColors.textMuted,
                    fontSize:   12,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),

          // ── Notes ────────────────────────────────────────────────────
          if (fu.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_rounded,
                    size: 13, color: AppColors.textMuted),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(fu.notes,
                      style: const TextStyle(
                          color:    AppColors.textSecondary,
                          fontSize: 12.5,
                          height:   1.45)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Skeleton card ──────────────────────────────────────────────────────────
  Widget _skeletonCard() {
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
              _shimmer(width: 50, height: 22, radius: 6),
              const SizedBox(width: 6),
              _shimmer(width: 70, height: 22, radius: 5),
              const Spacer(),
              _shimmer(width: 28, height: 28, radius: 7),
              const SizedBox(width: 6),
              _shimmer(width: 28, height: 28, radius: 7),
            ],
          ),
          const SizedBox(height: 10),
          _shimmer(width: 100, height: 24, radius: 7),
          const SizedBox(height: 8),
          _shimmer(width: 160, height: 12, radius: 4),
          const SizedBox(height: 8),
          _shimmer(width: double.infinity, height: 11, radius: 4),
          const SizedBox(height: 5),
          _shimmer(width: 200, height: 11, radius: 4),
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