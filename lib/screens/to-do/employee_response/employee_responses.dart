import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService, kTokenKey;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/screens/login.dart' show kTokenKey;
import 'package:coremicron_crm_app/common/pagination.dart';
import 'package:coremicron_crm_app/common/string_extensions.dart';
import 'package:coremicron_crm_app/screens/ticket/ticket_view.dart';
import 'package:coremicron_crm_app/screens/ticket/tickets.dart' show Ticket;
import 'package:coremicron_crm_app/screens/to-do/employee_response/give_employee_response.dart';

// ── Employee Response Model ────────────────────────────────────────────────
class EmployeeResponse {
  final String communicationId;
  final String jobId;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String? receiverName;
  final String ticketId;
  final String ticketNumber;
  final String message;
  final String response;
  final String? image;
  final String? responseImage;
  final String messageStatus;
  final String responseStatus;
  final String addedDate;
  final String addedTime;

  EmployeeResponse({
    required this.communicationId,
    required this.jobId,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    this.receiverName,
    required this.ticketId,
    required this.ticketNumber,
    required this.message,
    required this.response,
    this.image,
    this.responseImage,
    required this.messageStatus,
    required this.responseStatus,
    required this.addedDate,
    required this.addedTime,
  });

  factory EmployeeResponse.fromJson(Map<String, dynamic> j) => EmployeeResponse(
        communicationId: j['communication_id'] ?? '',
        jobId:           j['job_id']           ?? '',
        senderId:        j['sender_id']        ?? '',
        senderName:      j['sender_name']      ?? '',
        receiverId:      j['receiver_id']      ?? '',
        receiverName:    j['receiver_name'],
        ticketId:        j['ticket_id']        ?? '',
        ticketNumber:    j['ticket_number']    ?? '',
        message:         j['message']          ?? '',
        response:        j['response']         ?? '',
        image:           j['image'],
        responseImage:   j['response_image'],
        messageStatus:   j['message_status']   ?? '',
        responseStatus:  j['response_status']  ?? '',
        addedDate:       j['added_date']       ?? '',
        addedTime:       j['added_time']       ?? '',
      );
}

// ── Employee Responses Page ────────────────────────────────────────────────
class EmployeeResponsesPage extends StatefulWidget {
  final String username;
  final String? highlightId;
  const EmployeeResponsesPage({super.key, required this.username, this.highlightId});

  @override
  State<EmployeeResponsesPage> createState() => _EmployeeResponsesPageState();
}

class _EmployeeResponsesPageState extends State<EmployeeResponsesPage> {
  static const int _pageSize = 50;

  List<EmployeeResponse> _allResponses = [];
  List<EmployeeResponse> _filtered     = [];
  List<Ticket>           _allTickets   = [];
  bool                  _isLoading     = true;
  String?               _errorMessage;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int    _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _fetchResponses();
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
      _filtered = List.from(_allResponses);
    } else {
      _filtered = _allResponses.where((r) =>
          r.ticketNumber.toLowerCase().contains(_searchQuery) ||
          r.senderName.toLowerCase().contains(_searchQuery) ||
          r.message.toLowerCase().contains(_searchQuery) ||
          r.response.toLowerCase().contains(_searchQuery)).toList();
    }
  }

  Future<void> _fetchResponses() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      // 1. Fetch tickets first for lookup
      final ticketUrl = Uri.parse('${ApiService.baseUrl}/api/ticket/list.php');
      final tRes = await ApiService.get(ticketUrl).timeout(const Duration(seconds: 15));
      if (tRes.statusCode == 200) {
        final tData = jsonDecode(tRes.body);
        if (tData['success'] == true) {
          final List tList = tData['tickets'] ?? [];
          _allTickets = tList.map((e) => Ticket.fromJson(e)).toList();
        }
      }

      // 2. Fetch communications
      final url = Uri.parse('${ApiService.baseUrl}/api/ticket/communication_list.php?mode=inbox');
      final response = await ApiService.get(url).timeout(const Duration(seconds: 15));

      debugPrint('📥  [EMPLOYEE RESPONSE] ${response.statusCode}  ${response.body}');
      
      if (response.body.trim().isEmpty) {
        throw Exception('Server returned an empty response body.');
      }
      
      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final List list = data['communications'] ?? [];
        _allResponses = list.map((e) => EmployeeResponse.fromJson(e)).toList();
        _applyFilter();
      } else {
        _errorMessage = data['error'] ?? data['message'] ?? 'Failed to load responses.';
      }
    } on http.ClientException catch (e) {
      debugPrint('❌  [EMPLOYEE RESPONSE] ClientException: $e');
      _errorMessage = 'Unable to reach the server. Check your connection.';
    } catch (e) {
      debugPrint('❌  [EMPLOYEE RESPONSE] Unexpected Error: $e');
      _errorMessage = 'Something went wrong: $e';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  String _fmtDate(String raw) {
    try {
      final p = raw.trim().split('-');
      if (p.length == 3) {
        return '${p[2]}-${p[1]}-${p[0].substring(2)}';
      }
    } catch (_) {}
    return raw;
  }

  int get _totalPages => paginationTotalPages(_filtered.length, _pageSize);
  List<EmployeeResponse> get _pageItems =>
      paginationPageItems(_filtered, _currentPage, _pageSize);

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
                      '${_filtered.length} response'
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
                          : _buildResponseList(hPad),
            ),
            if (!_isLoading && _errorMessage == null && _filtered.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: AppPagination(
                  currentPage:       _currentPage,
                  totalPages:        _totalPages,
                  horizontalPadding: hPad,
                  onPageChanged:     (p) => setState(() => _currentPage = p),
                ),
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
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
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
          Text('Employee Response',
              style: TextStyle(
                  color:         AppColors.textPrimary,
                  fontSize:      isTablet ? 20 : 17,
                  fontWeight:    FontWeight.w800,
                  letterSpacing: -0.3)),
          const Spacer(),
          GestureDetector(
            onTap: _fetchResponses,
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

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: TextField(
        controller:  _searchCtrl,
        cursorColor: AppColors.primary,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: const InputDecoration(
          hintText:  'Search by ticket, sender, message…',
          hintStyle: TextStyle(color: AppColors.textHint, fontSize: 12.5),
          prefixIcon: Icon(Icons.search_rounded, color: AppColors.iconDefault, size: 19),
          border:         InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildResponseList(double hPad) {
    final items = _pageItems;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _responseCard(items[i]),
    );
  }

  Widget _responseCard(EmployeeResponse r) {
    final bool isDone = r.messageStatus.toLowerCase() == 'yes';
    final Color borderColor = isDone ? const Color(0xFF2E7D32) : const Color(0xFFE65100);
    final bool isHighlighted = widget.highlightId == r.communicationId;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? AppColors.primary : borderColor.withOpacity(0.5),
          width: isHighlighted ? 2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset:     const Offset(0, 3)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _navigateToTicket(r),
                child: Text(
                  '#${r.ticketNumber}',
                  style: const TextStyle(
                      color:          Color(0xFF1565C0),
                      fontSize:       13,
                      fontWeight:     FontWeight.w700,
                      decoration:     TextDecoration.underline,
                      decorationColor: Color(0xFF1565C0)),
                ),
              ),
              Text(
                _fmtDate(r.addedDate),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color:        AppColors.primaryLight,
                  shape:        BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    r.senderName.isNotEmpty ? r.senderName[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                r.senderName.capitalize(),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GiveEmployeeResponsePage(response: r),
                    ),
                  );
                  if (result == true) {
                    _fetchResponses();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:        AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border:       Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.reply_rounded, size: 18, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showDetailDialog(r),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:        AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border:       Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.mark_chat_read_outlined, size: 18, color: AppColors.primary),
                ),
              ),
            ],
          ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(EmployeeResponse r) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.forum_outlined, color: AppColors.primary),
            const SizedBox(width: 10),
            const Text('Communication Detail', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r.message.isNotEmpty || (r.image != null && r.image!.isNotEmpty && r.image != 'null'))
                Flexible(
                  child: SingleChildScrollView(
                    child: _dialogSection(Icons.message_outlined, 'Message', r.message, r.image),
                  ),
                ),
              if ((r.message.isNotEmpty || (r.image != null && r.image!.isNotEmpty && r.image != 'null')) &&
                  (r.response.isNotEmpty || (r.responseImage != null && r.responseImage!.isNotEmpty && r.responseImage != 'null')))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(),
                ),
              if (r.response.isNotEmpty || (r.responseImage != null && r.responseImage!.isNotEmpty && r.responseImage != 'null'))
                Flexible(
                  child: SingleChildScrollView(
                    child: _dialogSection(Icons.reply_all_rounded, 'Response', r.response, r.responseImage, isResponse: true),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _dialogSection(IconData icon, String label, String text, String? image, {bool isResponse = false}) {
    final Color color = isResponse ? const Color(0xFF2E7D32) : AppColors.textPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
        if (text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, height: 1.5),
            ),
          ),
        if (image != null && image.isNotEmpty && image != 'null')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: () => _viewImage(image),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:        Colors.blue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(6),
                  border:       Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.attachment_rounded, size: 12, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text('Attachment', style: TextStyle(color: Colors.blue, fontSize: 10.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _viewImage(String imageUrl) {
    // Existing _viewImage implementation from common pattern (already in file)
    final fullUrl = imageUrl.startsWith('http') ? imageUrl : '${ApiService.baseUrl}/uploads/$imageUrl';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                fullUrl,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                },
                errorBuilder: (context, error, stackTrace) => const Center(child: Text('Failed to load image', style: TextStyle(color: Colors.white))),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToTicket(EmployeeResponse r) {
    // Try to find the full ticket details from the fetched list
    Ticket? fullTicket;
    try {
      fullTicket = _allTickets.firstWhere((t) => t.ticketId == r.ticketId);
    } catch (_) {}

    if (fullTicket != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => TicketViewPage(ticket: fullTicket!)));
      return;
    }

    // Fallback if not found in the list (though it should be)
    final ticket = Ticket(
      ticketId:        r.ticketId,
      ticketNumber:    r.ticketNumber,
      typeOfTickets:   '',
      title:           '',
      notes:           '',
      priority:        '',
      status:          '',
      customerId:      '',
      taskHandlerId:   '',
      addedDate:       r.addedDate,
      addedTime:       r.addedTime,
      addedBy:         '',
      customerName:    '',
      phoneNumber:     '',
      taskHandlerName: '',
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => TicketViewPage(ticket: ticket)));
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.forum_outlined, size: 52, color: AppColors.border),
          SizedBox(height: 14),
          Text('No responses found', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(_errorMessage ?? '', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchResponses, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList(double hPad) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
      itemCount: 5,
      itemBuilder: (_, __) => _skeletonCard(),
    );
  }

  Widget _skeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _shimmer(width: 60, height: 20, radius: 6),
              _shimmer(width: 80, height: 12, radius: 4),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _shimmer(width: 32, height: 32, radius: 16),
              const SizedBox(width: 10),
              _shimmer(width: 100, height: 14, radius: 4),
            ],
          ),
          const SizedBox(height: 15),
          _shimmer(width: double.infinity, height: 12, radius: 4),
          const SizedBox(height: 8),
          _shimmer(width: 200, height: 12, radius: 4),
        ],
      ),
    );
  }

  Widget _shimmer({required double width, required double height, double radius = 0}) {
    return Container(
      width: width, height: height,
      decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(radius)),
    );
  }
}
