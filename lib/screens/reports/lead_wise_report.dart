import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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

// ── Enquiry Model ──────────────────────────────────────────────────────────
class _Enquiry {
  final String enquiryId;
  final String enquiryNumber;
  final String title;
  final String enquiry;
  final String customerName;
  final String phoneNumber;
  final String employeeName;
  final String addedDate;
  final String addedTime;
  final String status;

  const _Enquiry({
    required this.enquiryId,
    required this.enquiryNumber,
    required this.title,
    required this.enquiry,
    required this.customerName,
    required this.phoneNumber,
    required this.employeeName,
    required this.addedDate,
    required this.addedTime,
    required this.status,
  });

  factory _Enquiry.fromJson(Map<String, dynamic> j) => _Enquiry(
        enquiryId:     j['enquiry_id']     ?? '',
        enquiryNumber: j['enquiry_number'] ?? '',
        title:         j['title']          ?? '',
        enquiry:       j['enquiry']        ?? '',
        customerName:  j['customer_name']  ?? '',
        phoneNumber:   j['phone_number']   ?? '',
        employeeName:  j['employee_name']  ?? '',
        addedDate:     j['added_date']     ?? '',
        addedTime:     j['added_time']     ?? '',
        status:        j['status']         ?? '',
      );
}

// ── Lead Wise Report Page ──────────────────────────────────────────────────
class LeadWiseReportPage extends StatefulWidget {
  final String username;
  const LeadWiseReportPage({super.key, required this.username});

  @override
  State<LeadWiseReportPage> createState() => _LeadWiseReportPageState();
}

class _LeadWiseReportPageState extends State<LeadWiseReportPage> {
  static const int _pageSize = 50;

  // ── Filter state ───────────────────────────────────────────────────────────
  String   _selectedMode = 'all';
  DateTime _fromDate     = DateTime.now();
  DateTime _toDate       = DateTime.now();
  int?     _totalCount;

  // ── Data state ─────────────────────────────────────────────────────────────
  List<_Enquiry> _all        = [];
  List<_Enquiry> _filtered   = [];
  bool           _isLoading  = false;
  bool           _hasFetched = false;
  String?        _errorMessage;

  // ── Search / pagination ────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int    _currentPage = 1;

  // ── Export state ───────────────────────────────────────────────────────────
  bool _isExporting = false;

  static const List<Map<String, String>> _modeOptions = [
    {'label': 'All',      'value': 'all'},
    {'label': 'Rejected', 'value': 'rejected'},
    {'label': 'Deleted',  'value': 'deleted'},
  ];

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
      _filtered = _all.where((e) =>
          e.enquiryNumber.contains(_searchQuery) ||
          e.customerName.toLowerCase().contains(_searchQuery) ||
          e.phoneNumber.contains(_searchQuery) ||
          e.employeeName.toLowerCase().contains(_searchQuery) ||
          e.title.toLowerCase().contains(_searchQuery) ||
          e.status.toLowerCase().contains(_searchQuery) ||
          e.addedDate.contains(_searchQuery)).toList();
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
    final picked  = await showDatePicker(
      context:     context,
      initialDate: initial,
      firstDate:   DateTime(2020),
      lastDate:    DateTime(2030),
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
        '${ApiService.baseUrl}/api/leads/report.php'
        '?from_date=${_apiDate(_fromDate)}'
        '&to_date=${_apiDate(_toDate)}'
        '&mode=$_selectedMode',
      );

      debugPrint('─────────────────────────────────────────');
      debugPrint('📤  [LEAD WISE REPORT] Request');
      debugPrint('   🌐  URL : $url');
      debugPrint('─────────────────────────────────────────');

      final res  = await ApiService.get(url).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      debugPrint('─────────────────────────────────────────');
      debugPrint('📥  [LEAD WISE REPORT] Response');
      debugPrint('   🔢  Status : ${res.statusCode}');
      debugPrint('   📄  Body   : ${res.body}');
      debugPrint('─────────────────────────────────────────');

      if (res.statusCode == 200 && data['success'] == true) {
        final list = data['enquiries'] as List? ?? [];
        _all        = list.map((e) => _Enquiry.fromJson(e)).toList();
        _totalCount = data['total'] as int? ?? _all.length;
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
  List<_Enquiry> get _pageItems =>
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

  // ── Status styling ─────────────────────────────────────────────────────────
  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'active':   return AppColors.success;
      case 'rejected': return AppColors.error;
      case 'deleted':  return const Color(0xFF6B7280);
      case 'pending':  return const Color(0xFFD97706);
      default:         return AppColors.textMuted;
    }
  }

  Color _statusBg(String s) {
    switch (s.toLowerCase()) {
      case 'active':   return AppColors.successBg;
      case 'rejected': return const Color(0xFFFFF1F1);
      case 'deleted':  return const Color(0xFFF3F4F6);
      case 'pending':  return const Color(0xFFFEF3C7);
      default:         return const Color(0xFFF5F5F5);
    }
  }

Future<void> _printReport() async {
  if (_filtered.isEmpty) {
    AppSnackBar.show(context, 'No data to print.', isError: true);
    return;
  }

  try {
    final pdf = pw.Document();
    
    // Create table data
    final List<List<String>> tableData = [
      ['S.No', 'Date', 'Enq.No', 'Customer', 'Phone', 'Title', 'Assign', 'Status'], // Header
    ];
    
    // Add data rows - truncate long customer names if needed
    for (int i = 0; i < _filtered.length; i++) {
      final e = _filtered[i];
      String customerName = e.customerName.toUpperCase();
      String title = e.title.toUpperCase();
      String employeeName = e.employeeName.toUpperCase();
      
      // Truncate long customer names to prevent wrapping (optional)
      if (customerName.length > 30) {
        customerName = customerName.substring(0, 27) + '...';
      }
      if (title.length > 25) {
        title = title.substring(0, 22) + '...';
      }
      if (employeeName.length > 20) {
        employeeName = employeeName.substring(0, 17) + '...';
      }
      
      tableData.add([
        (i + 1).toString(),
        _fmtDate(e.addedDate),
        e.enquiryNumber,
        customerName,
        e.phoneNumber,
        title,
        employeeName,
        e.status.toUpperCase(),
      ]);
    }

    final modeLabel = _modeOptions
        .firstWhere((m) => m['value'] == _selectedMode,
            orElse: () => {'label': 'All'})['label']!;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            // Title
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'Leads Wise Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Coremicron CRM',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            // Date range and status
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
                        'Period: ${_displayDate(_fromDate)} to ${_displayDate(_toDate)}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Status: $modeLabel',
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
                        'Total Leads: ${_filtered.length}',
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

            // Table with improved column widths and text handling
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
                1: pw.Alignment.center,      // Date
                2: pw.Alignment.centerLeft,  // Enq.No
                3: pw.Alignment.centerLeft,  // Customer
                4: pw.Alignment.centerLeft,  // Phone
                5: pw.Alignment.centerLeft,  // Title
                6: pw.Alignment.centerLeft,  // Assign
                7: pw.Alignment.center,      // Status
              },
              columnWidths: {
                0: const pw.FixedColumnWidth(35),   // S.No
                1: const pw.FixedColumnWidth(65),   // Date
                2: const pw.FixedColumnWidth(75),   // Enq.No
                3: const pw.FlexColumnWidth(),      // Customer - flex to take available space
                4: const pw.FixedColumnWidth(85),   // Phone
                5: const pw.FlexColumnWidth(),      // Title - flex to take available space
                6: const pw.FixedColumnWidth(85),   // Assign
                7: const pw.FixedColumnWidth(65),   // Status
              },
              tableWidth: pw.TableWidth.max,
              cellPadding: const pw.EdgeInsets.all(5),
            ),

            // Footer line
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                '© ${DateTime.now().year} Coremicron CRM - Leads Wise Report',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ),
          ];
        },
      ),
    );

    // Print the document (this opens the native print dialog on mobile)
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
      final sheet = excel['Leads Wise Report'];

      // ── Header row ──────────────────────────────────────────────────
      final headers = [
        'S.NO', 'Date', 'Enquiry No', 'Customer',
        'Phone', 'Title', 'Assigned To', 'Status',
      ];

      final headerStyle = CellStyle(
        bold:            true,
        backgroundColorHex: ExcelColor.fromHexString('#1558E7'),
        fontColorHex:       ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Center,
      );

      for (int c = 0; c < headers.length; c++) {
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
        cell.value      = TextCellValue(headers[c]);
        cell.cellStyle  = headerStyle;
      }

      // Set column widths
      sheet.setColumnWidth(0, 6);   // S.NO
      sheet.setColumnWidth(1, 14);  // Date
      sheet.setColumnWidth(2, 12);  // Enquiry No
      sheet.setColumnWidth(3, 28);  // Customer
      sheet.setColumnWidth(4, 14);  // Phone
      sheet.setColumnWidth(5, 14);  // Title
      sheet.setColumnWidth(6, 18);  // Assigned To
      sheet.setColumnWidth(7, 12);  // Status

      // ── Data rows ───────────────────────────────────────────────────
      for (int i = 0; i < _filtered.length; i++) {
        final e   = _filtered[i];
        final row = i + 1;

        final rowData = [
          (i + 1).toString(),
          _fmtDate(e.addedDate),
          e.enquiryNumber,
          e.customerName.toUpperCase(),
          e.phoneNumber,
          e.title.toUpperCase(),
          e.employeeName.toUpperCase(),
          e.status.toUpperCase(),
        ];

        final evenBg = ExcelColor.fromHexString('#F0F4FF');
        final oddBg  = ExcelColor.fromHexString('#FFFFFF');

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

      // ── Save file ────────────────────────────────────────────────────
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to encode Excel file.');

      final dir      = await getApplicationDocumentsDirectory();
      final now      = DateTime.now();
      final fileName = 'leads_wise_report_'
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

                  // ── Header text ───────────────────────────────────────
                  const Text(
                    'Leads Wise Report',
                    style: TextStyle(
                      color:         AppColors.textPrimary,
                      fontSize:      17,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Filter and analyze lead records by date & status',
                    style: TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Filter card ───────────────────────────────────────
                  _buildFilterCard(isTablet),

                  const SizedBox(height: 14),

                  // ── Search bar ────────────────────────────────────────
                  if (_hasFetched && !_isLoading && _errorMessage == null)
                    _buildSearchBar(),

                  if (_hasFetched && !_isLoading && _errorMessage == null)
                    const SizedBox(height: 10),

                  // ── Result count ──────────────────────────────────────
                  if (_hasFetched && !_isLoading && _errorMessage == null)
                    Row(
                      children: [
                        Text(
                          '${_filtered.length} lead${_filtered.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                              color:      AppColors.textSecondary,
                              fontSize:   12.5,
                              fontWeight: FontWeight.w500),
                        ),
                        if (_totalCount != null && _searchQuery.isEmpty) ...[
                          const Text('  ·  ',
                              style: TextStyle(color: AppColors.textMuted)),
                          Text('Total: $_totalCount',
                              style: const TextStyle(
                                  color:    AppColors.textMuted,
                                  fontSize: 12)),
                        ],
                      ],
                    ),

                  if (_hasFetched && !_isLoading && _errorMessage == null)
                    const SizedBox(height: 10),

                  // ── Content ───────────────────────────────────────────
                  if (!_hasFetched)
                    _buildIdleState()
                  else if (_isLoading)
                    _buildSkeletonList()
                  else if (_errorMessage != null)
                    _buildError()
                  else if (_filtered.isEmpty)
                    _buildEmpty()
                  else
                    ..._pageItems.map((e) => _enquiryCard(e)).expand(
                          (w) => [w, const SizedBox(height: 8)]),

                  const SizedBox(height: 80),
                ],
              ),
            ),

            // ── Pagination ────────────────────────────────────────────
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
              Text('Leads Wise',
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

  // ── Filter card ────────────────────────────────────────────────────────────
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

          // ── Print + Export buttons ─────────────────────────────────────
          Row(
            children: [
              // Print
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_filtered.isEmpty || _isLoading)
                      ? null
                      : _printReport,
                  icon: const Icon(Icons.print_outlined,
                      size: 15, color: AppColors.primary),
                  label: const Text('Print',
                      style: TextStyle(
                          color:      AppColors.primary,
                          fontSize:   13,
                          fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: AppColors.primary, width: 1.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    backgroundColor: AppColors.primaryLight,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Export Excel
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_filtered.isEmpty || _isLoading || _isExporting)
                      ? null
                      : _exportExcel,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                              color: Color(0xFF1D6F42), strokeWidth: 2))
                      : const Icon(Icons.table_chart_outlined,
                          size: 15, color: Color(0xFF1D6F42)),
                  label: Text(
                    _isExporting ? 'Exporting…' : 'Export Excel',
                    style: const TextStyle(
                        color:      Color(0xFF1D6F42),
                        fontSize:   13,
                        fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: Color(0xFF1D6F42), width: 1.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    backgroundColor: const Color(0xFFEBF5EC),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 12),

          // ── Status + From + To ────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Status — fixed width so label never wraps
              SizedBox(
                width: 100,
                child: _filterLabel(
                  label: 'Status',
                  child: _statusDropdown(),
                ),
              ),
              const SizedBox(width: 8),
              // From
              Expanded(
                child: _filterLabel(
                  label: 'From',
                  child: _datePicker(isFrom: true),
                ),
              ),
              const SizedBox(width: 8),
              // To
              Expanded(
                child: _filterLabel(
                  label: 'To',
                  child: _datePicker(isFrom: false),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Search button ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _fetchReport,
              icon: _isLoading
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.search_rounded,
                      size: 16, color: Colors.white),
              label: Text(
                _isLoading ? 'Searching…' : 'Search',
                style: const TextStyle(
                    color:      Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize:   14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor:
                    AppColors.primary.withOpacity(0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11)),
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

  // ── Status dropdown — fixed width + overflow ellipsis ──────────────────────
  Widget _statusDropdown() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color:        AppColors.background,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value:      _selectedMode,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: AppColors.textLabel),
          style: const TextStyle(
              color:      AppColors.textPrimary,
              fontSize:   12.5,
              fontWeight: FontWeight.w500),
          onChanged: (v) {
            if (v != null) setState(() => _selectedMode = v);
          },
          selectedItemBuilder: (ctx) => _modeOptions.map((opt) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                opt['label']!,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                    color:      AppColors.textPrimary,
                    fontSize:   12.5,
                    fontWeight: FontWeight.w500),
              ),
            );
          }).toList(),
          items: _modeOptions.map((opt) => DropdownMenuItem(
            value: opt['value'],
            child: Text(opt['label']!,
                style: const TextStyle(fontSize: 13)),
          )).toList(),
        ),
      ),
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
                    fontSize:   12,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.calendar_today_rounded,
                size: 13, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────
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
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: const InputDecoration(
          hintText:  'Search by name, phone, employee, status…',
          hintStyle: TextStyle(color: AppColors.textHint, fontSize: 12.5),
          prefixIcon: Icon(Icons.search_rounded,
              color: AppColors.iconDefault, size: 19),
          border:         InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
              horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  // ── Enquiry card ───────────────────────────────────────────────────────────
  Widget _enquiryCard(_Enquiry e) {
    final stClr = _statusColor(e.status);
    final stBg  = _statusBg(e.status);

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
          // ── Top row: enquiry# + date + status ─────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('#${e.enquiryNumber}',
                    style: const TextStyle(
                        color:      AppColors.primary,
                        fontSize:   11,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.calendar_today_rounded,
                  size: 11, color: AppColors.textMuted),
              const SizedBox(width: 3),
              Text(_fmtDate(e.addedDate),
                  style: const TextStyle(
                      color:    AppColors.textMuted,
                      fontSize: 11)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        stBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: stClr.withOpacity(0.3), width: 1),
                ),
                child: Text(
                  e.status.capitalize(),
                  style: TextStyle(
                      color:      stClr,
                      fontSize:   10.5,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Customer name + phone ──────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36, height: 36,
                decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    e.customerName.isNotEmpty
                        ? e.customerName[0].toUpperCase()
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.customerName.capitalize(),
                      style: const TextStyle(
                          color:      AppColors.textPrimary,
                          fontSize:   13.5,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined,
                            size: 11,
                            color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Text(e.phoneNumber,
                            style: const TextStyle(
                                color:    AppColors.textSecondary,
                                fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 9),

          // ── Bottom info: title (no icon) + employee ────────────────
          Wrap(
            spacing:    14,
            runSpacing: 6,
            children: [
              // Title — no icon, just label text
              Text(
                e.title.capitalize(),
                style: const TextStyle(
                    color:      AppColors.textSecondary,
                    fontSize:   12,
                    fontWeight: FontWeight.w500),
              ),
              // Assigned employee
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(e.employeeName.capitalize(),
                      style: const TextStyle(
                          color:      AppColors.textSecondary,
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

  // ── Idle state ─────────────────────────────────────────────────────────────
  Widget _buildIdleState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                color:        AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.bar_chart_rounded,
                  size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text('Set filters and tap Search',
                style: TextStyle(
                    color:      AppColors.textSecondary,
                    fontSize:   14.5,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('Results will appear here',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 12.5)),
          ],
        ),
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
              _shimmer(width: 52, height: 20, radius: 6),
              _shimmer(width: 70, height: 20, radius: 10),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _shimmer(width: 36, height: 36, radius: 18),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmer(width: 140, height: 13, radius: 4),
                  const SizedBox(height: 6),
                  _shimmer(width: 90, height: 11, radius: 4),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _shimmer(width: double.infinity, height: 1, radius: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              _shimmer(width: 90, height: 12, radius: 4),
              const SizedBox(width: 14),
              _shimmer(width: 80, height: 12, radius: 4),
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

  // ── Empty ──────────────────────────────────────────────────────────────────
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
                  : 'No leads found for the selected filters',
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
                  : 'Try adjusting the date range or status',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────
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
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13.5),
            ),
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
          ],
        ),
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