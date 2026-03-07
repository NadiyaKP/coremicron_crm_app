import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../common/api_service.dart';
import '../../common/theme.dart';
import '../login.dart' show kSessionKey;
import '../home.dart';
import 'add_customer.dart';

// ── Customer Model ─────────────────────────────────────────────────────────
class Customer {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String status;
  final String confirm;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.status,
    required this.confirm,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id:      json['id']            ?? '',
        name:    json['customer_name'] ?? '',
        phone:   json['phone_number']  ?? '',
        email:   json['email']         ?? '',
        address: json['address']       ?? '',
        status:  json['status']        ?? '',
        confirm: json['confirm']       ?? '',
      );
}

// ── Customers Page ─────────────────────────────────────────────────────────
class CustomersPage extends StatefulWidget {
  final String username;

  const CustomersPage({super.key, required this.username});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  static const int _pageSize = 50;

  List<Customer> _allCustomers = [];
  List<Customer> _filtered     = [];
  bool           _isLoading    = true;
  String?        _errorMessage;

  // Search
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Pagination
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
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
      _filtered = List.from(_allCustomers);
    } else {
      _filtered = _allCustomers.where((c) {
        return c.name.toLowerCase().contains(_searchQuery)  ||
               c.phone.toLowerCase().contains(_searchQuery) ||
               c.email.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  // ── Fetch list ─────────────────────────────────────────────────────────────
  Future<void> _fetchCustomers() async {
    setState(() {
      _isLoading    = true;
      _errorMessage = null;
    });

    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url       = Uri.parse('${ApiService.baseUrl}/api/customer/list.php');

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

      if (response.statusCode == 200 && data['success'] == true) {
        final List list = data['data'] ?? [];
        _allCustomers   = list.map((e) => Customer.fromJson(e)).toList();
        _applyFilter();
      } else {
        _errorMessage = data['message'] ?? 'Failed to load customers.';
      }
    } on http.ClientException {
      _errorMessage = 'Unable to reach the server. Check your connection.';
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ── Delete API ─────────────────────────────────────────────────────────────
  Future<void> _deleteCustomer(String id, String reason) async {
    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url       = Uri.parse('${ApiService.baseUrl}/api/customer/delete.php');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
          'X-Session-ID': sessionId,
          'Cookie':       'PHPSESSID=$sessionId',
        },
        body: jsonEncode({'id': id, 'reason': reason}),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Customer deleted successfully.');
        _fetchCustomers(); // refresh list
      } else {
        AppSnackBar.show(
            context, data['message'] ?? 'Failed to delete.', isError: true);
      }
    } on http.ClientException {
      if (mounted) {
        AppSnackBar.show(context, 'Unable to reach the server.', isError: true);
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(context, 'Something went wrong.', isError: true);
      }
    }
  }

  // ── Pagination helpers ─────────────────────────────────────────────────────
  int get _totalPages =>
      (_filtered.length / _pageSize).ceil().clamp(1, 9999);

  List<Customer> get _pageItems {
    final start = (_currentPage - 1) * _pageSize;
    final end   = (start + _pageSize).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  // ── Navigate: New Customer ─────────────────────────────────────────────────
  Future<void> _openAddCustomer() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddCustomerPage()),
    );
    if (result == true) _fetchCustomers();
  }

  // ── Navigate: Edit Customer ────────────────────────────────────────────────
  Future<void> _openEditCustomer(Customer c) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddCustomerPage(
          customer: {
            'id':      c.id,
            'name':    c.name,
            'phone':   c.phone,
            'email':   c.email,
            'address': c.address,
          },
        ),
      ),
    );
    if (result == true) _fetchCustomers();
  }

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

  // ── View popup ─────────────────────────────────────────────────────────────
  void _showViewDialog(Customer c) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        _statusBadge(c.status),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textLabel, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.borderLight),
              const SizedBox(height: 14),
              _detailRow(Icons.phone_outlined,
                  'Phone',   c.phone.isNotEmpty   ? c.phone   : '—'),
              _detailRow(Icons.email_outlined,
                  'Email',   c.email.isNotEmpty   ? c.email   : '—'),
              _detailRow(Icons.location_on_outlined,
                  'Address', c.address.isNotEmpty ? c.address : '—'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: AppButtonStyles.primary,
                  child: const Text('Close',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 68,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
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
          color: isActive ? AppColors.success : const Color(0xFF856404),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Delete dialog with reason textbox ─────────────────────────────────────
  void _showDeleteDialog(Customer c) {
    final reasonCtrl = TextEditingController();
    final reasonFocus = FocusNode();
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon + title
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.error, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Delete Customer',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Customer name preview
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                            color: AppColors.borderLight, width: 1),
                      ),
                      child: Text(
                        c.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Reason label
                    Text(
                      'REASON FOR DELETION',
                      style: AppTextStyles.fieldLabel(false),
                    ),
                    const SizedBox(height: 7),

                    // Reason text area
                    Focus(
                      onFocusChange: (_) => setDialogState(() {}),
                      child: Builder(builder: (focusCtx) {
                        final focused = Focus.of(focusCtx).hasFocus;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: focused
                              ? AppDecorations.inputFocused
                              : AppDecorations.inputIdle,
                          child: TextField(
                            controller: reasonCtrl,
                            focusNode:  reasonFocus,
                            maxLines:   3,
                            cursorColor: AppColors.primary,
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Enter reason for deleting this customer…',
                              hintStyle: const TextStyle(
                                  color: AppColors.textHint, fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 20),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isDeleting
                                ? null
                                : () => Navigator.pop(dialogCtx),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppColors.border, width: 1.3),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              backgroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Cancel',
                                style: TextStyle(
                                    color: AppColors.textLabel,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isDeleting
                                ? null
                                : () async {
                                    final reason =
                                        reasonCtrl.text.trim();
                                    if (reason.isEmpty) {
                                      AppSnackBar.show(
                                        context,
                                        'Please enter a reason.',
                                        isError: true,
                                      );
                                      return;
                                    }
                                    setDialogState(
                                        () => isDeleting = true);
                                    Navigator.pop(dialogCtx);
                                    await _deleteCustomer(
                                        c.id, reason);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              disabledBackgroundColor:
                                  AppColors.error.withOpacity(0.5),
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
                                  : const Text(
                                      'Delete',
                                      key: ValueKey('del-label'),
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14),
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
        );
      },
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
                      '${_filtered.length} customer${_filtered.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500),
                    ),
                  const Spacer(),
                  _newCustomerButton(),
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
                          : _buildCustomerList(hPad),
            ),

            if (!_isLoading && _errorMessage == null && _filtered.isNotEmpty)
              _buildPagination(hPad),
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
            'Customers',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: isTablet ? 20 : 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _fetchCustomers,
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
        style:
            const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        cursorColor: AppColors.primary,
        decoration: const InputDecoration(
          hintText: 'Search by name, phone or email…',
          hintStyle:
              TextStyle(color: AppColors.textHint, fontSize: 13.5),
          prefixIcon: Icon(Icons.search_rounded,
              color: AppColors.iconDefault, size: 19),
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  // ── New Customer button ────────────────────────────────────────────────────
  Widget _newCustomerButton() {
    return ElevatedButton.icon(
      onPressed: _openAddCustomer,
      icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
      label: const Text('New Customer',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12.5)),
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

  // ── Customer list ──────────────────────────────────────────────────────────
  Widget _buildCustomerList(double hPad) {
    final items = _pageItems;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _customerCard(items[i]),
    );
  }

  // ── Customer card ──────────────────────────────────────────────────────────
  Widget _customerCard(Customer c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
                color: AppColors.primaryLight, shape: BoxShape.circle),
            child: Center(
              child: Text(
                c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Name + contact + action buttons stacked
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full name — no ellipsis
                Text(
                  c.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),

                const SizedBox(height: 5),

                // Phone & email — wraps naturally
                Wrap(
                  spacing: 10,
                  runSpacing: 3,
                  children: [
                    if (c.phone.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_outlined,
                              size: 11,
                              color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Text(c.phone,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11.5)),
                        ],
                      ),
                    if (c.email.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.email_outlined,
                              size: 11,
                              color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Text(c.email,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11.5)),
                        ],
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                // Action buttons — right aligned, below name
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _actionIcon(
                      icon:    Icons.remove_red_eye_outlined,
                      color:   AppColors.primary,
                      bgColor: AppColors.primaryLight,
                      onTap:   () => _showViewDialog(c),
                    ),
                    const SizedBox(width: 7),
                    _actionIcon(
                      icon:    Icons.edit_outlined,
                      color:   const Color(0xFF0D9488),
                      bgColor: const Color(0xFFECFDF5),
                      onTap:   () => _openEditCustomer(c),
                    ),
                    const SizedBox(width: 7),
                    _actionIcon(
                      icon:    Icons.delete_outline_rounded,
                      color:   AppColors.error,
                      bgColor: const Color(0xFFFFF1F1),
                      onTap:   () => _showDeleteDialog(c),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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

  // ── Smart pagination ───────────────────────────────────────────────────────
  Widget _buildPagination(double hPad) {
    return Container(
      padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _buildPageButtons(),
        ),
      ),
    );
  }

  List<Widget> _buildPageButtons() {
    final total   = _totalPages;
    final current = _currentPage;
    final buttons = <Widget>[];

    final Set<int> show = {1, total};
    for (int p = current - 1; p <= current + 1; p++) {
      if (p >= 1 && p <= total) show.add(p);
    }
    final sorted = show.toList()..sort();

    buttons.add(_arrowBtn(
      icon: Icons.chevron_left_rounded,
      enabled: current > 1,
      onTap: () => setState(() => _currentPage--),
    ));

    int? prev;
    for (final page in sorted) {
      if (prev != null && page - prev > 1) buttons.add(_ellipsis());
      buttons.add(_pageNumBtn(page, page == current));
      prev = page;
    }

    buttons.add(_arrowBtn(
      icon: Icons.chevron_right_rounded,
      enabled: current < total,
      onTap: () => setState(() => _currentPage++),
    ));

    return buttons;
  }

  Widget _arrowBtn(
      {required IconData icon,
      required bool enabled,
      required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: enabled ? AppColors.primaryLight : AppColors.borderLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 20,
              color: enabled ? AppColors.primary : AppColors.textMuted),
        ),
      ),
    );
  }

  Widget _pageNumBtn(int page, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: isActive ? null : () => setState(() => _currentPage = page),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? AppColors.primary : AppColors.border,
              width: 1.2,
            ),
          ),
          child: Center(
            child: Text(
              '$page',
              style: TextStyle(
                color:      isActive ? Colors.white : AppColors.textLabel,
                fontSize:   12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ellipsis() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(
          width: 20,
          height: 32,
          child: Center(
            child: Text('…',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      );

  // ── Skeleton ───────────────────────────────────────────────────────────────
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmer(width: 38, height: 38, radius: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmer(width: double.infinity, height: 13, radius: 4),
                const SizedBox(height: 7),
                _shimmer(width: 180, height: 11, radius: 4),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _shimmer(width: 30, height: 30, radius: 7),
                    const SizedBox(width: 7),
                    _shimmer(width: 30, height: 30, radius: 7),
                    const SizedBox(width: 7),
                    _shimmer(width: 30, height: 30, radius: 7),
                  ],
                ),
              ],
            ),
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

  // ── Empty ──────────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_search_rounded,
              size: 56, color: AppColors.border),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No customers found',
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Tap "New Customer" to get started',
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
            onPressed: _fetchCustomers,
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
  late Animation<double> _anim;

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