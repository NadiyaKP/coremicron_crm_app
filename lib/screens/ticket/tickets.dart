import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../common/api_service.dart';
import '../../common/theme.dart';
import '../login.dart' show kSessionKey;
import '../home.dart';
import '../../common/pagination.dart';
import 'ticket_view.dart';
import 'new_ticket.dart';
import 'assign_ticket.dart';
import '../../common/string_extensions.dart';

// ── Ticket Model ───────────────────────────────────────────────────────────
class Ticket {
  final String ticketId;
  final String ticketNumber;
  final String typeOfTickets;
  final String title;
  final String notes;
  final String priority;
  final String status;
  final String customerId;
  final String taskHandlerId;
  final String addedDate;
  final String addedTime;
  final String addedBy;
  final String customerName;
  final String phoneNumber;
  final String taskHandlerName;
  final String? image;

  const Ticket({
    required this.ticketId,
    required this.ticketNumber,
    required this.typeOfTickets,
    required this.title,
    required this.notes,
    required this.priority,
    required this.status,
    required this.customerId,
    required this.taskHandlerId,
    required this.addedDate,
    required this.addedTime,
    required this.addedBy,
    required this.customerName,
    required this.phoneNumber,
    required this.taskHandlerName,
    this.image,
  });

  factory Ticket.fromJson(Map<String, dynamic> j) => Ticket(
        ticketId:        j['ticket_id']         ?? '',
        ticketNumber:    j['ticket_number']      ?? '',
        typeOfTickets:   j['type_of_tickets']    ?? '',
        title:           j['title']              ?? '',
        notes:           j['notes']              ?? '',
        priority:        j['priority']           ?? '',
        status:          j['status']             ?? '',
        customerId:      j['customer_id']        ?? '',
        taskHandlerId:   j['task_handler_id']    ?? '',
        addedDate:       j['added_date']         ?? '',
        addedTime:       j['added_time']         ?? '',
        addedBy:         j['added_by']           ?? '',
        customerName:    j['customer_name']      ?? '',
        phoneNumber:     j['phone_number']       ?? '',
        taskHandlerName: j['task_handler_name']  ?? '',
        image:           j['image'],
      );
}

// ── Tickets Page ───────────────────────────────────────────────────────────
class TicketsPage extends StatefulWidget {
  final String username;
  const TicketsPage({super.key, required this.username});

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  static const int _pageSize = 50;

  List<Ticket> _allTickets = [];
  List<Ticket> _filtered   = [];
  bool         _isLoading  = true;
  String?      _errorMessage;

  final TextEditingController _searchCtrl = TextEditingController();
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
      _filtered = List.from(_allTickets);
    } else {
      _filtered = _allTickets.where((t) =>
          t.ticketNumber.toLowerCase().contains(_searchQuery) ||
          t.title.toLowerCase().contains(_searchQuery) ||
          t.customerName.toLowerCase().contains(_searchQuery) ||
          t.phoneNumber.contains(_searchQuery) ||
          t.priority.toLowerCase().contains(_searchQuery) ||
          t.typeOfTickets.toLowerCase().contains(_searchQuery)).toList();
    }
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchTickets() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url       = Uri.parse('${ApiService.baseUrl}/api/ticket/list.php');

      debugPrint('─────────────────────────────────────────');
      debugPrint('📤  [TICKETS LIST] Request  URL : $url');
      debugPrint('─────────────────────────────────────────');

      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Accept':       'application/json',
        'X-Session-ID': sessionId,
        'Cookie':       'PHPSESSID=$sessionId',
      }).timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = jsonDecode(response.body);
      debugPrint(
          '📥  [TICKETS LIST] ${response.statusCode}  ${response.body}');

      if (response.statusCode == 200 && data['success'] == true) {
        final List list = data['tickets'] ?? [];
        _allTickets = list.map((e) => Ticket.fromJson(e)).toList();
        _applyFilter();
      } else {
        _errorMessage =
            data['error'] ?? data['message'] ?? 'Failed to load tickets.';
      }
    } on http.ClientException {
      _errorMessage = 'Unable to reach the server. Check your connection.';
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  Future<void> _deleteTicket(String ticketId, String reason) async {
    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url  = Uri.parse('${ApiService.baseUrl}/api/ticket/delete.php');
      final body = {
        'ticket_id': ticketId,
        'reason':    reason,
      };

      debugPrint('📤  [DELETE TICKET] $url  ${jsonEncode(body)}');


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
      debugPrint(
          '📥  [DELETE TICKET] ${response.statusCode}  ${response.body}');

      if (response.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Ticket deleted successfully.');
        _fetchTickets();
      } else {
        AppSnackBar.show(
            context,
            data['error'] ?? data['message'] ?? 'Failed to delete ticket.',
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

  // ── Helpers ────────────────────────────────────────────────────────────────
  // "YYYY-MM-DD" → "DD-MM-YY"
  String _fmtDate(String raw) {
    try {
      final p = raw.trim().split('-');
      if (p.length == 3) {
        final yy = p[0].length >= 4 ? p[0].substring(2) : p[0];
        return '${p[2]}-${p[1]}-$yy';
      }
    } catch (_) {}
    return raw;
  }


  // Priority colors
  Color _priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'high':   return const Color(0xFFD32F2F);
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

  // Status colors
  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'open':        return const Color(0xFF1565C0);
      case 'closed':      return const Color(0xFF2E7D32);
      case 'in_progress': return const Color(0xFFE65100);
      case 'pending':     return const Color(0xFF6A1B9A);
      default:            return AppColors.primary;
    }
  }

  Color _statusBg(String s) {
    switch (s.toLowerCase()) {
      case 'open':        return const Color(0xFFE3F2FD);
      case 'closed':      return const Color(0xFFE8F5E9);
      case 'in_progress': return const Color(0xFFFFF3E0);
      case 'pending':     return const Color(0xFFF3E5F5);
      default:            return AppColors.primaryLight;
    }
  }

  // Pagination
  int get _totalPages => paginationTotalPages(_filtered.length, _pageSize);
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
                      '${_filtered.length} ticket'
                      '${_filtered.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color:      AppColors.textSecondary,
                          fontSize:   12.5,
                          fontWeight: FontWeight.w500),
                    ),
                  const Spacer(),
                  _newTicketButton(),
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
                          : _buildTicketList(hPad),
            ),

            if (!_isLoading &&
                _errorMessage == null &&
                _filtered.isNotEmpty)
              AppPagination(
                currentPage:       _currentPage,
                totalPages:        _totalPages,
                horizontalPadding: hPad,
                onPageChanged:
                    (p) => setState(() => _currentPage = p),
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
          Text('Tickets',
              style: TextStyle(
                  color:         AppColors.textPrimary,
                  fontSize:      isTablet ? 20 : 17,
                  fontWeight:    FontWeight.w800,
                  letterSpacing: -0.3)),
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
        style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 14),
        decoration: const InputDecoration(
          hintText:  'Search by ticket no, title, customer, priority…',
          hintStyle: TextStyle(
              color: AppColors.textHint, fontSize: 12.5),
          prefixIcon: Icon(Icons.search_rounded,
              color: AppColors.iconDefault, size: 19),
          border:         InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  // ── New Ticket button ──────────────────────────────────────────────────────
  Widget _newTicketButton() {
    return ElevatedButton.icon(
      onPressed: () async {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                NewTicketPage(username: widget.username),
          ),
        );
        if (result == true) _fetchTickets();
      },
      icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
      label: const Text('New Ticket',
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

  // ── Ticket list ────────────────────────────────────────────────────────────
  Widget _buildTicketList(double hPad) {
    final items = _pageItems;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _ticketCard(items[i]),
    );
  }

  // ── Ticket card ────────────────────────────────────────────────────────────
  Widget _ticketCard(Ticket t) {
    final priorityClr = _priorityColor(t.priority);
    final priorityBg  = _priorityBg(t.priority);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
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
          // ── Top row: date (left) + ticket number badge (right) ──────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(t.ticketNumber,
                    style: const TextStyle(
                      color:      AppColors.primary,
                      fontSize:   11,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ── Title ────────────────────────────────────────────────────
          Text(
            t.title.isEmpty ? '(No title)' : t.title.capitalize(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:      t.title.isEmpty
                  ? AppColors.textMuted
                  : AppColors.textPrimary,
              fontSize:   13.5,
              fontWeight: FontWeight.w600,
              fontStyle:  t.title.isEmpty
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),

          const SizedBox(height: 5),

          // ── Customer + phone ──────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 11, color: AppColors.textMuted),
              const SizedBox(width: 3),
              Expanded(
                child: Text(t.customerName.capitalize(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color:    AppColors.textSecondary,
                        fontSize: 12)),
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

          const SizedBox(height: 7),

          // ── Priority + Type badges ────────────────────────────────────
          Row(
            children: [
              // Priority
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color:        priorityBg,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: priorityClr.withOpacity(0.3), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag_outlined,
                        size: 10, color: priorityClr),
                    const SizedBox(width: 3),
                    Text(t.priority.capitalize(),
                        style: TextStyle(
                            color:      priorityClr,
                            fontSize:   10.5,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),

              const Spacer(),

              // Type badge
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
            ],
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 7),

          // ── Action buttons row ────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // View
              _actionIcon(
                icon:    Icons.visibility_outlined,
                color:   const Color(0xFF2E7D32),
                bgColor: const Color(0xFFE8F5E9),
                onTap:   () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TicketViewPage(ticket: t),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Edit
              _actionIcon(
                icon:    Icons.edit_outlined,
                color:   AppColors.primary,
                bgColor: AppColors.primaryLight,
                onTap:   () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NewTicketPage(
                          username: widget.username, ticket: t),
                    ),
                  );
                  if (result == true) _fetchTickets();
                },
              ),
              const SizedBox(width: 6),
              // Assign to
              _actionIcon(
                icon:    Icons.person_add_outlined,
                color:   const Color(0xFF6A1B9A),
                bgColor: const Color(0xFFF3E5F5),
                onTap:   () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AssignTicketPage(ticket: t),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Delete
              _actionIcon(
                icon:    Icons.delete_outline_rounded,
                color:   AppColors.error,
                bgColor: const Color(0xFFFFF1F1),
                onTap:   () => _showDeleteDialog(t),
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
            color:        bgColor,
            borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }

  // ── Delete Dialog ──────────────────────────────────────────────────────────
  void _showDeleteDialog(Ticket t) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _DeleteTicketDialog(
        ticket: t,
        onDelete: (reason) async {
          await _deleteTicket(t.ticketId, reason);
        },
      ),
    );
  }


  Widget _dialogRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(label,
              style: const TextStyle(
                  color:      AppColors.textMuted,
                  fontSize:   12.5,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value.isEmpty ? '—' : value,
              style: const TextStyle(
                  color:      AppColors.textPrimary,
                  fontSize:   13,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  // ── Skeleton ───────────────────────────────────────────────────────────────
  Widget _buildSkeletonList(double hPad) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => _skeletonCard(),
    );
  }

  Widget _skeletonCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
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
              _shimmer(width: 70, height: 11, radius: 4),
              _shimmer(width: 36, height: 20, radius: 6),
            ],
          ),
          const SizedBox(height: 8),
          _shimmer(width: 180, height: 13, radius: 4),
          const SizedBox(height: 7),
          _shimmer(width: double.infinity, height: 11, radius: 4),
          const SizedBox(height: 8),
          Row(
            children: [
              _shimmer(width: 60, height: 20, radius: 5),
              const SizedBox(width: 6),
              _shimmer(width: 55, height: 20, radius: 5),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _shimmer(width: 30, height: 30, radius: 7),
              const SizedBox(width: 6),
              _shimmer(width: 30, height: 30, radius: 7),
              const SizedBox(width: 6),
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
          const Icon(Icons.confirmation_number_outlined,
              size: 56, color: AppColors.border),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No tickets found',
            style: const TextStyle(
                color:      AppColors.textSecondary,
                fontSize:   14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Tap "New Ticket" to get started',
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

// ── Delete Ticket Dialog ──────────────────────────────────────────────────
class _DeleteTicketDialog extends StatefulWidget {
  final Ticket ticket;
  final Future<void> Function(String reason) onDelete;

  const _DeleteTicketDialog({
    required this.ticket,
    required this.onDelete,
  });

  @override
  State<_DeleteTicketDialog> createState() => _DeleteTicketDialogState();
}

class _DeleteTicketDialogState extends State<_DeleteTicketDialog> {
  bool _isDeleting = false;
  final _reasonCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.error, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Delete Ticket',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Are you sure you want to delete this ticket?',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.5,
                      height: 1.5),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 12),
                _ticketInfoRow(Icons.tag_rounded, 'Ticket No',
                    widget.ticket.ticketNumber),
                const SizedBox(height: 8),
                _ticketInfoRow(Icons.person_outline_rounded, 'Customer',
                    widget.ticket.customerName.capitalize()),
                const SizedBox(height: 8),
                _ticketInfoRow(Icons.phone_outlined, 'Phone',
                    widget.ticket.phoneNumber),
                const SizedBox(height: 16),
                const Text(
                  'Reason for deletion',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _reasonCtrl,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Type a reason here...',
                    hintStyle:
                        const TextStyle(color: AppColors.textHint, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide:
                          const BorderSide(color: AppColors.border, width: 1.2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide:
                          const BorderSide(color: AppColors.border, width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter a reason'
                      : null,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isDeleting ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.border, width: 1.3),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11)),
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
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
                        onPressed: _isDeleting
                            ? null
                            : () async {
                                if (_formKey.currentState!.validate()) {
                                  setState(() => _isDeleting = true);
                                  await widget.onDelete(_reasonCtrl.text.trim());
                                  if (mounted) Navigator.pop(context);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          disabledBackgroundColor:
                              AppColors.error.withOpacity(0.5),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11)),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _isDeleting
                              ? const SizedBox(
                                  key: ValueKey('del-loader'),
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.3))
                              : const Text('Delete',
                                  key: ValueKey('del-label'),
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
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

  Widget _ticketInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text('$label: ',
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
        ),
      ],
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