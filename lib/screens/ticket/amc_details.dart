import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService, AppSnackBar;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/common/string_extensions.dart';
import 'assign_amc.dart';

class AmcScheduleItem {
  final String scheduleId;
  final String serviceTitle;
  final String scheduledDate;
  final bool isAssigned;
  final String? employeeName;
  final String? assignId;
  final String? toDo;
  final String? image;
  final String? status;

  AmcScheduleItem({
    required this.scheduleId,
    required this.serviceTitle,
    required this.scheduledDate,
    required this.isAssigned,
    this.employeeName,
    this.assignId,
    this.toDo,
    this.image,
    this.status,
  });

  factory AmcScheduleItem.fromJson(Map<String, dynamic> json) {
    final job = json['job'] as Map<String, dynamic>?;
    return AmcScheduleItem(
      scheduleId: json['schedule_id'] ?? '',
      serviceTitle: json['service_title'] ?? '',
      scheduledDate: json['scheduled_date'] ?? '',
      isAssigned: json['is_assigned'] ?? false,
      employeeName: job?['employee_name'],
      assignId: job?['assign_id'],
      toDo: job?['to_do'],
      image: job?['image'],
      status: job?['status'],
    );
  }
}

// ─────────────────────────────────────────────
// Shimmer / Skeleton helpers
// ─────────────────────────────────────────────

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = 6,
  });

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
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row + badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _ShimmerBox(width: 160, height: 15, borderRadius: 6),
              const _ShimmerBox(width: 70, height: 22, borderRadius: 20),
            ],
          ),
          const SizedBox(height: 10),
          // Date row
          Row(
            children: const [
              _ShimmerBox(width: 13, height: 13, borderRadius: 4),
              SizedBox(width: 6),
              _ShimmerBox(width: 100, height: 12, borderRadius: 5),
            ],
          ),
          const SizedBox(height: 12),
          // Employee row
          Row(
            children: const [
              _ShimmerBox(width: 14, height: 14, borderRadius: 4),
              SizedBox(width: 6),
              _ShimmerBox(width: 140, height: 13, borderRadius: 5),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 12),
          // Action icons row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: const [
              _ShimmerBox(width: 30, height: 30, borderRadius: 7),
              SizedBox(width: 8),
              _ShimmerBox(width: 30, height: 30, borderRadius: 7),
              SizedBox(width: 8),
              _ShimmerBox(width: 30, height: 30, borderRadius: 7),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Main page
// ─────────────────────────────────────────────

class AmcDetailsPage extends StatefulWidget {
  final String ticketId;
  final String ticketNumber;

  const AmcDetailsPage({
    super.key,
    required this.ticketId,
    required this.ticketNumber,
  });

  @override
  State<AmcDetailsPage> createState() => _AmcDetailsPageState();
}

class _AmcDetailsPageState extends State<AmcDetailsPage> {
  List<AmcScheduleItem> _schedules = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAmcDetails();
  }

  Future<void> _fetchAmcDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/ticket/amc_list.php?ticket_id=${widget.ticketId}');
      final response =
          await ApiService.get(url).timeout(const Duration(seconds: 15));
      debugPrint('📥 [AMC LIST] Response: ${response.body}');
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final List list = data['data'] ?? [];
        setState(() {
          _schedules =
              list.map((e) => AmcScheduleItem.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              data['message'] ?? 'Failed to load AMC details.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Something went wrong.';
        _isLoading = false;
      });
    }
  }

  // ── Skeleton list ──────────────────────────
  Widget _buildSkeletonList(double hPad) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 32),
      itemCount: 4, // show 4 placeholder cards
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const _SkeletonCard(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final hPad = isTablet ? size.width * 0.06 : 16.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'AMC Details - ${widget.ticketNumber}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderLight, height: 1),
        ),
      ),
      body: _isLoading
          ? _buildSkeletonList(hPad)
          : _errorMessage != null
              ? Center(
                  child: Text(_errorMessage!,
                      style: const TextStyle(color: AppColors.error)))
              : _schedules.isEmpty
                  ? const Center(child: Text('No schedules found.'))
                  : ListView.separated(
                      padding:
                          EdgeInsets.fromLTRB(hPad, 20, hPad, 32),
                      itemCount: _schedules.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (_, i) =>
                          _buildScheduleCard(_schedules[i]),
                    ),
    );
  }

  Widget _buildScheduleCard(AmcScheduleItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.serviceTitle,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              if (item.status != null && item.status!.isNotEmpty)
                _statusBadge(item.status!)
              else if (!item.isAssigned)
                _statusBadge('unassigned'),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 5),
              Text(item.scheduledDate,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          if (item.isAssigned) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Handled by: ${item.employeeName ?? '—'}',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _actionIcon(
                icon: Icons.person_add_outlined,
                color: const Color(0xFF6A1B9A),
                bgColor: const Color(0xFFF3E5F5),
                onTap: () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AssignAmcPage(schedule: item),
                    ),
                  );
                  if (result == true) _fetchAmcDetails();
                },
              ),
              const SizedBox(width: 8),
              _actionIcon(
                icon: Icons.edit_outlined,
                color: AppColors.primary,
                bgColor: AppColors.primaryLight,
                onTap: () => _showEditDialog(item),
              ),
              const SizedBox(width: 8),
              _actionIcon(
                icon: Icons.delete_outline_rounded,
                color: AppColors.error,
                bgColor: const Color(0xFFFFF1F1),
                onTap: () => _showDeleteDialog(item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final s = status.toLowerCase();
    Color bg;
    Color fg;
    switch (s) {
      case 'completed':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      case 'verified':
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        break;
      case 'pending':
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFF57F17);
        break;
      case 'unassigned':
        bg = const Color(0xFFF5F5F5);
        fg = AppColors.textSecondary;
        break;
      default:
        bg = const Color(0xFFF5F5F5);
        fg = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
            color: fg, fontSize: 11, fontWeight: FontWeight.w700),
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

  void _showEditDialog(AmcScheduleItem item) {
    final titleCtrl =
        TextEditingController(text: item.serviceTitle);
    DateTime selectedDate =
        DateTime.tryParse(item.scheduledDate) ?? DateTime.now();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Update Schedule',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Service Title',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  hintText: 'Enter title',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text('Scheduled Date',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Text(
                        '${selectedDate.day.toString().padLeft(2, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.year}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style:
                      TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (titleCtrl.text.trim().isEmpty) return;
                      setDialogState(() => isSaving = true);
                      try {
                        final url = Uri.parse(
                            '${ApiService.baseUrl}/api/ticket/amc_update.php');
                        final body = {
                          'schedule_id': item.scheduleId,
                          'service_title':
                              titleCtrl.text.trim(),
                          'scheduled_date':
                              '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                        };
                        final res = await ApiService.post(url,
                                body: jsonEncode(body))
                            .timeout(
                                const Duration(seconds: 15));
                        final data = jsonDecode(res.body);

                        if (res.statusCode == 200 &&
                            data['success'] == true) {
                          Navigator.pop(ctx);
                          _fetchAmcDetails();
                          AppSnackBar.show(null,
                              'Schedule updated successfully.',
                              isError: false);
                        } else {
                          setDialogState(
                              () => isSaving = false);
                          AppSnackBar.show(
                              context,
                              data['message'] ??
                                  'Failed to update schedule.',
                              isError: true);
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        AppSnackBar.show(
                            context, 'Something went wrong.',
                            isError: true);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Update',
                      style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(AmcScheduleItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Schedule',
            style:
                TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: const Text(
            'Are you sure you want to delete this schedule item?',
            style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style:
                      TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final url = Uri.parse(
                    '${ApiService.baseUrl}/api/ticket/amc_delete.php');
                final body = {'schedule_id': item.scheduleId};
                final res = await ApiService.post(url,
                        body: jsonEncode(body))
                    .timeout(const Duration(seconds: 15));
                final data = jsonDecode(res.body);

                if (res.statusCode == 200 &&
                    data['success'] == true) {
                  _fetchAmcDetails();
                  AppSnackBar.show(
                      null, 'Schedule item deleted successfully.',
                      isError: false);
                } else {
                  AppSnackBar.show(
                      context,
                      data['message'] ?? 'Failed to delete.',
                      isError: true);
                }
              } catch (_) {
                AppSnackBar.show(
                    context, 'Something went wrong.',
                    isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}