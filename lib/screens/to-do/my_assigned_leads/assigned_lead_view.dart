import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../common/api_service.dart';
import '../../../common/theme.dart';
import '../../login.dart' show kSessionKey;
import '../../../common/string_extensions.dart';

// ── Assign Lead View Page ──────────────────────────────────────────────────
class AssignLeadViewPage extends StatefulWidget {
  final String enquiryId;
  final String enquiryNumber;
  final String dealName;
  final String dealColor;

  const AssignLeadViewPage({
    super.key,
    required this.enquiryId,
    required this.enquiryNumber,
    this.dealName  = '',
    this.dealColor = '',
  });

  @override
  State<AssignLeadViewPage> createState() => _AssignLeadViewPageState();
}

class _AssignLeadViewPageState extends State<AssignLeadViewPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  bool    _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic> _enquiry = {};
  List<dynamic>        _history = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _fetchTrackHistory();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchTrackHistory() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url       = Uri.parse(
          '${ApiService.baseUrl}/api/leads/track_history.php'
          '?enquiry_id=${widget.enquiryId}');

      debugPrint('─────────────────────────────────────────');
      debugPrint('📤  [ASSIGN LEAD VIEW] Request');
      debugPrint('   🌐  URL : $url');
      debugPrint('─────────────────────────────────────────');

      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Accept':       'application/json',
        'X-Session-ID': sessionId,
        'Cookie':       'PHPSESSID=$sessionId',
      }).timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = jsonDecode(response.body);
      debugPrint(
          '📥  [ASSIGN LEAD VIEW] ${response.statusCode}  ${response.body}');

      if (response.statusCode == 200 && data['success'] == true) {
        final d = data['data'] ?? {};
        _enquiry = d['enquiry'] ?? {};
        _history = d['history'] ?? [];
      } else {
        _errorMessage =
            data['error'] ?? data['message'] ?? 'Failed to load details.';
      }
    } on http.ClientException {
      _errorMessage = 'Unable to reach the server. Check your connection.';
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _str(dynamic v) => (v ?? '').toString().trim();

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'active' || s == 'completed') return AppColors.success;
    if (s.contains('pending')) return const Color(0xFFE65100);
    if (s == 'inactive' || s == 'cancelled') return AppColors.error;
    return AppColors.primary;
  }

  Color _statusBg(String status) {
    final s = status.toLowerCase();
    if (s == 'active' || s == 'completed') return AppColors.successBg;
    if (s.contains('pending')) return const Color(0xFFFFF3E0);
    if (s == 'inactive' || s == 'cancelled') return const Color(0xFFFFF1F1);
    return AppColors.primaryLight;
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
            _buildTabBar(),
            Expanded(
              child: _isLoading
                  ? _buildLoading()
                  : _errorMessage != null
                      ? _buildError()
                      : TabBarView(
                          controller: _tabCtrl,
                          children: [
                            _buildLeadDetails(hPad),
                            _buildTrackHistory(hPad),
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
            onTap: () => Navigator.pop(context),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lead ${_isLoading ? widget.enquiryNumber : _str(_enquiry['enquiry_number'])}',
                  style: TextStyle(
                      color:         AppColors.textPrimary,
                      fontSize:      isTablet ? 19 : 16,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: -0.3),
                ),
                if (!_isLoading && _enquiry['customer'] != null)
                  Text(
                    _str(_enquiry['customer']['name']).capitalize(),
                    style: const TextStyle(
                        color:    AppColors.textSecondary,
                        fontSize: 12),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _fetchTrackHistory,
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

  // ── Tab Bar ────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller:              _tabCtrl,
        labelColor:              AppColors.primary,
        unselectedLabelColor:    AppColors.textSecondary,
        indicatorColor:          AppColors.primary,
        indicatorWeight:         2.5,
        labelStyle: const TextStyle(
            fontSize: 13.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
            fontSize: 13.5, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(text: 'Lead Details'),
          Tab(text: 'Track History'),
        ],
      ),
    );
  }

  // ── Loading ────────────────────────────────────────────────────────────────
  Widget _buildLoading() {
    return TabBarView(
      controller: _tabCtrl,
      physics:    const NeverScrollableScrollPhysics(),
      children: [
        _buildDetailsSkeleton(),
        _buildHistorySkeleton(),
      ],
    );
  }

  Widget _buildDetailsSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmer(width: 100, height: 28, radius: 8),
          const SizedBox(height: 20),
          _skeletonCard(rows: 3),
          const SizedBox(height: 14),
          _skeletonCard(rows: 2),
          const SizedBox(height: 14),
          _skeletonCard(rows: 4, tall: true),
        ],
      ),
    );
  }

  Widget _buildHistorySkeleton() {
    return ListView.builder(
      padding:     const EdgeInsets.fromLTRB(16, 20, 16, 32),
      itemCount:   3,
      itemBuilder: (_, i) => _skeletonHistoryItem(isLast: i == 2),
    );
  }

  Widget _skeletonCard({required int rows, bool tall = false}) {
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                _shimmer(width: 30, height: 30, radius: 8),
                const SizedBox(width: 10),
                _shimmer(width: 120, height: 13, radius: 4),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          ...List.generate(
            rows,
            (i) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      _shimmer(width: 15, height: 15, radius: 4),
                      const SizedBox(width: 10),
                      _shimmer(width: 90, height: 12, radius: 4),
                      const SizedBox(width: 16),
                      _shimmer(
                          width:  tall ? 160 : 110,
                          height: 12,
                          radius: 4),
                    ],
                  ),
                ),
                if (i < rows - 1)
                  const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: AppColors.borderLight),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonHistoryItem({bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                _shimmer(width: 32, height: 32, radius: 16),
                if (!isLast)
                  Expanded(
                    child: Container(
                        width: 2, color: AppColors.borderLight),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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
                      _shimmer(width: 80, height: 22, radius: 5),
                      const Spacer(),
                      _shimmer(width: 110, height: 11, radius: 4),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _shimmer(
                      width: double.infinity, height: 12, radius: 4),
                  const SizedBox(height: 8),
                  _shimmer(width: 180, height: 12, radius: 4),
                  const SizedBox(height: 8),
                  _shimmer(width: 140, height: 12, radius: 4),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _shimmer(width: 24, height: 24, radius: 6),
                      const SizedBox(width: 7),
                      _shimmer(width: 120, height: 12, radius: 4),
                    ],
                  ),
                ],
              ),
            ),
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

  // ── Error ──────────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              onPressed: _fetchTrackHistory,
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
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── Tab 1 : Lead Details ──────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildLeadDetails(double hPad) {
    final customer   = _enquiry['customer']    as Map? ?? {};
    final assignedTo = _enquiry['assigned_to'] as Map? ?? {};

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enquiry Information
          _sectionCard(
            title: 'Enquiry Information',
            icon:  Icons.info_outline_rounded,
            children: [
              _detailRow(
                icon:  Icons.tag_rounded,
                label: 'Enquiry Number',
                value: _str(_enquiry['enquiry_number']),
              ),
              _divider(),
              _detailRow(
                icon:  Icons.calendar_today_outlined,
                label: 'Added Date',
                value: _formatDate(_str(_enquiry['added_date'])),
              ),
              _divider(),
              _detailRow(
                icon:  Icons.person_pin_outlined,
                label: 'Assigned To',
                value: _str(assignedTo['name']).capitalize(),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Customer
          _sectionCard(
            title: 'Customer',
            icon:  Icons.person_outline_rounded,
            children: [
              _detailRow(
                icon:  Icons.person_outline_rounded,
                label: 'Name',
                value: _str(customer['name']).capitalize(),
              ),
              _divider(),
              _detailRow(
                icon:  Icons.phone_outlined,
                label: 'Phone',
                value: _str(customer['phone']),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Lead Details
          _sectionCard(
            title: 'Lead Details',
            icon:  Icons.description_outlined,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Text(
                  _str(_enquiry['details']).isEmpty
                      ? '—'
                      : _str(_enquiry['details']),
                  style: const TextStyle(
                      color:    AppColors.textPrimary,
                      fontSize: 13.5,
                      height:   1.6),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Lead Status — from enquiry status field
          if (_str(_enquiry['status']).isNotEmpty) ...[
            const SizedBox(height: 14),
            _sectionCard(
              title: 'Lead Status',
              icon:  Icons.flag_outlined,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Builder(builder: (ctx) {
                    final status = _str(_enquiry['status']);
                    final clr    = _statusColor(status);
                    final bg     = _statusBg(status);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color:        bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: clr.withOpacity(0.3), width: 1),
                      ),
                      child: Text(status.capitalize(),
                          style: TextStyle(
                              color:      clr,
                              fontSize:   13,
                              fontWeight: FontWeight.w600)),
                    );
                  }),
                ),
              ],
            ),
          ],

        ],
      ),
    );
  }

  Widget _buildDealChip(String name, String colorHex) {
    Color bg;
    try {
      final clean = colorHex.replaceAll('#', '').trim();
      bg = clean.length == 6
          ? Color(int.parse('FF$clean', radix: 16))
          : Color(int.parse(clean, radix: 16));
    } catch (_) {
      bg = AppColors.primary;
    }
    final luminance  = bg.computeLuminance();
    final textColor =
        luminance > 0.45 ? const Color(0xFF1A1A2E) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(9)),
      child: Text(name,
          style: TextStyle(
              color:      textColor,
              fontSize:   13.5,
              fontWeight: FontWeight.w600)),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── Tab 2 : Track History ─────────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTrackHistory(double hPad) {
    if (_history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.history_rounded,
                  size: 52, color: AppColors.border),
              SizedBox(height: 14),
              Text(
                'No track history found for this enquiry',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color:      AppColors.textSecondary,
                    fontSize:   14,
                    fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 6),
              Text(
                'History will appear here when updates are made',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color:    AppColors.textMuted,
                    fontSize: 12.5,
                    height:   1.5),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding:          EdgeInsets.fromLTRB(hPad, 20, hPad, 32),
      itemCount:        _history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 0),
      itemBuilder:      (_, i)  => _historyItem(_history[i], i),
    );
  }

  Widget _historyItem(dynamic item, int index) {
    final Map    h           = item as Map? ?? {};
    final Map    addedBy     = h['added_by']   as Map? ?? {};
    final Map    assignedTo  = h['assigned_to'] as Map? ?? {};
    final String type        = _str(h['type']);
    final String addedAt     = _str(h['added_at']);
    final String notes       = _str(h['notes']);
    final String deal        = _str(h['deal']);
    final String followUp    = _str(h['follow_up']);
    final String fStatus     = _str(h['followup_status']);
    final String byName      = _str(addedBy['name']);
    final String byType      = _str(addedBy['type']);
    final String assignedName = _str(assignedTo['name']);
    final bool   isLast      = index == _history.length - 1;

    final Color    typeColor = _typeColor(type);
    final Color    typeBg    = _typeBg(type);
    final IconData typeIcon  = _typeIcon(type);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline spine
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color:  typeBg,
                    shape:  BoxShape.circle,
                    border: Border.all(
                        color: typeColor.withOpacity(0.4), width: 1.5),
                  ),
                  child: Icon(typeIcon, size: 15, color: typeColor),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                        width: 2, color: AppColors.borderLight),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Content card
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.borderLight, width: 1),
                boxShadow: [
                  BoxShadow(
                      color:      Colors.black.withOpacity(0.03),
                      blurRadius: 5,
                      offset:     const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:        typeBg,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(type.capitalize(),
                            style: TextStyle(
                                color:      typeColor,
                                fontSize:   10.5,
                                fontWeight: FontWeight.w700)),
                      ),
                      const Spacer(),
                      const Icon(Icons.access_time_rounded,
                          size: 11, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        _formatDateTime(addedAt),
                        style: const TextStyle(
                            color:    AppColors.textMuted,
                            fontSize: 11),
                      ),
                    ],
                  ),

                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _historyRow(Icons.notes_rounded, 'Notes', notes),
                  ],
                  if (deal.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _historyRow(
                        Icons.handshake_outlined, 'Deal', deal),
                  ],
                  if (followUp.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _historyRow(
                        Icons.event_outlined, 'Follow Up',
                        _formatDate(followUp),
                        suffix: fStatus.isNotEmpty
                            ? _followUpChip(fStatus)
                            : null),
                  ],
                  if (assignedName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person_pin_outlined,
                            size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        const Text('Assigned To  ',
                            style: TextStyle(
                                color:      AppColors.textMuted,
                                fontSize:   12,
                                fontWeight: FontWeight.w500)),
                        Expanded(
                          child: Text(assignedName.capitalize(),
                              style: const TextStyle(
                                  color:      AppColors.textPrimary,
                                  fontSize:   12.5,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 10),
                  const Divider(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color:        AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            byName.isNotEmpty
                                ? byName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color:      AppColors.primary,
                                fontSize:   11,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: byName.capitalize(),
                                style: const TextStyle(
                                    color:      AppColors.textPrimary,
                                    fontSize:   12,
                                    fontWeight: FontWeight.w600),
                              ),
                              if (byType.isNotEmpty)
                                TextSpan(
                                  text: '  ·  $byType',
                                  style: const TextStyle(
                                      color:    AppColors.textMuted,
                                      fontSize: 11.5),
                                ),
                            ],
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
    );
  }

  Widget _historyRow(IconData icon, String label, String value,
      {Widget? suffix}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 6),
        SizedBox(
          width: 66,
          child: Text(label,
              style: const TextStyle(
                  color:      AppColors.textMuted,
                  fontSize:   12,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  color:      AppColors.textPrimary,
                  fontSize:   12.5,
                  fontWeight: FontWeight.w500,
                  height:     1.4)),
        ),
        if (suffix != null) suffix,
      ],
    );
  }

  Widget _followUpChip(String status) {
    final clr = _statusColor(status);
    final bg  = _statusBg(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: clr.withOpacity(0.3)),
      ),
      child: Text(status.capitalize(),
          style: TextStyle(
              color:      clr,
              fontSize:   10.5,
              fontWeight: FontWeight.w600)),
    );
  }

  // ── Section card ───────────────────────────────────────────────────────────
  Widget _sectionCard({
    required String       title,
    required IconData     icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color:        AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                        color:      AppColors.textPrimary,
                        fontSize:   13.5,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String   label,
    required String   value,
    Color?            valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.iconDefault),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    color:      AppColors.textMuted,
                    fontSize:   12.5,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                  color:      valueColor ?? AppColors.textPrimary,
                  fontSize:   13,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(
      height: 1, indent: 16, endIndent: 16,
      color: AppColors.borderLight);

  // ── Type helpers ───────────────────────────────────────────────────────────
  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'communication':  return const Color(0xFF1565C0);
      case 'call':           return const Color(0xFF2E7D32);
      case 'meeting':        return const Color(0xFF6A1B9A);
      case 'email':          return const Color(0xFF00695C);
      case 'note':           return const Color(0xFFE65100);
      case 'status_change':  return const Color(0xFF0277BD);
      default:               return AppColors.primary;
    }
  }

  Color _typeBg(String type) {
    switch (type.toLowerCase()) {
      case 'communication':  return const Color(0xFFE3F2FD);
      case 'call':           return const Color(0xFFE8F5E9);
      case 'meeting':        return const Color(0xFFF3E5F5);
      case 'email':          return const Color(0xFFE0F2F1);
      case 'note':           return const Color(0xFFFFF3E0);
      case 'status_change':  return const Color(0xFFE1F5FE);
      default:               return AppColors.primaryLight;
    }
  }

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'communication':  return Icons.chat_bubble_outline_rounded;
      case 'call':           return Icons.phone_outlined;
      case 'meeting':        return Icons.people_outline_rounded;
      case 'email':          return Icons.email_outlined;
      case 'note':           return Icons.sticky_note_2_outlined;
      case 'status_change':  return Icons.swap_horiz_rounded;
      default:               return Icons.circle_outlined;
    }
  }

  String _formatDate(String raw) {
    try {
      final parts = raw.trim().split('-');
      if (parts.length == 3)
        return '${parts[2]}-${parts[1]}-${parts[0]}';
    } catch (_) {}
    return raw;
  }

  String _formatDateTime(String raw) {
    try {
      final spaceIdx = raw.indexOf(' ');
      if (spaceIdx != -1) {
        final datePart = raw.substring(0, spaceIdx);
        final timePart = raw.substring(spaceIdx + 1);
        final timeHM   = timePart.length >= 5
            ? timePart.substring(0, 5)
            : timePart;
        return '${_formatDate(datePart)}  $timeHM';
      }
      return _formatDate(raw);
    } catch (_) {}
    return raw;
  }
}

// ── Shimmer Box ────────────────────────────────────────────────────────────
class _ShimmerBox extends StatefulWidget {
  final double width, height, radius;
  const _ShimmerBox(
      {required this.width,
      required this.height,
      required this.radius});

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