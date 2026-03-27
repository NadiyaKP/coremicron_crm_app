import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:coremicron_crm_app/common/api_service.dart' show ApiService;

import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/common/side_drawer.dart';
import 'package:coremicron_crm_app/screens/chat/chat_list.dart';
import 'package:coremicron_crm_app/common/chat_websocket_service.dart';
import 'package:coremicron_crm_app/screens/to-do/Follow_Up/follow_ups.dart';
import 'package:coremicron_crm_app/screens/to-do/my_task/my_tasks.dart';
import 'package:coremicron_crm_app/screens/my_profile/pending_works/my_pending_works.dart';
import 'package:coremicron_crm_app/screens/my_profile/my_attendance/my_attendance.dart';
import 'package:coremicron_crm_app/screens/ticket/tickets.dart';
import 'package:http/http.dart' as http;

// ── Dashboard data model ───────────────────────────────────────────────────
class _DashData {
  final int enquiry;
  final int job;
  final int completed;
  final int overdue;
  final int pending;
  final int dueTodayJobs;
  final int target;
  final int pendingFollowups;
  final int leavesTaken;
  final List<dynamic> notifications;
  final List<dynamic> followupList;
  final Map<String, dynamic> taskChart;

  const _DashData({
    required this.enquiry,
    required this.job,
    required this.completed,
    required this.overdue,
    required this.pending,
    required this.dueTodayJobs,
    required this.target,
    required this.pendingFollowups,
    required this.leavesTaken,
    required this.notifications,
    required this.followupList,
    required this.taskChart,
  });

  factory _DashData.fromJson(Map<String, dynamic> j) => _DashData(
        enquiry:          _int(j['enquiry']),
        job:              _int(j['job']),
        completed:        _int(j['completed']),
        overdue:          _int(j['overdue']),
        pending:          _int(j['pending']),
        dueTodayJobs:     _int(j['due_today_jobs']),
        target:           _int(j['target']),
        pendingFollowups: _int(j['pending_followups']),
        leavesTaken:      _int(j['leaves_taken']),
        notifications:    j['notification']  as List? ?? [],
        followupList:     j['followup_list'] as List? ?? [],
        taskChart:        j['task_chart']    as Map<String, dynamic>? ?? {},
      );

  static int _int(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
}

class HomePage extends StatefulWidget {
  final String username;
  final bool   openDrawerOnLoad;

  const HomePage({
    super.key,
    required this.username,
    this.openDrawerOnLoad = false,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  _DashData? _dash;
  bool       _isLoading = true;
  String?    _error;

  @override
  void initState() {
    super.initState();
    ChatWebSocketService().connect();

    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();

    _fetchDashboard();

    if (widget.openDrawerOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scaffoldKey.currentState?.openDrawer();
      });
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Fetch Dashboard ────────────────────────────────────────────────────────
  Future<void> _fetchDashboard() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final url = Uri.parse('${ApiService.baseUrl}/api/user/dashboard.php');
      final res = await ApiService.get(url).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && data['success'] == true) {
        setState(() => _dash = _DashData.fromJson(data));
      } else {
        setState(() => _error = data['message'] ?? 'Failed to load dashboard.');
      }
    } on http.ClientException {
      setState(() => _error = 'Unable to reach the server.');
    } catch (_) {
      setState(() => _error = 'Something went wrong.');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Date / time ────────────────────────────────────────────────────────────
  String _fmtNotifTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt  = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final date  = DateTime(dt.year, dt.month, dt.day);
      if (date == today) {
        final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        final m = dt.minute.toString().padLeft(2, '0');
        return '$h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}';
      }
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }

  Color _hexColor(String hex, {Color fallback = const Color(0xFF1558E7)}) {

    try {
      final s = hex.replaceAll('#', '');
      return Color(int.parse('FF$s', radix: 16));
    } catch (_) { return fallback; }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size     = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final hPad     = isTablet ? size.width * 0.06 : 16.0;

    return Scaffold(
      key:             _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: AppSideDrawer(
        username:             widget.username,
        registrationExpanded: widget.openDrawerOnLoad,
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: RefreshIndicator(
              color:       AppColors.primary,
              onRefresh:   _fetchDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    _buildTopBar(isTablet),
                    const SizedBox(height: 16),

                    _buildWelcomeSection(),
                    const SizedBox(height: 20),
                    _buildQuickSection(isTablet),
                    const SizedBox(height: 24),

                    if (_error != null) ...[
                      _buildErrorCard(),
                      const SizedBox(height: 24),
                    ],

                    if (_isLoading && _dash == null) ...[
                      _buildSkeletonStats(),
                      const SizedBox(height: 22),
                      _buildSkeletonSection(),
                    ] else ...[
                      _buildStatisticsGrid(isTablet),
                      const SizedBox(height: 24),
                      _buildTaskLineChart(),
                      const SizedBox(height: 24),
                      _buildFollowupLeads(isTablet),
                    ],




                    const SizedBox(height: 24),

                    Center(
                      child: Text(
                        '© ${DateTime.now().year} Coremicron CRM',
                        style: const TextStyle(
                            color:    AppColors.textMuted,
                            fontSize: 11,
                            letterSpacing: 0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Top Bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar(bool isTablet) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, width: 1.2),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04),
                    blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.menu_rounded,
                color: AppColors.textPrimary, size: 19),
          ),
        ),
        // Logo
        const Text(
          'CRM System',
          style: TextStyle(
            color:         AppColors.primary,
            fontSize:      18,
            fontWeight:    FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        // Notification Icon with Badge
        GestureDetector(
          onTap: _showNotificationDialog,
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, width: 1.2),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04),
                    blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.notifications_none_rounded,
                    color: AppColors.primary, size: 20),
                if (_dash != null && _dash!.notifications.isNotEmpty)
                  Positioned(
                    top: 6, right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                      child: Text('${_dash!.notifications.length}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }


  // ── Welcome Section ────────────────────────────────────────────────────────
  Widget _buildWelcomeSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome back -',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5)),
            SizedBox(height: 2),
            Text('Here is what happening today',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ],
        ),
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => ChatListPage(username: widget.username))),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:        AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.forum_rounded, color: AppColors.primary, size: 22),
          ),
        ),
      ],
    );
  }



  // ── Statistics Grid ───────────────────────────────────────────────────────
  Widget _buildStatisticsGrid(bool isTablet) {
    final d = _dash;
    final stats = [
      _Stat('Leads',          d?.enquiry ?? 0,          Icons.group_outlined,               const Color(0xFF1976D2),   const Color(0xFFE3F2FD)),
      _Stat('Task Assigned',  d?.job ?? 0,               Icons.assignment_outlined,           const Color(0xFF7B1FA2),   const Color(0xFFF3E5F5)),
      _Stat('Task Completed', d?.completed ?? 0,         Icons.task_alt_rounded,              const Color(0xFF388E3C),   const Color(0xFFE8F5E9)),
      _Stat('Follow-up',      d?.pendingFollowups ?? 0,  Icons.ring_volume_rounded,           const Color(0xFFF57C00),   const Color(0xFFFFF3E0),
          sub: ['0 Due Today']),
      _Stat('Task Pending',   d?.pending ?? 0,           Icons.hourglass_empty_rounded,       const Color(0xFFD32F2F),   const Color(0xFFFFF1F1),
          sub: ['${d?.overdue ?? 0} Overdue', '${d?.dueTodayJobs ?? 0} Due Today']),
      _Stat('Leave',          d?.leavesTaken ?? 0,       Icons.event_busy_rounded,            const Color(0xFF00796B),   const Color(0xFFE0F2F1)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Overview',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap:  true,
          physics:     const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:     2,
            mainAxisSpacing:    12,
            crossAxisSpacing:   12,
            childAspectRatio:   isTablet ? 1.8 : 1.45,
          ),
          itemCount: stats.length,
          itemBuilder: (_, i) => _statCard(stats[i]),
        ),
      ],
    );
  }

  Widget _statCard(_Stat s) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight, width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03),
              blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.label.toUpperCase(),
                  style: const TextStyle(
                      color:    AppColors.textMuted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800)),
              Icon(s.icon, size: 15, color: s.color.withOpacity(0.7)),
            ],
          ),
          const Spacer(),
          Text('${s.value}',
              style: const TextStyle(
                  color:      AppColors.textPrimary,
                  fontSize:   24,
                  fontWeight: FontWeight.w900)),
          if (s.sub != null && s.sub!.isNotEmpty) ...[
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: s.sub!.map((txt) => Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color:        s.color.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(txt,
                      style: TextStyle(
                          color:    s.color,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700)),
                )).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }




  // ── Quick Section ──────────────────────────────────────────────────────────
  Widget _buildQuickSection(bool isTablet) {
    final actions = [
      _QuickAction(icon: Icons.notifications_active_rounded,
          label: 'FOLLOW UP',
          color: const Color(0xFFF57C00), bg: const Color(0xFFFFF3E0),
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => FollowUpsPage(username: widget.username)))),
      _QuickAction(icon: Icons.playlist_add_check_rounded,
          label: 'MY TASK',
          color: const Color(0xFF1976D2), bg: const Color(0xFFE3F2FD),
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => MyTasksPage(username: widget.username)))),
      _QuickAction(icon: Icons.pending_actions_rounded,
          label: 'PENDING',
          color: const Color(0xFFD84315), bg: const Color(0xFFFBE9E7),
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => PendingWorksPage(username: widget.username)))),
      _QuickAction(icon: Icons.how_to_reg_rounded,
          label: 'ATTENDANCE',
          color: const Color(0xFF00796B), bg: const Color(0xFFE0F2F1),
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => MyAttendancePage(username: widget.username)))),
      _QuickAction(icon: Icons.support_agent_rounded,
          label: 'TICKETS',
          color: const Color(0xFF512DA8), bg: const Color(0xFFEDE7F6),
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => TicketsPage(username: widget.username)))),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Access',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        SizedBox(
          height: isTablet ? 110 : 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior:    Clip.none,
            itemCount:       actions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _quickActionBtn(actions[i], isTablet),
          ),
        ),
      ],
    );
  }

  Widget _quickActionBtn(_QuickAction a, bool isTablet) {
    return GestureDetector(
      onTap: a.onTap,
      child: Container(
        width:  isTablet ? 150 : 120,
        decoration: BoxDecoration(
          color:        a.color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: a.color.withOpacity(0.2),
                blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(a.icon, color: Colors.white, size: 22),
            const SizedBox(height: 8),
            Text(a.label,
                style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }




  // ── Task Analysis Line Chart ───────────────────────────────────────────────
  Widget _buildTaskLineChart() {
    final chart    = _dash?.taskChart ?? {};
    final labels   = (chart['labels']    as List? ?? []).map((e) => e.toString()).toList();
    final assigned = (chart['assigned']  as List? ?? []).map((e) => double.tryParse(e.toString()) ?? 0.0).toList();
    final completed= (chart['completed'] as List? ?? []).map((e) => double.tryParse(e.toString()) ?? 0.0).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03),
              blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Task Analysis',
                  style: TextStyle(color: AppColors.textPrimary,
                      fontSize: 16, fontWeight: FontWeight.w800)),
              Row(
                children: [
                  _legendDot(AppColors.primary, 'Assigned'),
                  const SizedBox(width: 12),
                  _legendDot(const Color(0xFF2E7D32), 'Completed'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: labels.isNotEmpty ? LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 0.5,
                      getTitlesWidget: (val, meta) => Text(val.toStringAsFixed(1),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 8)),

                    ),
                    axisNameWidget: const Text('Tasks',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
                    axisNameSize: 18,
                  ),

                  topTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        int idx = val.toInt();
                        if (idx >= 0 && idx < labels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(labels[idx],
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 28,
                    ),
                    axisNameWidget: const Text('Timeline',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
                    axisNameSize: 18,
                  ),
                ),

                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(assigned.length, (i) => FlSpot(i.toDouble(), assigned[i])),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withOpacity(0.05),
                    ),
                  ),
                  LineChartBarData(
                    spots: List.generate(completed.length, (i) => FlSpot(i.toDouble(), completed[i])),
                    isCurved: true,
                    color: const Color(0xFF2E7D32),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF2E7D32).withOpacity(0.05),
                    ),
                  ),
                ],
              ),
            ) : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bar_chart_rounded, size: 40, color: AppColors.textMuted.withOpacity(0.3)),
                    const SizedBox(height: 8),
                    const Text('Performance data not available',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(
            color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }


  // ── Followup Leads ─────────────────────────────────────────────────────────
  Widget _buildFollowupLeads(bool isTablet) {
    final list = _dash?.followupList ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Leads by Deal',
                style: TextStyle(color: AppColors.textPrimary,
                    fontSize: 16, fontWeight: FontWeight.w800)),
            Text('${list.length} active deals',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: list.isEmpty ? const EdgeInsets.all(24) : EdgeInsets.zero,
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderLight, width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02),
                  blurRadius: 15, offset: const Offset(0, 5)),
            ],
          ),
          child: list.isEmpty
              ? const Center(
                  child: Column(
                    children: [
                      Icon(Icons.folder_open_rounded, color: AppColors.textMuted, size: 28),
                      SizedBox(height: 8),
                      Text('No active deals available',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderLight, indent: 45),
                  itemBuilder: (_, i) {
                    final item = list[i] as Map<String, dynamic>;
                    final name   = (item['deals_name'] ?? '').toString();
                    final colorStr = (item['deal_color'] ?? '#1558E7').toString();
                    final total  = (item['total_followups']?.toString() ?? '0');
                    final dealColor = _hexColor(colorStr);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color:        dealColor,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(color: dealColor.withOpacity(0.2),
                                      blurRadius: 4, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Text(
                                _capitalize(name),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color:      Colors.white,
                                    fontSize:   13.5,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color:        dealColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(total,
                                style: TextStyle(
                                    color:      dealColor,
                                    fontSize:   12,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }



  // ── Notification Dialog ────────────────────────────────────────────────────
  void _showNotificationDialog() {
    final notifs = _dash?.notifications ?? [];
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  const Text('Notifications',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: notifs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 48, color: AppColors.textMuted.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          const Text('No new notifications',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: notifs.length,
                      separatorBuilder: (_, __) => const Divider(indent: 72),
                      itemBuilder: (_, i) {
                        final n = notifs[i] as Map<String, dynamic>;
                        final type = (n['type'] ?? '').toString();
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(color: _notifBg(type), borderRadius: BorderRadius.circular(14)),
                                child: Icon(_notifIcon(type), size: 22, color: _notifColor(type)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (n['title'] ?? '').toString(),
                                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      (n['message'] ?? '').toString(),
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _fmtNotifTime(n['created_at']?.toString()),
                                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }



  IconData _notifIcon(String type) {
    switch (type) {
      case 'job_message':       return Icons.message_outlined;
      case 'ticket_assigned':   return Icons.confirmation_number_outlined;
      case 'enquiry_reassigned':return Icons.person_pin_outlined;
      default:                  return Icons.notifications_outlined;
    }
  }

  Color _notifColor(String type) {
    switch (type) {
      case 'job_message':       return const Color(0xFF0277BD);
      case 'ticket_assigned':   return const Color(0xFFC62828);
      case 'enquiry_reassigned':return const Color(0xFF2E7D32);
      default:                  return AppColors.primary;
    }
  }

  Color _notifBg(String type) {
    switch (type) {
      case 'job_message':       return const Color(0xFFE1F5FE);
      case 'ticket_assigned':   return const Color(0xFFFFF1F1);
      case 'enquiry_reassigned':return const Color(0xFFE8F5E9);
      default:                  return AppColors.primaryLight;
    }
  }

  // ── Skeleton ───────────────────────────────────────────────────────────────
  Widget _buildSkeletonStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _shimmer(width: 80, height: 14, radius: 4),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, mainAxisSpacing: 10,
            crossAxisSpacing: 10, childAspectRatio: 0.88),
          itemCount: 8,
          itemBuilder: (_, __) => Container(
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _shimmer(width: 32, height: 32, radius: 9),
                  const SizedBox(height: 6),
                  _shimmer(width: 28, height: 16, radius: 4),
                  const SizedBox(height: 4),
                  _shimmer(width: 44, height: 9, radius: 3),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonSection() {
    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmer(width: 100, height: 14, radius: 4),
          const SizedBox(height: 14),
          _shimmer(width: double.infinity, height: 80, radius: 8),
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

  // ── Error ──────────────────────────────────────────────────────────────────
  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.border),
          const SizedBox(height: 12),
          Text(_error ?? 'Failed to load.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13.5)),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _fetchDashboard,
            icon:  const Icon(Icons.refresh_rounded,
                size: 15, color: Colors.white),
            label: const Text('Retry',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

// ── Helper models ──────────────────────────────────────────────────────────
class _QuickAction {
  final IconData    icon;
  final String      label;
  final Color       color;
  final Color       bg;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon, required this.label,
    required this.color, required this.bg, required this.onTap});
}

class _Stat {
  final String   label;
  final int      value;
  final IconData icon;
  final Color    color;
  final Color    bg;
  final List<String>? sub;
  const _Stat(this.label, this.value, this.icon, this.color, this.bg, {this.sub});
}


// ── Shimmer Box ────────────────────────────────────────────────────────────
class _ShimmerBox extends StatefulWidget {
  final double width, height, radius;
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