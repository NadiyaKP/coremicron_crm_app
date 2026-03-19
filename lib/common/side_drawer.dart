import 'package:flutter/material.dart';
import 'theme.dart';
import '../screens/Registation/customer/customers.dart';
import '../screens/Registation/department/departments.dart';
import '../screens/Registation/team/teams.dart';
import '../screens/Registation/attendance_machine/attendance_machines.dart';
import '../screens/Registation/deals/deals.dart';
import '../screens/Registation/employee/employee.dart';
import '../screens/leads/leads.dart';
import '../screens/to-do/my_assigned_leads/my_assigned_leads.dart';
import '../screens/ticket/tickets.dart';
import '../screens/to-do/my_task/my_tasks.dart';
import '../screens/Follow_Up/follow_ups.dart';
import '../screens/employee_response/employee_responses.dart';
import '../screens/leave_application/leave_applications.dart';
import '../screens/update_attendance/update_attendance_list.dart';
import '../screens/my_project/my_projects.dart';

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
    _DrawerMenuItem(icon: Icons.task_alt_rounded,        label: 'My Task'),
    _DrawerMenuItem(icon: Icons.assignment_outlined,     label: 'My Assigned Leads'),
    _DrawerMenuItem(icon: Icons.event_note_outlined,     label: 'Follow Up'),
    _DrawerMenuItem(icon: Icons.forum_outlined,          label: 'Employee Response'),
    _DrawerMenuItem(icon: Icons.beach_access_outlined,   label: 'Leave Application'),
    _DrawerMenuItem(icon: Icons.fingerprint_rounded,     label: 'Update Attendance'),
    _DrawerMenuItem(icon: Icons.work_outline_rounded,    label: 'My Projects'),
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
                  const SizedBox(height: 8),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20),
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
                  padding:
                      const EdgeInsets.only(left: 28, right: 16),
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
          decoration:
              BoxDecoration(borderRadius: BorderRadius.circular(10)),
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

  Widget _buildSubItem(_DrawerMenuItem item) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        switch (item.label) {
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
                        EmployeeResponsesPage(username: widget.username)));
            break;
          case 'Leave Application':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        LeaveApplicationsPage(username: widget.username)));
            break;
          case 'Update Attendance':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        UpdateAttendancePage(username: widget.username)));
            break;
          case 'My Projects':
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        MyProjectsPage(username: widget.username)));
            break;
          default:
            break;
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: [
            Column(
              children: [
                Container(
                    width: 1.5, height: 10, color: AppColors.border),
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.5),
                  ),
                ),
                Container(
                    width: 1.5, height: 10, color: AppColors.border),
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
}

class _DrawerMenuItem {
  final IconData icon;
  final String   label;
  const _DrawerMenuItem({required this.icon, required this.label});
}