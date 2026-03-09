import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../common/api_service.dart';
import '../../common/theme.dart';
import '../login.dart' show kSessionKey;
import '../home.dart';
import '../../common/pagination.dart';
import 'add_team.dart';

// ── Models ─────────────────────────────────────────────────────────────────
class TeamMember {
  final String employeeDbId;
  final String employeeCode;
  final String employeeName;
  final String departmentId;
  final String departmentName;

  const TeamMember({
    required this.employeeDbId,
    required this.employeeCode,
    required this.employeeName,
    required this.departmentId,
    required this.departmentName,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
        employeeDbId:   json['employee_db_id']  ?? '',
        employeeCode:   json['employee_code']   ?? '',
        employeeName:   json['employee_name']   ?? '',
        departmentId:   json['department_id']   ?? '',
        departmentName: json['department_name'] ?? '',
      );
}

class Team {
  final String           id;
  final String           name;
  final String           status;
  final List<TeamMember> members;

  const Team({
    required this.id,
    required this.name,
    required this.status,
    required this.members,
  });

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id:      json['team_id']     ?? '',
        name:    json['team_name']   ?? '',
        status:  json['team_status'] ?? '',
        members: (json['members'] as List? ?? [])
            .map((m) => TeamMember.fromJson(m))
            .toList(),
      );

  bool get isActive => status.toLowerCase() == 'active';
}

// ── Teams Page ─────────────────────────────────────────────────────────────
class TeamsPage extends StatefulWidget {
  final String username;

  const TeamsPage({super.key, required this.username});

  @override
  State<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends State<TeamsPage> {
  static const int _pageSize = 50;

  List<Team> _allTeams  = [];
  List<Team> _filtered  = [];
  bool       _isLoading = true;
  String?    _errorMessage;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int    _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _fetchTeams();
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
      _filtered = List.from(_allTeams);
    } else {
      _filtered = _allTeams
          .where((t) => t.name.toLowerCase().contains(_searchQuery))
          .toList();
    }
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchTeams() async {
    setState(() {
      _isLoading    = true;
      _errorMessage = null;
    });

    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url       = Uri.parse('${ApiService.baseUrl}/api/team/list.php');

      debugPrint('─────────────────────────────────────────');
      debugPrint('📤  [TEAM LIST] Request');
      debugPrint('   🌐  URL : $url');
      debugPrint('─────────────────────────────────────────');

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

      debugPrint('─────────────────────────────────────────');
      debugPrint('📥  [TEAM LIST] Response');
      debugPrint('   🔢  Status : ${response.statusCode}');
      debugPrint('   📄  Body   : ${response.body}');
      debugPrint('─────────────────────────────────────────');

      if (response.statusCode == 200 && data['success'] == true) {
        final List list = data['teams'] ?? [];
        _allTeams = list.map((e) => Team.fromJson(e)).toList();
        _applyFilter();
      } else {
        _errorMessage = data['error'] ?? data['message'] ?? 'Failed to load teams.';
      }
    } on http.ClientException {
      _errorMessage = 'Unable to reach the server. Check your connection.';
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ── Toggle status API ──────────────────────────────────────────────────────
  Future<void> _toggleStatus(Team team) async {
    final newStatus = team.isActive ? 'inactive' : 'active';
    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url       = Uri.parse('${ApiService.baseUrl}/api/team/toggle_status.php');
      final body      = {'id': team.id, 'status': newStatus};

      debugPrint('─────────────────────────────────────────');
      debugPrint('📤  [TEAM TOGGLE STATUS] Request');
      debugPrint('   🌐  URL  : $url');
      debugPrint('   📦  Body : ${jsonEncode(body)}');
      debugPrint('─────────────────────────────────────────');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept':       'application/json',
          'X-Session-ID': sessionId,
          'Cookie':       'PHPSESSID=$sessionId',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final Map<String, dynamic> data = jsonDecode(response.body);

      debugPrint('─────────────────────────────────────────');
      debugPrint('📥  [TEAM TOGGLE STATUS] Response');
      debugPrint('   🔢  Status : ${response.statusCode}');
      debugPrint('   📄  Body   : ${response.body}');
      debugPrint('─────────────────────────────────────────');

      if (response.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Team marked as $newStatus.');
        _fetchTeams();
      } else {
        AppSnackBar.show(
            context, data['error'] ?? data['message'] ?? 'Failed to update status.',
            isError: true);
      }
    } on http.ClientException {
      if (mounted) AppSnackBar.show(context, 'Unable to reach the server.', isError: true);
    } catch (_) {
      if (mounted) AppSnackBar.show(context, 'Something went wrong.', isError: true);
    }
  }

  // ── Pagination ─────────────────────────────────────────────────────────────
  int get _totalPages => paginationTotalPages(_filtered.length, _pageSize);

  List<Team> get _pageItems =>
      paginationPageItems(_filtered, _currentPage, _pageSize);

  // ── Back to home ───────────────────────────────────────────────────────────
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

  // ── View members popup ─────────────────────────────────────────────────────
  void _showMembersDialog(Team team) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Padding(
          padding: const EdgeInsets.all(0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ─────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 14, 16),
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.groups_rounded,
                          color: Colors.white, size: 19),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            team.name,
                            style: const TextStyle(
                              color:      AppColors.textPrimary,
                              fontSize:   15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${team.members.length} member${team.members.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color:    AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.border, width: 1.1),
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: AppColors.textLabel),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Members list (scrollable) ───────────────────────────────
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.52,
                ),
                child: team.members.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_off_outlined,
                                size: 40, color: AppColors.border),
                            SizedBox(height: 10),
                            Text('No members in this team',
                                style: TextStyle(
                                    color:    AppColors.textSecondary,
                                    fontSize: 13.5)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        itemCount: team.members.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) =>
                            _memberTile(team.members[i], i),
                      ),
              ),

              // ── Close button ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 10),
                        minimumSize:   Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Close',
                          style: TextStyle(
                              color:      Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize:   13.5)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _memberTile(TeamMember m, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Row(
        children: [
          // Initial avatar
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
                color: AppColors.primaryLight, shape: BoxShape.circle),
            child: Center(
              child: Text(
                m.employeeName.isNotEmpty
                    ? m.employeeName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color:      AppColors.primary,
                  fontSize:   14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.employeeName,
                  style: const TextStyle(
                    color:      AppColors.textPrimary,
                    fontSize:   13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.apartment_rounded,
                        size: 11, color: AppColors.textSecondary),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        m.departmentName,
                        style: const TextStyle(
                          color:    AppColors.textSecondary,
                          fontSize: 11.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
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
                      '${_filtered.length} team${_filtered.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color:      AppColors.textSecondary,
                          fontSize:   12.5,
                          fontWeight: FontWeight.w500),
                    ),
                  const Spacer(),
                  _newTeamButton(),
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
                          : _buildTeamList(hPad),
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
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
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
            'Teams',
            style: TextStyle(
              color:      AppColors.textPrimary,
              fontSize:   isTablet ? 20 : 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _fetchTeams,
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
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        cursorColor: AppColors.primary,
        decoration: const InputDecoration(
          hintText:  'Search teams…',
          hintStyle: TextStyle(color: AppColors.textHint, fontSize: 13.5),
          prefixIcon: Icon(Icons.search_rounded,
              color: AppColors.iconDefault, size: 19),
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  // ── New Team button ────────────────────────────────────────────────────────
  Widget _newTeamButton() {
    return ElevatedButton.icon(
      onPressed: () async {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const AddTeamPage()),
        );
        if (result == true) _fetchTeams();
      },
      icon:  const Icon(Icons.add_rounded, size: 16, color: Colors.white),
      label: const Text('New Team',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    );
  }

  // ── Team list ──────────────────────────────────────────────────────────────
  Widget _buildTeamList(double hPad) {
    final items = _pageItems;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _teamCard(items[i]),
    );
  }

  // ── Team card ──────────────────────────────────────────────────────────────
  Widget _teamCard(Team t) {
    final isActive = t.isActive;

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
          // Icon avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primaryLight : AppColors.borderLight,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.groups_rounded,
                color: isActive ? AppColors.primary : AppColors.textMuted,
                size: 20),
          ),

          const SizedBox(width: 12),

          // Name + status + member count + action buttons
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Team name
                Text(
                  t.name,
                  style: const TextStyle(
                    color:      AppColors.textPrimary,
                    fontSize:   13.5,
                    fontWeight: FontWeight.w600,
                    height:     1.3,
                  ),
                ),

                const SizedBox(height: 6),

                // Status badge + member count
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.successBg
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        t.status,
                        style: TextStyle(
                          color: isActive
                              ? AppColors.success
                              : AppColors.textMuted,
                          fontSize:   10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.person_outline_rounded,
                        size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 3),
                    Text(
                      '${t.members.length} member${t.members.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color:    AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Action icons — right-aligned below
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _actionIcon(
                      icon:    Icons.remove_red_eye_outlined,
                      color:   AppColors.success,
                      bgColor: AppColors.successBg,
                      onTap:   () => _showMembersDialog(t),
                    ),
                    const SizedBox(width: 6),
                    _actionIcon(
                      icon:    Icons.edit_outlined,
                      color:   AppColors.primary,
                      bgColor: AppColors.primaryLight,
                      onTap: () async {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddTeamPage(
                              team: {
                                'id':      t.id,
                                'name':    t.name,
                                'members': t.members
                                    .map((m) => {
                                          'employee_db_id': m.employeeDbId,
                                        })
                                    .toList(),
                              },
                            ),
                          ),
                        );
                        if (result == true) _fetchTeams();
                      },
                    ),
                    const SizedBox(width: 6),
                    _actionIcon(
                      icon: isActive
                          ? Icons.toggle_on_rounded
                          : Icons.toggle_off_rounded,
                      color: isActive
                          ? AppColors.success
                          : AppColors.textMuted,
                      bgColor: isActive
                          ? AppColors.successBg
                          : const Color(0xFFF3F4F6),
                      onTap: () => _toggleStatus(t),
                      size: 20,
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
    double size = 15,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: size, color: color),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmer(width: 40, height: 40, radius: 11),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmer(width: double.infinity, height: 13, radius: 4),
                const SizedBox(height: 7),
                Row(
                  children: [
                    _shimmer(width: 58, height: 20, radius: 10),
                    const SizedBox(width: 8),
                    _shimmer(width: 80, height: 13, radius: 4),
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
          const Icon(Icons.groups_rounded, size: 56, color: AppColors.border),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No teams found',
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Tap "New Team" to get started',
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
          Text(_errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13.5)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchTeams,
            icon:  const Icon(Icons.refresh_rounded,
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
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EDF5),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
}