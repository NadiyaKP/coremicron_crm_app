import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/common/string_extensions.dart';

// ── Employee Model ─────────────────────────────────────────────────────────
class _Employee {
  final String id;
  final String name;
  final String phone;
  final String code;

  const _Employee({
    required this.id,
    required this.name,
    required this.phone,
    required this.code,
  });

  factory _Employee.fromJson(Map<String, dynamic> j) => _Employee(
        id:    j['id']            ?? '',
        name:  j['employee_name'] ?? '',
        phone: j['phone_number']  ?? '',
        code:  j['employee_code'] ?? '',
      );
}

// ── Assigned Employee ──────────────────────────────────────────────────────
class _AssignedEmployee {
  final _Employee employee;
  int count;
  _AssignedEmployee({required this.employee, this.count = 1});
}

// ── Bulk Add Page ──────────────────────────────────────────────────────────
class BulkAddPage extends StatefulWidget {
  final String username;
  const BulkAddPage({super.key, required this.username});

  @override
  State<BulkAddPage> createState() => _BulkAddPageState();
}

class _BulkAddPageState extends State<BulkAddPage> {
  // ── File state ─────────────────────────────────────────────────────────────
  String?              _fileName;
  Uint8List?           _fileBytes;
  List<String>         _excelColumns   = [];
  List<List<String>>   _excelRows      = [];   // all data rows (excl header)

  // ── Distribution state ─────────────────────────────────────────────────────
  bool                          _autoCreateCustomers = true;
  final List<_AssignedEmployee> _assigned            = [];

  // ── Column mapping state ───────────────────────────────────────────────────
  String? _colPhone;
  String? _colTitle;
  String? _colCustomer;
  String? _colLead;

  // ── UI state ───────────────────────────────────────────────────────────────
  bool _isImporting = false;

  // ── File picker ────────────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type:            FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData:        true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;

      final bytes  = file.bytes!;
      final name   = file.name;

      _parseExcel(bytes, name);
    } catch (e) {
      if (mounted)
        AppSnackBar.show(context, 'Error picking file: $e', isError: true);
    }
  }

  void _parseExcel(Uint8List bytes, String name) {
    try {
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables.values.first;
      if (sheet.rows.isEmpty) {
        AppSnackBar.show(context, 'The file appears to be empty.',
            isError: true);
        return;
      }

      // First row = headers
      final headers = sheet.rows.first
          .map((c) => c?.value?.toString().trim() ?? '')
          .where((h) => h.isNotEmpty)
          .toList();

      // Remaining rows = data
      final rows = sheet.rows
          .skip(1)
          .map((row) => row
              .map((c) => c?.value?.toString().trim() ?? '')
              .toList())
          .where((r) => r.any((v) => v.isNotEmpty))
          .toList();

      setState(() {
        _fileName      = name;
        _fileBytes     = bytes;
        _excelColumns  = headers;
        _excelRows     = rows;
        // Reset column mapping
        _colPhone    = null;
        _colTitle    = null;
        _colCustomer = null;
        _colLead     = null;
      });
    } catch (e) {
      AppSnackBar.show(context,
          'Failed to parse file. Ensure it is a valid Excel file.',
          isError: true);
    }
  }

  // ── Employee list ──────────────────────────────────────────────────────────
  Future<List<_Employee>> _fetchEmployees() async {
    final url = Uri.parse(
        '${ApiService.baseUrl}/api/employee/list.php?view=dropdown');
    final res = await ApiService.get(url)
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200 && data['success'] == true) {
      final list = data['data'] as List? ?? [];
      return list.map((e) => _Employee.fromJson(e)).toList();
    }
    throw Exception(
        data['error'] ?? data['message'] ?? 'Failed to fetch employees.');
  }

  void _showEmployeePicker() {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (bCtx) => _EmployeePickerSheet(
        fetchEmployees: _fetchEmployees,
        onSelected: (emp) {
          final matches = _assigned
              .where((a) => a.employee.id == emp.id)
              .toList();
          if (matches.isNotEmpty) {
            AppSnackBar.show(context,
                '${emp.name.capitalize()} is already assigned.');
          } else {
            setState(() => _assigned.add(
                _AssignedEmployee(employee: emp)));
          }
        },
      ),
    );
  }

  // ── Import ─────────────────────────────────────────────────────────────────
  Future<void> _import() async {
    if (_fileBytes == null) {
      AppSnackBar.show(context, 'Please upload an Excel file first.',
          isError: true);
      return;
    }
    if (_colPhone == null) {
      AppSnackBar.show(context, 'Please map the Phone Number column.',
          isError: true);
      return;
    }
    if (_colTitle == null) {
      AppSnackBar.show(context, 'Please map the Title column.',
          isError: true);
      return;
    }

    final int phoneIdx    = _excelColumns.indexOf(_colPhone!);
    final int titleIdx    = _excelColumns.indexOf(_colTitle!);
    final int customerIdx =
        _colCustomer != null ? _excelColumns.indexOf(_colCustomer!) : -1;
    final int leadIdx =
        _colLead != null ? _excelColumns.indexOf(_colLead!) : -1;

    final List<Map<String, String>> leads = _excelRows.map((row) {
      return <String, String>{
        'phone_number':  phoneIdx    >= 0 && phoneIdx    < row.length ? row[phoneIdx]    : '',
        'title':         titleIdx    >= 0 && titleIdx    < row.length ? row[titleIdx]    : '',
        'customer_name': customerIdx >= 0 && customerIdx < row.length ? row[customerIdx] : '',
        'lead':          leadIdx     >= 0 && leadIdx     < row.length ? row[leadIdx]     : '',
      };
    }).toList();

    final Map<String, int> distribution = {
      for (final a in _assigned) a.employee.id: a.count,
    };

    final body = {
      'leads':              leads,
      'distribution':       distribution,
      'auto_add_customers': _autoCreateCustomers,
    };

    setState(() => _isImporting = true);
    try {
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/leads/bulk_add.php');

      debugPrint('📤  [BULK ADD] $url  ${jsonEncode(body)}');
      final res = await ApiService.post(url, body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [BULK ADD] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Leads imported successfully.');
        Navigator.pop(context, true);
      } else {
        AppSnackBar.show(
            context,
            data['error'] ?? data['message'] ?? 'Import failed.',
            isError: true);
      }
    } on http.ClientException {
      if (mounted)
        AppSnackBar.show(context, 'Unable to reach the server.', isError: true);
    } catch (e) {
      if (mounted) AppSnackBar.show(context, 'Error: $e', isError: true);
    }
    if (mounted) setState(() => _isImporting = false);
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
            // ── App Bar ───────────────────────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 13),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                    bottom: BorderSide(color: AppColors.borderLight, width: 1)),
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
                  Text('Bulk Add Leads via Excel',
                      style: TextStyle(
                          color:         AppColors.textPrimary,
                          fontSize:      isTablet ? 19 : 16,
                          fontWeight:    FontWeight.w800,
                          letterSpacing: -0.3)),
                ],
              ),
            ),

            // ── Scrollable body ───────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ──────────────────────────────────────────────────
                    // STEP 1: Upload
                    // ──────────────────────────────────────────────────
                    _stepHeader(
                        icon:  Icons.upload_file_rounded,
                        label: 'STEP 1: UPLOAD EXCEL FILE'),
                    const SizedBox(height: 10),
                    _buildUploadZone(),

                    // Excel preview
                    if (_excelRows.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _buildExcelPreview(),
                    ],

                    const SizedBox(height: 24),

                    // ──────────────────────────────────────────────────
                    // STEP 2: Lead Distribution
                    // ──────────────────────────────────────────────────
                    _stepHeader(
                        icon:  Icons.people_outline_rounded,
                        label: 'STEP 2: LEAD DISTRIBUTION'),
                    const SizedBox(height: 12),

                    // Auto-create checkbox
                    GestureDetector(
                      onTap: () => setState(
                          () => _autoCreateCustomers = !_autoCreateCustomers),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20, height: 20,
                            child: Checkbox(
                              value:          _autoCreateCustomers,
                              onChanged: (v) => setState(
                                  () => _autoCreateCustomers = v ?? true),
                              activeColor:  AppColors.primary,
                              side: const BorderSide(
                                  color: AppColors.border, width: 1.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text('Auto-create customers if not exists',
                              style: TextStyle(
                                  color:    AppColors.textPrimary,
                                  fontSize: 13.5)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Assign Employees box
                    _buildAssignBox(),

                    const SizedBox(height: 24),

                    // ──────────────────────────────────────────────────
                    // STEP 3: Map Columns
                    // ──────────────────────────────────────────────────
                    _stepHeader(
                        icon:  Icons.table_chart_outlined,
                        label: 'STEP 3: MAP EXCEL COLUMNS'),
                    const SizedBox(height: 12),
                    _buildColumnMapping(),

                    const SizedBox(height: 32),

                    // ── Action buttons ────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isImporting
                                ? null
                                : () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded,
                                size: 16,
                                color: AppColors.textLabel),
                            label: const Text('Cancel',
                                style: TextStyle(
                                    color:      AppColors.textLabel,
                                    fontWeight: FontWeight.w600,
                                    fontSize:   14)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppColors.border, width: 1.3),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11)),
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isImporting ? null : _import,
                            icon: _isImporting
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                        color:       Colors.white,
                                        strokeWidth: 2.2))
                                : const Icon(Icons.upload_rounded,
                                    size: 16, color: Colors.white),
                            label: const Text('Process & Import',
                                style: TextStyle(
                                    color:      Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize:   14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              disabledBackgroundColor:
                                  AppColors.primary.withOpacity(0.5),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step Header ────────────────────────────────────────────────────────────
  Widget _stepHeader({required IconData icon, required String label}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color:         AppColors.primary,
                fontSize:      11.5,
                fontWeight:    FontWeight.w700,
                letterSpacing: 0.5)),
      ],
    );
  }

  // ── Upload Zone ────────────────────────────────────────────────────────────
  Widget _buildUploadZone() {
    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color:        const Color(0xFFEFF4FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.45),
            width: 1.5,
          ),
        ),
        child: _fileBytes == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color:        AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text('X',
                          style: TextStyle(
                              color:      Colors.white,
                              fontSize:   22,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Click to Upload Excel File',
                      style: TextStyle(
                          color:      AppColors.textPrimary,
                          fontSize:   15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('Supports .xlsx, .xls, .csv files',
                      style: TextStyle(
                          color:    AppColors.textMuted,
                          fontSize: 12.5)),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF2E7D32), size: 36),
                  const SizedBox(height: 8),
                  Text(_fileName ?? '',
                      style: const TextStyle(
                          color:      AppColors.textPrimary,
                          fontSize:   14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('${_excelRows.length} rows · ${_excelColumns.length} columns',
                      style: const TextStyle(
                          color:    AppColors.textMuted,
                          fontSize: 12)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickFile,
                    child: const Text('Change file',
                        style: TextStyle(
                            color:      AppColors.primary,
                            fontSize:   12.5,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline)),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Excel Preview ──────────────────────────────────────────────────────────
  Widget _buildExcelPreview() {
    final previewRows = _excelRows.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Preview (first ${previewRows.length} rows)',
            style: const TextStyle(
                color:      AppColors.textMuted,
                fontSize:   11.5,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderLight, width: 1),
          ),
          clipBehavior: Clip.hardEdge,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(
                  AppColors.primaryLight),
              headingTextStyle: const TextStyle(
                  color:      AppColors.primary,
                  fontSize:   11.5,
                  fontWeight: FontWeight.w700),
              dataTextStyle: const TextStyle(
                  color:    AppColors.textSecondary,
                  fontSize: 12),
              columnSpacing: 20,
              horizontalMargin: 14,
              headingRowHeight: 36,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 40,
              columns: _excelColumns
                  .map((h) => DataColumn(label: Text(h)))
                  .toList(),
              rows: previewRows.map((row) {
                return DataRow(
                  cells: List.generate(
                    _excelColumns.length,
                    (i) => DataCell(Text(
                        i < row.length ? row[i] : '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ── Assign Box ─────────────────────────────────────────────────────────────
  Widget _buildAssignBox() {
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                const Icon(Icons.groups_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Assign Employees to Leads',
                      style: TextStyle(
                          color:      AppColors.textPrimary,
                          fontSize:   13.5,
                          fontWeight: FontWeight.w700)),
                ),
                ElevatedButton.icon(
                  onPressed: _showEmployeePicker,
                  icon: const Icon(Icons.add_rounded,
                      size: 13, color: Colors.white),
                  label: const Text('Assign',
                      style: TextStyle(
                          color:      Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize:   11.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7)),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.borderLight),

          // Content
          if (_assigned.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.person_off_outlined,
                      size: 40,
                      color: AppColors.textMuted.withOpacity(0.5)),
                  const SizedBox(height: 10),
                  const Text(
                      "No Employee Assigned Yet. Click 'Assign' to start.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color:    AppColors.textMuted,
                          fontSize: 12.5)),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: _assigned.map((a) => _assignedTile(a)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _assignedTile(_AssignedEmployee a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color:        AppColors.background,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color:        AppColors.primaryLight,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: Text(
                a.employee.name.isNotEmpty
                    ? a.employee.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color:      AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize:   15),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Name + count
          Expanded(
            child: Text(
              a.employee.name.capitalize(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color:      AppColors.textPrimary,
                  fontSize:   13,
                  fontWeight: FontWeight.w600),
            ),
          ),
          // Count controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _countBtn(
                icon:  Icons.remove_rounded,
                onTap: () {
                  setState(() {
                    if (a.count > 1) {
                      a.count--;
                    }
                  });
                },
              ),
              Container(
                width: 34,
                alignment: Alignment.center,
                child: Text('${a.count}',
                    style: const TextStyle(
                        color:      AppColors.textPrimary,
                        fontSize:   14,
                        fontWeight: FontWeight.w700)),
              ),
              _countBtn(
                icon:  Icons.add_rounded,
                onTap: () => setState(() => a.count++),
              ),
            ],
          ),
          const SizedBox(width: 6),
          // Delete
          GestureDetector(
            onTap: () => setState(() => _assigned.remove(a)),
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                  color:        const Color(0xFFFFF1F1),
                  borderRadius: BorderRadius.circular(7)),
              child: const Icon(Icons.delete_outline_rounded,
                  size: 15, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countBtn({
    required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color:        AppColors.primaryLight,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }

  // ── Column Mapping ─────────────────────────────────────────────────────────
  Widget _buildColumnMapping() {
    final cols = ['', ..._excelColumns]; // empty = "-- Select Column --"

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _colDropdown(
                icon:      Icons.phone_outlined,
                label:     'PHONE NUMBER *',
                value:     _colPhone,
                columns:   cols,
                onChanged: (v) =>
                    setState(() => _colPhone = v?.isEmpty == true ? null : v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _colDropdown(
                icon:      Icons.label_outline_rounded,
                label:     'TITLE *',
                value:     _colTitle,
                columns:   cols,
                onChanged: (v) =>
                    setState(() => _colTitle = v?.isEmpty == true ? null : v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _colDropdown(
                icon:      Icons.person_outline_rounded,
                label:     'CUSTOMER NAME',
                value:     _colCustomer,
                columns:   cols,
                onChanged: (v) =>
                    setState(() =>
                        _colCustomer = v?.isEmpty == true ? null : v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _colDropdown(
                icon:      Icons.chat_bubble_outline_rounded,
                label:     'LEAD DETAILS',
                value:     _colLead,
                columns:   cols,
                onChanged: (v) =>
                    setState(() =>
                        _colLead = v?.isEmpty == true ? null : v),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _colDropdown({
    required IconData              icon,
    required String                label,
    required String?               value,
    required List<String>          columns,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color:         AppColors.textMuted,
                    fontSize:      10.5,
                    fontWeight:    FontWeight.w700,
                    letterSpacing: 0.3)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
                color: value != null
                    ? AppColors.primary
                    : AppColors.border,
                width: 1.2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: DropdownButton<String>(
            value:        value ?? '',
            isExpanded:   true,
            underline:    const SizedBox(),
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: AppColors.iconDefault),
            style: const TextStyle(
                color:    AppColors.textPrimary,
                fontSize: 13),
            dropdownColor: Colors.white,
            items: columns.map((c) => DropdownMenuItem<String>(
                  value: c,
                  child: Text(
                      c.isEmpty ? '-- Select Column --' : c,
                      style: TextStyle(
                          color: c.isEmpty
                              ? AppColors.textHint
                              : AppColors.textPrimary,
                          fontSize: 13)),
                )).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ── Employee Picker Bottom Sheet ───────────────────────────────────────────
class _EmployeePickerSheet extends StatefulWidget {
  final Future<List<_Employee>> Function() fetchEmployees;
  final void Function(_Employee)           onSelected;

  const _EmployeePickerSheet({
    required this.fetchEmployees,
    required this.onSelected,
  });

  @override
  State<_EmployeePickerSheet> createState() =>
      _EmployeePickerSheetState();
}

class _EmployeePickerSheetState extends State<_EmployeePickerSheet> {
  List<_Employee> _all      = [];
  List<_Employee> _filtered = [];
  bool            _loading  = true;
  String?         _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_filter);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await widget.fetchEmployees();
      if (mounted) setState(() { _all = list; _filter(); _loading = false; });
    } catch (e) {
      if (mounted)
        setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_all)
          : _all.where((e) =>
              e.name.toLowerCase().contains(q) ||
              e.phone.contains(q) ||
              e.code.contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height:     MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color:        AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Title
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Icon(Icons.people_outline_rounded,
                    size: 18, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Select Employee',
                    style: TextStyle(
                        color:      AppColors.textPrimary,
                        fontSize:   15,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color:        AppColors.background,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.border, width: 1.2),
              ),
              child: TextField(
                controller:  _searchCtrl,
                cursorColor: AppColors.primary,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 13.5),
                decoration: const InputDecoration(
                  hintText:  'Search by name, phone, code…',
                  hintStyle: TextStyle(
                      color: AppColors.textHint, fontSize: 12.5),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: AppColors.iconDefault, size: 17),
                  border:         InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          // List
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2.4))
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.error)))
                    : _filtered.isEmpty
                        ? const Center(
                            child: Text('No employees found.',
                                style: TextStyle(
                                    color: AppColors.textMuted)))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 4),
                            itemBuilder: (_, i) {
                              final emp = _filtered[i];
                              return InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  widget.onSelected(emp);
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 10),
                                  child: Row(
                                    children: [
                                      // Avatar
                                      Container(
                                        width: 36, height: 36,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius:
                                              BorderRadius.circular(9),
                                        ),
                                        child: Center(
                                          child: Text(
                                            emp.name.isNotEmpty
                                                ? emp.name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                                color:      AppColors.primary,
                                                fontWeight: FontWeight.w700,
                                                fontSize:   15),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              emp.name.capitalize(),
                                              style: const TextStyle(
                                                  color:      AppColors.textPrimary,
                                                  fontSize:   13.5,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${emp.phone}  ·  #${emp.code}',
                                              style: const TextStyle(
                                                  color:    AppColors.textMuted,
                                                  fontSize: 11.5),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                          Icons.chevron_right_rounded,
                                          size: 18,
                                          color: AppColors.textMuted),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}