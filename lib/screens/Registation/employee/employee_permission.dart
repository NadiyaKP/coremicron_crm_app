import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/common/string_extensions.dart';

// ── Scope helpers ──────────────────────────────────────────────────────────
// scope: 0 = None, 1 = Added Only, 2 = All
const _scopeLabels = ['All', 'Added Only', 'None'];
const _scopeValues = [2, 1, 0];

class EmployeePermissionPage extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const EmployeePermissionPage({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<EmployeePermissionPage> createState() =>
      _EmployeePermissionPageState();
}

class _EmployeePermissionPageState extends State<EmployeePermissionPage> {
  bool    _isLoading  = true;
  bool    _isSaving   = false;
  String? _errorMessage;

  // ── Permission state ───────────────────────────────────────────────────────
  bool _administrator = false;

  // Enquiry / Leads
  bool _enquiryAdd         = false;
  int  _enquiryViewScope   = 0;
  int  _enquiryEditScope   = 0;
  int  _enquiryDeleteScope = 0;
  int  _enquiryRejectScope = 0;

  // Followup
  bool _followupView     = false;
  bool _followupComplete = false;

  // Registration — Deals
  bool _regDealsView   = false;
  bool _regDealsAdd    = false;
  bool _regDealsEdit   = false;
  bool _regDealsDelete = false;

  // Registration — Department
  bool _regDeptView   = false;
  bool _regDeptAdd    = false;
  bool _regDeptEdit   = false;
  bool _regDeptDelete = false;

  // Registration — Employee
  bool _regEmpView       = false;
  bool _regEmpAdd        = false;
  bool _regEmpEdit       = false;
  bool _regEmpStatus     = false;
  bool _regEmpPermission = false;

  // Registration — Teams
  bool _regTeamsView   = false;
  bool _regTeamsAdd    = false;
  bool _regTeamsEdit   = false;
  bool _regTeamsStatus = false;

  // Registration — Customer
  bool _regCustView   = false;
  bool _regCustAdd    = false;
  bool _regCustEdit   = false;
  bool _regCustDelete = false;

  // Registration — Machine
  bool _regMachView   = false;
  bool _regMachAdd    = false;
  bool _regMachEdit   = false;
  bool _regMachDelete = false;

  // Ticket
  bool _ticketAdd         = false;
  int  _ticketViewScope   = 0;
  int  _ticketEditScope   = 0;
  int  _ticketAssignScope = 0;
  int  _ticketDeleteScope = 0;

  // Jobs
  bool _jobsView   = false;
  bool _jobsAdd    = false;
  bool _jobsEdit   = false;
  bool _jobsDelete = false;

  // Attendance
  bool _attendRequest  = false;
  bool _attendView     = false;
  bool _attendRegister = false;

  // Leave
  bool _leaveView    = false;
  bool _leaveAdd     = false;
  bool _leaveEdit    = false;
  bool _leaveDelete  = false;
  bool _leaveReject  = false;
  bool _leaveApprove = false;

  // Reports
  bool _repEnquiry     = false;
  bool _repDeal        = false;
  bool _repEmployee    = false;
  bool _repPending     = false;
  bool _repAttendance  = false;
  bool _repLeave       = false;

  // ── Fetch ──────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fetchPermissions();
  }

  Future<void> _fetchPermissions() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/employee/get_permission.php'
          '?employee_id=${widget.employeeId}');

      debugPrint('📤  [GET PERMISSION] $url');
      final res = await ApiService.get(url)
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [GET PERMISSION] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        _applyPermissions(data['permissions'] as Map<String, dynamic>);
      } else {
        _errorMessage =
            data['error'] ?? data['message'] ?? 'Failed to load permissions.';
      }
    } on http.ClientException {
      _errorMessage = 'Unable to reach the server. Check your connection.';
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _applyPermissions(Map<String, dynamic> p) {
    _administrator = p['administrator'] == true;

    final eq = p['enquiry'] as Map<String, dynamic>? ?? {};
    _enquiryAdd         = eq['add'] == true;
    _enquiryViewScope   = (eq['view_scope']   as num?)?.toInt() ?? 0;
    _enquiryEditScope   = (eq['edit_scope']   as num?)?.toInt() ?? 0;
    _enquiryDeleteScope = (eq['delete_scope'] as num?)?.toInt() ?? 0;
    _enquiryRejectScope = (eq['reject_scope'] as num?)?.toInt() ?? 0;

    final fu = p['followup'] as Map<String, dynamic>? ?? {};
    _followupView     = fu['view']     == true;
    _followupComplete = fu['complete'] == true;

    final reg  = p['registration'] as Map<String, dynamic>? ?? {};
    final deal = reg['deals']      as Map<String, dynamic>? ?? {};
    _regDealsView   = deal['view']   == true;
    _regDealsAdd    = deal['add']    == true;
    _regDealsEdit   = deal['edit']   == true;
    _regDealsDelete = deal['delete'] == true;

    final dept = reg['department'] as Map<String, dynamic>? ?? {};
    _regDeptView   = dept['view']   == true;
    _regDeptAdd    = dept['add']    == true;
    _regDeptEdit   = dept['edit']   == true;
    _regDeptDelete = dept['delete'] == true;

    final emp = reg['employee'] as Map<String, dynamic>? ?? {};
    _regEmpView       = emp['view']              == true;
    _regEmpAdd        = emp['add']               == true;
    _regEmpEdit       = emp['edit']              == true;
    _regEmpStatus     = emp['status_update']     == true;
    _regEmpPermission = emp['permission_manage'] == true;

    final teams = reg['teams'] as Map<String, dynamic>? ?? {};
    _regTeamsView   = teams['view']          == true;
    _regTeamsAdd    = teams['add']           == true;
    _regTeamsEdit   = teams['edit']          == true;
    _regTeamsStatus = teams['status_update'] == true;

    final cust = reg['customer'] as Map<String, dynamic>? ?? {};
    _regCustView   = cust['view']   == true;
    _regCustAdd    = cust['add']    == true;
    _regCustEdit   = cust['edit']   == true;
    _regCustDelete = cust['delete'] == true;

    final mach = reg['machine'] as Map<String, dynamic>? ?? {};
    _regMachView   = mach['view']   == true;
    _regMachAdd    = mach['add']    == true;
    _regMachEdit   = mach['edit']   == true;
    _regMachDelete = mach['delete'] == true;

    final tk = p['ticket'] as Map<String, dynamic>? ?? {};
    _ticketAdd         = tk['add']          == true;
    _ticketViewScope   = (tk['view_scope']   as num?)?.toInt() ?? 0;
    _ticketEditScope   = (tk['edit_scope']   as num?)?.toInt() ?? 0;
    _ticketAssignScope = (tk['assign_scope'] as num?)?.toInt() ?? 0;
    _ticketDeleteScope = (tk['delete_scope'] as num?)?.toInt() ?? 0;

    final jobs = p['jobs'] as Map<String, dynamic>? ?? {};
    _jobsView   = jobs['view']   == true;
    _jobsAdd    = jobs['add']    == true;
    _jobsEdit   = jobs['edit']   == true;
    _jobsDelete = jobs['delete'] == true;

    final att = p['attendance'] as Map<String, dynamic>? ?? {};
    _attendRequest  = att['request']  == true;
    _attendView     = att['view']     == true;
    _attendRegister = att['register'] == true;

    final lv = p['leave'] as Map<String, dynamic>? ?? {};
    _leaveView    = lv['view']    == true;
    _leaveAdd     = lv['add']     == true;
    _leaveEdit    = lv['edit']    == true;
    _leaveDelete  = lv['delete']  == true;
    _leaveReject  = lv['reject']  == true;
    _leaveApprove = lv['approve'] == true;

    final rp = p['reports'] as Map<String, dynamic>? ?? {};
    _repEnquiry    = rp['enquiry']      == true;
    _repDeal       = rp['deal']         == true;
    _repEmployee   = rp['employee']     == true;
    _repPending    = rp['pendingworks'] == true;
    _repAttendance = rp['attendance']   == true;
    _repLeave      = rp['leave']        == true;
  }

  // ── Build payload ──────────────────────────────────────────────────────────
  Map<String, dynamic> _buildPayload() => {
    'employee_id': widget.employeeId,
    'permissions': {
      'administrator': _administrator,
      'enquiry': {
        'add':          _enquiryAdd,
        'view_scope':   _enquiryViewScope,
        'edit_scope':   _enquiryEditScope,
        'delete_scope': _enquiryDeleteScope,
        'reject_scope': _enquiryRejectScope,
      },
      'followup': {
        'view':     _followupView,
        'complete': _followupComplete,
      },
      'registration': {
        'deals': {
          'view': _regDealsView, 'add': _regDealsAdd,
          'edit': _regDealsEdit, 'delete': _regDealsDelete,
        },
        'department': {
          'view': _regDeptView, 'add': _regDeptAdd,
          'edit': _regDeptEdit, 'delete': _regDeptDelete,
        },
        'employee': {
          'view': _regEmpView, 'add': _regEmpAdd,
          'edit': _regEmpEdit, 'status_update': _regEmpStatus,
          'permission_manage': _regEmpPermission,
        },
        'teams': {
          'view': _regTeamsView, 'add': _regTeamsAdd,
          'edit': _regTeamsEdit, 'status_update': _regTeamsStatus,
        },
        'customer': {
          'view': _regCustView, 'add': _regCustAdd,
          'edit': _regCustEdit, 'delete': _regCustDelete,
        },
        'machine': {
          'view': _regMachView, 'add': _regMachAdd,
          'edit': _regMachEdit, 'delete': _regMachDelete,
        },
      },
      'ticket': {
        'add':          _ticketAdd,
        'view_scope':   _ticketViewScope,
        'edit_scope':   _ticketEditScope,
        'assign_scope': _ticketAssignScope,
        'delete_scope': _ticketDeleteScope,
      },
      'jobs': {
        'view': _jobsView, 'add': _jobsAdd,
        'edit': _jobsEdit, 'delete': _jobsDelete,
      },
      'attendance': {
        'request':  _attendRequest,
        'view':     _attendView,
        'register': _attendRegister,
      },
      'leave': {
        'view':    _leaveView,    'add':     _leaveAdd,
        'edit':    _leaveEdit,    'delete':  _leaveDelete,
        'reject':  _leaveReject,  'approve': _leaveApprove,
      },
      'reports': {
        'enquiry':      _repEnquiry,
        'deal':         _repDeal,
        'employee':     _repEmployee,
        'pendingworks': _repPending,
        'attendance':   _repAttendance,
        'leave':        _repLeave,
      },
    },
  };

  // ── Save ───────────────────────────────────────────────────────────────────
  Future<void> _savePermissions() async {
    setState(() => _isSaving = true);
    try {
      final url     = Uri.parse(
          '${ApiService.baseUrl}/api/employee/update_permission.php');
      final payload = _buildPayload();

      debugPrint('📤  [UPDATE PERMISSION] $url  ${jsonEncode(payload)}');
      final res = await ApiService.post(url, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [UPDATE PERMISSION] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Permissions updated successfully.');
        Navigator.pop(context);
      } else {
        AppSnackBar.show(
            context,
            data['error'] ?? data['message'] ?? 'Failed to update permissions.',
            isError: true);
      }
    } on http.ClientException {
      if (mounted)
        AppSnackBar.show(context, 'Unable to reach the server.', isError: true);
    } catch (e) {
      if (mounted) AppSnackBar.show(context, 'Error: $e', isError: true);
    }
    if (mounted) setState(() => _isSaving = false);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size     = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final hPad     = isTablet ? size.width * 0.06 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFE8EEF4),
      body: SafeArea(
        child: Column(
          children: [
            // ── App Bar ───────────────────────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 13),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                    bottom: BorderSide(
                        color: AppColors.borderLight, width: 1)),
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
                        border: Border.all(
                            color: AppColors.border, width: 1.2),
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
                          '${widget.employeeName.capitalize()} Access Permissions',
                          style: TextStyle(
                              color:      AppColors.primary,
                              fontSize:   isTablet ? 17 : 14.5,
                              fontWeight: FontWeight.w800),
                        ),
                        const Text('Manage employee permissions',
                            style: TextStyle(
                                color:    AppColors.textSecondary,
                                fontSize: 11.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ──────────────────────────────────────────────────
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2.4)))
            else if (_errorMessage != null)
              Expanded(child: _buildError())
            else
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 20),
                  children: [
                    _buildSection('ADMINISTRATOR', [
                      _checkRow('Administrator', _administrator,
                          (v) => setState(() => _administrator = v)),
                    ]),

                    _buildSection('LEADS', [
                      _checkRow('Add', _enquiryAdd,
                          (v) => setState(() => _enquiryAdd = v)),
                      _scopeRow('View', _enquiryViewScope,
                          (v) => setState(() => _enquiryViewScope = v)),
                      _scopeRow('Edit', _enquiryEditScope,
                          (v) => setState(() => _enquiryEditScope = v)),
                      _scopeRow('Delete', _enquiryDeleteScope,
                          (v) => setState(() => _enquiryDeleteScope = v)),
                      _scopeRow('Reject', _enquiryRejectScope,
                          (v) => setState(() => _enquiryRejectScope = v)),
                    ]),

                    _buildSection('FOLLOWUP', [
                      _checkRow('View', _followupView,
                          (v) => setState(() => _followupView = v)),
                      _checkRow('Complete', _followupComplete,
                          (v) => setState(() => _followupComplete = v)),
                    ]),

                    _buildSection('REGISTRATION — DEALS', [
                      _checkRow('View',   _regDealsView,   (v) => setState(() => _regDealsView   = v)),
                      _checkRow('Add',    _regDealsAdd,    (v) => setState(() => _regDealsAdd    = v)),
                      _checkRow('Edit',   _regDealsEdit,   (v) => setState(() => _regDealsEdit   = v)),
                      _checkRow('Delete', _regDealsDelete, (v) => setState(() => _regDealsDelete = v)),
                    ]),

                    _buildSection('REGISTRATION — DEPARTMENT', [
                      _checkRow('View',   _regDeptView,   (v) => setState(() => _regDeptView   = v)),
                      _checkRow('Add',    _regDeptAdd,    (v) => setState(() => _regDeptAdd    = v)),
                      _checkRow('Edit',   _regDeptEdit,   (v) => setState(() => _regDeptEdit   = v)),
                      _checkRow('Delete', _regDeptDelete, (v) => setState(() => _regDeptDelete = v)),
                    ]),

                    _buildSection('REGISTRATION — EMPLOYEE', [
                      _checkRow('View',              _regEmpView,       (v) => setState(() => _regEmpView       = v)),
                      _checkRow('Add',               _regEmpAdd,        (v) => setState(() => _regEmpAdd        = v)),
                      _checkRow('Edit',              _regEmpEdit,       (v) => setState(() => _regEmpEdit       = v)),
                      _checkRow('Status Update',     _regEmpStatus,     (v) => setState(() => _regEmpStatus     = v)),
                      _checkRow('Permission Manage', _regEmpPermission, (v) => setState(() => _regEmpPermission = v)),
                    ]),

                    _buildSection('REGISTRATION — TEAMS', [
                      _checkRow('View',          _regTeamsView,   (v) => setState(() => _regTeamsView   = v)),
                      _checkRow('Add',           _regTeamsAdd,    (v) => setState(() => _regTeamsAdd    = v)),
                      _checkRow('Edit',          _regTeamsEdit,   (v) => setState(() => _regTeamsEdit   = v)),
                      _checkRow('Status Update', _regTeamsStatus, (v) => setState(() => _regTeamsStatus = v)),
                    ]),

                    _buildSection('REGISTRATION — CUSTOMER', [
                      _checkRow('View',   _regCustView,   (v) => setState(() => _regCustView   = v)),
                      _checkRow('Add',    _regCustAdd,    (v) => setState(() => _regCustAdd    = v)),
                      _checkRow('Edit',   _regCustEdit,   (v) => setState(() => _regCustEdit   = v)),
                      _checkRow('Delete', _regCustDelete, (v) => setState(() => _regCustDelete = v)),
                    ]),

                    _buildSection('REGISTRATION — MACHINE', [
                      _checkRow('View',   _regMachView,   (v) => setState(() => _regMachView   = v)),
                      _checkRow('Add',    _regMachAdd,    (v) => setState(() => _regMachAdd    = v)),
                      _checkRow('Edit',   _regMachEdit,   (v) => setState(() => _regMachEdit   = v)),
                      _checkRow('Delete', _regMachDelete, (v) => setState(() => _regMachDelete = v)),
                    ]),

                    _buildSection('TICKETS', [
                      _checkRow('Add', _ticketAdd,
                          (v) => setState(() => _ticketAdd = v)),
                      _scopeRow('View',   _ticketViewScope,   (v) => setState(() => _ticketViewScope   = v)),
                      _scopeRow('Edit',   _ticketEditScope,   (v) => setState(() => _ticketEditScope   = v)),
                      _scopeRow('Assign', _ticketAssignScope, (v) => setState(() => _ticketAssignScope = v)),
                      _scopeRow('Delete', _ticketDeleteScope, (v) => setState(() => _ticketDeleteScope = v)),
                    ]),

                    _buildSection('JOBS', [
                      _checkRow('View',   _jobsView,   (v) => setState(() => _jobsView   = v)),
                      _checkRow('Add',    _jobsAdd,    (v) => setState(() => _jobsAdd    = v)),
                      _checkRow('Edit',   _jobsEdit,   (v) => setState(() => _jobsEdit   = v)),
                      _checkRow('Delete', _jobsDelete, (v) => setState(() => _jobsDelete = v)),
                    ]),

                    _buildSection('ATTENDANCE', [
                      _checkRow('Request',  _attendRequest,  (v) => setState(() => _attendRequest  = v)),
                      _checkRow('View',     _attendView,     (v) => setState(() => _attendView     = v)),
                      _checkRow('Register', _attendRegister, (v) => setState(() => _attendRegister = v)),
                    ]),

                    _buildSection('LEAVE', [
                      _checkRow('View',    _leaveView,    (v) => setState(() => _leaveView    = v)),
                      _checkRow('Add',     _leaveAdd,     (v) => setState(() => _leaveAdd     = v)),
                      _checkRow('Edit',    _leaveEdit,    (v) => setState(() => _leaveEdit    = v)),
                      _checkRow('Delete',  _leaveDelete,  (v) => setState(() => _leaveDelete  = v)),
                      _checkRow('Reject',  _leaveReject,  (v) => setState(() => _leaveReject  = v)),
                      _checkRow('Approve', _leaveApprove, (v) => setState(() => _leaveApprove = v)),
                    ]),

                    _buildSection('REPORTS', [
                      _checkRow('Leads',        _repEnquiry,    (v) => setState(() => _repEnquiry    = v)),
                      _checkRow('Deal',         _repDeal,       (v) => setState(() => _repDeal       = v)),
                      _checkRow('Employee',     _repEmployee,   (v) => setState(() => _repEmployee   = v)),
                      _checkRow('Pending Works',_repPending,    (v) => setState(() => _repPending    = v)),
                      _checkRow('Attendance',   _repAttendance, (v) => setState(() => _repAttendance = v)),
                      _checkRow('Leave',        _repLeave,      (v) => setState(() => _repLeave      = v)),
                    ]),

                    const SizedBox(height: 8),

                    // ── Action buttons ────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppColors.border, width: 1.3),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11)),
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 15),
                            ),
                            child: const Text('Cancel',
                                style: TextStyle(
                                    color:      AppColors.textLabel,
                                    fontWeight: FontWeight.w600,
                                    fontSize:   15)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _savePermissions,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              disabledBackgroundColor:
                                  AppColors.primary.withOpacity(0.5),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 15),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11)),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _isSaving
                                  ? const SizedBox(
                                      key:   ValueKey('save-loader'),
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(
                                          color:       Colors.white,
                                          strokeWidth: 2.4))
                                  : const Text('Update',
                                      key: ValueKey('save-label'),
                                      style: TextStyle(
                                          color:      Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize:   15)),
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
    );
  }

  // ── Section card ───────────────────────────────────────────────────────────
  Widget _buildSection(String title, List<Widget> rows) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Text(title,
                style: TextStyle(
                    color:         AppColors.primary.withOpacity(0.85),
                    fontSize:      12,
                    fontWeight:    FontWeight.w800,
                    letterSpacing: 0.5)),
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          // Rows
          ...rows.map((r) => Column(
                children: [
                  r,
                  if (r != rows.last)
                    const Divider(
                        height: 1,
                        color:  AppColors.borderLight,
                        indent: 14),
                ],
              )),
        ],
      ),
    );
  }

  // ── Checkbox row ───────────────────────────────────────────────────────────
  Widget _checkRow(
      String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(
                    color:    AppColors.textPrimary,
                    fontSize: 13.5)),
          ),
          SizedBox(
            width: 20, height: 20,
            child: Checkbox(
              value:       value,
              onChanged:   (v) => onChanged(v ?? false),
              activeColor: AppColors.primary,
              side: const BorderSide(color: AppColors.border, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 7),
          Text('Allow',
              style: const TextStyle(
                  color:    AppColors.textSecondary,
                  fontSize: 13.5)),
        ],
      ),
    );
  }

  // ── Scope radio row: All / Added Only / None ───────────────────────────────
  Widget _scopeRow(
      String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: const TextStyle(
                    color:    AppColors.textPrimary,
                    fontSize: 13.5)),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: List.generate(3, (i) {
                final scopeVal = _scopeValues[i];
                final selected = value == scopeVal;
                return GestureDetector(
                  onTap: () => onChanged(scopeVal),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20, height: 20,
                        child: Radio<int>(
                          value:           scopeVal,
                          groupValue:      value,
                          onChanged:       (v) => onChanged(v ?? 0),
                          activeColor:     AppColors.primary,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(_scopeLabels[i],
                          style: TextStyle(
                              color:    selected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontSize: 12.5,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400)),
                      const SizedBox(width: 10),
                    ],
                  ),
                );
              }),
            ),
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
            onPressed: _fetchPermissions,
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