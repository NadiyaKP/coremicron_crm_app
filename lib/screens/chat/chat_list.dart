import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:coremicron_crm_app/common/api_service.dart';
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/common/string_extensions.dart';
import 'package:coremicron_crm_app/screens/chat/chatting.dart';

class ChatListPage extends StatefulWidget {
  final String username;
  const ChatListPage({super.key, required this.username});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  List<dynamic> _chats       = [];
  bool          _isLoading   = true;
  String?       _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchChats();
  }

  Future<void> _fetchChats() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final url = Uri.parse('${ApiService.baseUrl}/api/chat/list.php');
      final res = await ApiService.get(url).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['success'] == true) {
        setState(() => _chats = data['data'] ?? []);
      } else {
        setState(() => _errorMessage = data['message'] ?? 'Failed to load chats');
      }
    } catch (_) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatLastTime(String? createdAt) {
    if (createdAt == null || createdAt.isEmpty) return '';
    try {
      final dt  = DateTime.parse(createdAt).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (dt.isAfter(today)) {
        final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        final m = dt.minute.toString().padLeft(2, '0');
        final p = dt.hour >= 12 ? 'PM' : 'AM';
        return '$h:$m $p';
      }
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _isLoading
                  ? _buildSkeletonList()
                  : _errorMessage != null
                      ? _buildError()
                      : _chats.isEmpty
                          ? _buildEmpty()
                          : _buildChatList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 13),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end:   Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.chat_bubble_rounded,
                color: Colors.white, size: 19),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Messages',
                style: TextStyle(
                    color:         AppColors.textPrimary,
                    fontSize:      17,
                    fontWeight:    FontWeight.w800,
                    letterSpacing: -0.3)),
          ),
          GestureDetector(
            onTap: _fetchChats,
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

  // ── Chat List ──────────────────────────────────────────────────────────────
  Widget _buildChatList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: _chats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _chatCard(_chats[i]),
    );
  }

  Widget _chatCard(dynamic chat) {
    final String employeeName   = chat['employee_name'] ?? 'Unknown';
    final String? lastMessage   = chat['message'];
    final int    unread         = int.tryParse(chat['unread']?.toString() ?? '0') ?? 0;
    final dynamic conversationId = chat['conversation_id'];
    final dynamic employeeId    = chat['employee_id'];
    final String timeStr        = _formatLastTime(chat['created_at']);
    final bool   hasUnread      = unread > 0;

    // Avatar color derived from first letter
    final List<Color> avatarColors = [
      const Color(0xFF1558E7),
      const Color(0xFF0277BD),
      const Color(0xFF2E7D32),
      const Color(0xFF6A1B9A),
      const Color(0xFFC62828),
      const Color(0xFFE65100),
    ];
    final Color avatarColor = avatarColors[
        (employeeName.isNotEmpty ? employeeName.codeUnitAt(0) : 0) %
            avatarColors.length];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChattingPage(
              username:       widget.username,
              employeeName:   employeeName,
              employeeId:     employeeId,
              conversationId: conversationId == 'null' ? null : conversationId,
            ),
          ),
        ).then((_) => _fetchChats());
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasUnread
                ? AppColors.primary.withOpacity(0.25)
                : AppColors.borderLight,
            width: hasUnread ? 1.3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(hasUnread ? 0.06 : 0.03),
              blurRadius: hasUnread ? 10 : 6,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Avatar ────────────────────────────────────────────────
            Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color:        avatarColor.withOpacity(0.12),
                    shape:        BoxShape.circle,
                    border: Border.all(
                        color: avatarColor.withOpacity(0.2), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      employeeName.isNotEmpty
                          ? employeeName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          color:      avatarColor,
                          fontSize:   18,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),

            const SizedBox(width: 12),

            // ── Content ───────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          employeeName.capitalize(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color:      AppColors.textPrimary,
                              fontSize:   14.5,
                              fontWeight: hasUnread
                                  ? FontWeight.w800
                                  : FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (timeStr.isNotEmpty)
                        Text(
                          timeStr,
                          style: TextStyle(
                              fontSize:   11,
                              color:      hasUnread
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                              fontWeight: hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.w400),
                        ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color:      hasUnread
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              fontSize:   12.5),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color:        AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : unread.toString(),
                            style: const TextStyle(
                                color:      Colors.white,
                                fontSize:   10.5,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Skeleton ───────────────────────────────────────────────────────────────
  Widget _buildSkeletonList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => _skeletonCard(),
    );
  }

  Widget _skeletonCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Row(
        children: [
          _shimmer(width: 50, height: 50, radius: 25),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _shimmer(width: 130, height: 14, radius: 4),
                    _shimmer(width: 40,  height: 11, radius: 4),
                  ],
                ),
                const SizedBox(height: 7),
                _shimmer(width: double.infinity, height: 12, radius: 4),
              ],
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

  // ── Empty ──────────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color:        AppColors.primaryLight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          const Text('No conversations yet',
              style: TextStyle(
                  color:      AppColors.textPrimary,
                  fontSize:   16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Your team messages will appear here',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 13)),
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
          Text(_errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13.5)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchChats,
            icon:  const Icon(Icons.refresh_rounded,
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