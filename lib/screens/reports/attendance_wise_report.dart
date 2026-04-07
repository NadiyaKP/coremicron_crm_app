import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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

// ── Models ─────────────────────────────────────────────────────────────────
class _Session {
  final String inTime;
  final String outTime;
  final String workedDuration;

  const _Session({
    required this.inTime,
    required this.outTime,
    required this.workedDuration,
  });

  factory _Session.fromJson(Map<String, dynamic> j) => _Session(
        inTime:          j['in_time']         ?? '',
        outTime:         j['out_time']        ?? '',
        workedDuration:  j['worked_duration'] ?? '',
      );
}

class _EmployeeAttendance {
  final String       employeeId;
  final String       employeeName;
  final List<_Session> sessions;
  final String       totalWorkedDuration;

  const _EmployeeAttendance({
    required this.employeeId,
    required this.employeeName,
    required this.sessions,
    required this.totalWorkedDuration,
  });

  factory _EmployeeAttendance.fromJson(Map<String, dynamic> j) =>
      _EmployeeAttendance(
        employeeId:          j['employee_id']           ?? '',
        employeeName:        j['employee_name']         ?? '',
        totalWorkedDuration: j['total_worked_duration'] ?? '',
        sessions: (j['sessions'] as List? ?? [])
            .map((s) => _Session.fromJson(s))
            .toList(),
      );
}

class _AttendanceDay {
  final String                    date;
  final List<_EmployeeAttendance> employees;

  const _AttendanceDay({required this.date, required this.employees});

  factory _AttendanceDay.fromJson(Map<String, dynamic> j) => _AttendanceDay(
        date:      j['date'] ?? '',
        employees: (j['employees'] as List? ?? [])
            .map((e) => _EmployeeAttendance.fromJson(e))
            .toList(),
      );
}

// ── Flat row for display + search/pagination ───────────────────────────────
class _AttendanceRow {
  final String date;
  final String employeeName;
  final String inTime;
  final String outTime;
  final String workedDuration;
  final String totalWorkedDuration;

  const _AttendanceRow({
    required this.date,
    required this.employeeName,
    required this.inTime,
    required this.outTime,
    required this.workedDuration,
    required this.totalWorkedDuration,
  });
}

// ── Attendance Wise Report Page ────────────────────────────────────────────
class AttendanceWiseReportPage extends StatefulWidget {
  final String username;
  const AttendanceWiseReportPage({super.key, required this.username});

  @override
  State<AttendanceWiseReportPage> createState() =>
      _AttendanceWiseReportPageState();
}

class _AttendanceWiseReportPageState
    extends State<AttendanceWiseReportPage> {
  static const int _pageSize = 50;

  // ── Filter state ───────────────────────────────────────────────────────────
  DateTime _fromDate = DateTime.now();
  DateTime _toDate   = DateTime.now();

  // ── Data state ─────────────────────────────────────────────────────────────
  List<_AttendanceRow> _all        = [];
  List<_AttendanceRow> _filtered   = [];
  bool                 _isLoading  = false;
  bool                 _hasFetched = false;
  String?              _errorMessage;

  // ── Search / pagination ────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int    _currentPage = 1;

  // ── Export state ───────────────────────────────────────────────────────────
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
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
      _filtered = _all.where((r) =>
          r.employeeName.toLowerCase().contains(_searchQuery) ||
          r.date.contains(_searchQuery) ||
          r.inTime.contains(_searchQuery) ||
          r.outTime.contains(_searchQuery) ||
          r.workedDuration.contains(_searchQuery)).toList();
    }
  }

  // ── Date helpers ───────────────────────────────────────────────────────────
  String _apiDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return '—';
    try {
      final p = raw.trim().split('-');
      if (p.length == 3) return '${p[2]}/${p[1]}/${p[0]}';
    } catch (_) {}
    return raw;
  }

  String _fmtTime(String? t) {
    if (t == null || t.isEmpty || t == 'null') return '—';
    // convert HH:MM:SS to HH:MM
    final parts = t.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return t;
  }

  // ── Date picker ────────────────────────────────────────────────────────────
  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom ? _fromDate : _toDate;
    final picked  = await showDatePicker(
      context:     context,
      initialDate: initial,
      firstDate:   DateTime(2020),
      lastDate:    DateTime.now(),
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

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchReport() async {
    setState(() {
      _isLoading    = true;
      _errorMessage = null;
      _hasFetched   = true;
      _searchCtrl.clear();
      _searchQuery  = '';
      _currentPage  = 1;
    });

    try {
      final url = Uri.parse(
        '${ApiService.baseUrl}/api/attendance/report.php'
        '?from_date=${_apiDate(_fromDate)}'
        '&to_date=${_apiDate(_toDate)}',
      );

      debugPrint('─────────────────────────────────────────');
      debugPrint('📤  [ATTENDANCE REPORT] Request');
      debugPrint('   🌐  URL : $url');
      debugPrint('─────────────────────────────────────────');

      final res  = await ApiService.get(url).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      debugPrint('─────────────────────────────────────────');
      debugPrint('📥  [ATTENDANCE REPORT] Response');
      debugPrint('   🔢  Status : ${res.statusCode}');
      debugPrint('   📄  Body   : ${res.body}');
      debugPrint('─────────────────────────────────────────');

      if (res.statusCode == 200 && data['success'] == true) {
        final days = (data['report'] as List? ?? [])
            .map((d) => _AttendanceDay.fromJson(d))
            .toList();

        // Flatten: one row per employee-session combination
        final rows = <_AttendanceRow>[];
        for (final day in days) {
          for (final emp in day.employees) {
            if (emp.sessions.isEmpty) {
              rows.add(_AttendanceRow(
                date:                day.date,
                employeeName:        emp.employeeName,
                inTime:              '—',
                outTime:             '—',
                workedDuration:      '—',
                totalWorkedDuration: emp.totalWorkedDuration,
              ));
            } else {
              for (int i = 0; i < emp.sessions.length; i++) {
                final s = emp.sessions[i];
                rows.add(_AttendanceRow(
                  date:                day.date,
                  employeeName:        emp.employeeName,
                  inTime:              s.inTime,
                  outTime:             s.outTime,
                  workedDuration:      s.workedDuration,
                  totalWorkedDuration: emp.totalWorkedDuration,
                ));
              }
            }
          }
        }

        _all = rows;
        _applyFilter();
      } else {
        _errorMessage =
            data['error'] ?? data['message'] ?? 'Failed to load report.';
      }
    } on http.ClientException {
      _errorMessage = 'Unable to reach the server. Check your connection.';
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ── Pagination ─────────────────────────────────────────────────────────────
  int get _totalPages =>
      paginationTotalPages(_filtered.length, _pageSize);
  List<_AttendanceRow> get _pageItems =>
      paginationPageItems(_filtered, _currentPage, _pageSize);

  void _goBackToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            HomePage(username: widget.username, openDrawerOnLoad: true),
      ),
      (route) => false,
    );
  }

  // ── Print ──────────────────────────────────────────────────────────────────
  Future<void> _printReport() async {
    if (_filtered.isEmpty) {
      AppSnackBar.show(context, 'No data to print.', isError: true);
      return;
    }
    try {
      final pdf = pw.Document();

      final List<List<String>> tableData = [
        ['S.No', 'Date', 'Employee', 'In Time', 'Out Time', 'Duration'],
      ];

      for (int i = 0; i < _filtered.length; i++) {
        final r = _filtered[i];
        String empName = r.employeeName.toUpperCase();
        tableData.add([
          (i + 1).toString(),
          _fmtDate(r.date),
          empName,
          _fmtTime(r.inTime),
          _fmtTime(r.outTime),
          r.workedDuration,
        ]);
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin:     const pw.EdgeInsets.all(20),
          build: (pw.Context ctx) => [
            pw.Center(
              child: pw.Text(
                'Attendance Wise Report',
                style: pw.TextStyle(
                    fontSize: 22, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Period: ${_displayDate(_fromDate)} to ${_displayDate(_toDate)}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Generated: ${DateTime.now().toString().substring(0, 19)}',
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey600),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Total Records: ${_filtered.length}',
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Table.fromTextArray(
              context: ctx,
              data: tableData,
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.center,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
                5: pw.Alignment.center,
              },
              columnWidths: {
                0: const pw.FixedColumnWidth(35),
                1: const pw.FixedColumnWidth(65),
                2: const pw.FlexColumnWidth(),
                3: const pw.FixedColumnWidth(60),
                4: const pw.FixedColumnWidth(60),
                5: const pw.FixedColumnWidth(65),
              },
              tableWidth: pw.TableWidth.max,
              cellPadding: const pw.EdgeInsets.all(5),
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
          ],
        ),
      );

      await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save());
    } catch (e) {
      if (mounted) AppSnackBar.show(context, 'Failed to print: $e', isError: true);
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
      final sheet = excel['Attendance Report'];

      final headers = [
        'S.NO', 'Date', 'Employee', 'In Time', 'Out Time',
        'Session Duration', 'Total Duration',
      ];

      final headerStyle = CellStyle(
        bold:               true,
        backgroundColorHex: ExcelColor.fromHexString('#1558E7'),
        fontColorHex:       ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign:    HorizontalAlign.Center,
      );

      for (int c = 0; c < headers.length; c++) {
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
        cell.value     = TextCellValue(headers[c]);
        cell.cellStyle = headerStyle;
      }

      sheet.setColumnWidth(0, 6);
      sheet.setColumnWidth(1, 14);
      sheet.setColumnWidth(2, 26);
      sheet.setColumnWidth(3, 12);
      sheet.setColumnWidth(4, 12);
      sheet.setColumnWidth(5, 18);
      sheet.setColumnWidth(6, 18);

      final evenBg = ExcelColor.fromHexString('#F0F4FF');
      final oddBg  = ExcelColor.fromHexString('#FFFFFF');

      for (int i = 0; i < _filtered.length; i++) {
        final r   = _filtered[i];
        final row = i + 1;
        final rowData = [
          (i + 1).toString(),
          _fmtDate(r.date),
          r.employeeName.toUpperCase(),
          _fmtTime(r.inTime),
          _fmtTime(r.outTime),
          r.workedDuration,
          r.totalWorkedDuration,
        ];

        for (int c = 0; c < rowData.length; c++) {
          final cell = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
          cell.value     = TextCellValue(rowData[c]);
          cell.cellStyle = CellStyle(
            backgroundColorHex: i.isEven ? evenBg : oddBg,
            horizontalAlign:
                c == 0 ? HorizontalAlign.Center : HorizontalAlign.Left,
          );
        }
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to encode Excel.');

      final dir  = await getApplicationDocumentsDirectory();
      final now  = DateTime.now();
      final name = 'attendance_report_'
          '${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}.xlsx';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      AppSnackBar.show(context, 'Excel exported: $name');
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) AppSnackBar.show(context, 'Export failed: $e', isError: true);
    }

    if (mounted) setState(() => _isExporting = false);
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAppBar(isTablet, hPad),

            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
                children: [
                  const SizedBox(height: 16),

                  const Text('Attendance Wise Report',
                      style: TextStyle(
                          color:         AppColors.textPrimary,
                          fontSize:      17,
                          fontWeight:    FontWeight.w800,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 3),
                  const Text(
                      'Filter and analyze attendance records by date range',
                      style: TextStyle(
                          color:    AppColors.textSecondary,
                          fontSize: 12.5)),

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
                          '${_filtered.length} record'
                          '${_filtered.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                              color:      AppColors.textSecondary,
                              fontSize:   12.5,
                              fontWeight: FontWeight.w500),
                        ),
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
                    ..._pageItems.map((r) => _attendanceCard(r)).expand(
                          (w) => [w, const SizedBox(height: 8)]),

                  const SizedBox(height: 80),
                ],
              ),
            ),

            if (_hasFetched && !_isLoading &&
                _errorMessage == null && _filtered.isNotEmpty)
              AppPagination(
                currentPage:       _currentPage,
                totalPages:        _totalPages,
                horizontalPadding: hPad,
                onPageChanged: (p) => setState(() => _currentPage = p),
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
            onTap: _goBackToHome,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Attendance Wise',
                  style: TextStyle(
                      color:         AppColors.textPrimary,
                      fontSize:      isTablet ? 20 : 17,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: -0.3)),
              const Text('Reports',
                  style: TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 11.5)),
            ],
          ),
          const Spacer(),
          if (_hasFetched)
            GestureDetector(
              onTap: _fetchReport,
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

  // ── Filter Card ────────────────────────────────────────────────────────────
  Widget _buildFilterCard(bool isTablet) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight, width: 1),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset:     const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Print + Export ─────────────────────────────────────────
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
                        color:      AppColors.primary,
                        fontSize:   12,
                        fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                      color: AppColors.primary, width: 1.2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  backgroundColor: AppColors.primaryLight,
                  visualDensity:   VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed:
                    (_filtered.isEmpty || _isLoading || _isExporting)
                        ? null
                        : _exportExcel,
                icon: _isExporting
                    ? const SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(
                            color: Color(0xFF1D6F42), strokeWidth: 2))
                    : const Icon(Icons.table_chart_outlined,
                        size: 14, color: Color(0xFF1D6F42)),
                label: Text(
                  _isExporting ? 'Exporting…' : 'Excel',
                  style: const TextStyle(
                      color:      Color(0xFF1D6F42),
                      fontSize:   12,
                      fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                      color: Color(0xFF1D6F42), width: 1.2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  backgroundColor: const Color(0xFFEBF5EC),
                  visualDensity:   VisualDensity.compact,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 12),

          // ── From + To ──────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _filterLabel(
                  label: 'From',
                  child: _datePicker(isFrom: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _filterLabel(
                  label: 'To',
                  child: _datePicker(isFrom: false),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Search button ──────────────────────────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 125, height: 36,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _fetchReport,
                icon: _isLoading
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.search_rounded,
                        size: 15, color: Colors.white),
                label: Text(
                  _isLoading ? 'Searching…' : 'Search',
                  style: const TextStyle(
                      color:      Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize:   13.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor:
                      AppColors.primary.withOpacity(0.5),
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
                color:         AppColors.textLabel,
                fontSize:      10.5,
                fontWeight:    FontWeight.w600,
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
          color:        AppColors.background,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.border, width: 1.2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _displayDate(date),
                style: const TextStyle(
                    color:      AppColors.textPrimary,
                    fontSize:   12.5,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const Icon(Icons.calendar_today_outlined,
                size: 14, color: AppColors.iconDefault),
          ],
        ),
      ),
    );
  }

  // ── Search Bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset:     const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller:  _searchCtrl,
        cursorColor: AppColors.primary,
        style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 14),
        decoration: const InputDecoration(
          hintText:  'Search by employee, date, time…',
          hintStyle: TextStyle(
              color: AppColors.textHint, fontSize: 12.5),
          prefixIcon: Icon(Icons.search_rounded,
              color: AppColors.iconDefault, size: 19),
          border:         InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
              horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  // ── Attendance Card ────────────────────────────────────────────────────────
  Widget _attendanceCard(_AttendanceRow r) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          // ── Top row: date ─────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 11, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(_fmtDate(r.date),
                        style: const TextStyle(
                            color:      AppColors.primary,
                            fontSize:   11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Employee name ──────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    r.employeeName.isNotEmpty
                        ? r.employeeName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color:      AppColors.primary,
                        fontSize:   14,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r.employeeName.capitalize(),
                  style: const TextStyle(
                      color:      AppColors.textPrimary,
                      fontSize:   13.5,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 9),

          // ── In / Out / Duration row ────────────────────────────────
          Row(
            children: [
              Expanded(child: _timeChip(
                  icon:  Icons.login_rounded,
                  label: 'In',
                  value: _fmtTime(r.inTime),
                  color: const Color(0xFF0277BD),
                  bg:    const Color(0xFFE1F5FE))),
              const SizedBox(width: 8),
              Expanded(child: _timeChip(
                  icon:  Icons.logout_rounded,
                  label: 'Out',
                  value: _fmtTime(r.outTime),
                  color: const Color(0xFFC62828),
                  bg:    const Color(0xFFFFF1F1))),
              const SizedBox(width: 8),
              Expanded(child: _timeChip(
                  icon:  Icons.timer_outlined,
                  label: 'Duration',
                  value: r.workedDuration,
                  color: const Color(0xFF2E7D32),
                  bg:    const Color(0xFFE8F5E9))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeChip({
    required IconData icon,
    required String   label,
    required String   value,
    required Color    color,
    required Color    bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 3),
              Text(label,
                  style: TextStyle(
                      color:      color,
                      fontSize:   10,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color:      color,
                  fontSize:   12,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ── Idle State ─────────────────────────────────────────────────────────────
  Widget _buildIdleState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              color:        AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.fingerprint_rounded,
                size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('Set date range and tap Search',
              style: TextStyle(
                  color:      AppColors.textSecondary,
                  fontSize:   14.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Attendance records will appear here',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 12.5)),
        ]),
      ),
    );
  }

  // ── Skeleton ───────────────────────────────────────────────────────────────
  Widget _buildSkeletonList() {
    return Column(
      children: List.generate(5, (_) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _shimmer(width: 90, height: 22, radius: 6),
                  _shimmer(width: 80, height: 22, radius: 5),
                ],
              ),
              const SizedBox(height: 12),
              Row(children: [
                _shimmer(width: 36, height: 36, radius: 18),
                const SizedBox(width: 10),
                _shimmer(width: 140, height: 13, radius: 4),
              ]),
              const SizedBox(height: 12),
              _shimmer(width: double.infinity, height: 1, radius: 1),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _shimmer(
                    width: double.infinity, height: 48, radius: 8)),
                const SizedBox(width: 8),
                Expanded(child: _shimmer(
                    width: double.infinity, height: 48, radius: 8)),
                const SizedBox(width: 8),
                Expanded(child: _shimmer(
                    width: double.infinity, height: 48, radius: 8)),
              ]),
            ],
          ),
        ),
      )),
    );
  }

  Widget _shimmer({
    required double width,
    required double height,
    required double radius,
  }) => _ShimmerBox(width: width, height: height, radius: radius);

  // ── Empty ──────────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.search_off_rounded,
              size: 56, color: AppColors.border),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No attendance records found',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color:      AppColors.textSecondary,
                fontSize:   14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Try adjusting the date range',
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 12.5),
          ),
        ]),
      ),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded,
              size: 52, color: AppColors.border),
          const SizedBox(height: 14),
          Text(_errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13.5)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchReport,
            icon:  const Icon(Icons.refresh_rounded,
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
        ]),
      ),
    );
  }
}

// ── Shimmer Box ────────────────────────────────────────────────────────────
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