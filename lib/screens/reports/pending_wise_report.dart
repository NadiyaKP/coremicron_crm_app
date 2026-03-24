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

// ── Pending Job Model ──────────────────────────────────────────────────────
class _PendingJob {
  final String id;
  final String employeeName;
  final String employeeId;
  final String ticketNumber;
  final String toDo;
  final String fixbyDate;
  final String status;

  const _PendingJob({
    required this.id,
    required this.employeeName,
    required this.employeeId,
    required this.ticketNumber,
    required this.toDo,
    required this.fixbyDate,
    required this.status,
  });

  factory _PendingJob.fromJson(Map<String, dynamic> j) => _PendingJob(
        id: j['id'] ?? '',
        employeeName: j['employee_name'] ?? '',
        employeeId: j['employee_id'] ?? '',
        ticketNumber: j['ticket_number'] ?? '',
        toDo: j['to_do'] ?? '',
        fixbyDate: j['fixby_date'] ?? '',
        status: j['status'] ?? '',
      );
}

// ── Pending Wise Report Page ──────────────────────────────────────────────
class PendingWiseReportPage extends StatefulWidget {
  final String username;
  const PendingWiseReportPage({super.key, required this.username});

  @override
  State<PendingWiseReportPage> createState() => _PendingWiseReportPageState();
}

class _PendingWiseReportPageState extends State<PendingWiseReportPage> {
  static const int _pageSize = 20;

  // ── Data state ─────────────────────────────────────────────────────────────
  List<_PendingJob> _all = [];
  List<_PendingJob> _filtered = [];
  bool _isLoading = false;
  bool _hasFetched = false;
  String? _errorMessage;
  int? _totalRecords;
  int? _totalPages;
  int _currentPage = 1;
  int _currentApiPage = 1;

  // ── Search state ───────────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // ── Export state ───────────────────────────────────────────────────────────
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
    _fetchPendingJobs();
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
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filtered = List.from(_all);
    } else {
      _filtered = _all.where((job) =>
          job.ticketNumber.contains(_searchQuery) ||
          job.toDo.toLowerCase().contains(_searchQuery) ||
          job.employeeName.toLowerCase().contains(_searchQuery) ||
          job.status.toLowerCase().contains(_searchQuery) ||
          job.fixbyDate.contains(_searchQuery)).toList();
    }
  }

  // ── Date helper ───────────────────────────────────────────────────────────
  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return '—';
    try {
      final p = raw.trim().split('-');
      if (p.length == 3) return '${p[2]}/${p[1]}/${p[0]}';
    } catch (_) {}
    return raw;
  }

  // ── Fetch Pending Jobs ────────────────────────────────────────────────────
  Future<void> _fetchPendingJobs({int page = 1}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasFetched = true;
    });

    try {
      final url = Uri.parse(
        '${ApiService.baseUrl}/api/ticket/job_report.php?page=$page&limit=$_pageSize',
      );

      debugPrint('─────────────────────────────────────────');
      debugPrint('📤  [PENDING JOBS REPORT] Request');
      debugPrint('   🌐  URL : $url');
      debugPrint('─────────────────────────────────────────');

      final res = await ApiService.get(url).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      debugPrint('─────────────────────────────────────────');
      debugPrint('📥  [PENDING JOBS REPORT] Response');
      debugPrint('   🔢  Status : ${res.statusCode}');
      debugPrint('   📄  Body   : ${res.body}');
      debugPrint('─────────────────────────────────────────');

      if (res.statusCode == 200 && data['success'] == true) {
        final list = data['data'] as List? ?? [];
        _all = list.map((e) => _PendingJob.fromJson(e)).toList();
        _totalRecords = data['total_records'] as int?;
        _totalPages = data['total_pages'] as int?;
        _currentApiPage = page;
        _applyFilter();
      } else {
        _errorMessage = data['error'] ?? data['message'] ?? 'Failed to load pending jobs.';
      }
    } on http.ClientException {
      _errorMessage = 'Unable to reach the server. Check your connection.';
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ── Pagination ─────────────────────────────────────────────────────────────
  int get _totalFilteredPages => (_filtered.length / _pageSize).ceil();
  List<_PendingJob> get _pageItems {
    final start = (_currentPage - 1) * _pageSize;
    final end = start + _pageSize;
    if (start >= _filtered.length) return [];
    return _filtered.sublist(start, end > _filtered.length ? _filtered.length : end);
  }

  void _goBackToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomePage(username: widget.username, openDrawerOnLoad: true),
      ),
      (route) => false,
    );
  }

  void _refreshData() {
    _fetchPendingJobs(page: _currentApiPage);
  }

  // ── Print Report ───────────────────────────────────────────────────────────
  Future<void> _printReport() async {
    if (_filtered.isEmpty) {
      AppSnackBar.show(context, 'No data to print.', isError: true);
      return;
    }

    try {
      final pdf = pw.Document();

      // Create table data
      final List<List<String>> tableData = [
        ['S.No', 'Ticket No', 'Employee', 'Fixby Date', 'Status', 'To Do'],
      ];

      // Add data rows
      for (int i = 0; i < _filtered.length; i++) {
        final job = _filtered[i];
        String toDo = job.toDo;
        String employeeName = job.employeeName.capitalize();

        // Truncate long text to prevent wrapping
        if (toDo.length > 60) {
          toDo = toDo.substring(0, 57) + '...';
        }
        if (employeeName.length > 25) {
          employeeName = employeeName.substring(0, 22) + '...';
        }

        tableData.add([
          (i + 1).toString(),
          job.ticketNumber,
          employeeName,
          _fmtDate(job.fixbyDate),
          job.status.toUpperCase(),
          toDo,
        ]);
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              // Title
              pw.Center(
                child: pw.Text(
                  'Pending Jobs Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 16),

              // Info container
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
                        pw.Text(
                          'Report Type: Pending Jobs',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Status: Active / Pending',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Generated: ${DateTime.now().toString().substring(0, 19)}',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Total Jobs: ${_filtered.length}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // Table
              pw.Table.fromTextArray(
                context: context,
                data: tableData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  0: pw.Alignment.center,      // S.No
                  1: pw.Alignment.centerLeft,  // Ticket No
                  2: pw.Alignment.centerLeft,  // Employee
                  3: pw.Alignment.center,      // Fixby Date
                  4: pw.Alignment.center,      // Status
                  5: pw.Alignment.centerLeft,  // To Do
                },
                columnWidths: {
                  0: const pw.FixedColumnWidth(35),   // S.No
                  1: const pw.FixedColumnWidth(70),   // Ticket No
                  2: const pw.FixedColumnWidth(100),  // Employee
                  3: const pw.FixedColumnWidth(70),   // Fixby Date
                  4: const pw.FixedColumnWidth(65),   // Status
                  5: const pw.FlexColumnWidth(),      // To Do - flex
                },
                tableWidth: pw.TableWidth.max,
                cellPadding: const pw.EdgeInsets.all(5),
              ),

              // Footer
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
      final sheet = excel['Pending Jobs Report'];

      // Header row
      final headers = [
        'S.NO', 'Ticket No', 'Employee', 'Fixby Date', 'Status', 'To Do',
      ];

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
      sheet.setColumnWidth(0, 6);   // S.NO
      sheet.setColumnWidth(1, 12);  // Ticket No
      sheet.setColumnWidth(2, 20);  // Employee
      sheet.setColumnWidth(3, 14);  // Fixby Date
      sheet.setColumnWidth(4, 12);  // Status
      sheet.setColumnWidth(5, 50);  // To Do

      // Data rows
      for (int i = 0; i < _filtered.length; i++) {
        final job = _filtered[i];
        final row = i + 1;

        final rowData = [
          (i + 1).toString(),
          job.ticketNumber,
          job.employeeName.capitalize(),
          _fmtDate(job.fixbyDate),
          job.status.toUpperCase(),
          job.toDo,
        ];

        final evenBg = ExcelColor.fromHexString('#F0F4FF');
        final oddBg = ExcelColor.fromHexString('#FFFFFF');

        for (int c = 0; c < rowData.length; c++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
          cell.value = TextCellValue(rowData[c]);
          cell.cellStyle = CellStyle(
            backgroundColorHex: i.isEven ? evenBg : oddBg,
            horizontalAlign: c == 0 || c == 3 || c == 4
                ? HorizontalAlign.Center
                : HorizontalAlign.Left,
          );
        }
      }

      // Save file
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to encode Excel file.');

      final dir = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final fileName = 'pending_jobs_report_'
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

                  // Header
                  const Text(
                    'Pending Jobs Report',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'View and manage all pending jobs and tasks',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action buttons card
                  _buildActionCard(),

                  const SizedBox(height: 14),

                  // Search bar
                  if (_hasFetched && !_isLoading && _errorMessage == null)
                    _buildSearchBar(),

                  if (_hasFetched && !_isLoading && _errorMessage == null)
                    const SizedBox(height: 10),

                  // Result count
                  if (_hasFetched && !_isLoading && _errorMessage == null)
                    Row(
                      children: [
                        Text(
                          '${_filtered.length} job${_filtered.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_totalRecords != null && _searchQuery.isEmpty) ...[
                          const Text('  ·  ',
                              style: TextStyle(color: AppColors.textMuted)),
                          Text('Total: $_totalRecords',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ],
                    ),

                  if (_hasFetched && !_isLoading && _errorMessage == null)
                    const SizedBox(height: 10),

                  // Content
                  if (_isLoading && !_hasFetched)
                    _buildSkeletonList()
                  else if (_errorMessage != null)
                    _buildError()
                  else if (_filtered.isEmpty)
                    _buildEmpty()
                  else
                    ..._pageItems.map((job) => _jobCard(job)).expand(
                          (w) => [w, const SizedBox(height: 8)]),

                  const SizedBox(height: 80),
                ],
              ),
            ),

            // Pagination
            if (_hasFetched && !_isLoading &&
                _errorMessage == null && _filtered.isNotEmpty)
              AppPagination(
                currentPage: _currentPage,
                totalPages: _totalFilteredPages,
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
              Text('Pending Jobs',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: isTablet ? 20 : 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3)),
              const Text('Report',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 11.5)),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _refreshData,
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

  // ── Action Card (Print + Export) ──────────────────────────────────────────
  Widget _buildActionCard() {
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Print
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
          // Export Excel
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
    );
  }

  // ── Search Bar ─────────────────────────────────────────────────────────────
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
        decoration: const InputDecoration(
          hintText: 'Search by ticket no, employee, to-do, status...',
          hintStyle: TextStyle(color: AppColors.textHint, fontSize: 12.5),
          prefixIcon: Icon(Icons.search_rounded,
              color: AppColors.iconDefault, size: 19),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  // ── Job Card ───────────────────────────────────────────────────────────────
  Widget _jobCard(_PendingJob job) {
    // Status color mapping
    Color statusColor;
    String statusText = job.status.toUpperCase();
    
    switch (job.status.toLowerCase()) {
      case 'active':
        statusColor = const Color(0xFF1D6F42);
        statusText = 'ACTIVE';
        break;
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'completed':
        statusColor = const Color(0xFF1D6F42);
        break;
      case 'overdue':
        statusColor = Colors.red;
        break;
      default:
        statusColor = AppColors.textSecondary;
    }

    // Check if fixby date is overdue
    bool isOverdue = false;
    if (job.fixbyDate.isNotEmpty && job.fixbyDate != 'null') {
      try {
        final fixby = DateTime.parse(job.fixbyDate);
        final today = DateTime.now();
        if (fixby.isBefore(today) && job.status.toLowerCase() != 'completed') {
          isOverdue = true;
        }
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue ? Colors.red.withOpacity(0.3) : AppColors.borderLight,
          width: isOverdue ? 1.5 : 1,
        ),
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
          // Top row: ticket# + status + employee
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Ticket #${job.ticketNumber}',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              Row(
                children: [
                  // Employee badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_outline_rounded,
                            size: 10, color: AppColors.textSecondary),
                        const SizedBox(width: 2),
                        Text(
                          job.employeeName.capitalize(),
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // To Do description
          Text(
            job.toDo,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 9),

          // Bottom info: fixby date
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 11, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                'Fixby Date: ${_fmtDate(job.fixbyDate)}',
                style: TextStyle(
                  color: isOverdue ? Colors.red : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (isOverdue) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'OVERDUE',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Skeleton ───────────────────────────────────────────────────────────────
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
              _shimmer(width: 80, height: 20, radius: 4),
            ],
          ),
          const SizedBox(height: 12),
          _shimmer(width: double.infinity, height: 40, radius: 4),
          const SizedBox(height: 12),
          _shimmer(width: double.infinity, height: 1, radius: 1),
          const SizedBox(height: 10),
          _shimmer(width: 100, height: 12, radius: 4),
        ],
      ),
    );
  }

  Widget _shimmer({
    required double width,
    required double height,
    required double radius,
  }) => _ShimmerBox(width: width, height: height, radius: radius);

  // ── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_late_outlined,
                size: 56, color: AppColors.border),
            const SizedBox(height: 14),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results for "$_searchQuery"'
                  : 'No pending jobs found',
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
                  : 'All jobs are completed or no pending tasks',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error State ───────────────────────────────────────────────────────────
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
              onPressed: _refreshData,
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

// ── Shimmer Box ────────────────────────────────────────────────────────────
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