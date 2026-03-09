import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../common/api_service.dart';
import '../../common/theme.dart';
import '../login.dart' show kSessionKey;
import '../home.dart';
import '../../common/pagination.dart';

// ── Employee Model ─────────────────────────────────────────────────────────
class Employee {
  final String id;
  final String employeeName;
  final String employeeId;
  final String phoneNumber;
  final String badgeNumber;
  final String machineId;
  final String machineUserId;
  final String departmentId;
  final String status;
  final String confirm;
  final String departmentName;
  final String machineName;

  const Employee({
    required this.id,
    required this.employeeName,
    required this.employeeId,
    required this.phoneNumber,
    required this.badgeNumber,
    required this.machineId,
    required this.machineUserId,
    required this.departmentId,
    required this.status,
    required this.confirm,
    required this.departmentName,
    required this.machineName,
  });

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
        id:             json['id']              ?? '',
        employeeName:   json['employee_name']   ?? '',
        employeeId:     json['employee_id']     ?? '',
        phoneNumber:    json['phone_number']    ?? '',
        badgeNumber:    json['badge_number']    ?? '',
        machineId:      json['machine_id']      ?? '',
        machineUserId:  json['machine_user_id'] ?? '',
        departmentId:   json['department_id']   ?? '',
        status:         json['status']          ?? '',
        confirm:        json['confirm']         ?? '',
        departmentName: json['department_name'] ?? '',
        machineName:    json['machine_name']    ?? '',
      );

  bool get isActive => status.toLowerCase() == 'active';
}

// ── Employee Page ──────────────────────────────────────────────────────────
class EmployeePage extends StatefulWidget {
  final String username;
  const EmployeePage({super.key, required this.username});

  @override
  State<EmployeePage> createState() => _EmployeePageState();
}

class _EmployeePageState extends State<EmployeePage> {
  static const int _pageSize = 50;

  List<Employee> _allEmployees = [];
  List<Employee> _filtered     = [];
  bool           _isLoading    = true;
  String?        _errorMessage;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int    _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
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
      _filtered = List.from(_allEmployees);
    } else {
      _filtered = _allEmployees.where((e) {
        return e.employeeName.toLowerCase().contains(_searchQuery) ||
            e.employeeId.toLowerCase().contains(_searchQuery) ||
            e.phoneNumber.toLowerCase().contains(_searchQuery) ||
            e.departmentName.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchEmployees() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url       = Uri.parse('${ApiService.baseUrl}/api/employee/list.php');

      debugPrint('─────────────────────────────────────────');
      debugPrint('📤  [EMPLOYEE LIST] Request');
      debugPrint('   🌐  URL : $url');
      debugPrint('─────────────────────────────────────────');

      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Accept':       'application/json',
        'X-Session-ID': sessionId,
        'Cookie':       'PHPSESSID=$sessionId',
      }).timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = jsonDecode(response.body);

      debugPrint('─────────────────────────────────────────');
      debugPrint('📥  [EMPLOYEE LIST] Response');
      debugPrint('   🔢  Status : ${response.statusCode}');
      debugPrint('   📄  Body   : ${response.body}');
      debugPrint('─────────────────────────────────────────');

      if (response.statusCode == 200 && data['success'] == true) {
        final List list = data['data'] ?? [];
        _allEmployees = list.map((e) => Employee.fromJson(e)).toList();
        _applyFilter();
      } else {
        _errorMessage = data['error'] ?? data['message'] ?? 'Failed to load employees.';
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
  List<Employee> get _pageItems =>
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
                      '${_filtered.length} employee'
                      '${_filtered.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color:      AppColors.textSecondary,
                          fontSize:   12.5,
                          fontWeight: FontWeight.w500),
                    ),
                  const Spacer(),
                  _addEmployeeButton(),
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
                          : _buildEmployeeList(hPad),
            ),

            if (!_isLoading &&
                _errorMessage == null &&
                _filtered.isNotEmpty)
              AppPagination(
                currentPage:       _currentPage,
                totalPages:        _totalPages,
                horizontalPadding: hPad,
                onPageChanged:
                    (page) => setState(() => _currentPage = page),
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
        border:
            Border(bottom: BorderSide(color: AppColors.borderLight)),
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
                border:
                    Border.all(color: AppColors.border, width: 1.2),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 15, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Text('Employees',
              style: TextStyle(
                  color:         AppColors.textPrimary,
                  fontSize:      isTablet ? 20 : 17,
                  fontWeight:    FontWeight.w800,
                  letterSpacing: -0.3)),
          const Spacer(),
          GestureDetector(
            onTap: _fetchEmployees,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color:        AppColors.background,
                borderRadius: BorderRadius.circular(9),
                border:
                    Border.all(color: AppColors.border, width: 1.2),
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
        style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 14),
        cursorColor: AppColors.primary,
        decoration: const InputDecoration(
          hintText:  'Search by name, ID, phone, department…',
          hintStyle: TextStyle(
              color: AppColors.textHint, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded,
              color: AppColors.iconDefault, size: 19),
          border:         InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  // ── Add Employee button ────────────────────────────────────────────────────
  Widget _addEmployeeButton() {
    return ElevatedButton.icon(
      onPressed: () {
        // TODO: navigate to Add Employee page
      },
      icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
      label: const Text('Add Employee',
          style: TextStyle(
              color:      Colors.white,
              fontWeight: FontWeight.w600,
              fontSize:   12.5)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        elevation: 0,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9)),
      ),
    );
  }

  // ── Employee list ──────────────────────────────────────────────────────────
  Widget _buildEmployeeList(double hPad) {
    final items = _pageItems;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _employeeCard(items[i]),
    );
  }

  // ── Employee card ──────────────────────────────────────────────────────────
  Widget _employeeCard(Employee e) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Avatar ──────────────────────────────────────────────────
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color:        AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                e.employeeName.isNotEmpty
                    ? e.employeeName[0].toUpperCase()
                    : 'E',
                style: const TextStyle(
                  color:      AppColors.primary,
                  fontSize:   16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ── Info ─────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Text(
                  e.employeeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color:      AppColors.textPrimary,
                    fontSize:   13.5,
                    fontWeight: FontWeight.w600,
                    height:     1.3,
                  ),
                ),
                const SizedBox(height: 3),
                // ID + Phone
                Row(
                  children: [
                    _infoChip(Icons.badge_outlined, 'ID: ${e.employeeId}'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _infoChip(
                          Icons.phone_outlined, e.phoneNumber,
                          ellipsis: true),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // Department
                _infoChip(Icons.apartment_rounded, e.departmentName,
                    ellipsis: true),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ── Action buttons ───────────────────────────────────────────
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Edit
              _actionIcon(
                icon:    Icons.edit_outlined,
                color:   AppColors.primary,
                bgColor: AppColors.primaryLight,
                onTap:   () {
                  // TODO: navigate to Edit Employee page
                },
              ),
              const SizedBox(height: 6),
              // Active / Inactive toggle
              _statusButton(e),
              const SizedBox(height: 6),
              // Settings
              _actionIcon(
                icon:    Icons.settings_outlined,
                color:   AppColors.textLabel,
                bgColor: const Color(0xFFF0F0F0),
                onTap:   () {
                  // TODO: open settings
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Small info row chip ───────────────────────────────────────────────────
  Widget _infoChip(IconData icon, String text,
      {bool ellipsis = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppColors.textMuted),
        const SizedBox(width: 3),
        ellipsis
            ? Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 11.5),
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                    color:    AppColors.textSecondary,
                    fontSize: 11.5),
              ),
      ],
    );
  }

  // ── Active / Inactive pill button ─────────────────────────────────────────
  Widget _statusButton(Employee e) {
    final isActive = e.isActive;
    return GestureDetector(
      onTap: () {
        // TODO: toggle status API call
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.successBg
              : const Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isActive
                ? AppColors.success.withOpacity(0.4)
                : const Color(0xFFFFB300).withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size:  11,
              color: isActive
                  ? AppColors.success
                  : const Color(0xFF856404),
            ),
            const SizedBox(width: 3),
            Text(
              isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                color: isActive
                    ? AppColors.success
                    : const Color(0xFF856404),
                fontSize:   10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionIcon({
    required IconData     icon,
    required Color        color,
    required Color        bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
            color:        bgColor,
            borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }

  // ── Skeleton ───────────────────────────────────────────────────────────────
  Widget _buildSkeletonList(double hPad) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
      itemCount: 7,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => _skeletonCard(),
    );
  }

  Widget _skeletonCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _shimmer(width: 40, height: 40, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmer(width: 140, height: 13, radius: 4),
                const SizedBox(height: 6),
                _shimmer(width: 200, height: 11, radius: 4),
                const SizedBox(height: 5),
                _shimmer(width: 120, height: 11, radius: 4),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _shimmer(width: 30, height: 30, radius: 7),
              const SizedBox(height: 6),
              _shimmer(width: 62, height: 28, radius: 7),
              const SizedBox(height: 6),
              _shimmer(width: 30, height: 30, radius: 7),
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
  }) =>
      _ShimmerBox(width: width, height: height, radius: radius);

  // ── Empty ──────────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.badge_outlined,
              size: 56, color: AppColors.border),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No employees found',
            style: const TextStyle(
                color:      AppColors.textSecondary,
                fontSize:   14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Tap "Add Employee" to get started',
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 12.5),
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
            onPressed: _fetchEmployees,
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

// ── Shimmer box ────────────────────────────────────────────────────────────
class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
  });

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
          width:  widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color:        const Color(0xFFE8EDF5),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
}