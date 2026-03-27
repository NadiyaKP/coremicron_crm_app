import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService, kTokenKey;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/screens/home.dart';
import 'package:coremicron_crm_app/screens/Registation/customer/add_customer.dart';
import 'package:coremicron_crm_app/screens/Registation/customer/customer_view.dart';
import 'package:coremicron_crm_app/screens/Registation/customer/contact_list.dart'; // ← NEW import
import 'package:coremicron_crm_app/common/pagination.dart';
import 'package:coremicron_crm_app/common/string_extensions.dart';

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
      final url = Uri.parse('${ApiService.baseUrl}/api/customer/list.php');

      debugPrint('──── API REQUEST ────────────────────────────────────────');
      debugPrint('GET ${url.toString()}');

      final response = await ApiService.get(url).timeout(const Duration(seconds: 15));

      debugPrint('──── API RESPONSE ───────────────────────────────────────');
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Body:   ${response.body}');
      debugPrint('─────────────────────────────────────────────────────────');

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
      final url  = Uri.parse('${ApiService.baseUrl}/api/customer/delete.php');
      final body = {'id': id, 'reason': reason};

      debugPrint('──── API REQUEST ────────────────────────────────────────');
      debugPrint('POST ${url.toString()}');
      debugPrint('Body:   ${jsonEncode(body)}');

      final response = await ApiService.post(url, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      debugPrint('──── API RESPONSE ───────────────────────────────────────');
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Body:   ${response.body}');
      debugPrint('─────────────────────────────────────────────────────────');

      if (!mounted) return;
      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Customer deleted successfully.');
        _fetchCustomers();
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
  int get _totalPages => paginationTotalPages(_filtered.length, _pageSize);

  List<Customer> get _pageItems =>
      paginationPageItems(_filtered, _currentPage, _pageSize);

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

  // ── Navigate: View Customer ────────────────────────────────────────────────
  void _openViewCustomer(Customer c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerViewPage(
          customerId:   c.id,
          customerName: c.name,
        ),
      ),
    );
  }

  // ── Navigate: Contact List ─────────────────────────────────────────────────
  void _openContactList(Customer c) {                              // ← NEW
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactListPage(
          customerId:   c.id,
          customerName: c.name,
        ),
      ),
    );
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

  // ── Delete dialog with reason textbox ─────────────────────────────────────
  void _showDeleteDialog(Customer c) {
    final reasonCtrl  = TextEditingController();
    final reasonFocus = FocusNode();
    bool isDeleting   = false;

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
                        c.name.capitalize(),
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
                            decoration: const InputDecoration(
                              hintText: 'Enter reason for deleting this customer…',
                              hintStyle: TextStyle(
                                  color: AppColors.textHint, fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
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
                                    final reason = reasonCtrl.text.trim();
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
                                    await _deleteCustomer(c.id, reason);
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

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name.capitalize(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),

                const SizedBox(height: 5),

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

                // ── Action icons row (now includes Contacts icon) ────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // ── NEW: Contacts icon ───────────────────────────────────
                    _actionIcon(
                      icon:    Icons.contacts_outlined,
                      color:   const Color(0xFF7C3AED),   // purple tint
                      bgColor: const Color(0xFFF3EDFF),
                      onTap:   () => _openContactList(c),
                    ),
                    const SizedBox(width: 7),
                    _actionIcon(
                      icon:    Icons.remove_red_eye_outlined,
                      color:   AppColors.success,
                      bgColor: AppColors.successBg,
                      onTap:   () => _openViewCustomer(c),
                    ),
                    const SizedBox(width: 7),
                    _actionIcon(
                      icon:    Icons.edit_outlined,
                      color:   AppColors.primary,
                      bgColor: AppColors.primaryLight,
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