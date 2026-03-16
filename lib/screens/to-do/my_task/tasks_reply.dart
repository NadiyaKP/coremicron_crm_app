import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../common/api_service.dart';
import '../../../common/theme.dart';
import '../../login.dart' show kSessionKey;
import '../../../common/string_extensions.dart';

// ── Tasks Reply Page ───────────────────────────────────────────────────────
class TasksReplyPage extends StatefulWidget {
  final String jobId;
  final String jobTitle;

  const TasksReplyPage({
    super.key,
    required this.jobId,
    required this.jobTitle,
  });

  @override
  State<TasksReplyPage> createState() => _TasksReplyPageState();
}

class _TasksReplyPageState extends State<TasksReplyPage>
    with SingleTickerProviderStateMixin {
  // ── Tab controller ─────────────────────────────────────────────────────────
  late TabController _tabController;

  // ── Employee autocomplete ──────────────────────────────────────────────────
  List<Map<String, dynamic>> _allEmployees      = [];
  List<Map<String, dynamic>> _filteredEmployees = [];
  Map<String, dynamic>?      _selectedEmployee;
  bool                       _showSuggestions   = false;
  bool                       _loadingEmployees  = false;

  final _employeeCtrl  = TextEditingController();
  final _employeeFocus = FocusNode();

  // ── Reply compose ──────────────────────────────────────────────────────────
  final _replyCtrl  = TextEditingController();
  final _replyFocus = FocusNode();

  // ── Attachment ─────────────────────────────────────────────────────────────
  File?  _attachedImage;
  String _attachedImageName = '';

  // ── Submit ─────────────────────────────────────────────────────────────────
  bool _isSubmitting = false;

  // ── Chat ───────────────────────────────────────────────────────────────────
  List<dynamic> _communications = [];
  bool          _loadingChats   = true;
  String?       _chatError;

  final _chatScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchEmployees();
    _fetchCommunications();

    _employeeFocus.addListener(() {
      if (!_employeeFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) setState(() => _showSuggestions = false);
        });
      }
      setState(() {});
    });
    _replyFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _employeeCtrl.dispose();
    _employeeFocus.dispose();
    _replyCtrl.dispose();
    _replyFocus.dispose();
    _chatScrollCtrl.dispose();
    super.dispose();
  }

  // ── Fetch employees ────────────────────────────────────────────────────────
  Future<void> _fetchEmployees() async {
    setState(() => _loadingEmployees = true);
    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/employee/list.php?view=dropdown');

      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Accept':       'application/json',
        'X-Session-ID': sessionId,
        'Cookie':       'PHPSESSID=$sessionId',
      }).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && data['success'] == true) {
        final list = data['data'] as List? ?? [];
        _allEmployees =
            list.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (e) {
      debugPrint('⚠️  [EMPLOYEES] $e');
    }
    if (mounted) setState(() => _loadingEmployees = false);
  }

  void _onEmployeeSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredEmployees = [];
        _showSuggestions   = false;
        _selectedEmployee  = null;
      } else {
        _filteredEmployees = _allEmployees.where((e) {
          final name  = (e['employee_name'] ?? '').toString().toLowerCase();
          final phone = (e['phone_number']  ?? '').toString();
          return name.contains(q) || phone.contains(q);
        }).toList();
        _showSuggestions  = true;
        _selectedEmployee = null;
      }
    });
  }

  void _selectEmployee(Map<String, dynamic> emp) {
    setState(() {
      _selectedEmployee  = emp;
      _showSuggestions   = false;
      _employeeCtrl.text =
          (emp['employee_name'] ?? '').toString().capitalize();
    });
    _employeeFocus.unfocus();
  }

  // ── Fetch communications ───────────────────────────────────────────────────
  Future<void> _fetchCommunications() async {
    setState(() { _loadingChats = true; _chatError = null; });
    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/ticket/communication_list.php'
          '?job_id=${widget.jobId}');

      debugPrint('📤  [COMM LIST] $url');

      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Accept':       'application/json',
        'X-Session-ID': sessionId,
        'Cookie':       'PHPSESSID=$sessionId',
      }).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint(
          '📥  [COMM LIST] ${response.statusCode}  ${response.body}');

      if (response.statusCode == 200 && data['success'] == true) {
        _communications = data['communications'] as List? ?? [];
      } else {
        _chatError =
            data['error'] ?? data['message'] ?? 'Failed to load chats.';
      }
    } on http.ClientException {
      _chatError = 'Unable to reach the server.';
    } catch (_) {
      _chatError = 'Something went wrong.';
    }
    if (mounted) {
      setState(() => _loadingChats = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(
          _chatScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve:    Curves.easeOut,
        );
      }
    });
  }

  void _switchToChatsTab() {
    _tabController.animateTo(1);
    Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
  }

  // ── Pick image ─────────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _attachedImage     = File(picked.path);
        _attachedImageName = picked.name;
      });
    }
  }

  void _removeAttachment() =>
      setState(() { _attachedImage = null; _attachedImageName = ''; });

  // ── View network image ─────────────────────────────────────────────────────
  void _viewNetworkImage(String url) {
    final full = url.startsWith('http')
        ? url
        : '${ApiService.baseUrl}/uploads/$url';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5, maxScale: 4.0,
                  child: Image.network(full,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                      loadingBuilder: (_, child, prog) {
                        if (prog == null) return child;
                        return const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white));
                      },
                      errorBuilder: (_, __, ___) => const Center(
                          child: Text('Failed to load image',
                              style:
                                  TextStyle(color: Colors.white)))),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 32),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── View local file image ──────────────────────────────────────────────────
  void _viewLocalImage(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                    child:
                        Image.file(file, fit: BoxFit.contain)),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 32),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_selectedEmployee == null) {
      AppSnackBar.show(context, 'Please select a recipient employee.',
          isError: true);
      return;
    }
    if (_replyCtrl.text.trim().isEmpty) {
      AppSnackBar.show(context, 'Please type a message.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final prefs     = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(kSessionKey) ?? '';
      final url = Uri.parse(
          '${ApiService.baseUrl}/api/ticket/communication_create.php');

      final request = http.MultipartRequest('POST', url)
        ..headers.addAll({
          'X-Session-ID': sessionId,
          'Cookie':       'PHPSESSID=$sessionId',
        })
        ..fields['job_id']    = widget.jobId
        ..fields['assign_id'] =
            _selectedEmployee!['id']?.toString() ?? ''
        ..fields['message']   = _replyCtrl.text.trim();

      if (_attachedImage != null) {
        request.files.add(await http.MultipartFile.fromPath(
            'image', _attachedImage!.path));
      }

      debugPrint('📤  [COMM CREATE] $url');
      final streamed =
          await request.send().timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint(
          '📥  [COMM CREATE] ${response.statusCode}  ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Message sent successfully.');
        // Clear form
        _replyCtrl.clear();
        _removeAttachment();
        setState(() => _selectedEmployee = null);
        _employeeCtrl.clear();
        // Refresh chats then navigate to Chats tab
        await _fetchCommunications();
        _switchToChatsTab();
      } else {
        final err =
            data['error'] ?? data['message'] ?? 'Failed to send message.';
        AppSnackBar.show(context, err, isError: true);
      }
    } on http.ClientException {
      if (mounted)
        AppSnackBar.show(context, 'Unable to reach the server.',
            isError: true);
    } catch (e) {
      if (mounted)
        AppSnackBar.show(context, 'Error: $e', isError: true);
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _fmtDateTime(String? date, String? time) {
    if (date == null || date.isEmpty) return '';
    try {
      final p = date.trim().split('-');
      final d = p.length == 3
          ? '${p[2]}-${p[1]}-${p[0].length >= 4 ? p[0].substring(2) : p[0]}'
          : date;
      final t = time != null && time.length >= 5
          ? time.substring(0, 5)
          : time ?? '';
      return '$d  $t'.trim();
    } catch (_) {
      return date;
    }
  }

  bool _hasContent(String? s) =>
      s != null && s.isNotEmpty && s != 'null';

  // ═══════════════════════════════════════════════════════════════════════════
  // ── Build ──────────────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
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
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildNewMessageTab(hPad),
                  _buildChatsTab(hPad),
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
                border: Border.all(
                    color: AppColors.border, width: 1.2),
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
                  widget.jobTitle.isEmpty
                      ? 'Task Reply'
                      : widget.jobTitle.capitalize(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color:         AppColors.textPrimary,
                      fontSize:      isTablet ? 19 : 16,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: -0.3),
                ),
                const Text('Task Reply',
                    style: TextStyle(
                        color:    AppColors.textSecondary,
                        fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              if (_tabController.index == 1) _fetchCommunications();
            },
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color:        AppColors.background,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                    color: AppColors.border, width: 1.2),
              ),
              child: const Icon(Icons.refresh_rounded,
                  size: 18, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller:              _tabController,
        labelColor:              AppColors.primary,
        unselectedLabelColor:    AppColors.textSecondary,
        indicatorColor:          AppColors.primary,
        indicatorWeight:         2.5,
        labelStyle:              const TextStyle(
            fontSize: 13.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle:    const TextStyle(
            fontSize: 13.5, fontWeight: FontWeight.w500),
        tabs: [
          const Tab(
            icon:        Icon(Icons.edit_outlined, size: 17),
            text:        'New Message',
            iconMargin:  EdgeInsets.only(bottom: 2),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chat_bubble_outline_rounded,
                    size: 17),
                const SizedBox(width: 6),
                const Text('Chats'),
                if (!_loadingChats &&
                    _communications.isNotEmpty) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color:        AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_communications.length}',
                      style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── Tab 1 : New Message ────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildNewMessageTab(double hPad) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hPad, 18, hPad, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // To
          _fieldLabel('To', required: true),
          const SizedBox(height: 6),
          _buildEmployeeField(),

          const SizedBox(height: 16),

          // Message
          _fieldLabel('Message', required: true),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: _replyFocus.hasFocus
                ? AppDecorations.inputFocused
                : AppDecorations.inputIdle,
            child: TextField(
              controller:  _replyCtrl,
              focusNode:   _replyFocus,
              maxLines:    6,
              minLines:    4,
              cursorColor: AppColors.primary,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText:  'Type your message here…',
                hintStyle: TextStyle(
                    color: AppColors.textHint, fontSize: 13.5),
                border:         InputBorder.none,
                enabledBorder:  InputBorder.none,
                focusedBorder:  InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Attachment
          _fieldLabel('Attachment', required: false),
          const SizedBox(height: 6),
          _buildAttachmentSection(),

          const SizedBox(height: 24),

          // Submit
          SizedBox(
            width:  double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor:
                    AppColors.primary.withOpacity(0.45),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isSubmitting
                    ? const SizedBox(
                        key:   ValueKey('loading'),
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.3))
                    : const Row(
                        key:             ValueKey('label'),
                        mainAxisSize:    MainAxisSize.min,
                        children: [
                          Icon(Icons.send_rounded,
                              size: 17, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Submit',
                              style: TextStyle(
                                  color:      Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize:   15.5)),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Field label ────────────────────────────────────────────────────────────
  Widget _fieldLabel(String label, {bool required = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                color:      AppColors.textLabel,
                fontSize:   12.5,
                fontWeight: FontWeight.w600)),
        if (required)
          const Text(' *',
              style: TextStyle(
                  color:      AppColors.error,
                  fontSize:   13,
                  fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ── Employee autocomplete ──────────────────────────────────────────────────
  Widget _buildEmployeeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: _employeeFocus.hasFocus
                    ? AppColors.primary
                    : AppColors.border,
                width: _employeeFocus.hasFocus ? 1.6 : 1.2),
            boxShadow: _employeeFocus.hasFocus
                ? [
                    BoxShadow(
                        color:      AppColors.primary.withOpacity(0.08),
                        blurRadius: 6,
                        offset:     const Offset(0, 2))
                  ]
                : [],
          ),
          child: TextField(
            controller:  _employeeCtrl,
            focusNode:   _employeeFocus,
            onChanged:   _onEmployeeSearch,
            cursorColor: AppColors.primary,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText:  'Search employee by name or phone…',
              hintStyle: const TextStyle(
                  color: AppColors.textHint, fontSize: 13),
              prefixIcon: _loadingEmployees
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary)))
                  : const Icon(Icons.person_search_outlined,
                      color: AppColors.iconDefault, size: 19),
              suffixIcon: _employeeCtrl.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _employeeCtrl.clear();
                        setState(() {
                          _selectedEmployee  = null;
                          _showSuggestions   = false;
                          _filteredEmployees = [];
                        });
                      },
                      child: const Icon(Icons.close_rounded,
                          size: 17, color: AppColors.textMuted),
                    )
                  : null,
              border:         InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13),
            ),
          ),
        ),

        // Suggestions dropdown
        if (_showSuggestions)
          Container(
            margin:      const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 210),
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(11),
              border:
                  Border.all(color: AppColors.borderLight, width: 1),
              boxShadow: [
                BoxShadow(
                    color:      Colors.black.withOpacity(0.08),
                    blurRadius: 14,
                    offset:     const Offset(0, 4)),
              ],
            ),
            child: _filteredEmployees.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: const [
                        Icon(Icons.search_off_rounded,
                            size:  16,
                            color: AppColors.textMuted),
                        SizedBox(width: 8),
                        Text('No employees found',
                            style: TextStyle(
                                color:    AppColors.textMuted,
                                fontSize: 13)),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap:       true,
                    padding:          EdgeInsets.zero,
                    itemCount:        _filteredEmployees.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1, color: AppColors.borderLight),
                    itemBuilder: (_, i) {
                      final emp = _filteredEmployees[i];
                      return InkWell(
                        onTap: () => _selectEmployee(emp),
                        borderRadius: BorderRadius.circular(11),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                              12, 10, 12, 10),
                          child: Row(
                            children: [
                              Container(
                                width: 34, height: 34,
                                decoration: BoxDecoration(
                                  color:        AppColors.primaryLight,
                                  borderRadius:
                                      BorderRadius.circular(9),
                                ),
                                child: Center(
                                  child: Text(
                                    (emp['employee_name'] ?? ' ')
                                        .toString()
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                        color:      AppColors.primary,
                                        fontSize:   14,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (emp['employee_name'] ?? '')
                                          .toString()
                                          .capitalize(),
                                      style: const TextStyle(
                                          color:      AppColors.textPrimary,
                                          fontSize:   13.5,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone_outlined,
                                            size:  11,
                                            color: AppColors.textMuted),
                                        const SizedBox(width: 3),
                                        Text(
                                          emp['phone_number']
                                                  ?.toString() ??
                                              '',
                                          style: const TextStyle(
                                              color:    AppColors.textMuted,
                                              fontSize: 11.5),
                                        ),
                                        if ((emp['department_name'] ?? '')
                                            .toString()
                                            .isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          const Text('•',
                                              style: TextStyle(
                                                  color:    AppColors.textMuted,
                                                  fontSize: 10)),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              emp['department_name']
                                                      ?.toString() ??
                                                  '',
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  color:    AppColors.textMuted,
                                                  fontSize: 11),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  size:  16,
                                  color: AppColors.textMuted),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),


      ],
    );
  }

  // ── Attachment section ─────────────────────────────────────────────────────
  Widget _buildAttachmentSection() {
    if (_attachedImage != null) {
      return Row(
        children: [
          GestureDetector(
            onTap: () => _viewLocalImage(_attachedImage!),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.blue.withOpacity(0.3), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Image.file(_attachedImage!,
                        width: 36, height: 36, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Attachment',
                          style: TextStyle(
                              color:      Colors.blue,
                              fontSize:   12,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 1),
                      Text(
                        _attachedImageName.length > 22
                            ? '${_attachedImageName.substring(0, 22)}…'
                            : _attachedImageName,
                        style: const TextStyle(
                            color:    Colors.blue,
                            fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _removeAttachment,
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color:        const Color(0xFFFFF1F1),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                    color: AppColors.error.withOpacity(0.3), width: 1),
              ),
              child: const Icon(Icons.close_rounded,
                  size: 14, color: AppColors.error),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color:        AppColors.background,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppColors.border, width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.attach_file_rounded,
                size: 18, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Text('Tap to add an image',
                style: TextStyle(
                    color:      AppColors.textSecondary,
                    fontSize:   13.5,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── Tab 2 : Chats ──────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildChatsTab(double hPad) {
    if (_loadingChats)       return _buildChatSkeleton(hPad);
    if (_chatError != null)  return _buildChatError();
    if (_communications.isEmpty) return _buildChatEmpty();

    return ListView.separated(
      controller:       _chatScrollCtrl,
      padding:          EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
      itemCount:        _communications.length,
      separatorBuilder: (_, __) => Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          height: 1.5,
          color:  const Color(0xFFCDD3DE)),
      itemBuilder: (_, i) => _buildChatUnit(_communications[i]),
    );
  }

  // ── Single chat unit — compact layout ─────────────────────────────────────
  Widget _buildChatUnit(dynamic comm) {
    final message       = (comm['message']       ?? '').toString();
    final response      = (comm['response']      ?? '').toString();
    final receiverName  = (comm['receiver_name'] ?? '').toString();
    final image         = comm['image']?.toString();
    final responseImage = comm['response_image']?.toString();
    final addedDate     = comm['added_date']?.toString();
    final addedTime     = comm['added_time']?.toString();
    final dateTime      = _fmtDateTime(addedDate, addedTime);

    final hasResponse      = _hasContent(response);
    final hasImage         = _hasContent(image) && image != 'null';
    final hasResponseImage =
        _hasContent(responseImage) && responseImage != 'null';

    final bubbleMax = MediaQuery.of(context).size.width * 0.72;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Sent (right) + Response (left) on the same row ───────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ── Response — LEFT ──────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasResponse || hasResponseImage) ...[
                    if (hasImage) const SizedBox(height: 22),
                    if (receiverName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          receiverName.capitalize(),
                          style: TextStyle(
                              color:      AppColors.primary,
                              fontSize:   10.5,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    IntrinsicWidth(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft:     Radius.circular(12),
                            topRight:    Radius.circular(12),
                            bottomRight: Radius.circular(12),
                            bottomLeft:  Radius.circular(3),
                          ),
                          border: Border.all(
                              color: AppColors.borderLight, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasResponse)
                              Text(
                                response,
                                style: const TextStyle(
                                    color:    AppColors.textPrimary,
                                    fontSize: 13,
                                    height:   1.4),
                              ),
                            if (hasResponseImage) ...[
                              if (hasResponse) const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () =>
                                    _viewNetworkImage(responseImage!),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.image_outlined,
                                        size:  11,
                                        color: AppColors.textMuted),
                                    const SizedBox(width: 3),
                                    Text('Attachment',
                                        style: TextStyle(
                                            color:      AppColors.textMuted,
                                            fontSize:   10.5,
                                            fontWeight: FontWeight.w500,
                                            decoration:
                                                TextDecoration.underline,
                                            decorationColor:
                                                AppColors.textMuted)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ── Sent — RIGHT ─────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IntrinsicWidth(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: const BorderRadius.only(
                          topLeft:     Radius.circular(12),
                          topRight:    Radius.circular(12),
                          bottomLeft:  Radius.circular(12),
                          bottomRight: Radius.circular(3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.isEmpty ? '(No message)' : message,
                            style: const TextStyle(
                                color:    Colors.white,
                                fontSize: 13,
                                height:   1.4),
                          ),
                          if (hasImage) ...[
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () => _viewNetworkImage(image!),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.image_outlined,
                                      size: 11, color: Colors.white70),
                                  SizedBox(width: 3),
                                  Text('Attachment',
                                      style: TextStyle(
                                          color:      Colors.white70,
                                          fontSize:   10.5,
                                          fontWeight: FontWeight.w500,
                                          decoration:
                                              TextDecoration.underline,
                                          decorationColor:
                                              Colors.white70)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (dateTime.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(dateTime,
                          style: const TextStyle(
                              color:    AppColors.textMuted,
                              fontSize: 10)),
                    ),
                ],
              ),
            ),
          ],
        ),

        // Awaiting indicator when no response yet
        if (!(hasResponse || hasResponseImage))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Icon(Icons.hourglass_empty_rounded,
                    size: 10, color: AppColors.textMuted),
                SizedBox(width: 3),
                Text('Awaiting response…',
                    style: TextStyle(
                        color:     AppColors.textMuted,
                        fontSize:  10,
                        fontStyle: FontStyle.italic)),
              ],
            ),
          ),
      ],
    );
  }

  // ── Chat skeleton ──────────────────────────────────────────────────────────
  Widget _buildChatSkeleton(double hPad) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
      itemCount: 3,
      separatorBuilder: (_, __) => Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          height: 1.5,
          color:  const Color(0xFFCDD3DE)),
      itemBuilder: (_, __) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sent — right
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _shimmer(width: 180, height: 36, radius: 10),
            ],
          ),
          const SizedBox(height: 6),
          // Response — left
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shimmer(width: 70, height: 10, radius: 4),
              const SizedBox(height: 4),
              _shimmer(width: 140, height: 30, radius: 10),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 52, color: AppColors.border),
          SizedBox(height: 12),
          Text('No messages yet',
              style: TextStyle(
                  color:      AppColors.textSecondary,
                  fontSize:   14,
                  fontWeight: FontWeight.w500)),
          SizedBox(height: 5),
          Text('Send a message to start the conversation',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _buildChatError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 46, color: AppColors.border),
            const SizedBox(height: 12),
            Text(_chatError ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color:    AppColors.textSecondary,
                    fontSize: 13.5)),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _fetchCommunications,
              icon: const Icon(Icons.refresh_rounded,
                  size: 16, color: Colors.white),
              label: const Text('Retry',
                  style: TextStyle(
                      color:      Colors.white,
                      fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation:       0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmer(
          {required double width,
          required double height,
          required double radius}) =>
      _ShimmerBox(width: width, height: height, radius: radius);
}

// ── Shimmer ──────────────────────────────────────────────────────────────────
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