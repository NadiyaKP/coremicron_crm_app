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
import 'add_deal.dart';

// ── Hex helpers (also imported by add_deal.dart) ───────────────────────────
Color _hexToColor(String hex) {
  try {
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
    if (clean.length == 8) return Color(int.parse(clean, radix: 16));
  } catch (_) {}
  return const Color(0xFF6B7280);
}

String _colorToHex(Color c) =>
    '#${c.red.toRadixString(16).padLeft(2, '0')}'
    '${c.green.toRadixString(16).padLeft(2, '0')}'
    '${c.blue.toRadixString(16).padLeft(2, '0')}';

// ── Deal Model ─────────────────────────────────────────────────────────────
class Deal {
  final String id;
  final String dealsName;
  final String color;
  final String status;
  final String confirm;

  const Deal({
    required this.id,
    required this.dealsName,
    required this.color,
    required this.status,
    required this.confirm,
  });

  factory Deal.fromJson(Map<String, dynamic> json) => Deal(
        id:        json['id']         ?? '',
        dealsName: json['deals_name'] ?? '',
        color:     json['color']      ?? '#1E88E5',
        status:    json['status']     ?? '',
        confirm:   json['confirm']    ?? '',
      );
}

// ── Deals Page ─────────────────────────────────────────────────────────────
class DealsPage extends StatefulWidget {
  final String username;
  const DealsPage({super.key, required this.username});

  @override
  State<DealsPage> createState() => _DealsPageState();
}

class _DealsPageState extends State<DealsPage> {
  static const int _pageSize = 50;

  List<Deal> _allDeals  = [];
  List<Deal> _filtered  = [];
  bool       _isLoading = true;
  String?    _errorMessage;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int    _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _fetchDeals();
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
    _filtered = _searchQuery.isEmpty
        ? List.from(_allDeals)
        : _allDeals
            .where((d) => d.dealsName.toLowerCase().contains(_searchQuery))
            .toList();
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchDeals() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url       = Uri.parse('${ApiService.baseUrl}/api/deals/list.php');

      debugPrint('─────────────────────────────────────────');
      debugPrint('📤  [DEALS LIST] Request  URL : $url');
      debugPrint('─────────────────────────────────────────');

      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Accept':       'application/json',
        'X-Session-ID': sessionId,
        'Cookie':       'PHPSESSID=$sessionId',
      }).timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = jsonDecode(response.body);
      debugPrint('📥  [DEALS LIST] ${response.statusCode}  ${response.body}');

      if (response.statusCode == 200 && data['success'] == true) {
        final List list = data['data'] ?? [];
        _allDeals = list.map((e) => Deal.fromJson(e)).toList();
        _applyFilter();
      } else {
        _errorMessage = data['error'] ?? data['message'] ?? 'Failed to load deals.';
      }
    } on http.ClientException {
      _errorMessage = 'Unable to reach the server. Check your connection.';
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  Future<void> _deleteDeal(String id) async {
    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url       = Uri.parse('${ApiService.baseUrl}/api/deals/delete.php');
      final body      = {'id': id};

      debugPrint('📤  [DELETE DEAL] $url  ${jsonEncode(body)}');

      final response = await http.post(url,
          headers: {
            'Content-Type': 'application/json',
            'Accept':       'application/json',
            'X-Session-ID': sessionId,
            'Cookie':       'PHPSESSID=$sessionId',
          },
          body: jsonEncode(body)).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final Map<String, dynamic> data = jsonDecode(response.body);
      debugPrint('📥  [DELETE DEAL] ${response.statusCode}  ${response.body}');

      if (response.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Deal deleted successfully.');
        _fetchDeals();
      } else {
        AppSnackBar.show(context, data['error'] ?? data['message'] ?? 'Failed to delete.',
            isError: true);
      }
    } on http.ClientException {
      if (mounted)
        AppSnackBar.show(context, 'Unable to reach the server.',
            isError: true);
    } catch (_) {
      if (mounted)
        AppSnackBar.show(context, 'Something went wrong.', isError: true);
    }
  }

  // ── Open Add / Edit page ───────────────────────────────────────────────────
  Future<void> _openAddEditPage({Deal? deal}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddDealPage(username: widget.username, deal: deal),
      ),
    );
    if (result == true) _fetchDeals();
  }

  // ── Pagination ─────────────────────────────────────────────────────────────
  int get _totalPages =>
      paginationTotalPages(_filtered.length, _pageSize);
  List<Deal> get _pageItems =>
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

  // ── Delete dialog ──────────────────────────────────────────────────────────
  void _showDeleteDialog(Deal d) {
    bool isDeleting = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.error, size: 26),
                ),

                const SizedBox(height: 16),

                const Text('Delete Deal',
                    style: TextStyle(
                        color:      AppColors.textPrimary,
                        fontSize:   16,
                        fontWeight: FontWeight.w700)),

                const SizedBox(height: 10),

                Text(
                  'Are you sure you want to delete\n"${d.dealsName.capitalize()}"?\nThis action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 13.5,
                      height:   1.55),
                ),

                const SizedBox(height: 22),

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
                              borderRadius: BorderRadius.circular(11)),
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 13),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(
                                color:      AppColors.textLabel,
                                fontWeight: FontWeight.w600,
                                fontSize:   14)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isDeleting
                            ? null
                            : () async {
                                setDialogState(
                                    () => isDeleting = true);
                                Navigator.pop(dialogCtx);
                                await _deleteDeal(d.id);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          disabledBackgroundColor:
                              AppColors.error.withOpacity(0.5),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11)),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: isDeleting
                              ? const SizedBox(
                                  key: ValueKey('del-loader'),
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      color:       Colors.white,
                                      strokeWidth: 2.3))
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
                      '${_filtered.length} deal'
                      '${_filtered.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color:      AppColors.textSecondary,
                          fontSize:   12.5,
                          fontWeight: FontWeight.w500),
                    ),
                  const Spacer(),
                  _addDealButton(),
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
                          : _buildDealList(hPad),
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
          Text('Deals',
              style: TextStyle(
                  color:         AppColors.textPrimary,
                  fontSize:      isTablet ? 20 : 17,
                  fontWeight:    FontWeight.w800,
                  letterSpacing: -0.3)),
          const Spacer(),
          GestureDetector(
            onTap: _fetchDeals,
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

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
              color:  Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller:  _searchCtrl,
        style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 14),
        cursorColor: AppColors.primary,
        decoration: const InputDecoration(
          hintText:  'Search deals…',
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

  Widget _addDealButton() {
    return ElevatedButton.icon(
      onPressed: () => _openAddEditPage(),
      icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
      label: const Text('Add Deal',
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

  Widget _buildDealList(double hPad) {
    final items = _pageItems;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _dealCard(items[i]),
    );
  }

  Widget _dealCard(Deal d) {
    final dealColor = _hexToColor(d.color);
    final luminance = dealColor.computeLuminance();
    final textColor =
        luminance > 0.45 ? const Color(0xFF1A1A2E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight, width: 1),
        boxShadow: [
          BoxShadow(
              color:  Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color:        dealColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  d.dealsName.capitalize(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:      textColor,
                    fontSize:   13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionIcon(
                  icon:    Icons.edit_outlined,
                  color:   AppColors.primary,
                  bgColor: AppColors.primaryLight,
                  onTap:   () => _openAddEditPage(deal: d),
                ),
                const SizedBox(width: 6),
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
            color: bgColor, borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }

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
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
              child: _shimmer(
                  width: double.infinity, height: 36, radius: 8)),
          const SizedBox(width: 10),
          _shimmer(width: 30, height: 30, radius: 7),
          const SizedBox(width: 6),
          _shimmer(width: 30, height: 30, radius: 7),
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

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.handshake_outlined,
              size: 56, color: AppColors.border),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No deals found',
            style: const TextStyle(
                color:      AppColors.textSecondary,
                fontSize:   14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Tap "Add Deal" to get started',
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

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
            onPressed: _fetchDeals,
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