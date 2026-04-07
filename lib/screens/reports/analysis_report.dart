import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:coremicron_crm_app/common/api_service.dart';
import 'package:coremicron_crm_app/screens/leads/lead_view.dart';
import 'package:coremicron_crm_app/screens/ticket/ticket_view.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ─── String Extension ─────────────────────────────────────────────────────────

extension StringCapitalization on String {
  String capitalize() {
    if (isEmpty) return this;
    final s = trim();
    if (s.isEmpty) return this;
    if (s.contains(',')) {
      return s.split(',').map((e) => e.trim().capitalize()).join(', ');
    }
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}

String _fmtDateStr(String? raw) {
  if (raw == null || raw.isEmpty || raw == '0000-00-00' || raw == 'null') return '—';
  try {
    // Try parsing YYYY-MM-DD
    if (raw.contains('-')) {
      final parts = raw.split(' ')[0].split('-');
      if (parts.length == 3) {
        if (parts[0].length == 4) return '${parts[2].padLeft(2,'0')}-${parts[1].padLeft(2,'0')}-${parts[0]}';
        return '${parts[0].padLeft(2,'0')}-${parts[1].padLeft(2,'0')}-${parts[2]}';
      }
    }
    return raw.replaceAll('/', '-');
  } catch (_) { return raw; }
}

// ─── App Colors (mirrors theme.dart AppColors) ────────────────────────────────

class _C {
  static const primary       = Color(0xFF1558E7);
  static const primaryDark   = Color(0xFF0636A8);
  static const primaryLight  = Color(0xFFEEF4FF);
  static const primaryAccent = Color(0xFFAAD4FF);
  static const background    = Color(0xFFF8FAFF);
  static const surface       = Colors.white;
  static const inputFill     = Color(0xFFF5F7FA);
  static const textPrimary   = Color(0xFF0A0F1E);
  static const textSecondary = Color(0xFF8A96AE);
  static const textHint      = Color(0xFFBBC4D6);
  static const textLabel     = Color(0xFF64718A);
  static const textMuted     = Color(0xFFB0BACC);
  static const border        = Color(0xFFDDE3EF);
  static const borderLight   = Color(0xFFEEF2FA);
  static const success       = Color(0xFF2F855A);
  static const successBg     = Color(0xFFEAFAF1);
  static const error         = Color(0xFFE53E3E);
  static const errorBg       = Color(0xFFFFF5F5);
  static const warning       = Color(0xFFD97706);
  static const warningBg     = Color(0xFFFFFBEB);
  static const iconDefault   = Color(0xFFA0ABBE);
}

// ─── Data Models ─────────────────────────────────────────────────────────────

class ReportSummary {
  final int leadsTotal, leadsActive, leadsRejected;
  final int ticketsTotal, ticketsOpen, ticketsClosed;
  final int jobsTotal, jobsPending, jobsCompleted;
  final int customersTotal, customersActive, customersInactive;
  final int employees;
  final int followupsTotal, followupsPending, followupsCompleted, followupsOverdue;

  ReportSummary.fromJson(Map<String, dynamic> j)
      : leadsTotal         = (j['leads']?['total'] as num?)?.toInt() ?? 0,
        leadsActive        = (j['leads']?['active'] as num?)?.toInt() ?? 0,
        leadsRejected      = (j['leads']?['rejected'] as num?)?.toInt() ?? 0,
        ticketsTotal       = (j['tickets']?['total'] as num?)?.toInt() ?? 0,
        ticketsOpen        = (j['tickets']?['open'] as num?)?.toInt() ?? 0,
        ticketsClosed      = (j['tickets']?['closed'] as num?)?.toInt() ?? 0,
        jobsTotal          = (j['jobs']?['total'] as num?)?.toInt() ?? 0,
        jobsPending        = (j['jobs']?['pending'] as num?)?.toInt() ?? 0,
        jobsCompleted      = (j['jobs']?['completed'] as num?)?.toInt() ?? 0,
        customersTotal     = (j['customers']?['total'] as num?)?.toInt() ?? 0,
        customersActive    = (j['customers']?['active'] as num?)?.toInt() ?? 0,
        customersInactive  = (j['customers']?['inactive'] as num?)?.toInt() ?? 0,
        employees          = (j['employees'] as num?)?.toInt() ?? 0,
        followupsTotal     = (j['followups']?['total'] as num?)?.toInt() ?? 0,
        followupsPending   = (j['followups']?['pending'] as num?)?.toInt() ?? 0,
        followupsCompleted = (j['followups']?['completed'] as num?)?.toInt() ?? 0,
        followupsOverdue   = (j['followups']?['overdue'] as num?)?.toInt() ?? 0;
}

class EmployeePerformance {
  final String id, name;
  final int jobsAssigned, jobsCompleted, jobsVerified, jobsPending;
  final int followupsCompleted, followupsPending;
  final double completionScore;

  EmployeePerformance.fromJson(Map<String, dynamic> j)
      : id                 = j['employee_id']?.toString() ?? '',
        name               = j['employee_name']?.toString() ?? '',
        jobsAssigned       = (j['jobs_assigned'] as num?)?.toInt() ?? 0,
        jobsCompleted      = (j['jobs_completed'] as num?)?.toInt() ?? 0,
        jobsVerified       = (j['jobs_verified'] as num?)?.toInt() ?? 0,
        jobsPending        = (j['jobs_pending'] as num?)?.toInt() ?? 0,
        followupsCompleted = (j['followups_completed'] as num?)?.toInt() ?? 0,
        followupsPending   = (j['followups_pending'] as num?)?.toInt() ?? 0,
        completionScore    = (j['completion_score'] as num?)?.toDouble() ?? 0.0;
}

class Lead {
  final String id, number, title, customerName, phone, addedDate, status, assignedTo;
  final String? lastFollowupDate, lastFollowupStatus, currentDeal;

  Lead.fromJson(Map<String, dynamic> j)
      : id                 = j['enquiry_id']?.toString() ?? '',
        number             = j['enquiry_number']?.toString() ?? '',
        title              = j['title']?.toString() ?? '',
        customerName       = j['customer_name']?.toString() ?? '',
        phone              = j['phone_number']?.toString() ?? '',
        addedDate          = j['added_date']?.toString() ?? '',
        status             = j['status']?.toString() ?? '',
        assignedTo         = j['assigned_to']?.toString() ?? '',
        lastFollowupDate   = j['last_followup_date']?.toString(),
        lastFollowupStatus = j['last_followup_status']?.toString(),
        currentDeal        = j['current_deal']?.toString();
}

class Ticket {
  final String id, number, type, title, priority, status, customerName, addedDate, raisedBy, taskHandler;
  final int totalJobs, completedJobs, pendingJobs, verifiedJobs;

  Ticket.fromJson(Map<String, dynamic> j)
      : id           = j['ticket_id']?.toString() ?? '',
        number       = j['ticket_number']?.toString() ?? '',
        type         = j['type_of_tickets']?.toString() ?? '',
        title        = j['title']?.toString() ?? '',
        priority     = j['priority']?.toString() ?? '',
        status       = j['status']?.toString() ?? '',
        customerName = j['customer_name']?.toString() ?? '',
        addedDate    = j['added_date']?.toString() ?? '',
        raisedBy     = j['raised_by']?.toString() ?? '',
        taskHandler  = j['task_handler']?.toString() ?? '',
        totalJobs    = int.tryParse(j['total_jobs']?.toString() ?? '0') ?? 0,
        completedJobs= int.tryParse(j['completed_jobs']?.toString() ?? '0') ?? 0,
        pendingJobs  = int.tryParse(j['pending_jobs']?.toString() ?? '0') ?? 0,
        verifiedJobs = int.tryParse(j['verified_jobs']?.toString() ?? '0') ?? 0;
}

class Customer {
  final String id, name, phone;
  final String? email, lastActivityDate;
  final int totalEnquiries, totalFollowups;
  final int? daysSinceActivity;

  Customer.fromJson(Map<String, dynamic> j)
      : id               = j['customer_id']?.toString() ?? '',
        name             = j['customer_name']?.toString() ?? '',
        phone            = j['phone_number']?.toString() ?? '',
        email            = j['email']?.toString(),
        lastActivityDate = j['last_activity_date']?.toString(),
        totalEnquiries   = int.tryParse(j['total_enquiries']?.toString() ?? '0') ?? 0,
        totalFollowups   = int.tryParse(j['total_followups']?.toString() ?? '0') ?? 0,
        daysSinceActivity= (j['days_since_activity'] as num?)?.toInt();
}

class OverdueFollowup {
  final String comid, followUp, notes, enquiryNumber, enquiryTitle, customerName, phone, assignedTo;
  final int daysOverdue;

  OverdueFollowup.fromJson(Map<String, dynamic> j)
      : comid         = j['comid']?.toString() ?? '',
        followUp      = j['follow_up']?.toString() ?? '',
        notes         = j['notes']?.toString() ?? '',
        enquiryNumber = j['enquiry_number']?.toString() ?? '',
        enquiryTitle  = j['enquiry_title']?.toString() ?? '',
        customerName  = j['customer_name']?.toString() ?? '',
        phone         = j['phone_number']?.toString() ?? '',
        assignedTo    = j['assigned_to']?.toString() ?? '',
        daysOverdue   = int.tryParse(j['days_overdue']?.toString() ?? '0') ?? 0;
}

class LeaveSummary {
  final String employeeId, employeeName;
  final int totalApplications, approved, rejected, pending;

  LeaveSummary.fromJson(Map<String, dynamic> j)
      : employeeId        = j['employee_id']?.toString() ?? '',
        employeeName      = j['employee_name']?.toString() ?? '',
        totalApplications = int.tryParse(j['total_applications']?.toString() ?? '0') ?? 0,
        approved          = int.tryParse(j['approved']?.toString() ?? '0') ?? 0,
        rejected          = int.tryParse(j['rejected']?.toString() ?? '0') ?? 0,
        pending           = int.tryParse(j['pending']?.toString() ?? '0') ?? 0;
}

class ReportData {
  final String generatedAt;
  final ReportSummary summary;
  final List<EmployeePerformance> employeePerformance;
  final List<Lead> leads;
  final List<Ticket> tickets;
  final List<Customer> activeCustomers;
  final List<Customer> inactiveCustomers;
  final List<OverdueFollowup> overdueFollowups;
  final List<LeaveSummary> leaveSummary;

  ReportData.fromJson(Map<String, dynamic> j)
      : generatedAt         = j['generated_at']?.toString() ?? '',
        summary             = ReportSummary.fromJson(j['summary'] ?? {}),
        employeePerformance = (j['employee_performance'] as List? ?? []).map((e) => EmployeePerformance.fromJson(e)).toList(),
        leads               = (j['leads'] as List? ?? []).map((e) => Lead.fromJson(e)).toList(),
        tickets             = (j['tickets'] as List? ?? []).map((e) => Ticket.fromJson(e)).toList(),
        activeCustomers     = (j['active_customers'] as List? ?? []).map((e) => Customer.fromJson(e)).toList(),
        inactiveCustomers   = (j['inactive_customers'] as List? ?? []).map((e) => Customer.fromJson(e)).toList(),
        overdueFollowups    = (j['overdue_followups'] as List? ?? []).map((e) => OverdueFollowup.fromJson(e)).toList(),
        leaveSummary        = (j['leave_summary'] as List? ?? []).map((e) => LeaveSummary.fromJson(e)).toList();
}

// ─── Main Page ───────────────────────────────────────────────────────────────

class AnalysisReportPage extends StatefulWidget {
  final String? username;
  const AnalysisReportPage({super.key, this.username});

  @override
  State<AnalysisReportPage> createState() => _AnalysisReportPageState();
}

class _AnalysisReportPageState extends State<AnalysisReportPage> {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 90));
  DateTime _toDate   = DateTime.now();
  bool _loading      = false;
  String? _error;
  ReportData? _data;

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: _C.primary,
            onPrimary: Colors.white,
            surface: _C.surface,
            onSurface: _C.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) _fromDate = picked;
        else _toDate = picked;
      });
    }
  }

  Future<void> _generateReport() async {
    setState(() { _loading = true; _error = null; _data = null; });
    final from = '${_fromDate.year}-${_fromDate.month.toString().padLeft(2,'0')}-${_fromDate.day.toString().padLeft(2,'0')}';
    final to   = '${_toDate.year}-${_toDate.month.toString().padLeft(2,'0')}-${_toDate.day.toString().padLeft(2,'0')}';
    try {
      final url = Uri.parse('${ApiService.baseUrl}/api/user/report.php?from_date=$from&to_date=$to');
      
      debugPrint('─────────────────────────────────────────');
      debugPrint('📤  [ANALYSIS REPORT] Request');
      debugPrint('   🌐  URL : $url');
      debugPrint('─────────────────────────────────────────');

      final res = await ApiService.get(url).timeout(const Duration(seconds: 15));

      debugPrint('─────────────────────────────────────────');
      debugPrint('📥  [ANALYSIS REPORT] Response');
      debugPrint('   🔢  Status : ${res.statusCode}');
      debugPrint('   📄  Body   : ${res.body}');
      debugPrint('─────────────────────────────────────────');

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        setState(() { _data = ReportData.fromJson(json); _loading = false; });
      } else {
        setState(() { _error = 'Server error: ${res.statusCode}'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _data != null ? _ReportTabs(data: _data!) : _buildEmptyState(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: _C.surface,
        border: Border(bottom: BorderSide(color: _C.border)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: _C.background,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: _C.border, width: 1.2),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: _C.textPrimary, size: 15),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_C.primary, _C.primaryDark]),
                borderRadius: BorderRadius.circular(9),
                boxShadow: [BoxShadow(color: _C.primary.withOpacity(0.30), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Analysis Report',
              style: TextStyle(color: _C.textPrimary, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _DateField(label: 'From', date: _fromDate, onTap: () => _pickDate(true))),
            const SizedBox(width: 8),
            Expanded(child: _DateField(label: 'To',   date: _toDate,   onTap: () => _pickDate(false))),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_data != null) ...[
                  GestureDetector(
                    onTap: _printReport,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _C.successBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _C.success.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.print_rounded, color: _C.success, size: 14),
                          SizedBox(width: 4),
                          Text('Print', style: TextStyle(color: _C.success, fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
                _loading
                    ? Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: _C.primary, borderRadius: BorderRadius.circular(12)),
                        child: const Center(child: SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
                      )
                    : GestureDetector(
                        onTap: _generateReport,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [_C.primary, _C.primaryDark]),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: _C.primary.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text('Generate',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
              ],
            ),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _C.errorBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _C.error.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: _C.error, size: 14),
                const SizedBox(width: 6),
                Expanded(child: Text(_error!, style: const TextStyle(color: _C.error, fontSize: 11))),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: _C.primaryLight,
              shape: BoxShape.circle,
              border: Border.all(color: _C.primary.withOpacity(0.25)),
            ),
            child: const Icon(Icons.bar_chart_rounded, color: _C.primary, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('Select a date range and generate a report',
            style: TextStyle(color: _C.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _printReport() async {
    if (_data == null) return;
    try {
      final pdf = pw.Document();
      final fromStr = _fmtDateStr(_fromDate.toString());
      final toStr = _fmtDateStr(_toDate.toString());

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ANALYSIS REPORT', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Text('$fromStr to $toStr', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 10),
            ],
          ),
          footer: (context) => pw.Column(
            children: [
              pw.Divider(thickness: 0.5, color: PdfColors.grey300),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Generated by Coremicron CRM', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                  pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                ],
              ),
            ],
          ),
          build: (context) => [
            ..._pwSection('Leads Summary', 
              ['No.', 'Title', 'Customer', 'Phone', 'Date', 'Assignee', 'Status', 'Deal', 'FU Date', 'FU Status'],
              _data!.leads.map((l) => [l.number, l.title, l.customerName, l.phone, l.addedDate, l.assignedTo, l.status, l.currentDeal ?? '—', l.lastFollowupDate ?? '—', l.lastFollowupStatus ?? '—']).toList()
            ),
            ..._pwSection('Tickets Summary', 
              ['No.', 'Type', 'Pri', 'Title', 'Customer', 'Handler', 'Date', 'Jobs (T/D/P/V)'],
              _data!.tickets.map((t) => [t.number, t.type, t.priority, t.title, t.customerName, t.taskHandler, t.addedDate, '${t.totalJobs}/${t.completedJobs}/${t.pendingJobs}/${t.verifiedJobs}']).toList()
            ),
            ..._pwSection('Active Customers', 
              ['Name', 'Phone', 'Email', 'Enq', 'FU', 'Last Activity', 'Days'],
              _data!.activeCustomers.map((c) => [c.name, c.phone, c.email ?? '—', '${c.totalEnquiries}', '${c.totalFollowups}', c.lastActivityDate ?? '—', '${c.daysSinceActivity ?? '—'}']).toList()
            ),
            ..._pwSection('Inactive Customers', 
              ['Name', 'Phone', 'Email', 'Enq', 'FU', 'Last Activity', 'Days'],
              _data!.inactiveCustomers.map((c) => [c.name, c.phone, c.email ?? '—', '${c.totalEnquiries}', '${c.totalFollowups}', c.lastActivityDate ?? '—', '${c.daysSinceActivity ?? '—'}']).toList()
            ),
            ..._pwSection('Overdue Follow-ups', 
              ['Enq No.', 'Title', 'Customer', 'Phone', 'Assigned To', 'Notes', 'Overdue'],
              _data!.overdueFollowups.map((f) => [f.enquiryNumber, f.enquiryTitle, f.customerName, f.phone, f.assignedTo, f.notes, '${f.daysOverdue} days']).toList()
            ),
            ..._pwSection('Leave Summary', 
              ['Employee', 'Total', 'Appr', 'Rej', 'Pend'],
              _data!.leaveSummary.map((l) => [l.employeeName, '${l.totalApplications}', '${l.approved}', '${l.rejected}', '${l.pending}']).toList()
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Print failed: $e'), backgroundColor: _C.error));
      }
    }
  }

  List<pw.Widget> _pwSection(String title, List<String> headers, List<List<String>> data) {
    if (data.isEmpty) return [];
    return [
      pw.SizedBox(height: 15),
      pw.Text(title.toUpperCase(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
      pw.SizedBox(height: 6),
      pw.Table.fromTextArray(
        headers: headers,
        data: data.map((row) => row.map((cell) => cell.capitalize()).toList()).toList(),
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
        cellStyle: const pw.TextStyle(fontSize: 6.5),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        columnWidths: {
          0: const pw.IntrinsicColumnWidth(),
        },
      ),
    ];
  }
}

// ─── Date Field ───────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  const _DateField({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt =
        '${date.day.toString().padLeft(2,'0')}-${date.month.toString().padLeft(2,'0')}-${date.year}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.border, width: 1.2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                color: _C.primary, size: 14),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: _C.textLabel,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(fmt,
                        style: const TextStyle(
                            color: _C.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Report Tabs ─────────────────────────────────────────────────────────────

class _ReportTabs extends StatefulWidget {
  final ReportData data;
  const _ReportTabs({required this.data});

  @override
  State<_ReportTabs> createState() => _ReportTabsState();
}

class _ReportTabsState extends State<_ReportTabs> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _tabs = ['Overall', 'Leads', 'Tickets', 'Customers', 'Overdue', 'Leaves'];

  @override
  void initState() { super.initState(); _tab = TabController(length: _tabs.length, vsync: this); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: _C.surface,
          child: TabBar(
            controller: _tab,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: _C.primary,
            unselectedLabelColor: _C.textSecondary,
            indicatorColor: _C.primary,
            indicatorWeight: 2,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _OverallTab(data: widget.data),
              _LeadsTab(leads: widget.data.leads),
              _TicketsTab(tickets: widget.data.tickets),
              _CustomersTab(active: widget.data.activeCustomers, inactive: widget.data.inactiveCustomers),
              _OverdueTab(followups: widget.data.overdueFollowups),
              _LeavesTab(leaves: widget.data.leaveSummary),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Overall Tab ─────────────────────────────────────────────────────────────

class _OverallTab extends StatelessWidget {
  final ReportData data;
  const _OverallTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final s = data.summary;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _sectionTitle('Summary Overview'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: [
            _SummaryCard(
              icon: Icons.people_alt_rounded, color: _C.primary, title: 'Leads',
              mainValue: '${s.leadsTotal}',
              chips: [_Chip('Active', s.leadsActive, _C.success), _Chip('Rejected', s.leadsRejected, _C.error)],
            ),
            _SummaryCard(
              icon: Icons.confirmation_number_rounded, color: _C.warning, title: 'Tickets',
              mainValue: '${s.ticketsTotal}',
              chips: [_Chip('Open', s.ticketsOpen, _C.warning), _Chip('Closed', s.ticketsClosed, _C.success)],
            ),
            _SummaryCard(
              icon: Icons.work_rounded, color: _C.success, title: 'Jobs',
              mainValue: '${s.jobsTotal}',
              chips: [_Chip('Pending', s.jobsPending, _C.warning), _Chip('Done', s.jobsCompleted, _C.success)],
            ),
            _SummaryCard(
              icon: Icons.group_rounded, color: _C.primaryDark, title: 'Customers',
              mainValue: '${s.customersTotal}',
              chips: [_Chip('Active', s.customersActive, _C.success), _Chip('Inactive', s.customersInactive, _C.textMuted)],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _StatTile(icon: Icons.badge_rounded, color: _C.primary, label: 'Employees', value: '${s.employees}')),
          const SizedBox(width: 10),
          Expanded(child: _FollowupTile(s: s)),
        ]),
        const SizedBox(height: 18),
        _sectionTitle('Employee Performance'),
        const SizedBox(height: 10),
        ..._buildRanked(data.employeePerformance),
      ],
    );
  }

  List<Widget> _buildRanked(List<EmployeePerformance> list) {
    final sorted = [...list]..sort((a, b) => b.completionScore.compareTo(a.completionScore));
    return sorted.asMap().entries.map((e) => _EmployeeCard(rank: e.key + 1, emp: e.value)).toList();
  }
}

class _Chip {
  final String label; final int value; final Color color;
  _Chip(this.label, this.value, this.color);
}

class _SummaryCard extends StatelessWidget {
  final IconData icon; final Color color; final String title, mainValue; final List<_Chip> chips;
  const _SummaryCard({required this.icon, required this.color, required this.title,
    required this.mainValue, required this.chips});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.borderLight, width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(color: _C.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(mainValue, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
        ]),
        const Spacer(),
        Row(children: chips.map((c) => Expanded(child: _MiniChip(c))).toList()),
      ]),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final _Chip chip;
  const _MiniChip(this.chip);
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: chip.color.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('${chip.value}', style: TextStyle(color: chip.color, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(width: 3),
        Text(chip.label, style: TextStyle(color: chip.color.withOpacity(0.7), fontSize: 9)),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon; final Color color; final String label, value;
  const _StatTile({required this.icon, required this.color, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.borderLight, width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: _C.textSecondary, fontSize: 10)),
          Text(value,  style: const TextStyle(color: _C.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
        ]),
      ]),
    );
  }
}

class _FollowupTile extends StatelessWidget {
  final ReportSummary s;
  const _FollowupTile({required this.s});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.borderLight, width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.schedule_rounded, color: _C.warning, size: 14),
          const SizedBox(width: 5),
          const Text('Follow-ups', style: TextStyle(color: _C.textSecondary, fontSize: 10)),
          const Spacer(),
          Text('${s.followupsTotal}',
            style: const TextStyle(color: _C.warning, fontSize: 18, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            _tiny('Pending', s.followupsPending, _C.warning),
            _tiny('Done', s.followupsCompleted, _C.success),
            _tiny('Overdue', s.followupsOverdue, _C.error),
          ],
        ),
      ]),
    );
  }

  Widget _tiny(String l, int v, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(5)),
    child: Text('$v $l', style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w600)),
  );
}

class _EmployeeCard extends StatelessWidget {
  final int rank;
  final EmployeePerformance emp;
  const _EmployeeCard({required this.rank, required this.emp});

  @override
  Widget build(BuildContext context) {
    final rankColors = [
      const Color(0xFFD97706), // gold
      const Color(0xFF6B7280), // silver
      const Color(0xFF92400E), // bronze
    ];
    final rankColor = rank <= 3 ? rankColors[rank - 1] : _C.textMuted;
    final progress  = emp.jobsAssigned > 0 ? emp.jobsCompleted / emp.jobsAssigned : 0.0;
    final hasScore  = emp.completionScore > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: rank == 1 ? const Color(0xFFD97706).withOpacity(0.35) : _C.borderLight,
          width: 1.2,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: rankColor.withOpacity(0.4)),
            ),
            child: Center(
              child: rank <= 3
                  ? Text(['🥇','🥈','🥉'][rank-1], style: const TextStyle(fontSize: 14))
                  : Text('#$rank', style: TextStyle(color: rankColor, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(emp.name.capitalize(),
              style: const TextStyle(color: _C.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: hasScore ? _C.successBg : _C.inputFill,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${emp.completionScore.toStringAsFixed(1)}%',
              style: TextStyle(
                color: hasScore ? _C.success : _C.textMuted,
                fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: _C.borderLight,
            valueColor: AlwaysStoppedAnimation(hasScore ? _C.success : _C.textHint),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _empStat('Assigned', emp.jobsAssigned,       _C.primary),
          _empStat('Done',     emp.jobsCompleted,      _C.success),
          _empStat('Verified', emp.jobsVerified,       _C.primaryDark),
          _empStat('Pending',  emp.jobsPending,        _C.warning),
          const Spacer(),
          _empStat('FU Done',  emp.followupsCompleted, _C.success),
          _empStat('FU Pend',  emp.followupsPending,   _C.error),
        ]),
      ]),
    );
  }

  Widget _empStat(String l, int v, Color c) => Padding(
    padding: const EdgeInsets.only(right: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$v', style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w700)),
      Text(l,   style: const TextStyle(color: _C.textSecondary, fontSize: 9)),
    ]),
  );
}

// ─── Leads Tab ───────────────────────────────────────────────────────────────

class _LeadsTab extends StatelessWidget {
  final List<Lead> leads;
  const _LeadsTab({required this.leads});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _sectionTitle('Leads (${leads.length})'),
        const SizedBox(height: 10),
        ...leads.map((l) => _LeadCard(lead: l)),
      ],
    );
  }
}

class _LeadCard extends StatelessWidget {
  final Lead lead;
  const _LeadCard({required this.lead});

  @override
  Widget build(BuildContext context) {
    final isActive = lead.status == 'active';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? _C.success.withOpacity(0.25) : _C.error.withOpacity(0.25),
          width: 1.2,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeadViewPage(enquiryId: lead.id, enquiryNumber: lead.number))),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: _C.primaryLight, borderRadius: BorderRadius.circular(5)),
              child: Text('#${lead.number}',
                style: const TextStyle(color: _C.primary, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(lead.title.capitalize(),
            style: const TextStyle(color: _C.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isActive ? _C.successBg : _C.errorBg,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(lead.status.capitalize(),
              style: TextStyle(color: isActive ? _C.success : _C.error, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 5),
        Row(children: [
          const Icon(Icons.business_rounded, color: _C.iconDefault, size: 11),
          const SizedBox(width: 3),
          Expanded(child: Text(lead.customerName.capitalize(),
            style: const TextStyle(color: _C.textSecondary, fontSize: 11),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
          const Icon(Icons.phone_rounded, color: _C.iconDefault, size: 11),
          const SizedBox(width: 3),
          Text(lead.phone, style: const TextStyle(color: _C.textSecondary, fontSize: 11)),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.calendar_today_rounded, color: _C.iconDefault, size: 10),
          const SizedBox(width: 3),
          Text(_fmtDateStr(lead.addedDate), style: const TextStyle(color: _C.textMuted, fontSize: 10)),
          const Spacer(),
          if (lead.lastFollowupDate != null) ...[
            const Icon(Icons.history_rounded, color: _C.iconDefault, size: 10),
            const SizedBox(width: 2),
            Text(_fmtDateStr(lead.lastFollowupDate!), style: const TextStyle(color: _C.textMuted, fontSize: 10)),
          ],
        ]),
        if (lead.assignedTo.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.group_rounded, color: _C.primary, size: 11),
            const SizedBox(width: 3),
            Expanded(child: Text(lead.assignedTo.capitalize(),
              style: const TextStyle(color: _C.primary, fontSize: 10),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ],
        if (lead.currentDeal != null) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.handshake_rounded, color: _C.warning, size: 11),
            const SizedBox(width: 3),
            Text(lead.currentDeal!.capitalize(), style: const TextStyle(color: _C.warning, fontSize: 10)),
          ]),
        ],
        if (lead.lastFollowupStatus != null) ...[
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: _C.warningBg, borderRadius: BorderRadius.circular(4)),
            child: Text('Follow-up: ${lead.lastFollowupStatus!.capitalize()}',
              style: const TextStyle(color: _C.warning, fontSize: 9, fontWeight: FontWeight.w600)),
          ),
        ],
      ]
    ),);
  }
}

// ─── Tickets Tab ─────────────────────────────────────────────────────────────

class _TicketsTab extends StatelessWidget {
  final List<Ticket> tickets;
  const _TicketsTab({required this.tickets});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _sectionTitle('Tickets (${tickets.length})'),
        const SizedBox(height: 10),
        ...tickets.map((t) => _TicketCard(ticket: t)),
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Ticket ticket;
  const _TicketCard({required this.ticket});

  Color get _priorityColor {
    switch (ticket.priority.toLowerCase()) {
      case 'high':   return _C.error;
      case 'medium': return _C.warning;
      case 'low':    return _C.success;
      default:       return _C.textMuted;
    }
  }

  Color get _typeColor {
    switch (ticket.type) {
      case 'AMC':        return _C.primary;
      case 'Complaints': return _C.error;
      case 'New Works':  return _C.success;
      default:           return _C.primaryDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobProgress = ticket.totalJobs > 0 ? ticket.completedJobs / ticket.totalJobs : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.borderLight, width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TicketViewPage(
              ticketId: ticket.id,
              ticketNumber: ticket.number,
              typeOfTickets: ticket.type,
              title: ticket.title,
              status: ticket.status,
              taskHandlerId: '', // Ideally we'd have this, but for now empty is better than build error
              addedTime: '',
            ))),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(color: _C.primaryLight, borderRadius: BorderRadius.circular(5)),
              child: Text('#${ticket.number}',
                style: const TextStyle(color: _C.primary, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: _typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
            child: Text(ticket.type.capitalize(), style: TextStyle(color: _typeColor, fontSize: 9, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 4),
          if (ticket.priority.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(color: _priorityColor.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
              child: Text(ticket.priority.capitalize(),
                style: TextStyle(color: _priorityColor, fontSize: 9, fontWeight: FontWeight.w600)),
            ),
          const Spacer(),
          Text(_fmtDateStr(ticket.addedDate), style: const TextStyle(color: _C.textMuted, fontSize: 10)),
        ]),
        const SizedBox(height: 5),
        Text(ticket.title.capitalize(),
          style: const TextStyle(color: _C.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.business_rounded, color: _C.iconDefault, size: 11),
          const SizedBox(width: 3),
          Expanded(child: Text(ticket.customerName.capitalize(),
            style: const TextStyle(color: _C.textSecondary, fontSize: 11))),
          const Icon(Icons.manage_accounts_rounded, color: _C.iconDefault, size: 11),
          const SizedBox(width: 3),
          Text(ticket.taskHandler.capitalize(),
            style: const TextStyle(color: _C.textSecondary, fontSize: 11)),
        ]),
        if (ticket.totalJobs > 0) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Text('Jobs', style: TextStyle(color: _C.textSecondary, fontSize: 10)),
            const SizedBox(width: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: jobProgress,
                  backgroundColor: _C.borderLight,
                  valueColor: AlwaysStoppedAnimation(jobProgress >= 1.0 ? _C.success : _C.primary),
                  minHeight: 5,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text('${ticket.completedJobs}/${ticket.totalJobs}',
              style: const TextStyle(color: _C.textSecondary, fontSize: 10)),
          ]),
          const SizedBox(height: 5),
          Row(children: [
            _jobStat('Total',    ticket.totalJobs,    _C.primary),
            _jobStat('Done',     ticket.completedJobs, _C.success),
            _jobStat('Pending',  ticket.pendingJobs,   _C.warning),
            _jobStat('Verified', ticket.verifiedJobs,  _C.primaryDark),
          ]),
        ],
      ]),
    );
  }

  Widget _jobStat(String l, int v, Color c) => Container(
    margin: const EdgeInsets.only(right: 6),
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(5)),
    child: Text('$l: $v', style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w600)),
  );
}

// ─── Customers Tab ───────────────────────────────────────────────────────────

class _CustomersTab extends StatefulWidget {
  final List<Customer> active, inactive;
  const _CustomersTab({required this.active, required this.inactive});
  @override
  State<_CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<_CustomersTab> with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: _C.surface,
          child: TabBar(
            controller: _tab,
            labelColor: _C.success,
            unselectedLabelColor: _C.textSecondary,
            indicatorColor: _C.success,
            indicatorWeight: 2,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Active (${widget.active.length})'),
              Tab(text: 'Inactive (${widget.inactive.length})'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _CustomerList(customers: widget.active,   isActive: true),
              _CustomerList(customers: widget.inactive, isActive: false),
            ],
          ),
        ),
      ],
    );
  }
}

class _CustomerList extends StatelessWidget {
  final List<Customer> customers; final bool isActive;
  const _CustomerList({required this.customers, required this.isActive});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: customers.map((c) => _CustomerCard(customer: c, isActive: isActive)).toList(),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Customer customer; final bool isActive;
  const _CustomerCard({required this.customer, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? _C.success.withOpacity(0.25) : _C.borderLight,
          width: 1.2,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: isActive ? _C.successBg : _C.inputFill,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: isActive ? _C.success : _C.textLabel,
                fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(customer.name.capitalize(),
              style: const TextStyle(color: _C.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(customer.phone, style: const TextStyle(color: _C.textSecondary, fontSize: 11)),
            if (customer.lastActivityDate != null)
              Text('Last: ${_fmtDateStr(customer.lastActivityDate)}',
                style: const TextStyle(color: _C.textMuted, fontSize: 10)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _custStat('Enquiries: ${customer.totalEnquiries}', _C.primary),
          const SizedBox(height: 4),
          _custStat('Followups: ${customer.totalFollowups}', _C.warning),
          if (customer.daysSinceActivity != null)
            Text('${customer.daysSinceActivity}d ago',
              style: const TextStyle(color: _C.error, fontSize: 9)),
        ]),
      ]),
    );
  }

  Widget _custStat(String v, Color c) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(v, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
    ],
  );
}

// ─── Overdue Followups Tab ───────────────────────────────────────────────────

class _OverdueTab extends StatelessWidget {
  final List<OverdueFollowup> followups;
  const _OverdueTab({required this.followups});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _sectionTitle('Overdue Follow-ups (${followups.length})'),
        const SizedBox(height: 10),
        ...followups.map((f) => _OverdueCard(followup: f)),
      ],
    );
  }
}

class _OverdueCard extends StatelessWidget {
  final OverdueFollowup followup;
  const _OverdueCard({required this.followup});

  @override
  Widget build(BuildContext context) {
    final urgency   = followup.daysOverdue > 20 ? _C.error
        : followup.daysOverdue > 7               ? _C.warning
        : const Color(0xFFD97706);
    final urgencyBg = followup.daysOverdue > 20 ? _C.errorBg
        : followup.daysOverdue > 7               ? _C.warningBg
        : const Color(0xFFFFFBEB);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: urgency.withOpacity(0.3), width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 46,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(color: urgencyBg, borderRadius: BorderRadius.circular(8)),
          child: Column(children: [
            Text('${followup.daysOverdue}',
              style: TextStyle(color: urgency, fontSize: 16, fontWeight: FontWeight.w800)),
            Text('days', style: TextStyle(color: urgency.withOpacity(0.7), fontSize: 9)),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(followup.enquiryTitle.capitalize(),
              style: const TextStyle(color: _C.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              const Icon(Icons.person_rounded, color: _C.iconDefault, size: 11),
              const SizedBox(width: 3),
              Expanded(child: Text(followup.customerName.capitalize(),
                style: const TextStyle(color: _C.textSecondary, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
              const Icon(Icons.phone_rounded, color: _C.iconDefault, size: 10),
              const SizedBox(width: 2),
              Text(followup.phone, style: const TextStyle(color: _C.textSecondary, fontSize: 10)),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.manage_accounts_rounded, color: _C.primary, size: 11),
              const SizedBox(width: 3),
              Text(followup.assignedTo.capitalize(),
                style: const TextStyle(color: _C.primary, fontSize: 11)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: _C.primaryLight, borderRadius: BorderRadius.circular(4)),
                child: Text('#${followup.enquiryNumber}',
                  style: const TextStyle(color: _C.primary, fontSize: 9, fontWeight: FontWeight.w600)),
              ),
            ]),
            if (followup.notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(followup.notes.capitalize(),
                style: const TextStyle(color: _C.textSecondary, fontSize: 10, fontStyle: FontStyle.italic),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ─── Leaves Tab ──────────────────────────────────────────────────────────────

class _LeavesTab extends StatelessWidget {
  final List<LeaveSummary> leaves;
  const _LeavesTab({required this.leaves});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _sectionTitle('Leave Summary'),
        const SizedBox(height: 10),
        if (leaves.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('No leave records', style: TextStyle(color: _C.textSecondary)),
          ))
        else
          ...leaves.map((l) => _LeaveCard(leave: l)),
      ],
    );
  }
}

class _LeaveCard extends StatelessWidget {
  final LeaveSummary leave;
  const _LeaveCard({required this.leave});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.borderLight, width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        const CircleAvatar(
          radius: 18, backgroundColor: _C.primaryLight,
          child: Icon(Icons.badge_rounded, color: _C.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(leave.employeeName.capitalize(),
              style: const TextStyle(color: _C.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('${leave.totalApplications} Application${leave.totalApplications != 1 ? 's' : ''}',
              style: const TextStyle(color: _C.textSecondary, fontSize: 11)),
          ]),
        ),
        Row(children: [
          _leaveStat('Approved', leave.approved, _C.success, _C.successBg),
          const SizedBox(width: 5),
          _leaveStat('Rejected', leave.rejected, _C.error,   _C.errorBg),
          const SizedBox(width: 5),
          _leaveStat('Pending',  leave.pending,  _C.warning, _C.warningBg),
        ]),
      ]),
    );
  }

  Widget _leaveStat(String l, int v, Color c, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Column(children: [
      Text('$v', style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w800)),
      Text(l,   style: TextStyle(color: c.withOpacity(0.75), fontSize: 8)),
    ]),
  );
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

Widget _sectionTitle(String title) => Text(
  title,
  style: const TextStyle(
    color: _C.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
  ),
);