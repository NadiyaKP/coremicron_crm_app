import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../common/api_service.dart';
import '../../../common/theme.dart';
import '../../login.dart' show kSessionKey;
import '../../home.dart';
import '../../../common/pagination.dart';
import '../../../common/string_extensions.dart';

// ── Department Model ───────────────────────────────────────────────────────
class Department {
  final String id;
  final String name;
  final String status;
  final String confirm;

  const Department({
    required this.id,
    required this.name,
    required this.status,
    required this.confirm,
  });

  factory Department.fromJson(Map<String, dynamic> json) => Department(
        id:      json['id']              ?? '',
        name:    json['department_name'] ?? '',
        status:  json['status']          ?? '',
        confirm: json['confirm']         ?? '',
      );
}

// ── Department Page ────────────────────────────────────────────────────────
class DepartmentPage extends StatefulWidget {
  final String username;

  const DepartmentPage({super.key, required this.username});

  @override
  State<DepartmentPage> createState() => _DepartmentPageState();
}

class _DepartmentPageState extends State<DepartmentPage> {
  static const int _pageSize = 50;

  List<Department> _allDepartments = [];
  List<Department> _filtered       = [];
  bool             _isLoading      = true;
  String?          _errorMessage;

  // Search
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Pagination
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchCtrl.text.trim().toLowerCase();
      _currentPage = 1;
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filtered = List.from(_allDepartments);
    } else {
      _filtered = _allDepartments
          .where((d) => d.name.toLowerCase().contains(_searchQuery))
          .toList();
    }
  }

  // ── Fetch list ─────────────────────────────────────────────────────────────
  Future<void> _fetchDepartments() async {
    setState(() {
      _isLoading    = true;
      _errorMessage = null;
    });

    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url       = Uri.parse('${ApiService.baseUrl}/api/department/list.php');

      debugPrint('─────────────────────────────────────────');
      debugPrint('📤  [DEPARTMENT LIST] Request');
      debugPrint('   🌐  URL : $url');
      debugPrint('─────────────────────────────────────────');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
          'X-Session-ID': sessionId,
          'Cookie':       'PHPSESSID=$sessionId',
        },
      ).timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = jsonDecode(response.body);

      debugPrint('─────────────────────────────────────────');
      debugPrint('📥  [DEPARTMENT LIST] Response');
      debugPrint('   🔢  Status : ${response.statusCode}');
      debugPrint('   📄  Body   : ${response.body}');
      debugPrint('─────────────────────────────────────────');

      if (response.statusCode == 200 && data['success'] == true) {
        final List list = data['data'] ?? [];
        _allDepartments = list.map((e) => Department.fromJson(e)).toList();
        _applyFilter();
      } else {
        _errorMessage = data['message'] ?? 'Failed to load departments.';
      }
    } on http.ClientException {
      _errorMessage = 'Unable to reach the server. Check your connection.';
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ── API: Create ────────────────────────────────────────────────────────────
  Future<void> _createDepartment(String name) async {
    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url       = Uri.parse('${ApiService.baseUrl}/api/department/create.php');
      final body      = {'department_name': name};

      debugPrint('─────────────────────────────────────────');
      debugPrint('📤  [CREATE DEPARTMENT] Request');
      debugPrint('   🌐  URL  : $url');
      debugPrint('   📦  Body : ${jsonEncode(body)}');
      debugPrint('─────────────────────────────────────────');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
          'X-Session-ID': sessionId,
          'Cookie':       'PHPSESSID=$sessionId',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final Map<String, dynamic> data = jsonDecode(response.body);

      debugPrint('─────────────────────────────────────────');
      debugPrint('📥  [CREATE DEPARTMENT] Response');
      debugPrint('   🔢  Status : ${response.statusCode}');
      debugPrint('   📄  Body   : ${response.body}');
      debugPrint('─────────────────────────────────────────');

      if (response.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Department added successfully.');
        _fetchDepartments();
      } else {
        AppSnackBar.show(
            context, data['message'] ?? 'Failed to create.', isError: true);
      }
    } on http.ClientException {
      if (mounted) AppSnackBar.show(context, 'Unable to reach the server.', isError: true);
    } catch (_) {
      if (mounted) AppSnackBar.show(context, 'Something went wrong.', isError: true);
    }
  }

  // ── API: Update ────────────────────────────────────────────────────────────
  Future<void> _updateDepartment(String id, String name) async {
    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url       = Uri.parse('${ApiService.baseUrl}/api/department/update.php');
      final body      = {'id': id, 'department_name': name};

      debugPrint('─────────────────────────────────────────');
      debugPrint('📤  [UPDATE DEPARTMENT] Request');
      debugPrint('   🌐  URL  : $url');
      debugPrint('   📦  Body : ${jsonEncode(body)}');
      debugPrint('─────────────────────────────────────────');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
          'X-Session-ID': sessionId,
          'Cookie':       'PHPSESSID=$sessionId',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final Map<String, dynamic> data = jsonDecode(response.body);

      debugPrint('─────────────────────────────────────────');
      debugPrint('📥  [UPDATE DEPARTMENT] Response');
      debugPrint('   🔢  Status : ${response.statusCode}');
      debugPrint('   📄  Body   : ${response.body}');
      debugPrint('─────────────────────────────────────────');

      if (response.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Department updated successfully.');
        _fetchDepartments();
      } else {
        AppSnackBar.show(
            context, data['message'] ?? 'Failed to update.', isError: true);
      }
    } on http.ClientException {
      if (mounted) AppSnackBar.show(context, 'Unable to reach the server.', isError: true);
    } catch (_) {
      if (mounted) AppSnackBar.show(context, 'Something went wrong.', isError: true);
    }
  }

  // ── API: Delete ────────────────────────────────────────────────────────────
  Future<void> _deleteDepartment(String id) async {
    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url       = Uri.parse('${ApiService.baseUrl}/api/department/delete.php');
      final body      = {'id': id};

      debugPrint('─────────────────────────────────────────');
      debugPrint('📤  [DELETE DEPARTMENT] Request');
      debugPrint('   🌐  URL  : $url');
      debugPrint('   📦  Body : ${jsonEncode(body)}');
      debugPrint('─────────────────────────────────────────');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
          'X-Session-ID': sessionId,
          'Cookie':       'PHPSESSID=$sessionId',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final Map<String, dynamic> data = jsonDecode(response.body);

      debugPrint('─────────────────────────────────────────');
      debugPrint('📥  [DELETE DEPARTMENT] Response');
      debugPrint('   🔢  Status : ${response.statusCode}');
      debugPrint('   📄  Body   : ${response.body}');
      debugPrint('─────────────────────────────────────────');

      if (response.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Department deleted successfully.');
        _fetchDepartments();
      } else {
        AppSnackBar.show(
            context, data['message'] ?? 'Failed to delete.', isError: true);
      }
    } on http.ClientException {
      if (mounted) AppSnackBar.show(context, 'Unable to reach the server.', isError: true);
    } catch (_) {
      if (mounted) AppSnackBar.show(context, 'Something went wrong.', isError: true);
    }
  }

  // ── Pagination ─────────────────────────────────────────────────────────────
  int get _totalPages => paginationTotalPages(_filtered.length, _pageSize);

  List<Department> get _pageItems =>
      paginationPageItems(_filtered, _currentPage, _pageSize);

  // ── Back to Home with drawer open ──────────────────────────────────────────
  void _goBackToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomePage(
          username: widget.username,
          openDrawerOnLoad: true,
        ),
      ),
      (route) => false,
    );
  }

  // ── Add / Edit popup ───────────────────────────────────────────────────────
  // Pass [department] for edit mode, null for add mode.
  void _showAddEditDialog({Department? department}) {
    final isEdit  = department != null;
    final nameCtrl  = TextEditingController(text: isEdit ? department.name : '');
    final nameFocus = FocusNode();
    bool  isSaving  = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final focused = nameFocus.hasFocus;
          nameFocus.addListener(() => setDialogState(() {}));

          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header: title + × close ──────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isEdit
                              ? Icons.edit_outlined
                              : Icons.apartment_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isEdit ? 'Edit Department' : 'New Department',
                          style: const TextStyle(
                            color:      AppColors.textPrimary,
                            fontSize:   16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      // × close button
                      GestureDetector(
                        onTap: isSaving
                            ? null
                            : () => Navigator.pop(dialogCtx),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.border, width: 1.1),
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 16, color: AppColors.textLabel),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Label ────────────────────────────────────────────
                  Text('DEPARTMENT NAME',
                      style: AppTextStyles.fieldLabel(false)),
                  const SizedBox(height: 8),

                  // ── Input box ────────────────────────────────────────
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: focused
                        ? AppDecorations.inputFocused
                        : AppDecorations.inputIdle,
                    child: TextField(
                      controller:      nameCtrl,
                      focusNode:       nameFocus,
                      autofocus:       true,
                      textInputAction: TextInputAction.done,
                      cursorColor:     AppColors.primary,
                      style: const TextStyle(
                          color:      AppColors.textPrimary,
                          fontSize:   14,
                          fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText:  'Enter department name',
                        hintStyle: const TextStyle(
                            color:    AppColors.textHint,
                            fontSize: 13.5),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.apartment_rounded,
                              size:  18,
                              color: focused
                                  ? AppColors.primary
                                  : AppColors.iconDefault),
                        ),
                        border:             InputBorder.none,
                        enabledBorder:      InputBorder.none,
                        focusedBorder:      InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 15),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── Save / Update button ─────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                if (name.isEmpty) {
                                  AppSnackBar.show(
                                      context,
                                      'Please enter a department name.',
                                      isError: true);
                                  return;
                                }
                                setDialogState(() => isSaving = true);
                                Navigator.pop(dialogCtx);
                                if (isEdit) {
                                  await _updateDepartment(
                                      department.id, name);
                                } else {
                                  await _createDepartment(name);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor:
                              AppColors.primary.withOpacity(0.45),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 11),
                          minimumSize:   Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: isSaving
                              ? const SizedBox(
                                  key: ValueKey('s-loader'),
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.2),
                                )
                              : Text(
                                  isEdit ? 'Update' : 'Save',
                                  key: const ValueKey('s-label'),
                                  style: const TextStyle(
                                    color:      Colors.white,
                                    fontSize:   13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
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
    );
  }

  // ── Simple delete confirmation ─────────────────────────────────────────────
  void _showDeleteDialog(Department d) {
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Red delete icon
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.error, size: 26),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Delete Department',
                  style: TextStyle(
                    color:      AppColors.textPrimary,
                    fontSize:   16,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Are you sure you want to delete\n"${d.name.capitalize()}"?\nThis action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color:    AppColors.textSecondary,
                    fontSize: 13.5,
                    height:   1.55,
                  ),
                ),

                const SizedBox(height: 22),

                Row(
                  children: [
                    // Cancel
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isDeleting
                            ? null
                            : () => Navigator.pop(dialogCtx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.border, width: 1.3),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11)),
                          backgroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(
                                color:      AppColors.textLabel,
                                fontWeight: FontWeight.w600,
                                fontSize:   14)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Delete
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isDeleting
                            ? null
                            : () async {
                                setDialogState(() => isDeleting = true);
                                Navigator.pop(dialogCtx);
                                await _deleteDepartment(d.id);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          disabledBackgroundColor:
                              AppColors.error.withOpacity(0.5),
                          elevation: 0,
                          padding:
                              const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11)),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: isDeleting
                              ? const SizedBox(
                                  key: ValueKey('del-loader'),
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.3),
                                )
                              : const Text('Delete',
                                  key: ValueKey('del-label'),
                                  style: TextStyle(
                                      color:      Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize:   14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 0),
              child: _buildSearchBar(),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 0),
              child: Row(
                children: [
                  if (!_isLoading)
                    Text(
                      '${_filtered.length} department${_filtered.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color:      AppColors.textSecondary,
                          fontSize:   12.5,
                          fontWeight: FontWeight.w500),
                    ),
                  const Spacer(),
                  _newDepartmentButton(),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: _isLoading
                  ? _buildSkeletonList(hPad)
                  : _errorMessage != null
                      ? _buildError()
                      : _filtered.isEmpty
                          ? _buildEmpty()
                          : _buildDepartmentList(hPad),
            ),

            if (!_isLoading && _errorMessage == null && _filtered.isNotEmpty)
              AppPagination(
                currentPage:       _currentPage,
                totalPages:        _totalPages,
                horizontalPadding: hPad,
                onPageChanged:     (page) => setState(() => _currentPage = page),
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
          Text(
            'Departments',
            style: TextStyle(
              color:      AppColors.textPrimary,
              fontSize:   isTablet ? 20 : 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _fetchDepartments,
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

  // ── Search bar ─────────────────────────────────────────────────────────────
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
              offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 14),
        cursorColor: AppColors.primary,
        decoration: const InputDecoration(
          hintText:  'Search departments…',
          hintStyle: TextStyle(color: AppColors.textHint, fontSize: 13.5),
          prefixIcon: Icon(Icons.search_rounded,
              color: AppColors.iconDefault, size: 19),
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  // ── New Department button ──────────────────────────────────────────────────
  Widget _newDepartmentButton() {
    return ElevatedButton.icon(
      onPressed: () => _showAddEditDialog(),
      icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
      label: const Text('New Department',
          style: TextStyle(
              color:      Colors.white,
              fontWeight: FontWeight.w600,
              fontSize:   12.5)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9)),
      ),
    );
  }

  // ── Department list ────────────────────────────────────────────────────────
  Widget _buildDepartmentList(double hPad) {
    final items = _pageItems;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _departmentCard(items[i]),
    );
  }

  // ── Department card ────────────────────────────────────────────────────────
  Widget _departmentCard(Department d) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight, width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Icon avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.apartment_rounded,
                color: AppColors.primary, size: 17),
          ),

          const SizedBox(width: 12),

          // Department name
          Expanded(
            child: Text(
              d.name.capitalize(),
              style: const TextStyle(
                color:      AppColors.textPrimary,
                fontSize:   13.5,
                fontWeight: FontWeight.w600,
                height:     1.3,
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Action buttons — inline right side
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _actionIcon(
                icon:    Icons.edit_outlined,
                color:   AppColors.primary,
                bgColor: AppColors.primaryLight,
                onTap:   () => _showAddEditDialog(department: d),
              ),
              const SizedBox(width: 7),
              _actionIcon(
                icon:    Icons.delete_outline_rounded,
                color:   AppColors.error,
                bgColor: const Color(0xFFFFF1F1),
                onTap:   () => _showDeleteDialog(d),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final isActive = status.toLowerCase() == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? AppColors.successBg : const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.isNotEmpty ? status : '—',
        style: TextStyle(
          color:      isActive ? AppColors.success : const Color(0xFF856404),
          fontSize:   11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _actionIcon({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }

  // ── Skeleton loading ───────────────────────────────────────────────────────
  Widget _buildSkeletonList(double hPad) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => _skeletonCard(),
    );
  }

  Widget _skeletonCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Row(
        children: [
          _shimmer(width: 36, height: 36, radius: 9),
          const SizedBox(width: 12),
          Expanded(child: _shimmer(width: double.infinity, height: 13, radius: 4)),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _shimmer(width: 30, height: 30, radius: 7),
              const SizedBox(width: 7),
              _shimmer(width: 30, height: 30, radius: 7),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shimmer(
          {required double width,
          required double height,
          required double radius}) =>
      _ShimmerBox(width: width, height: height, radius: radius);

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.apartment_rounded,
              size: 56, color: AppColors.border),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No departments found',
            style: const TextStyle(
                color:      AppColors.textSecondary,
                fontSize:   14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Tap "New Department" to get started',
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  // ── Error state ────────────────────────────────────────────────────────────
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
            onPressed: _fetchDepartments,
            icon: const Icon(Icons.refresh_rounded,
                size: 16, color: Colors.white),
            label: const Text('Retry',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
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

// ── Shimmer box ────────────────────────────────────────────────────────────
class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

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
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
          width:  widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EDF5),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
}