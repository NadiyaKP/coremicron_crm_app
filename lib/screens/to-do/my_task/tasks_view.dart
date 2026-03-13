import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../common/api_service.dart';
import '../../../common/theme.dart';
import '../../login.dart' show kSessionKey;
import '../../ticket/tickets.dart' show Ticket;
import '../../../common/string_extensions.dart';

// ── Task View Page ─────────────────────────────────────────────────────────
class TasksViewPage extends StatefulWidget {
  final Ticket ticket;
  const TasksViewPage({super.key, required this.ticket});

  @override
  State<TasksViewPage> createState() => _TasksViewPageState();
}

class _TasksViewPageState extends State<TasksViewPage> {
  bool         _isLoading = true;
  String?      _errorMessage;
  List<dynamic> _jobs     = [];
  String        _ticketNumber = '';
  String        _title        = '';

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
          '?mode=my_assigned&ticket_id=${widget.ticket.ticketId}');

      debugPrint('─────────────────────────────────────────');
      debugPrint('📤  [TASK VIEW] Request');
      debugPrint('   🌐  URL : $url');
      debugPrint('─────────────────────────────────────────');

      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Accept':       'application/json',
        'X-Session-ID': sessionId,
        'Cookie':       'PHPSESSID=$sessionId',
      }).timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = jsonDecode(response.body);
      debugPrint('📥  [TASK VIEW] ${response.statusCode}  ${response.body}');

      if (response.statusCode == 200 && data['success'] == true) {
        _ticketNumber = data['ticket_number']?.toString() ?? '';
        _title        = data['title']?.toString()         ?? '';
        _jobs         = data['jobs'] as List? ?? [];
        if (_jobs.isNotEmpty) {
          debugPrint('🔍  [TASK VIEW] First Job Keys: ${_jobs.first.keys}');
          debugPrint('🖼️  [TASK VIEW] First Job Image: ${_jobs.first['image']}');
        }
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

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return '—';
    try {
      final p = raw.trim().split('-');
      if (p.length == 3) return '${p[2]}-${p[1]}-${p[0]}';
    } catch (_) {}
    return raw;
  }


  bool _isCompleted(dynamic job) =>
      (job['status'] ?? '').toString().toLowerCase() == 'completed';

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'completed': return const Color(0xFF2E7D32);
      case 'verified':  return const Color(0xFF1565C0);
      case 'cancelled': return AppColors.error;
      default:          return const Color(0xFFE65100); // pending
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

  Widget? _buildDeadlineIndicator(dynamic job) {
    if (_isCompleted(job)) return null;

    final rawDate = job['fixby_date']?.toString();
    if (rawDate == null || rawDate.isEmpty || rawDate == 'null') return null;

    try {
      final fixBy = DateTime.parse(rawDate);
      final now   = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final diff  = fixBy.difference(today).inDays;

      if (diff < 0) {
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${diff} days - You have exceeded the deadline',
            style: const TextStyle(
                color: AppColors.error,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        );
      } else if (diff <= 3) {
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '$diff day${diff == 1 ? '' : 's'} left',
            style: const TextStyle(
                color: Color(0xFFE65100),
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        );
      }
    } catch (_) {}
    return null;
  }

  void _viewImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty || imageUrl == 'null') return;
    
    final fullUrl = imageUrl.startsWith('http')
        ? imageUrl
        : '${ApiService.baseUrl}/uploads/$imageUrl';
        
    debugPrint('🖼️  [IMAGE VIEW] URL: $fullUrl');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    fullUrl,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Text('Failed to load image',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 32),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reply dialog ───────────────────────────────────────────────────────────
  void _showReplyDialog(dynamic job) {
    final ctrl = TextEditingController();
    final focus = FocusNode();
    bool isSending = false;

    showModalBottomSheet(
      context:        context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bCtx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color:        AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color:        AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.reply_rounded,
                          size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Reply to Task',
                              style: TextStyle(
                                  color:      AppColors.textPrimary,
                                  fontSize:   15,
                                  fontWeight: FontWeight.w700)),
                          Text(
                            (job['to_do']?.toString() ?? '').length > 45
                                ? '${job['to_do'].toString().substring(0, 45)}…'
                                : job['to_do']?.toString() ?? '',
                            style: const TextStyle(
                                color:    AppColors.textMuted,
                                fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 14),

                // Reply text field
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: focus.hasFocus
                      ? AppDecorations.inputFocused
                      : AppDecorations.inputIdle,
                  child: TextField(
                    controller:      ctrl,
                    focusNode:       focus,
                    maxLines:        4,
                    minLines:        3,
                    cursorColor:     AppColors.primary,
                    autofocus:       true,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(
                        color:      AppColors.textPrimary,
                        fontSize:   14),
                    decoration: const InputDecoration(
                      hintText:  'Type your reply…',
                      hintStyle: TextStyle(
                          color:    AppColors.textHint,
                          fontSize: 13.5),
                      border:         InputBorder.none,
                      enabledBorder:  InputBorder.none,
                      focusedBorder:  InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(bCtx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.border, width: 1.3),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11)),
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
                        onPressed: isSending
                            ? null
                            : () async {
                                if (ctrl.text.trim().isEmpty) {
                                  AppSnackBar.show(
                                      context,
                                      'Please type a reply.',
                                      isError: true);
                                  return;
                                }
                                setS(() => isSending = true);
                                await _sendReply(
                                    job['job_id']?.toString() ?? '',
                                    ctrl.text.trim());
                                if (mounted) Navigator.pop(bCtx);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor:
                              AppColors.primary.withOpacity(0.45),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11)),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: isSending
                              ? const SizedBox(
                                  key: ValueKey('r-loader'),
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      color:       Colors.white,
                                      strokeWidth: 2.3))
                              : const Text('Send',
                                  key: ValueKey('r-label'),
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
        ),
      ),
    );
  }

  Future<void> _sendReply(String jobId, String reply) async {
    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url  = Uri.parse(
          '${ApiService.baseUrl}/api/ticket/job_reply.php');
      final body = {'job_id': jobId, 'reply': reply};

      debugPrint('📤  [REPLY] $url  ${jsonEncode(body)}');

      final response = await http.post(url,
          headers: {
            'Content-Type': 'application/json',
            'Accept':       'application/json',
            'X-Session-ID': sessionId,
            'Cookie':       'PHPSESSID=$sessionId',
          },
          body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint('📥  [REPLY] ${response.statusCode}  ${response.body}');

      if (response.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Reply sent successfully.');
      } else {
        AppSnackBar.show(
            context,
            data['error'] ?? data['message'] ?? 'Failed to send reply.',
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

  Future<void> _toggleJobCompletion(dynamic job) async {
    final jobId = job['job_id']?.toString() ?? '';
    if (jobId.isEmpty) return;

    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url  = Uri.parse('${ApiService.baseUrl}/api/ticket/job_complete.php');
      final body = {'job_id': jobId};

      debugPrint('📤  [JOB COMPLETE] $url  ${jsonEncode(body)}');

      final response = await http.post(url,
          headers: {
            'Content-Type': 'application/json',
            'Accept':       'application/json',
            'X-Session-ID': sessionId,
            'Cookie':       'PHPSESSID=$sessionId',
          },
          body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint('📥  [JOB COMPLETE] ${response.statusCode}  ${response.body}');

      if (response.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Task updated successfully.');
        _fetchJobs(); // Refresh to update status
      } else {
        AppSnackBar.show(
            context,
            data['error'] ?? data['message'] ?? 'Failed to complete job.',
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

  // ═══════════════════════════════════════════════════════════════════════════
  // ── Build ───────────────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
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
                  ? _buildSkeleton(hPad)
                  : _errorMessage != null
                      ? _buildError()
                      : _buildContent(hPad),
            ),
          ],
        ),
      ),
    );
  }

  // ── App Bar ─────────────────────────────────────────────────────────────────
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
                  _isLoading
                      ? (widget.ticket.title.isEmpty
                          ? 'Task Details'
                          : widget.ticket.title.capitalize())
                      : (_title.isEmpty
                          ? 'Task Details'
                          : _title.capitalize()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color:         AppColors.textPrimary,
                      fontSize:      isTablet ? 19 : 16,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: -0.3),
                ),
                Text(
                  'Ticket #${_isLoading ? widget.ticket.ticketNumber : _ticketNumber}',
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

  // ── Content ─────────────────────────────────────────────────────────────────
  Widget _buildContent(double hPad) {
    if (_jobs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.task_outlined, size: 52, color: AppColors.border),
              SizedBox(height: 14),
              Text('No tasks found for this ticket',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color:      AppColors.textSecondary,
                      fontSize:   14,
                      fontWeight: FontWeight.w600)),
              SizedBox(height: 6),
              Text(
                'Tasks assigned to you will appear here',
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

    // Progress summary
    final total     = _jobs.length;
    final completed = _jobs.where((j) => _isCompleted(j)).length;
    final progress  = total > 0 ? completed / total : 0.0;

    return ListView(
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 32),
      children: [
        // ── Ticket header card ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(14),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color:        AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Ticket #$_ticketNumber',
                      style: const TextStyle(
                          color:      AppColors.primary,
                          fontSize:   11.5,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$completed / $total done',
                    style: const TextStyle(
                        color:      AppColors.textMuted,
                        fontSize:   11.5,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _title.capitalize(),
                style: const TextStyle(
                    color:      AppColors.textPrimary,
                    fontSize:   14.5,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value:            progress,
                  minHeight:        6,
                  backgroundColor:  AppColors.borderLight,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress == 1.0
                        ? const Color(0xFF2E7D32)
                        : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Jobs list ───────────────────────────────────────────────────
        ..._jobs.asMap().entries.map((entry) {
          final index = entry.key;
          final job   = entry.value;
          return _jobCard(job, index);
        }).toList(),
      ],
    );
  }

  // ── Job card ─────────────────────────────────────────────────────────────
  Widget _jobCard(dynamic job, int index) {
    final completed   = _isCompleted(job);
    final status      = job['status']?.toString() ?? '';
    final toDo        = job['to_do']?.toString() ?? '';
    final fixbyDate   = _fmtDate(job['fixby_date']?.toString());
    final statusClr   = _statusColor(status);
    final statusBg    = _statusBg(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: completed
              ? const Color(0xFF2E7D32).withOpacity(0.25)
              : AppColors.borderLight,
          width: 1,
        ),
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
          // ── Main row: checkbox + content ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: SizedBox(
                    width: 22, height: 22,
                    child: Checkbox(
                      value:          completed,
                      onChanged: (val) {
                        if (val != null) {
                          _toggleJobCompletion(job);
                        }
                      },
                      activeColor:    const Color(0xFF2E7D32),
                      checkColor:     Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5)),
                      side: BorderSide(
                        color: completed
                            ? const Color(0xFF2E7D32)
                            : AppColors.border,
                        width: 1.5,
                      ),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Task number badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:        AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Task ${index + 1}',
                          style: const TextStyle(
                              color:      AppColors.primary,
                              fontSize:   10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // To Do text — strikethrough if completed
                      Text(
                        toDo.isEmpty ? '(No description)' : toDo,
                        style: TextStyle(
                          color: completed
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                          fontSize:   13.5,
                          fontWeight: FontWeight.w500,
                          height:     1.45,
                          decoration: completed
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor:
                              AppColors.textMuted,
                          decorationThickness: 1.8,
                        ),
                      ),
                      if (_buildDeadlineIndicator(job) != null)
                        _buildDeadlineIndicator(job)!,

                      // Attachment
                      if (job['image'] != null &&
                          job['image'].toString().isNotEmpty &&
                          job['image'].toString() != 'null')
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: GestureDetector(
                            onTap: () => _viewImage(job['image'].toString()),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: Colors.blue.withOpacity(0.3),
                                    width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.attachment_rounded,
                                      size: 11, color: Colors.blue),
                                  SizedBox(width: 3),
                                  Text('Attachment',
                                      style: TextStyle(
                                          color: Colors.blue,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.borderLight),

          // ── Bottom row: status + fix by date + reply ──────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 10),
            child: Row(
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color:        statusBg,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                        color: statusClr.withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        completed
                            ? Icons.check_circle_outline_rounded
                            : Icons.hourglass_empty_rounded,
                        size:  10,
                        color: statusClr,
                      ),
                      const SizedBox(width: 3),
                      Text(status.capitalize(),
                          style: TextStyle(
                              color:      statusClr,
                              fontSize:   10.5,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Fix by date
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_outlined,
                        size: 11, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Text(fixbyDate,
                        style: const TextStyle(
                            color:    AppColors.textMuted,
                            fontSize: 11.5)),
                  ],
                ),

                const Spacer(),

                // Reply button
                GestureDetector(
                  onTap: () => _showReplyDialog(job),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color:        AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.25),
                          width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.reply_rounded,
                            size: 13, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text('Reply',
                            style: TextStyle(
                                color:      AppColors.primary,
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

  // ── Skeleton ────────────────────────────────────────────────────────────────
  Widget _buildSkeleton(double hPad) {
    return ListView(
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 32),
      children: [
        // Header skeleton
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _shimmer(width: 90, height: 22, radius: 6),
                const Spacer(),
                _shimmer(width: 70, height: 13, radius: 4),
              ]),
              const SizedBox(height: 10),
              _shimmer(width: 200, height: 15, radius: 4),
              const SizedBox(height: 14),
              _shimmer(width: double.infinity, height: 6, radius: 4),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (int i = 0; i < 3; i++) ...[
          _skeletonJobCard(),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _skeletonJobCard() {
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmer(width: 22, height: 22, radius: 5),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _shimmer(width: 50, height: 16, radius: 4),
                      const SizedBox(height: 8),
                      _shimmer(
                          width: double.infinity, height: 13, radius: 4),
                      const SizedBox(height: 5),
                      _shimmer(width: 200, height: 13, radius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 10),
            child: Row(
              children: [
                _shimmer(width: 70, height: 22, radius: 5),
                const SizedBox(width: 8),
                _shimmer(width: 80, height: 13, radius: 4),
                const Spacer(),
                _shimmer(width: 64, height: 28, radius: 8),
              ],
            ),
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

  // ── Error ────────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
      ),
    );
  }
}

// ── Shimmer ──────────────────────────────────────────────────────────────────
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