import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService, kTokenKey;
import 'package:coremicron_crm_app/common/theme.dart';
import 'tickets.dart' show Ticket;
import 'package:coremicron_crm_app/common/string_extensions.dart';

// ── Ticket View Page ───────────────────────────────────────────────────────
class TicketViewPage extends StatefulWidget {
  final Ticket? ticket;
  final String? ticketId;
  final String? ticketNumber;
  final String? title;
  final String? customerName;
  final String? phoneNumber;
  final String? typeOfTickets;
  final String? priority;
  final String? status;
  final String? addedDate;
  final String? addedTime;
  final String? addedBy;
  final String? taskHandlerName;
  final String? taskHandlerId;
  final String? notes;
  final String? customerId;

  const TicketViewPage({
    super.key,
    this.ticket,
    this.ticketId,
    this.ticketNumber,
    this.title,
    this.customerName,
    this.phoneNumber,
    this.typeOfTickets,
    this.priority,
    this.status,
    this.addedDate,
    this.addedTime,
    this.addedBy,
    this.taskHandlerName,
    this.taskHandlerId,
    this.notes,
    this.customerId,
  });

  // Helper to get ticket data
  Ticket get _ticket {
    if (ticket != null) return ticket!;
    
    return Ticket(
      ticketId: ticketId ?? '',
      ticketNumber: ticketNumber ?? '',
      title: title ?? '',
      customerName: customerName ?? '',
      phoneNumber: phoneNumber ?? '',
      customerId: customerId ?? '',
      typeOfTickets: typeOfTickets ?? '',
      priority: priority ?? '',
      status: status ?? '',
      addedDate: addedDate ?? '',
      addedTime: addedTime ?? '',
      addedBy: addedBy ?? '',
      taskHandlerName: taskHandlerName ?? '',
      taskHandlerId: taskHandlerId ?? '',
      notes: notes ?? '',
    );
  }

  @override
  State<TicketViewPage> createState() => _TicketViewPageState();
}

class _TicketViewPageState extends State<TicketViewPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  bool         _isLoading = true;
  String?      _errorMessage;
  List<dynamic> _jobs     = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _fetchJobs();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Fetch Job History ──────────────────────────────────────────────────────
  Future<void> _fetchJobs() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/ticket/job_list.php'
          '?ticket_id=${widget._ticket.ticketId}');
      final response = await ApiService.get(url).timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = jsonDecode(response.body);
      debugPrint(
          '📥  [JOB LIST] ${response.statusCode}  ${response.body}');

      if (response.statusCode == 200 && data['success'] == true) {
        _jobs = data['jobs'] ?? [];
      } else {
        _errorMessage =
            data['error'] ?? data['message'] ?? 'Failed to load job history.';
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


  Color _jobStatusColor(String s) {
    switch (s.toLowerCase()) {
      case 'completed':  return const Color(0xFF2E7D32);
      case 'pending':    return const Color(0xFFE65100);
      case 'verified':   return const Color(0xFF1565C0);
      case 'cancelled':  return AppColors.error;
      default:           return AppColors.primary;
    }
  }

  Color _jobStatusBg(String s) {
    switch (s.toLowerCase()) {
      case 'completed':  return const Color(0xFFE8F5E9);
      case 'pending':    return const Color(0xFFFFF3E0);
      case 'verified':   return const Color(0xFFE3F2FD);
      case 'cancelled':  return const Color(0xFFFFF1F1);
      default:           return AppColors.primaryLight;
    }
  }

  IconData _jobStatusIcon(String s) {
    switch (s.toLowerCase()) {
      case 'completed':  return Icons.check_circle_outline_rounded;
      case 'pending':    return Icons.hourglass_empty_rounded;
      case 'verified':   return Icons.verified_outlined;
      case 'cancelled':  return Icons.cancel_outlined;
      default:           return Icons.circle_outlined;
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
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildTicketDetails(hPad),
                  _isLoading
                      ? _buildJobSkeleton(hPad)
                      : _errorMessage != null
                          ? _buildError()
                          : _buildJobHistory(hPad),
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
    final t = widget._ticket;
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
                  'Ticket ${t.ticketNumber}',
                  style: TextStyle(
                      color:         AppColors.textPrimary,
                      fontSize:      isTablet ? 19 : 16,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: -0.3),
                ),
                Text(
                  t.customerName.capitalize(),
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

  // ── Tab Bar ────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller:            _tabCtrl,
        labelColor:            AppColors.primary,
        unselectedLabelColor:  AppColors.textSecondary,
        indicatorColor:        AppColors.primary,
        indicatorWeight:       2.5,
        labelStyle: const TextStyle(
            fontSize: 13.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
            fontSize: 13.5, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(text: 'Ticket Details'),
          Tab(text: 'Job History'),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── Tab 1 : Ticket Details ─────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTicketDetails(double hPad) {
    final t = widget._ticket;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Card: ticket info ─────────────────────────────────────────
          _sectionCard(
            title: 'Ticket Information',
            icon:  Icons.confirmation_number_outlined,
            children: [
              _detailRow(
                icon:  Icons.tag_rounded,
                label: 'Ticket Number',
                value: t.ticketNumber,
              ),
              _divider(),
              _detailRow(
                icon:  Icons.category_outlined,
                label: 'Type',
                value: t.typeOfTickets,
              ),
              _divider(),
              _detailRow(
                icon:  Icons.flag_outlined,
                label: 'Priority',
                value: t.priority.capitalize(),
                valueWidget: _priorityChip(t.priority.capitalize()),
              ),
              _divider(),
              _detailRow(
                icon:  Icons.calendar_today_outlined,
                label: 'Added Date',
                value: _fmtDate(t.addedDate),
              ),
              _divider(),
              _detailRow(
                icon:  Icons.person_outline_rounded,
                label: 'Added By',
                value: t.addedBy,
              ),
              _divider(),
              _detailRow(
                icon:  Icons.support_agent_outlined,
                label: 'Task Handled By',
                value: t.taskHandlerName.isEmpty ? '—' : t.taskHandlerName.capitalize(),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Card: customer ────────────────────────────────────────────
          _sectionCard(
            title: 'Customer',
            icon:  Icons.person_outline_rounded,
            children: [
              _detailRow(
                icon:  Icons.person_outline_rounded,
                label: 'Customer Name',
                value: t.customerName.capitalize(),
              ),
              _divider(),
              _detailRow(
                icon:  Icons.phone_outlined,
                label: 'Phone Number',
                value: t.phoneNumber,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Card: complaint details ───────────────────────────────────
          _sectionCard(
            title: 'Notes',
            icon:  Icons.description_outlined,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Text(
                  t.notes.isEmpty ? '—' : t.notes,
                  style: const TextStyle(
                    color:    AppColors.textPrimary,
                    fontSize: 13.5,
                    height:   1.6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJobHistory(double hPad) {
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
              Text(
                'No job history found for this ticket',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color:      AppColors.textSecondary,
                    fontSize:   14,
                    fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 6),
              Text(
                'Job history will appear here when jobs are assigned to this ticket',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color:  AppColors.textMuted,
                    fontSize: 12.5,
                    height:   1.5),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 32),
      itemCount: _jobs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 0),
      itemBuilder: (_, i) => _jobItem(_jobs[i], i),
    );
  }

  Widget _jobItem(dynamic item, int index) {
    final Map    j             = item as Map? ?? {};
    final String assignName    = j['assign_name']     ?? '';
    final String toDo          = j['to_do']           ?? '';
    final String fixbyDate     = _fmtDate(j['fixby_date']?.toString());
    final String completedDate = _fmtDate(j['completed_date']?.toString());
    final String status        = j['status']          ?? '';
    final bool   isLast        = index == _jobs.length - 1;

    final Color    statusClr  = _jobStatusColor(status);
    final Color    statusBg   = _jobStatusBg(status);
    final IconData statusIcon = _jobStatusIcon(status);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline spine ──────────────────────────────────────────
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color:  statusBg,
                    shape:  BoxShape.circle,
                    border: Border.all(
                        color: statusClr.withOpacity(0.4), width: 1.5),
                  ),
                  child: Icon(statusIcon, size: 15, color: statusClr),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                        width: 2, color: AppColors.borderLight),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Job card ────────────────────────────────────────────────
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.borderLight, width: 1),
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
                  // Status badge + assigned name
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:        statusBg,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                              color: statusClr.withOpacity(0.3),
                              width: 1),
                        ),
                        child: Text(
                          status.capitalize(),
                          style: TextStyle(
                              color:      statusClr,
                              fontSize:   10.5,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Spacer(),
                      // Assignee avatar + name
                      Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color:        AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            assignName.isNotEmpty
                                ? assignName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color:      AppColors.primary,
                                fontSize:   10,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        assignName.isEmpty ? '—' : assignName.capitalize(),
                        style: const TextStyle(
                            color:      AppColors.textPrimary,
                            fontSize:   12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),

                  if (toDo.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _jobRow(Icons.work_outline_rounded, 'Work', toDo),
                  ],

                  const SizedBox(height: 8),
                  const Divider(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: 8),

                  // Dates row
                  Row(
                    children: [
                      Expanded(
                        child: _jobDateCell(
                          icon:  Icons.event_outlined,
                          label: 'Fix By',
                          value: fixbyDate,
                          color: fixbyDate == '—'
                              ? AppColors.textMuted
                              : const Color(0xFFE65100),
                        ),
                      ),
                      if (status.toLowerCase() != 'pending') ...[
                        Container(
                            width: 1, height: 30,
                            color: AppColors.borderLight),
                        Expanded(
                          child: _jobDateCell(
                            icon:  Icons.check_circle_outline_rounded,
                            label: 'Completed',
                            value: completedDate,
                            color: completedDate == '—'
                                ? AppColors.textMuted
                                : const Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _jobRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 6),
        SizedBox(
          width: 40,
          child: Text(label,
              style: const TextStyle(
                  color:      AppColors.textMuted,
                  fontSize:   12,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  color:      AppColors.textPrimary,
                  fontSize:   12.5,
                  fontWeight: FontWeight.w500,
                  height:     1.4)),
        ),
      ],
    );
  }

  Widget _jobDateCell({
    required IconData icon,
    required String   label,
    required String   value,
    required Color    color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color:    AppColors.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 3),
              Text(value,
                  style: TextStyle(
                      color:      color,
                      fontSize:   12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Section card ───────────────────────────────────────────────────────────
  Widget _sectionCard({
    required String        title,
    required IconData      icon,
    required List<Widget>  children,
  }) {
    return Container(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color:        AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                        color:      AppColors.textPrimary,
                        fontSize:   13.5,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          ...children,
        ],
      ),
    );
  }

  // ── Detail row ─────────────────────────────────────────────────────────────
  Widget _detailRow({
    required IconData  icon,
    required String    label,
    required String    value,
    Widget?            valueWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.iconDefault),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    color:      AppColors.textMuted,
                    fontSize:   12.5,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: valueWidget ??
                Text(
                  value.isEmpty ? '—' : value,
                  style: const TextStyle(
                      color:      AppColors.textPrimary,
                      fontSize:   13,
                      fontWeight: FontWeight.w600),
                ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(
      height: 1, indent: 16, endIndent: 16,
      color: AppColors.borderLight);

  // ── Priority chip ──────────────────────────────────────────────────────────
  Widget _priorityChip(String priority) {
    Color clr;
    Color bg;
    switch (priority.toLowerCase()) {
      case 'high':
        clr = const Color(0xFFD32F2F);
        bg  = const Color(0xFFFFF1F1);
        break;
      case 'medium':
        clr = const Color(0xFFE65100);
        bg  = const Color(0xFFFFF3E0);
        break;
      case 'low':
        clr = const Color(0xFF2E7D32);
        bg  = const Color(0xFFE8F5E9);
        break;
      default:
        clr = AppColors.primary;
        bg  = AppColors.primaryLight;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: clr.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_outlined, size: 11, color: clr),
          const SizedBox(width: 3),
          Text(priority.capitalize(),
              style: TextStyle(
                  color:      clr,
                  fontSize:   11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────
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

  // ── Job skeleton ───────────────────────────────────────────────────────────
  Widget _buildJobSkeleton(double hPad) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 32),
      itemCount: 3,
      itemBuilder: (_, i) => _skeletonJobItem(isLast: i == 2),
    );
  }

  Widget _skeletonJobItem({bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                _shimmer(width: 32, height: 32, radius: 16),
                if (!isLast)
                  Expanded(
                    child: Container(
                        width: 2, color: AppColors.borderLight),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.borderLight, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _shimmer(width: 70, height: 22, radius: 5),
                      const Spacer(),
                      _shimmer(width: 110, height: 13, radius: 4),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _shimmer(width: double.infinity, height: 12, radius: 4),
                  const SizedBox(height: 6),
                  _shimmer(width: 200, height: 12, radius: 4),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: _shimmer(
                              width: double.infinity,
                              height: 32,
                              radius: 6)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _shimmer(
                              width: double.infinity,
                              height: 32,
                              radius: 6)),
                    ],
                  ),
                ],
              ),
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
}

// ── Shimmer box ────────────────────────────────────────────────────────────
class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
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
        vsync: this,
        duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
          width:  widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color:        const Color(0xFFE8EDF5),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
}