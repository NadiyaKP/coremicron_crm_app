import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/screens/home.dart';
import 'package:coremicron_crm_app/common/pagination.dart';
import 'package:coremicron_crm_app/common/string_extensions.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ── Employee Model for dropdown/search ──────────────────────────────────────
class _Employee {
  final String id;
  final String employeeName;
  final String phoneNumber;
  final String employeeCode;

  const _Employee({
    required this.id,
    required this.employeeName,
    required this.phoneNumber,
    required this.employeeCode,
  });

  factory _Employee.fromJson(Map<String, dynamic> j) => _Employee(
        id: j['id'] ?? '',
        employeeName: j['employee_name'] ?? '',
        phoneNumber: j['phone_number'] ?? '',
        employeeCode: j['employee_code'] ?? '',
      );

  String get displayText => '$employeeName (${employeeCode.isEmpty ? phoneNumber : employeeCode})';
}

// ── Style Options ───────────────────────────────────────────────────────────
enum StyleOption {
  attendance('attendance', 'Attendance'),
  leaveApplication('leaveapplication', 'Leave Application'),
  pendingWorks('pendingworks', 'Pending Works'),
  completedTasks('completedtasks', 'Completed Tasks');

  final String apiValue;
  final String displayName;

  const StyleOption(this.apiValue, this.displayName);
}

// ── Models for different report types ──────────────────────────────────────
class _CompletedTask {
  final String jobId;
  final String ticketId;
  final String ticketNumber;
  final String toDo;
  final String fixbyDate;
  final String completedDate;
  final String verifiedBy;
  final String verifiedDate;
  final String status;

  const _CompletedTask({
    required this.jobId,
    required this.ticketId,
    required this.ticketNumber,
    required this.toDo,
    required this.fixbyDate,
    required this.completedDate,
    required this.verifiedBy,
    required this.verifiedDate,
    required this.status,
  });

  factory _CompletedTask.fromJson(Map<String, dynamic> j) => _CompletedTask(
        jobId: j['job_id'] ?? '',
        ticketId: j['ticket_id'] ?? '',
        ticketNumber: j['ticket_number'] ?? '',
        toDo: j['to_do'] ?? '',
        fixbyDate: j['fixby_date'] ?? '',
        completedDate: j['completed_date'] ?? '',
        verifiedBy: j['verified_by'] ?? '',
        verifiedDate: j['verified_date'] ?? '',
        status: j['status'] ?? '',
      );
}

class _PendingWork {
  final String ticketNumber;
  final String fixbyDate;
  final String addedDate;
  final String status;
  final String toDo;

  const _PendingWork({
    required this.ticketNumber,
    required this.fixbyDate,
    required this.addedDate,
    required this.status,
    required this.toDo,
  });

  factory _PendingWork.fromJson(Map<String, dynamic> j) => _PendingWork(
        ticketNumber: j['ticket_number'] ?? '',
        fixbyDate: j['fixby_date'] ?? '',
        addedDate: j['added_date'] ?? '',
        status: j['status'] ?? '',
        toDo: j['to_do'] ?? '',
      );
}

class _LeaveApplication {
  final String absenceFrom;
  final String absenceThrough;
  final String typeOfAbsence;
  final String reason;
  final String status;

  const _LeaveApplication({
    required this.absenceFrom,
    required this.absenceThrough,
    required this.typeOfAbsence,
    required this.reason,
    required this.status,
  });

  factory _LeaveApplication.fromJson(Map<String, dynamic> j) => _LeaveApplication(
        absenceFrom: j['absence_from'] ?? '',
        absenceThrough: j['absence_through'] ?? '',
        typeOfAbsence: j['type_of_absence'] ?? '',
        reason: j['reason'] ?? '',
        status: j['status'] ?? '',
      );
}

class _Attendance {
  final String date;
  final List<Map<String, dynamic>> sessions;
  final int totalSeconds;
  final String totalWorked;

  const _Attendance({
    required this.date,
    required this.sessions,
    required this.totalSeconds,
    required this.totalWorked,
  });

  factory _Attendance.fromJson(Map<String, dynamic> j) => _Attendance(
        date: j['date'] ?? '',
        sessions: List<Map<String, dynamic>>.from(j['sessions'] ?? []),
        totalSeconds: j['total_seconds'] ?? 0,
        totalWorked: j['total_worked'] ?? '00:00:00',
      );
}

// ── Employee Wise Report Page ───────────────────────────────────────────────
class EmployeeWiseReportPage extends StatefulWidget {
  final String username;
  const EmployeeWiseReportPage({super.key, required this.username});

  @override
  State<EmployeeWiseReportPage> createState() => _EmployeeWiseReportPageState();
}

class _EmployeeWiseReportPageState extends State<EmployeeWiseReportPage> {
  static const int _pageSize = 50;

  // ── Filter state ───────────────────────────────────────────────────────────
  String _selectedEmployeeId = '';
  String _selectedEmployeeName = '';
  StyleOption? _selectedStyle;
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  int? _totalCount;
  String? _selectedEmployeePhone;
  String? _selectedEmployeeCode;

  // ── Data state ─────────────────────────────────────────────────────────────
  List<dynamic> _all = [];
  List<dynamic> _filtered = [];
  bool _isLoading = false;
  bool _hasFetched = false;
  String? _errorMessage;

  // ── Employees list for search ─────────────────────────────────────────────
  List<_Employee> _employeesList = [];
  bool _isLoadingEmployees = false;

  // ── Search / pagination ────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 1;

  // ── Export state ───────────────────────────────────────────────────────────
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
    _fetchEmployeesList();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    setState(() {
      _searchQuery = _searchCtrl.text.trim().toLowerCase();
      _currentPage = 1;
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filtered = List.from(_all);
    } else {
      _filtered = _all.where((item) {
        if (_selectedStyle == StyleOption.completedTasks) {
          final task = item as _CompletedTask;
          return task.ticketNumber.contains(_searchQuery) ||
              task.toDo.toLowerCase().contains(_searchQuery) ||
              task.status.toLowerCase().contains(_searchQuery) ||
              task.verifiedBy.toLowerCase().contains(_searchQuery);
        } else if (_selectedStyle == StyleOption.pendingWorks) {
          final work = item as _PendingWork;
          return work.ticketNumber.contains(_searchQuery) ||
              work.toDo.toLowerCase().contains(_searchQuery) ||
              work.status.toLowerCase().contains(_searchQuery);
        } else if (_selectedStyle == StyleOption.leaveApplication) {
          final leave = item as _LeaveApplication;
          return leave.typeOfAbsence.toLowerCase().contains(_searchQuery) ||
              leave.reason.toLowerCase().contains(_searchQuery) ||
              leave.status.toLowerCase().contains(_searchQuery);
        } else if (_selectedStyle == StyleOption.attendance) {
          final attendance = item as _Attendance;
          return attendance.date.contains(_searchQuery) ||
              attendance.totalWorked.contains(_searchQuery);
        }
        return false;
      }).toList();
    }
  }

  // ── Date helpers ───────────────────────────────────────────────────────────
  String _apiDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return '—';
    try {
      final p = raw.trim().split('-');
      if (p.length == 3) return '${p[2]}/${p[1]}/${p[0]}';
    } catch (_) {}
    return raw;
  }

  // ── Date picker ────────────────────────────────────────────────────────────
  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom ? _fromDate : _toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_toDate.isBefore(picked)) _toDate = picked;
      } else {
        _toDate = picked;
        if (_fromDate.isAfter(picked)) _fromDate = picked;
      }
    });
  }

  // ── Fetch Employees List for Search/Auto-completion ────────────────────────
  Future<void> _fetchEmployeesList() async {
    setState(() => _isLoadingEmployees = true);

    try {
      final url = Uri.parse('${ApiService.baseUrl}/api/employee/list.php?view=dropdown');

      debugPrint('─────────────────────────────────────────');
      debugPrint('📤  [EMPLOYEES DROPDOWN] Request');
      debugPrint('   🌐  URL : $url');
      debugPrint('─────────────────────────────────────────');

      final res = await ApiService.get(url).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      debugPrint('─────────────────────────────────────────');
      debugPrint('📥  [EMPLOYEES DROPDOWN] Response');
      debugPrint('   🔢  Status : ${res.statusCode}');
      debugPrint('   📄  Body   : ${res.body}');
      debugPrint('─────────────────────────────────────────');

      if (res.statusCode == 200 && data['success'] == true) {
        final list = data['data'] as List? ?? [];
        _employeesList = list.map((e) => _Employee.fromJson(e)).toList();
      } else {
        debugPrint('Failed to load employees list: ${data['message']}');
      }
    } catch (e) {
      debugPrint('Error fetching employees list: $e');
    }

    if (mounted) setState(() => _isLoadingEmployees = false);
  }

  // ── Fetch Report ────────────────────────────────────────────────────────────
  Future<void> _fetchReport() async {
    if (_selectedEmployeeId.isEmpty) {
      AppSnackBar.show(context, 'Please select an employee first.', isError: true);
      return;
    }

    if (_selectedStyle == null) {
      AppSnackBar.show(context, 'Please select a style.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasFetched = true;
      _searchCtrl.clear();
      _searchQuery = '';
      _currentPage = 1;
    });

    try {
      final url = Uri.parse(
        '${ApiService.baseUrl}/api/employee/report.php'
        '?from_date=${_apiDate(_fromDate)}'
        '&to_date=${_apiDate(_toDate)}'
        '&style=${_selectedStyle!.apiValue}'
        '&employee_id=${Uri.encodeComponent(_selectedEmployeeId)}',
      );

      debugPrint('─────────────────────────────────────────');
      debugPrint('📤  [EMPLOYEE WISE REPORT] Request');
      debugPrint('   🌐  URL : $url');
      debugPrint('─────────────────────────────────────────');

      final res = await ApiService.get(url).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      debugPrint('─────────────────────────────────────────');
      debugPrint('📥  [EMPLOYEE WISE REPORT] Response');
      debugPrint('   🔢  Status : ${res.statusCode}');
      debugPrint('   📄  Body   : ${res.body}');
      debugPrint('─────────────────────────────────────────');

      if (res.statusCode == 200 && data['success'] == true) {
        final list = data['data'] as List? ?? [];
        
        // Parse based on style
        if (_selectedStyle == StyleOption.completedTasks) {
          _all = list.map((e) => _CompletedTask.fromJson(e)).toList();
        } else if (_selectedStyle == StyleOption.pendingWorks) {
          _all = list.map((e) => _PendingWork.fromJson(e)).toList();
        } else if (_selectedStyle == StyleOption.leaveApplication) {
          _all = list.map((e) => _LeaveApplication.fromJson(e)).toList();
        } else if (_selectedStyle == StyleOption.attendance) {
          _all = list.map((e) => _Attendance.fromJson(e)).toList();
        }
        
        _totalCount = data['total'] as int? ?? _all.length;
        _selectedEmployeeName = data['employee_name'] as String? ?? _selectedEmployeeName;
        _applyFilter();
      } else {
        _errorMessage = data['error'] ?? data['message'] ?? 'Failed to load report.';
      }
    } on http.ClientException {
      _errorMessage = 'Unable to reach the server. Check your connection.';
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ── Pagination ─────────────────────────────────────────────────────────────
  int get _totalPages => paginationTotalPages(_filtered.length, _pageSize);
  List<dynamic> get _pageItems => paginationPageItems(_filtered, _currentPage, _pageSize);

  void _goBackToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomePage(username: widget.username, openDrawerOnLoad: true),
      ),
      (route) => false,
    );
  }

  // ── Print Report ───────────────────────────────────────────────────────────
  Future<void> _printReport() async {
    if (_filtered.isEmpty) {
      AppSnackBar.show(context, 'No data to print.', isError: true);
      return;
    }

    try {
      final pdf = pw.Document();

      // Create table data based on style
      List<List<String>> tableData = [];
      
      if (_selectedStyle == StyleOption.completedTasks) {
        tableData = [
          ['S.No', 'Ticket No', 'Fixby Date', 'Completed Date', 'Verified By', 'Verified Date', 'Status', 'To Do'],
        ];
        for (int i = 0; i < _filtered.length; i++) {
          final e = _filtered[i] as _CompletedTask;
          String toDo = e.toDo;
          if (toDo.length > 40) toDo = toDo.substring(0, 37) + '...';
          tableData.add([
            (i + 1).toString(),
            e.ticketNumber,
            _fmtDate(e.fixbyDate),
            _fmtDate(e.completedDate),
            e.verifiedBy.toUpperCase(),
            _fmtDate(e.verifiedDate),
            e.status.toUpperCase(),
            toDo,
          ]);
        }
      } else if (_selectedStyle == StyleOption.pendingWorks) {
        tableData = [
          ['S.No', 'Ticket No', 'Fixby Date', 'Added Date', 'Status', 'To Do'],
        ];
        for (int i = 0; i < _filtered.length; i++) {
          final e = _filtered[i] as _PendingWork;
          String toDo = e.toDo;
          if (toDo.length > 50) toDo = toDo.substring(0, 47) + '...';
          tableData.add([
            (i + 1).toString(),
            e.ticketNumber,
            _fmtDate(e.fixbyDate),
            _fmtDate(e.addedDate),
            e.status.toUpperCase(),
            toDo,
          ]);
        }
      } else if (_selectedStyle == StyleOption.leaveApplication) {
        tableData = [
          ['S.No', 'Absence From', 'Absence Through', 'Type of Absence', 'Reason', 'Status'],
        ];
        for (int i = 0; i < _filtered.length; i++) {
          final e = _filtered[i] as _LeaveApplication;
          String reason = e.reason;
          if (reason.length > 50) reason = reason.substring(0, 47) + '...';
          tableData.add([
            (i + 1).toString(),
            _fmtDate(e.absenceFrom),
            _fmtDate(e.absenceThrough),
            e.typeOfAbsence.toUpperCase(),
            reason,
            e.status.toUpperCase(),
          ]);
        }
      } else if (_selectedStyle == StyleOption.attendance) {
        tableData = [
          ['S.No', 'Date', 'Total Worked', 'Sessions'],
        ];
        for (int i = 0; i < _filtered.length; i++) {
          final e = _filtered[i] as _Attendance;
          String sessionsStr = e.sessions.map((s) {
            final inTime = s['in_time'] ?? '--:--:--';
            final outTime = s['out_time'] ?? '--:--:--';
            return '$inTime - $outTime';
          }).join(', ');
          if (sessionsStr.length > 60) sessionsStr = sessionsStr.substring(0, 57) + '...';
          tableData.add([
            (i + 1).toString(),
            _fmtDate(e.date),
            e.totalWorked,
            sessionsStr,
          ]);
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              pw.Center(
                child: pw.Text(
                  'Employee Wise Report',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Period: ${_displayDate(_fromDate)} to ${_displayDate(_toDate)}',
                            style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(height: 4),
                        pw.Text('Employee: $_selectedEmployeeName',
                            style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(height: 4),
                        pw.Text('Style: ${_selectedStyle!.displayName}',
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Generated: ${DateTime.now().toString().substring(0, 19)}',
                            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                        pw.SizedBox(height: 4),
                        pw.Text('Total Records: ${_filtered.length}',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Table.fromTextArray(
                context: context,
                data: tableData,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignment: pw.Alignment.centerLeft,
                tableWidth: pw.TableWidth.max,
                cellPadding: const pw.EdgeInsets.all(5),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      AppSnackBar.show(context, 'Failed to print: $e', isError: true);
    }
  }

  // ── Export Excel ───────────────────────────────────────────────────────────
  Future<void> _exportExcel() async {
    if (_filtered.isEmpty) {
      AppSnackBar.show(context, 'No data to export.', isError: true);
      return;
    }

    setState(() => _isExporting = true);

    try {
      final excel = Excel.createExcel();
      final sheet = excel['Employee Wise Report'];

      List<String> headers = [];
      
      if (_selectedStyle == StyleOption.completedTasks) {
        headers = ['S.NO', 'Ticket No', 'Fixby Date', 'Completed Date', 'Verified By', 'Verified Date', 'Status', 'To Do'];
      } else if (_selectedStyle == StyleOption.pendingWorks) {
        headers = ['S.NO', 'Ticket No', 'Fixby Date', 'Added Date', 'Status', 'To Do'];
      } else if (_selectedStyle == StyleOption.leaveApplication) {
        headers = ['S.NO', 'Absence From', 'Absence Through', 'Type of Absence', 'Reason', 'Status'];
      } else if (_selectedStyle == StyleOption.attendance) {
        headers = ['S.NO', 'Date', 'Total Worked', 'Sessions'];
      }

      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1558E7'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Center,
      );

      for (int c = 0; c < headers.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
        cell.value = TextCellValue(headers[c]);
        cell.cellStyle = headerStyle;
      }

      // Set column widths
      for (int c = 0; c < headers.length; c++) {
        sheet.setColumnWidth(c, headers[c].length + 5);
      }

      // Data rows
      for (int i = 0; i < _filtered.length; i++) {
        final row = i + 1;
        List<String> rowData = [];

        if (_selectedStyle == StyleOption.completedTasks) {
          final e = _filtered[i] as _CompletedTask;
          rowData = [
            (i + 1).toString(),
            e.ticketNumber,
            _fmtDate(e.fixbyDate),
            _fmtDate(e.completedDate),
            e.verifiedBy.toUpperCase(),
            _fmtDate(e.verifiedDate),
            e.status.toUpperCase(),
            e.toDo,
          ];
        } else if (_selectedStyle == StyleOption.pendingWorks) {
          final e = _filtered[i] as _PendingWork;
          rowData = [
            (i + 1).toString(),
            e.ticketNumber,
            _fmtDate(e.fixbyDate),
            _fmtDate(e.addedDate),
            e.status.toUpperCase(),
            e.toDo,
          ];
        } else if (_selectedStyle == StyleOption.leaveApplication) {
          final e = _filtered[i] as _LeaveApplication;
          rowData = [
            (i + 1).toString(),
            _fmtDate(e.absenceFrom),
            _fmtDate(e.absenceThrough),
            e.typeOfAbsence.toUpperCase(),
            e.reason,
            e.status.toUpperCase(),
          ];
        } else if (_selectedStyle == StyleOption.attendance) {
          final e = _filtered[i] as _Attendance;
          final sessionsStr = e.sessions.map((s) {
            final inTime = s['in_time'] ?? '--:--:--';
            final outTime = s['out_time'] ?? '--:--:--';
            return '$inTime - $outTime';
          }).join('; ');
          rowData = [
            (i + 1).toString(),
            _fmtDate(e.date),
            e.totalWorked,
            sessionsStr,
          ];
        }

        final evenBg = ExcelColor.fromHexString('#F0F4FF');
        final oddBg = ExcelColor.fromHexString('#FFFFFF');

        for (int c = 0; c < rowData.length; c++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
          cell.value = TextCellValue(rowData[c]);
          cell.cellStyle = CellStyle(
            backgroundColorHex: i.isEven ? evenBg : oddBg,
            horizontalAlign: c == 0 ? HorizontalAlign.Center : HorizontalAlign.Left,
          );
        }
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to encode Excel file.');

      final dir = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final fileName = 'employee_wise_report_'
          '${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}.xlsx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      AppSnackBar.show(context, 'Excel exported: $fileName');
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, 'Export failed: $e', isError: true);
      }
    }

    if (mounted) setState(() => _isExporting = false);
  }

  // ── Employee Search with Auto-completion ───────────────────────────────────
  Widget _employeeSearchField() {
    if (_isLoadingEmployees && _employeesList.isEmpty) {
      return Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.border, width: 1.2),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: Autocomplete<_Employee>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<_Employee>.empty();
              }
              final searchTerm = textEditingValue.text.toLowerCase();
              return _employeesList.where((employee) =>
                  employee.employeeName.toLowerCase().contains(searchTerm) ||
                  employee.phoneNumber.contains(searchTerm) ||
                  employee.employeeCode.contains(searchTerm));
            },
            displayStringForOption: (employee) => employee.displayText,
            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
              if (_selectedEmployeeId.isNotEmpty && textEditingController.text.isEmpty) {
                final selected = _employeesList.firstWhere(
                  (e) => e.id == _selectedEmployeeId,
                  orElse: () => _employeesList.first,
                );
                textEditingController.text = selected.displayText;
              }
              return TextField(
                controller: textEditingController,
                focusNode: focusNode,
                cursorColor: AppColors.primary,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search employee by name, code or phone...',
                  hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 12),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.iconDefault, size: 18),
                  suffixIcon: _selectedEmployeeId.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () {
                            setState(() {
                              _selectedEmployeeId = '';
                              _selectedEmployeeName = '';
                              _selectedEmployeePhone = null;
                              _selectedEmployeeCode = null;
                              textEditingController.clear();
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              );
            },
            onSelected: (employee) {
              setState(() {
                _selectedEmployeeId = employee.id;
                _selectedEmployeeName = employee.employeeName;
                _selectedEmployeePhone = employee.phoneNumber;
                _selectedEmployeeCode = employee.employeeCode;
              });
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: constraints.maxWidth,
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final employee = options.elementAt(index);
                        return InkWell(
                          onTap: () => onSelected(employee),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.borderLight,
                                  width: index == options.length - 1 ? 0 : 0.5,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  employee.employeeName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (employee.employeeCode.isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Code: ${employee.employeeCode}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      '📞 ${employee.phoneNumber}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ── Style Dropdown ─────────────────────────────────────────────────────────
  Widget _styleDropdown() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<StyleOption?>(
          value: _selectedStyle,
          hint: const Text('Choose Style',
              style: TextStyle(color: AppColors.textHint, fontSize: 12.5)),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: AppColors.textLabel),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
          onChanged: (v) {
            setState(() {
              _selectedStyle = v;
              // Clear data when style changes
              _all.clear();
              _filtered.clear();
              _hasFetched = false;
            });
          },
          items: [
            const DropdownMenuItem<StyleOption?>(
              value: null,
              child: Text('Choose Style', style: TextStyle(fontSize: 13)),
            ),
            ...StyleOption.values.map((style) => DropdownMenuItem(
              value: style,
              child: Text(style.displayName, style: const TextStyle(fontSize: 13)),
            )),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final hPad = isTablet ? size.width * 0.06 : 16.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAppBar(isTablet, hPad),

            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
                children: [
                  const SizedBox(height: 16),

                  const Text(
                    'Employee Wise Report',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Filter and analyze employee tasks by style & date',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildFilterCard(isTablet),

                  const SizedBox(height: 14),

                  if (_hasFetched && !_isLoading && _errorMessage == null)
                    _buildSearchBar(),

                  if (_hasFetched && !_isLoading && _errorMessage == null)
                    const SizedBox(height: 10),

                  if (_hasFetched && !_isLoading && _errorMessage == null)
                    Row(
                      children: [
                        Text(
                          '${_filtered.length} record${_filtered.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_totalCount != null && _searchQuery.isEmpty) ...[
                          const Text('  ·  ',
                              style: TextStyle(color: AppColors.textMuted)),
                          Text('Total: $_totalCount',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ],
                    ),

                  if (_hasFetched && !_isLoading && _errorMessage == null)
                    const SizedBox(height: 10),

                  if (!_hasFetched)
                    _buildIdleState()
                  else if (_isLoading)
                    _buildSkeletonList()
                  else if (_errorMessage != null)
                    _buildError()
                  else if (_filtered.isEmpty)
                    _buildEmpty()
                  else
                    ..._pageItems.map((e) => _buildReportCard(e)).expand(
                          (w) => [w, const SizedBox(height: 8)]),

                  const SizedBox(height: 80),
                ],
              ),
            ),

            if (_hasFetched && !_isLoading &&
                _errorMessage == null && _filtered.isNotEmpty)
              AppPagination(
                currentPage: _currentPage,
                totalPages: _totalPages,
                horizontalPadding: hPad,
                onPageChanged: (p) => setState(() => _currentPage = p),
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
              width: 36,
              height: 36,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Employee Wise',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: isTablet ? 20 : 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3)),
              const Text('Reports',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 11.5)),
            ],
          ),
          const Spacer(),
          if (_hasFetched)
            GestureDetector(
              onTap: _fetchReport,
              child: Container(
                width: 36,
                height: 36,
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

  Widget _buildFilterCard(bool isTablet) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: (_filtered.isEmpty || _isLoading)
                    ? null
                    : _printReport,
                icon: const Icon(Icons.print_outlined,
                    size: 14, color: AppColors.primary),
                label: const Text('Print',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary, width: 1.2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  backgroundColor: AppColors.primaryLight,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: (_filtered.isEmpty || _isLoading || _isExporting)
                    ? null
                    : _exportExcel,
                icon: _isExporting
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            color: Color(0xFF1D6F42), strokeWidth: 2))
                    : const Icon(Icons.table_chart_outlined,
                        size: 14, color: Color(0xFF1D6F42)),
                label: Text(
                  _isExporting ? 'Exporting…' : 'Excel',
                  style: const TextStyle(
                      color: Color(0xFF1D6F42),
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1D6F42), width: 1.2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  backgroundColor: const Color(0xFFEBF5EC),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 12),

          _filterLabel(
            label: 'Employee',
            child: _employeeSearchField(),
          ),

          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Style dropdown - reduced width
              SizedBox(
                width: 110,
                child: _filterLabel(
                  label: 'Style',
                  child: _styleDropdown(),
                ),
              ),
              const SizedBox(width: 8),
              // From - expanded
              Expanded(
                flex: 1,
                child: _filterLabel(
                  label: 'From',
                  child: _datePicker(isFrom: true),
                ),
              ),
              const SizedBox(width: 8),
              // To - expanded
              Expanded(
                flex: 1,
                child: _filterLabel(
                  label: 'To',
                  child: _datePicker(isFrom: false),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 125,
              height: 34,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _fetchReport,
                icon: _isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.search_rounded,
                        size: 14, color: Colors.white),
                label: Text(_isLoading ? 'Searching…' : 'Search',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterLabel({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textLabel,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3)),
        const SizedBox(height: 5),
        child,
      ],
    );
  }

  Widget _datePicker({required bool isFrom}) {
    final date = isFrom ? _fromDate : _toDate;
    return GestureDetector(
      onTap: () => _pickDate(isFrom),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.border, width: 1.2),
        ),
        child: Center(
          child: Text(
            _displayDate(date),
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
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
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        cursorColor: AppColors.primary,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: _getSearchHintText(),
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 12.5),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.iconDefault, size: 19),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  String _getSearchHintText() {
    if (_selectedStyle == StyleOption.completedTasks) {
      return 'Search by ticket no, to-do, status, verified by...';
    } else if (_selectedStyle == StyleOption.pendingWorks) {
      return 'Search by ticket no, to-do, status...';
    } else if (_selectedStyle == StyleOption.leaveApplication) {
      return 'Search by type, reason, status...';
    } else if (_selectedStyle == StyleOption.attendance) {
      return 'Search by date, total worked...';
    }
    return 'Search...';
  }

  Widget _buildReportCard(dynamic item) {
    if (_selectedStyle == StyleOption.completedTasks) {
      final e = item as _CompletedTask;
      Color statusColor;
      switch (e.status.toLowerCase()) {
        case 'verified':
          statusColor = const Color(0xFF1D6F42);
          break;
        case 'pending':
          statusColor = Colors.orange;
          break;
        case 'rejected':
          statusColor = Colors.red;
          break;
        default:
          statusColor = AppColors.textSecondary;
      }

      return Container(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Ticket #${e.ticketNumber}',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    e.status.toUpperCase(),
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              e.toDo,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 9),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 11, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Text('Fixby: ${_fmtDate(e.fixbyDate)}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
                if (e.completedDate.isNotEmpty && e.completedDate != 'null')
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 11, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text('Done: ${_fmtDate(e.completedDate)}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                if (e.verifiedBy.isNotEmpty && e.verifiedBy != 'null')
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded,
                          size: 11, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text('By: ${e.verifiedBy.capitalize()}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                if (e.verifiedDate.isNotEmpty && e.verifiedDate != 'null')
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.date_range_rounded,
                          size: 11, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text('On: ${_fmtDate(e.verifiedDate)}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      );
    } else if (_selectedStyle == StyleOption.pendingWorks) {
      final e = item as _PendingWork;
      Color statusColor = e.status.toLowerCase() == 'pending' ? Colors.orange : AppColors.textSecondary;

      return Container(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Ticket #${e.ticketNumber}',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    e.status.toUpperCase(),
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              e.toDo,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 9),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 11, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Text('Fixby: ${_fmtDate(e.fixbyDate)}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_circle_outline_rounded,
                        size: 11, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Text('Added: ${_fmtDate(e.addedDate)}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    } else if (_selectedStyle == StyleOption.leaveApplication) {
      final e = item as _LeaveApplication;
      Color statusColor;
      switch (e.status.toLowerCase()) {
        case 'approved':
          statusColor = const Color(0xFF1D6F42);
          break;
        case 'pending':
          statusColor = Colors.orange;
          break;
        case 'rejected':
          statusColor = Colors.red;
          break;
        default:
          statusColor = AppColors.textSecondary;
      }

      return Container(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(e.typeOfAbsence.toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    e.status.toUpperCase(),
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              e.reason,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 9),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 11, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Text('From: ${_fmtDate(e.absenceFrom)}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 11, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Text('To: ${_fmtDate(e.absenceThrough)}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    } else if (_selectedStyle == StyleOption.attendance) {
      final e = item as _Attendance;
      
      return Container(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_fmtDate(e.date),
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D6F42).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(e.totalWorked,
                      style: const TextStyle(
                          color: Color(0xFF1D6F42),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Column(
              children: e.sessions.map((session) {
                final inTime = session['in_time'] ?? '--:--:--';
                final outTime = session['out_time'] ?? '--:--:--';
                final duration = session['duration_display'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$inTime → $outTime',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ),
                      if (duration != null)
                        Text(
                          '($duration)',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 10),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildIdleState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.person_search_rounded,
                  size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text('Select an employee and tap Search',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('Results will appear here',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return Column(
      children: List.generate(5, (_) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _skeletonCard(),
      )),
    );
  }

  Widget _skeletonCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _shimmer(width: 70, height: 20, radius: 6),
              _shimmer(width: 55, height: 18, radius: 4),
            ],
          ),
          const SizedBox(height: 12),
          _shimmer(width: double.infinity, height: 32, radius: 4),
          const SizedBox(height: 12),
          _shimmer(width: double.infinity, height: 1, radius: 1),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            children: [
              _shimmer(width: 80, height: 12, radius: 4),
              _shimmer(width: 75, height: 12, radius: 4),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shimmer({
    required double width,
    required double height,
    required double radius,
  }) => _ShimmerBox(width: width, height: height, radius: radius);

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 56, color: AppColors.border),
            const SizedBox(height: 14),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results for "$_searchQuery"'
                  : 'No records found for the selected filters',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Try adjusting the date range or style',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 52, color: AppColors.border),
            const SizedBox(height: 14),
            Text(
              _errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchReport,
              icon: const Icon(Icons.refresh_rounded,
                  size: 16, color: Colors.white),
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
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double width, height, radius;
  const _ShimmerBox({required this.width, required this.height, required this.radius});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

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
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EDF5),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
}