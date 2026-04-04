import 'package:flutter/material.dart';
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/screens/Registation/customer/customers.dart';
import 'package:coremicron_crm_app/screens/Registation/department/departments.dart';
import 'package:coremicron_crm_app/screens/Registation/team/teams.dart';
import 'package:coremicron_crm_app/screens/Registation/attendance_machine/attendance_machines.dart';
import 'package:coremicron_crm_app/screens/Registation/deals/deals.dart';
import 'package:coremicron_crm_app/screens/Registation/employee/employee.dart';
import 'package:coremicron_crm_app/screens/leads/leads.dart';
import 'package:coremicron_crm_app/screens/to-do/my_assigned_leads/my_assigned_leads.dart';
import 'package:coremicron_crm_app/screens/ticket/tickets.dart';
import 'package:coremicron_crm_app/screens/to-do/my_task/my_tasks.dart';
import 'package:coremicron_crm_app/screens/to-do/Follow_Up/follow_ups.dart';
import 'package:coremicron_crm_app/screens/to-do/employee_response/employee_responses.dart';
import 'package:coremicron_crm_app/screens/to-do/leave_application/leave_applications.dart';
import 'package:coremicron_crm_app/screens/to-do/update_attendance/update_attendance_list.dart';
import 'package:coremicron_crm_app/screens/to-do/my_project/my_projects.dart';
import 'package:coremicron_crm_app/screens/my_profile/my_attendance/my_attendance.dart';
import 'package:coremicron_crm_app/screens/my_profile/leave_application/my_leave_application.dart';
import 'package:coremicron_crm_app/screens/my_profile/pending_works/my_pending_works.dart';
import 'package:coremicron_crm_app/screens/my_profile/completed_tasks/my_completed_tasks.dart';
import 'package:coremicron_crm_app/screens/reports/lead_wise_report.dart';
import 'package:coremicron_crm_app/screens/reports/deal_wise_report.dart';
import 'package:coremicron_crm_app/screens/reports/employee_wise_report.dart';
import 'package:coremicron_crm_app/screens/reports/pending_wise_report.dart';
import 'package:coremicron_crm_app/screens/reports/attendance_wise_report.dart';
import 'package:coremicron_crm_app/screens/reports/leave_application_report.dart';
import 'package:coremicron_crm_app/screens/reports/amc_wise_report.dart';
import 'package:coremicron_crm_app/screens/reports/analysis_report.dart';
import 'package:coremicron_crm_app/screens/settings/change_password.dart';
import 'package:coremicron_crm_app/screens/settings/api_url.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coremicron_crm_app/screens/login.dart';
import 'package:coremicron_crm_app/common/api_service.dart';

class AppSideDrawer extends StatefulWidget {
  final String username;
  final bool registrationExpanded;
  const AppSideDrawer(
      {super.key,
      required this.username,
      this.registrationExpanded = false});

  @override
  State<AppSideDrawer> createState() => _AppSideDrawerState();
}

class _AppSideDrawerState extends State<AppSideDrawer> {
  bool _registrationExpanded = false;
  bool _todoExpanded         = false;
  bool _profileExpanded      = false;
  bool _reportsExpanded      = false;
  bool _settingsExpanded     = false;

  @override
  void initState() {
    super.initState();
    _registrationExpanded = widget.registrationExpanded;
  }

  final List<_DrawerMenuItem> _registrationItems = [
    _DrawerMenuItem(icon: Icons.apartment_rounded,      label: 'Department'),
    _DrawerMenuItem(icon: Icons.person_outline_rounded, label: 'Customer'),
    _DrawerMenuItem(icon: Icons.badge_outlined,         label: 'Employee'),
    _DrawerMenuItem(icon: Icons.handshake_outlined,     label: 'Deals'),
    _DrawerMenuItem(icon: Icons.groups_outlined,        label: 'Teams'),
    _DrawerMenuItem(icon: Icons.fingerprint_rounded,    label: 'Attendance Machines'),
  ];

  final List<_DrawerMenuItem> _todoItems = [
    _DrawerMenuItem(icon: Icons.task_alt_rounded,       label: 'My Task'),
    _DrawerMenuItem(icon: Icons.assignment_outlined,    label: 'My Assigned Leads'),
    _DrawerMenuItem(icon: Icons.event_note_outlined,    label: 'Follow Up'),
    _DrawerMenuItem(icon: Icons.forum_outlined,         label: 'Employee Response'),
    _DrawerMenuItem(icon: Icons.beach_access_outlined,  label: 'Leave Application'),
    _DrawerMenuItem(icon: Icons.fingerprint_rounded,    label: 'Update Attendance'),
    _DrawerMenuItem(icon: Icons.work_outline_rounded,   label: 'My Projects'),
  ];

  final List<_DrawerMenuItem> _profileItems = [
    _DrawerMenuItem(icon: Icons.calendar_month_outlined,      label: 'My Attendance'),
    _DrawerMenuItem(icon: Icons.beach_access_outlined,        label: 'My Leave Application'),
    _DrawerMenuItem(icon: Icons.pending_actions_rounded,      label: 'Pending Works'),
    _DrawerMenuItem(icon: Icons.check_circle_outline_rounded, label: 'Completed Tasks'),
  ];

  final List<_DrawerMenuItem> _reportsItems = [
    _DrawerMenuItem(icon: Icons.format_list_bulleted_rounded, label: 'Leads Wise'),
    _DrawerMenuItem(icon: Icons.handshake_outlined,           label: 'Deal Wise'),
    _DrawerMenuItem(icon: Icons.badge_outlined,               label: 'Employee Wise'),
    _DrawerMenuItem(icon: Icons.pending_actions_rounded,      label: 'Pending Works', id: 'pending_wise'),
    _DrawerMenuItem(icon: Icons.fingerprint_rounded,          label: 'Attendance'),
    _DrawerMenuItem(icon: Icons.beach_access_outlined,        label: 'Leave Application', id: 'leave_report'),
    _DrawerMenuItem(icon: Icons.description_rounded,          label: 'AMC Report', id: 'amc_report'),
    _DrawerMenuItem(icon: Icons.analytics_rounded,            label: 'Analysis Report', id: 'analysis_report'),
  ];

  final List<_DrawerMenuItem> _settingsItems = [
    _DrawerMenuItem(icon: Icons.lock_outline_rounded, label: 'Change Password'),
    _DrawerMenuItem(icon: Icons.link_rounded,         label: 'API URL'),
    _DrawerMenuItem(icon: Icons.logout_rounded,       label: 'Logout'),
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      width: MediaQuery.of(context).size.width * 0.78,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildExpandableSection(
                    icon:     Icons.app_registration_rounded,
                    label:    'Registration',
                    expanded: _registrationExpanded,
                    items:    _registrationItems,
                    onTap:    () => setState(
                        () => _registrationExpanded = !_registrationExpanded),
                  ),
                  const SizedBox(height: 4),
                  _buildStandaloneItem(
                      icon: Icons.format_list_bulleted_rounded,
                      label: 'Leads'),
                  const SizedBox(height: 4),
                  _buildStandaloneItem(
                      icon: Icons.confirmation_number_outlined,
                      label: 'Tickets'),
                  const SizedBox(height: 4),
                  _buildExpandableSection(
                    icon:     Icons.checklist_rounded,
                    label:    'To Do',
                    expanded: _todoExpanded,
                    items:    _todoItems,
                    onTap:    () =>
                        setState(() => _todoExpanded = !_todoExpanded),
                  ),
                  const SizedBox(height: 4),
                  _buildExpandableSection(
                    icon:     Icons.person_outline_rounded,
                    label:    'My Profile',
                    expanded: _profileExpanded,
                    items:    _profileItems,
                    onTap:    () =>
                        setState(() => _profileExpanded = !_profileExpanded),
                  ),
                  const SizedBox(height: 4),
                  _buildExpandableSection(
                    icon:     Icons.bar_chart_rounded,
                    label:    'Reports',
                    expanded: _reportsExpanded,
                    items:    _reportsItems,
                    onTap:    () =>
                        setState(() => _reportsExpanded = !_reportsExpanded),
                  ),
                  const SizedBox(height: 4),
                  _buildExpandableSection(
                    icon:     Icons.settings_outlined,
                    label:    'Settings',
                    expanded: _settingsExpanded,
                    items:    _settingsItems,
                    onTap:    () =>
                        setState(() => _settingsExpanded = !_settingsExpanded),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(
                        color: AppColors.borderLight, thickness: 1),
                  ),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Expandable section ─────────────────────────────────────────────────────
  Widget _buildExpandableSection({
    required IconData              icon,
    required String                label,
    required bool                  expanded,
    required List<_DrawerMenuItem> items,
    required VoidCallback          onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap:        onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color:        expanded
                    ? AppColors.primaryLight
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color:        expanded
                          ? AppColors.primary
                          : const Color(0xFFF0F4FF),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon,
                        size:  17,
                        color: expanded
                            ? Colors.white
                            : AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(label,
                        style: TextStyle(
                            color:         expanded
                                ? AppColors.primary
                                : AppColors.textPrimary,
                            fontSize:      14,
                            fontWeight:    FontWeight.w600,
                            letterSpacing: -0.1)),
                  ),
                  AnimatedRotation(
                    turns:    expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: expanded
                            ? AppColors.primary
                            : AppColors.iconDefault,
                        size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve:    Curves.easeInOut,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(left: 28, right: 16),
                  child: Column(
                      children: items
                          .map((item) => _buildSubItem(item))
                          .toList()),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ── Standalone item ────────────────────────────────────────────────────────
  Widget _buildStandaloneItem(
      {required IconData icon, required String label}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          switch (label) {
            case 'Leads':
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          LeadsPage(username: widget.username)));
              break;
            case 'Tickets':
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          TicketsPage(username: widget.username)));
              break;
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color:        AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Text(label,
                  style: const TextStyle(
                      color:      AppColors.textPrimary,
                      fontSize:   14,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sub-item tile ──────────────────────────────────────────────────────────
  Widget _buildSubItem(_DrawerMenuItem item) {
    return InkWell(
      onTap: () {
        if (item.label != 'Logout') {
          Navigator.pop(context);
        }
        final String key = item.id ?? item.label;
        switch (key) {
          // ── Registration ─────────────────────────────────────────────
          case 'Department':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        DepartmentPage(username: widget.username)));
            break;
          case 'Customer':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        CustomersPage(username: widget.username)));
            break;
          case 'Teams':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        TeamsPage(username: widget.username)));
            break;
          case 'Employee':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        EmployeePage(username: widget.username)));
            break;
          case 'Deals':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        DealsPage(username: widget.username)));
            break;
          case 'Attendance Machines':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        AttendanceMachinePage(
                            username: widget.username)));
            break;

          // ── To Do ────────────────────────────────────────────────────
          case 'Ticket':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        TicketsPage(username: widget.username)));
            break;
          case 'My Task':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        MyTasksPage(username: widget.username)));
            break;
          case 'My Assigned Leads':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        MyAssignedLeadsPage(
                            username: widget.username)));
            break;
          case 'Follow Up':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        FollowUpsPage(username: widget.username)));
            break;
          case 'Employee Response':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        EmployeeResponsesPage(
                            username: widget.username)));
            break;
          case 'Leave Application':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        LeaveApplicationsPage(
                            username: widget.username)));
            break;
          case 'Update Attendance':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        UpdateAttendancePage(
                            username: widget.username)));
            break;
          case 'My Projects':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        MyProjectsPage(username: widget.username)));
            break;

          // ── My Profile ───────────────────────────────────────────────
          case 'My Attendance':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        MyAttendancePage(username: widget.username)));
            break;
          case 'My Leave Application':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        MyLeaveApplicationPage(
                            username: widget.username)));
            break;
          case 'Pending Works':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        PendingWorksPage(username: widget.username)));
            break;
          case 'Completed Tasks':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        MyCompletedTasksPage(
                            username: widget.username)));
            break;

          // ── Reports ──────────────────────────────────────────────────
          case 'Leads Wise':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        LeadWiseReportPage(username: widget.username)));
            break;
          case 'Deal Wise':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        DealWiseReportPage(username: widget.username)));
            break;
          case 'Employee Wise':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        EmployeeWiseReportPage(username: widget.username)));
            break;
          case 'pending_wise':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        PendingWiseReportPage(username: widget.username)));
            break;
          case 'leave_report':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        LeaveApplicationReportPage(username: widget.username)));
            break;
          case 'amc_report':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        AmcReportPage(username: widget.username)));
            break;
          case 'analysis_report':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        AnalysisReportPage(username: widget.username)));
            break;
          case 'Attendance':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        AttendanceWiseReportPage(username: widget.username)));
            break;

          // ── Settings ─────────────────────────────────────────────────
          case 'Change Password':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ChangePasswordPage()));
            break;
          case 'API URL':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ApiUrlPage()));
            break;
          case 'Logout':
            _handleLogout();
            break;

          default:
            break;
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 7),
        child: Row(
          children: [
            Column(
              children: [
                Container(
                    width: 1.5, height: 10,
                    color: AppColors.border),
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.5),
                  ),
                ),
                Container(
                    width: 1.5, height: 10,
                    color: AppColors.border),
              ],
            ),
            const SizedBox(width: 14),
            Icon(item.icon, size: 18, color: AppColors.textLabel),
            const SizedBox(width: 10),
            Text(item.label,
                style: const TextStyle(
                    color:      AppColors.textPrimary,
                    fontSize:   13.5,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft:  Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
              color:      AppColors.primary.withOpacity(0.28),
              blurRadius: 20,
              offset:     const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color:        Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.25), width: 1),
                ),
                child: const Icon(Icons.layers_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Core',
                      style: TextStyle(
                          color:         Colors.white,
                          fontSize:      18,
                          fontWeight:    FontWeight.w800,
                          letterSpacing: -0.2),
                    ),
                    TextSpan(
                      text: 'micron',
                      style: TextStyle(
                          color:         Color(0xFFAAD4FF),
                          fontSize:      18,
                          fontWeight:    FontWeight.w800,
                          letterSpacing: -0.2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.20),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.30), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    widget.username.isNotEmpty
                        ? widget.username[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   18,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.username,
                      style: const TextStyle(
                          color:         Colors.white,
                          fontSize:      15,
                          fontWeight:    FontWeight.w700,
                          letterSpacing: -0.2)),
                  const SizedBox(height: 2),
                  Text('CRM User',
                      style: TextStyle(
                          color:      Colors.white.withOpacity(0.65),
                          fontSize:   12,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: AppColors.borderLight, width: 1)),
      ),
      child: Text(
        '© ${DateTime.now().year} Coremicron CRM',
        style: const TextStyle(
            color:         AppColors.textMuted,
            fontSize:      11,
            letterSpacing: 0.2),
      ),
    );
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> _handleLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textLabel)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout',
                style: TextStyle(
                    color:      AppColors.error,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final url = Uri.parse('${ApiService.baseUrl}/auth/logout.php');
      await ApiService.post(url).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Logout API Error: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }
}

// ── Menu item model ────────────────────────────────────────────────────────
class _DrawerMenuItem {
  final IconData icon;
  final String   label;
  final String?  id;
  const _DrawerMenuItem({required this.icon, required this.label, this.id});
}