import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService, kTokenKey;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/screens/login.dart' show kUsernameKey;
import 'package:coremicron_crm_app/screens/home.dart';
import 'package:coremicron_crm_app/common/pagination.dart';
import 'package:coremicron_crm_app/common/string_extensions.dart';
import 'package:coremicron_crm_app/screens/ticket/tickets.dart' show Ticket;
import 'package:coremicron_crm_app/screens/ticket/assign_ticket.dart';
import 'package:coremicron_crm_app/screens/ticket/amc_details.dart';
import 'package:coremicron_crm_app/screens/ticket/ticket_view.dart';
import 'package:coremicron_crm_app/screens/Registation/customer/contact_list.dart';
import 'my_project_view.dart';

// ── Ticket Model ───────────────────────────────────────────────────────────

// ── My Projects Page ───────────────────────────────────────────────────────
class MyProjectsPage extends StatefulWidget {
  final String username;
  final String? highlightId;
  const MyProjectsPage({super.key, required this.username, this.highlightId});

  @override
  State<MyProjectsPage> createState() => _MyProjectsPageState();
}

class _MyProjectsPageState extends State<MyProjectsPage> {
  static const int _pageSize = 50;

  List<Ticket> _all      = [];
  List<Ticket> _filtered = [];
  bool          _isLoading = true;
  String?       _errorMessage;

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int    _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _fetchTickets();
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
      _filtered = _all.where((t) =>
          t.ticketNumber.contains(_searchQuery) ||
          t.title.toLowerCase().contains(_searchQuery) ||
          t.customerName.toLowerCase().contains(_searchQuery) ||
          t.phoneNumber.contains(_searchQuery) ||
          t.priority.toLowerCase().contains(_searchQuery) ||
          t.status.toLowerCase().contains(_searchQuery)).toList();
    }
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchTickets() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/ticket/list.php?mode=my_assigned');

      final res = await ApiService.get(url).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [MY PROJECTS] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        final list = data['tickets'] as List? ?? [];
        _all = list.map((e) => Ticket.fromJson(e)).toList();
        _applyFilter();
      } else {
        _errorMessage =
            data['error'] ?? data['message'] ?? 'Failed to load projects.';
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
  List<Ticket> get _pageItems =>
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

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return '—';
    try {
      final p = raw.trim().split('-');
      if (p.length == 3) return '${p[2]}-${p[1]}-${p[0]}';
    } catch (_) {}
    return raw;
  }

  Color _priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'high':   return const Color(0xFFC62828);
      case 'medium': return const Color(0xFFE65100);
      case 'low':    return const Color(0xFF2E7D32);
      default:       return AppColors.primary;
    }
  }

  Color _priorityBg(String p) {
    switch (p.toLowerCase()) {
      case 'high':   return const Color(0xFFFFF1F1);
      case 'medium': return const Color(0xFFFFF3E0);
      case 'low':    return const Color(0xFFE8F5E9);
      default:       return AppColors.primaryLight;
    }
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'active':    return const Color(0xFF2E7D32);
      case 'completed': return AppColors.primary;
      case 'pending':   return const Color(0xFFE65100);
      case 'inactive':  return AppColors.textMuted;
      default:          return AppColors.primary;
    }
  }

  Color _statusBg(String s) {
    switch (s.toLowerCase()) {
      case 'active':    return const Color(0xFFE8F5E9);
      case 'completed': return AppColors.primaryLight;
      case 'pending':   return const Color(0xFFFFF3E0);
      case 'inactive':  return const Color(0xFFF5F5F5);
      default:          return AppColors.primaryLight;
    }
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
              padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 0),
              child: Row(
                children: [
                  if (!_isLoading)
                    Text(
                      '${_filtered.length} project'
                      '${_filtered.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color:      AppColors.textSecondary,
                          fontSize:   12.5,
                          fontWeight: FontWeight.w500),
                    ),
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
                          : _buildList(hPad),
            ),

            if (!_isLoading && _errorMessage == null && _filtered.isNotEmpty)
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
              Text('My Projects',
                  style: TextStyle(
                      color:         AppColors.textPrimary,
                      fontSize:      isTablet ? 20 : 17,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: -0.3)),
              const Text('Assigned tickets',
                  style: TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 11.5)),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _fetchTickets,
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
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: const InputDecoration(
          hintText:  'Search by number, title, customer, priority…',
          hintStyle: TextStyle(color: AppColors.textHint, fontSize: 12.5),
          prefixIcon: Icon(Icons.search_rounded,
              color: AppColors.iconDefault, size: 19),
          border:         InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  // ── List ───────────────────────────────────────────────────────────────────
  Widget _buildList(double hPad) {
    final items = _pageItems;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _ticketCard(items[i]),
    );
  }

  // ── Card ───────────────────────────────────────────────────────────────────
  Widget _ticketCard(Ticket t) {
    final prClr = _priorityColor(t.priority);
    final prBg  = _priorityBg(t.priority);
    final bool isHighlighted = widget.highlightId == t.ticketId;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? AppColors.primary : AppColors.borderLight,
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset:     const Offset(0, 2)),
        ],
      ),
      child: Stack(
        children: [
          if (isHighlighted)
            Positioned(
              top: 0, left: 0,
              child: Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // ── Top row: ticket badge + date + priority ────────────────────
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TicketViewPage(ticket: t),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:        AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('#${t.ticketNumber}',
                      style: const TextStyle(
                          color:      AppColors.primary,
                          fontSize:   11,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline)),
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 11, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text(_fmtDate(t.addedDate),
                      style: const TextStyle(
                          color:    AppColors.textMuted,
                          fontSize: 11)),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color:        prBg,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: prClr.withOpacity(0.3), width: 1),
                ),
                child: Text(t.priority.capitalize(),
                    style: TextStyle(
                        color:      prClr,
                        fontSize:   10.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),

          const SizedBox(height: 7),

          // ── Title ──────────────────────────────────────────────────────
          Text(
            t.title.isEmpty ? '(No title)' : t.title.capitalize(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:      t.title.isEmpty
                  ? AppColors.textMuted
                  : AppColors.textPrimary,
              fontSize:   13.5,
              fontWeight: FontWeight.w700,
              fontStyle:  t.title.isEmpty
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),

          const SizedBox(height: 5),

          // ── Customer + phone ───────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 11, color: AppColors.textMuted),
              const SizedBox(width: 3),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ContactListPage(
                          customerId:   t.customerId,
                          customerName: t.customerName,
                          readOnly:     true,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    t.customerName.capitalize(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color:      AppColors.primary,
                        fontSize:   12,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.phone_outlined,
                  size: 11, color: AppColors.textMuted),
              const SizedBox(width: 3),
              Text(t.phoneNumber,
                  style: const TextStyle(
                      color:    AppColors.textSecondary,
                      fontSize: 12)),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 7),

          // ── Bottom row: view first, then assign task or AMC Details ───────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Ticket type badge
              if (t.typeOfTickets.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color:        const Color(0xFFF0F0F5),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(t.typeOfTickets,
                      style: const TextStyle(
                          color:      AppColors.textLabel,
                          fontSize:   10.5,
                          fontWeight: FontWeight.w500)),
                ),
              const Spacer(),
              // View
              _actionIcon(
                icon:    Icons.visibility_outlined,
                color:   const Color(0xFF2E7D32),
                bgColor: const Color(0xFFE8F5E9),
                onTap:   () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyProjectViewPage(
                      ticketId:     t.ticketId,
                      ticketNumber: t.ticketNumber,
                      title:        t.title,
                      typeOfTicket: t.typeOfTickets,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Conditional Action: Assign Task or AMC Details
              t.typeOfTickets.toUpperCase() == 'AMC'
                  ? _actionIcon(
                      icon:    Icons.list_alt_rounded,
                      color:   AppColors.primary,
                      bgColor: AppColors.primaryLight,
                      onTap:   () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AmcDetailsPage(
                            ticketId:     t.ticketId,
                            ticketNumber: t.ticketNumber,
                          ),
                        ),
                      ),
                    )
                  : _actionIcon(
                      icon:    Icons.person_add_outlined,
                      color:   const Color(0xFF6A1B9A),
                      bgColor: const Color(0xFFF3E5F5),
                      onTap:   () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AssignTicketPage(ticket: t),
                          ),
                        );
                        _fetchTickets();
                      },
                    ),
            ],
          ),
            ],
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _shimmer(width: 44, height: 20, radius: 6),
              const SizedBox(width: 6),
              _shimmer(width: 70, height: 11, radius: 4),
              const Spacer(),
              _shimmer(width: 56, height: 20, radius: 5),
            ],
          ),
          const SizedBox(height: 8),
          _shimmer(width: 160, height: 13, radius: 4),
          const SizedBox(height: 6),
          _shimmer(width: double.infinity, height: 11, radius: 4),
          const SizedBox(height: 10),
          Row(
            children: [
              _shimmer(width: 54, height: 20, radius: 5),
              const Spacer(),
              _shimmer(width: 30, height: 30, radius: 7),
              const SizedBox(width: 6),
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
          const Icon(Icons.work_outline_rounded,
              size: 56, color: AppColors.border),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No projects found',
            style: const TextStyle(
                color:      AppColors.textSecondary,
                fontSize:   14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Assigned projects will appear here',
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
            onPressed: _fetchTickets,
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