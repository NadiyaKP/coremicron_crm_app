import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/common/string_extensions.dart';

// ── Models ─────────────────────────────────────────────────────────────────
class _CustomerDetail {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String status;
  final String confirm;

  const _CustomerDetail({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.status,
    required this.confirm,
  });

  factory _CustomerDetail.fromJson(Map<String, dynamic> j) => _CustomerDetail(
        id:      j['id']            ?? '',
        name:    j['customer_name'] ?? '',
        phone:   j['phone_number']  ?? '',
        email:   j['email']         ?? '',
        address: j['address']       ?? '',
        status:  j['status']        ?? '',
        confirm: j['confirm']       ?? '',
      );
}

class _Enquiry {
  final String id;
  final String enquiryNumber;
  final String title;
  final String enquiry;
  final String assignName;
  final String addedName;
  final String addedDate;
  final String addedTime;
  final String status;

  const _Enquiry({
    required this.id,
    required this.enquiryNumber,
    required this.title,
    required this.enquiry,
    required this.assignName,
    required this.addedName,
    required this.addedDate,
    required this.addedTime,
    required this.status,
  });

  factory _Enquiry.fromJson(Map<String, dynamic> j) => _Enquiry(
        id:            j['id']            ?? '',
        enquiryNumber: j['enquiry_number'] ?? '',
        title:         j['title']         ?? '',
        enquiry:       j['enquiry']        ?? '',
        assignName:    j['assign_name']   ?? '',
        addedName:     j['added_name']    ?? '',
        addedDate:     j['added_date']    ?? '',
        addedTime:     j['added_time']    ?? '',
        status:        j['status']        ?? '',
      );
}

class _Ticket {
  final String compId;
  final String ticketNumber;
  final String typeOfTickets;
  final String title;
  final String priority;
  final String taskHandlerName;
  final String addedName;
  final String addedDate;
  final String status;

  const _Ticket({
    required this.compId,
    required this.ticketNumber,
    required this.typeOfTickets,
    required this.title,
    required this.priority,
    required this.taskHandlerName,
    required this.addedName,
    required this.addedDate,
    required this.status,
  });

  factory _Ticket.fromJson(Map<String, dynamic> j) => _Ticket(
        compId:          j['compid']           ?? '',
        ticketNumber:    j['ticket_number']    ?? '',
        typeOfTickets:   j['type_of_tickets']  ?? '',
        title:           j['title']            ?? '',
        priority:        j['priority']         ?? '',
        taskHandlerName: j['task_handler_name'] ?? '',
        addedName:       j['added_name']        ?? '',
        addedDate:       j['added_date']        ?? '',
        status:          j['status']            ?? '',
      );
}

// ── Customer View Page ─────────────────────────────────────────────────────
class CustomerViewPage extends StatefulWidget {
  final String customerId;
  final String customerName;

  const CustomerViewPage({
    super.key,
    required this.customerId,
    this.customerName = '',
  });

  @override
  State<CustomerViewPage> createState() => _CustomerViewPageState();
}

class _CustomerViewPageState extends State<CustomerViewPage>
    with SingleTickerProviderStateMixin {
  _CustomerDetail? _customer;
  List<_Enquiry>   _enquiries = [];
  List<_Ticket>    _tickets   = [];
  bool             _isLoading = true;
  String?          _errorMessage;

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _fetchCustomer();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchCustomer() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/customer/view.php'
          '?customer_id=${widget.customerId}');

      debugPrint('📤  [CUSTOMER VIEW] $url');
      final res = await ApiService.get(url)
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint('📥  [CUSTOMER VIEW] ${res.statusCode}  ${res.body}');

      if (res.statusCode == 200 && data['success'] == true) {
        _customer  = _CustomerDetail.fromJson(
            data['customer'] as Map<String, dynamic>);
        _enquiries = (data['enquiries'] as List? ?? [])
            .map((e) => _Enquiry.fromJson(e)).toList();
        _tickets   = (data['tickets'] as List? ?? [])
            .map((e) => _Ticket.fromJson(e)).toList();
      } else {
        _errorMessage =
            data['error'] ?? data['message'] ?? 'Failed to load customer.';
      }
    } on http.ClientException {
      _errorMessage = 'Unable to reach the server. Check your connection.';
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    }
    if (mounted) setState(() => _isLoading = false);
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

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'active':    return const Color(0xFF2E7D32);
      case 'open':      return const Color(0xFF0277BD);
      case 'rejected':  return const Color(0xFFC62828);
      case 'closed':    return const Color(0xFF6A1B9A);
      case 'pending':   return const Color(0xFFE65100);
      case 'completed': return const Color(0xFF2E7D32);
      default:          return AppColors.primary;
    }
  }

  Color _statusBg(String s) {
    switch (s.toLowerCase()) {
      case 'active':    return const Color(0xFFE8F5E9);
      case 'open':      return const Color(0xFFE1F5FE);
      case 'rejected':  return const Color(0xFFFFF1F1);
      case 'closed':    return const Color(0xFFF3E5F5);
      case 'pending':   return const Color(0xFFFFF3E0);
      case 'completed': return const Color(0xFFE8F5E9);
      default:          return AppColors.primaryLight;
    }
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
            _buildAppBar(isTablet, hPad),

            if (_isLoading)
              const Expanded(child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2.4)))
            else if (_errorMessage != null)
              Expanded(child: _buildError())
            else
              Expanded(
                child: Column(
                  children: [
                    // ── Customer Info Card ─────────────────────────────
                    _buildInfoCard(hPad),

                    // ── Tab Bar ────────────────────────────────────────
                    Container(
                      color: Colors.white,
                      child: TabBar(
                        controller:         _tabCtrl,
                        labelColor:         AppColors.primary,
                        unselectedLabelColor: AppColors.textMuted,
                        indicatorColor:     AppColors.primary,
                        indicatorWeight:    2.5,
                        labelStyle: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700),
                        unselectedLabelStyle: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w500),
                        tabs: [
                          Tab(text:
                              'Enquiries (${_enquiries.length})'),
                          Tab(text:
                              'Tickets (${_tickets.length})'),
                        ],
                      ),
                    ),

                    // ── Tab Content ────────────────────────────────────
                    Expanded(
                      child: TabBarView(
                        controller: _tabCtrl,
                        children: [
                          _buildEnquiriesList(hPad),
                          _buildTicketsList(hPad),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────────
  Widget _buildAppBar(bool isTablet, double hPad) {
    final name = _customer?.name ?? widget.customerName;
    return Container(
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
                border: Border.all(color: AppColors.border, width: 1.2),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 15, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Customer Details' : name.capitalize(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color:         AppColors.textPrimary,
                      fontSize:      isTablet ? 19 : 16,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: -0.3),
                ),
                const Text('Customer Profile',
                    style: TextStyle(
                        color:    AppColors.textSecondary,
                        fontSize: 11.5)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _fetchCustomer,
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

  // ── Info Card ──────────────────────────────────────────────────────────────
  Widget _buildInfoCard(double hPad) {
    final c = _customer!;
    final stClr = _statusColor(c.status);
    final stBg  = _statusBg(c.status);

    return Container(
      margin: EdgeInsets.fromLTRB(hPad, 14, hPad, 0),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight, width: 1),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset:     const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 50, height: 50,
            decoration: const BoxDecoration(
                color: AppColors.primaryLight, shape: BoxShape.circle),
            child: Center(
              child: Text(
                c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color:      AppColors.primary,
                    fontSize:   20,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + status
                Row(
                  children: [
                    Expanded(
                      child: Text(c.name.capitalize(),
                          style: const TextStyle(
                              color:      AppColors.textPrimary,
                              fontSize:   15,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:        stBg,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: stClr.withOpacity(0.3), width: 1),
                      ),
                      child: Text(c.status.capitalize(),
                          style: TextStyle(
                              color:      stClr,
                              fontSize:   10.5,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Phone
                if (c.phone.isNotEmpty)
                  _infoRow(Icons.phone_outlined, c.phone),

                // Email
                if (c.email.isNotEmpty)
                  _infoRow(Icons.email_outlined, c.email),

                // Address
                if (c.address.isNotEmpty)
                  _infoRow(Icons.location_on_outlined,
                      c.address.capitalize()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color:    AppColors.textSecondary,
                    fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  // ── Enquiries List ─────────────────────────────────────────────────────────
  Widget _buildEnquiriesList(double hPad) {
    if (_enquiries.isEmpty) {
      return _buildTabEmpty('No enquiries found for this customer.');
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 20),
      itemCount: _enquiries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _enquiryCard(_enquiries[i]),
    );
  }

  Widget _enquiryCard(_Enquiry e) {
    final stClr = _statusColor(e.status);
    final stBg  = _statusBg(e.status);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
          // ── Top row: enquiry number + status ────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color:        stBg,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: stClr.withOpacity(0.3), width: 1),
                ),
                child: Text(e.status.capitalize(),
                    style: TextStyle(
                        color:      stClr,
                        fontSize:   10.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),

          const SizedBox(height: 7),

          // ── Title ──────────────────────────────────────────────────
          Text(
            e.title.isEmpty ? '(No title)' : e.title.capitalize(),
            style: TextStyle(
                color:      e.title.isEmpty
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
                fontSize:   13.5,
                fontWeight: FontWeight.w700,
                fontStyle:  e.title.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal),
          ),

          // ── Enquiry text ───────────────────────────────────────────
          if (e.enquiry.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              e.enquiry.trim().capitalize(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color:    AppColors.textSecondary,
                  fontSize: 12.5,
                  height:   1.4),
            ),
          ],

          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 7),

          // ── Bottom meta row ────────────────────────────────────────
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _metaChip(Icons.person_outline_rounded,
                  'Assigned', e.assignName.capitalize()),
              _metaChip(Icons.person_pin_outlined,
                  'Added by', e.addedName.capitalize()),
              _metaChip(Icons.calendar_today_outlined,
                  'Date', _fmtDate(e.addedDate)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tickets List ───────────────────────────────────────────────────────────
  Widget _buildTicketsList(double hPad) {
    if (_tickets.isEmpty) {
      return _buildTabEmpty('No tickets found for this customer.');
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 20),
      itemCount: _tickets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _ticketCard(_tickets[i]),
    );
  }

  Widget _ticketCard(_Ticket t) {
    final stClr = _statusColor(t.status);
    final stBg  = _statusBg(t.status);
    final prClr = _priorityColor(t.priority);
    final prBg  = _priorityBg(t.priority);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
          // ── Top row: ticket number + priority + status ──────────────
          Row(
            children: [
              Container(
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
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
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
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color:        stBg,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: stClr.withOpacity(0.3), width: 1),
                ),
                child: Text(t.status.capitalize(),
                    style: TextStyle(
                        color:      stClr,
                        fontSize:   10.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),

          const SizedBox(height: 7),

          // ── Title + type chip in same row ─────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  t.title.isEmpty ? '(No title)' : t.title.capitalize(),
                  style: TextStyle(
                      color:      t.title.isEmpty
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                      fontSize:   13.5,
                      fontWeight: FontWeight.w700,
                      fontStyle:  t.title.isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color:        AppColors.background,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: AppColors.borderLight, width: 1),
                ),
                child: Text(t.typeOfTickets.capitalize(),
                    style: const TextStyle(
                        color:      AppColors.textSecondary,
                        fontSize:   10.5,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 7),

          // ── Bottom meta row ────────────────────────────────────────
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (t.taskHandlerName.isNotEmpty)
                _metaChip(Icons.manage_accounts_outlined,
                    'Handler', t.taskHandlerName.capitalize()),
              _metaChip(Icons.person_pin_outlined,
                  'Added by', t.addedName.capitalize()),
              _metaChip(Icons.calendar_today_outlined,
                  'Date', _fmtDate(t.addedDate)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Shared ─────────────────────────────────────────────────────────────────
  Widget _metaChip(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppColors.textMuted),
        const SizedBox(width: 3),
        Text('$label: ',
            style: const TextStyle(
                color:    AppColors.textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w500)),
        Text(value.isEmpty ? '—' : value,
            style: const TextStyle(
                color:      AppColors.textPrimary,
                fontSize:   11.5,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildTabEmpty(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined,
              size: 48, color: AppColors.border),
          const SizedBox(height: 12),
          Text(msg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color:    AppColors.textSecondary,
                  fontSize: 13.5)),
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
            onPressed: _fetchCustomer,
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