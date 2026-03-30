import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/common/string_extensions.dart';

// ── Contact Model ──────────────────────────────────────────────────────────
class Contact {
  final String id;
  final String name;
  final String phone;

  const Contact({
    required this.id,
    required this.name,
    required this.phone,
  });

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        id:    json['id']            ?? '',
        name:  json['contact_name']  ?? '',
        phone: json['contact_phone'] ?? '',
      );
}

// ── Contact List Page ──────────────────────────────────────────────────────
class ContactListPage extends StatefulWidget {
  final String customerId;
  final String customerName;
  final bool   readOnly;     // ← NEW

  const ContactListPage({
    super.key,
    required this.customerId,
    required this.customerName,
    this.readOnly = false,    // ← NEW (defaults to false)
  });

  @override
  State<ContactListPage> createState() => _ContactListPageState();
}

class _ContactListPageState extends State<ContactListPage> {
  List<Contact> _contacts   = [];
  bool          _isLoading  = true;
  String?       _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  // ── Fetch contacts ─────────────────────────────────────────────────────────
  Future<void> _fetchContacts() async {
    setState(() {
      _isLoading    = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse(
        '${ApiService.baseUrl}/api/customer/contact_list.php?customer_id=${widget.customerId}',
      );

      debugPrint('──── API REQUEST ────────────────────────────────────────');
      debugPrint('GET ${url.toString()}');

      final response = await ApiService.get(url).timeout(const Duration(seconds: 15));

      debugPrint('──── API RESPONSE ───────────────────────────────────────');
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Body:   ${response.body}');
      debugPrint('─────────────────────────────────────────────────────────');

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final List list = data['data'] ?? [];
        _contacts = list.map((e) => Contact.fromJson(e)).toList();
      } else {
        _errorMessage = data['message'] ?? 'Failed to load contacts.';
      }
    } on http.ClientException {
      _errorMessage = 'Unable to reach the server. Check your connection.';
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ── Add Contact API ────────────────────────────────────────────────────────
  Future<void> _addContact(String name, String phone) async {
    final url  = Uri.parse('${ApiService.baseUrl}/api/customer/contact_add.php');
    final body = jsonEncode({
      'customer_id':   widget.customerId,
      'contact_name':  name,
      'contact_phone': phone,
    });

    debugPrint('──── API REQUEST ────────────────────────────────────────');
    debugPrint('POST ${url.toString()}');
    debugPrint('Body:   $body');

    try {
      final response = await ApiService.post(url, body: body)
          .timeout(const Duration(seconds: 15));

      debugPrint('──── API RESPONSE ───────────────────────────────────────');
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Body:   ${response.body}');
      debugPrint('─────────────────────────────────────────────────────────');

      if (!mounted) return;
      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Contact added successfully.');
        _fetchContacts();
      } else {
        AppSnackBar.show(
          context,
          data['message'] ?? 'Failed to add contact.',
          isError: true,
        );
      }
    } on http.ClientException {
      if (mounted) AppSnackBar.show(context, 'Unable to reach the server.', isError: true);
    } catch (_) {
      if (mounted) AppSnackBar.show(context, 'Something went wrong.', isError: true);
    }
  }

  // ── Update Contact API ─────────────────────────────────────────────────────
  Future<void> _updateContact(String contactId, String name, String phone) async {
    final url  = Uri.parse('${ApiService.baseUrl}/api/customer/contact_update.php');
    final body = jsonEncode({
      'contact_id':    contactId,
      'contact_name':  name,
      'contact_phone': phone,
    });

    debugPrint('──── API REQUEST ────────────────────────────────────────');
    debugPrint('POST ${url.toString()}');
    debugPrint('Body:   $body');

    try {
      final response = await ApiService.post(url, body: body)
          .timeout(const Duration(seconds: 15));

      debugPrint('──── API RESPONSE ───────────────────────────────────────');
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Body:   ${response.body}');
      debugPrint('─────────────────────────────────────────────────────────');

      if (!mounted) return;
      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Contact updated successfully.');
        _fetchContacts();
      } else {
        AppSnackBar.show(
          context,
          data['message'] ?? 'Failed to update contact.',
          isError: true,
        );
      }
    } on http.ClientException {
      if (mounted) AppSnackBar.show(context, 'Unable to reach the server.', isError: true);
    } catch (_) {
      if (mounted) AppSnackBar.show(context, 'Something went wrong.', isError: true);
    }
  }

  // ── Delete Contact API ─────────────────────────────────────────────────────
  Future<void> _deleteContact(String contactId) async {
    final url  = Uri.parse('${ApiService.baseUrl}/api/customer/contact_delete.php');
    final body = jsonEncode({'contact_id': contactId});

    debugPrint('──── API REQUEST ────────────────────────────────────────');
    debugPrint('POST ${url.toString()}');
    debugPrint('Body:   $body');

    try {
      final response = await ApiService.post(url, body: body)
          .timeout(const Duration(seconds: 15));

      debugPrint('──── API RESPONSE ───────────────────────────────────────');
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Body:   ${response.body}');
      debugPrint('─────────────────────────────────────────────────────────');

      if (!mounted) return;
      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        AppSnackBar.show(context, 'Contact deleted successfully.');
        _fetchContacts();
      } else {
        AppSnackBar.show(
          context,
          data['message'] ?? 'Failed to delete contact.',
          isError: true,
        );
      }
    } on http.ClientException {
      if (mounted) AppSnackBar.show(context, 'Unable to reach the server.', isError: true);
    } catch (_) {
      if (mounted) AppSnackBar.show(context, 'Something went wrong.', isError: true);
    }
  }

  // ── Add Contact Dialog ─────────────────────────────────────────────────────
  void _showAddContactDialog() {
    _showContactDialog(
      title:       'Add Contact',
      headerIcon:  Icons.person_add_alt_1_rounded,
      actionLabel: 'Save',
      onSubmit:    (name, phone) => _addContact(name, phone),
    );
  }

  // ── Edit Contact Dialog ────────────────────────────────────────────────────
  void _showEditContactDialog(Contact c) {
    _showContactDialog(
      title:        'Edit Contact',
      headerIcon:   Icons.edit_outlined,
      actionLabel:  'Update',
      prefillName:  c.name,
      prefillPhone: c.phone,
      onSubmit:     (name, phone) => _updateContact(c.id, name, phone),
    );
  }

  // ── Shared Contact Dialog (Add / Edit) ────────────────────────────────────
  void _showContactDialog({
    required String   title,
    required IconData headerIcon,
    required String   actionLabel,
    String prefillName  = '',
    String prefillPhone = '',
    required Future<void> Function(String name, String phone) onSubmit,
  }) {
    final nameCtrl  = TextEditingController(text: prefillName);
    final phoneCtrl = TextEditingController(text: prefillPhone);
    bool isBusy     = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ───────────────────────────────────────────────
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(headerIcon,
                              color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Name ─────────────────────────────────────────────────
                    Text('NAME', style: AppTextStyles.fieldLabel(false)),
                    const SizedBox(height: 7),
                    _dialogTextField(
                      controller:     nameCtrl,
                      hint:           'Enter contact name',
                      icon:           Icons.person_outline_rounded,
                      keyboardType:   TextInputType.name,
                      setDialogState: setDialogState,
                    ),

                    const SizedBox(height: 14),

                    // ── Phone ─────────────────────────────────────────────────
                    Text('PHONE NUMBER', style: AppTextStyles.fieldLabel(false)),
                    const SizedBox(height: 7),
                    _dialogTextField(
                      controller:     phoneCtrl,
                      hint:           'Enter phone number',
                      icon:           Icons.phone_outlined,
                      keyboardType:   TextInputType.phone,
                      setDialogState: setDialogState,
                    ),

                    const SizedBox(height: 22),

                    // ── Buttons ───────────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isBusy
                                ? null
                                : () => Navigator.pop(dialogCtx),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppColors.border, width: 1.3),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              backgroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
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
                            onPressed: isBusy
                                ? null
                                : () async {
                                    final name  = nameCtrl.text.trim();
                                    final phone = phoneCtrl.text.trim();

                                    if (name.isEmpty) {
                                      AppSnackBar.show(context,
                                          'Please enter a name.',
                                          isError: true);
                                      return;
                                    }
                                    if (phone.isEmpty) {
                                      AppSnackBar.show(context,
                                          'Please enter a phone number.',
                                          isError: true);
                                      return;
                                    }

                                    setDialogState(() => isBusy = true);
                                    Navigator.pop(dialogCtx);
                                    await onSubmit(name, phone);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              disabledBackgroundColor:
                                  AppColors.primary.withOpacity(0.5),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: isBusy
                                  ? const SizedBox(
                                      key: ValueKey('busy-loader'),
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.3),
                                    )
                                  : Text(
                                      actionLabel,
                                      key: const ValueKey('action-label'),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Delete Confirmation Dialog ─────────────────────────────────────────────
  void _showDeleteDialog(Contact c) {
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ───────────────────────────────────────────────
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.error, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Delete Contact',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Contact preview ───────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                            color: AppColors.borderLight, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name.capitalize(),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (c.phone.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              c.phone,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12.5),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Confirmation message ──────────────────────────────────
                    const Text(
                      'Are you sure you want to delete this contact? This action cannot be undone.',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.5),
                    ),

                    const SizedBox(height: 20),

                    // ── Buttons ───────────────────────────────────────────────
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
                                  borderRadius: BorderRadius.circular(10)),
                              backgroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
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
                            onPressed: isDeleting
                                ? null
                                : () async {
                                    setDialogState(() => isDeleting = true);
                                    Navigator.pop(dialogCtx);
                                    await _deleteContact(c.id);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              disabledBackgroundColor:
                                  AppColors.error.withOpacity(0.5),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: isDeleting
                                  ? const SizedBox(
                                      key: ValueKey('del-loader'),
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.3),
                                    )
                                  : const Text(
                                      'Delete',
                                      key: ValueKey('del-label'),
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Dialog text field helper ───────────────────────────────────────────────
  Widget _dialogTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required TextInputType keyboardType,
    required StateSetter setDialogState,
  }) {
    return Focus(
      onFocusChange: (_) => setDialogState(() {}),
      child: Builder(builder: (focusCtx) {
        final focused = Focus.of(focusCtx).hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: focused
              ? AppDecorations.inputFocused
              : AppDecorations.inputIdle,
          child: TextField(
            controller:   controller,
            keyboardType: keyboardType,
            cursorColor:  AppColors.primary,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                  color: AppColors.textHint, fontSize: 13),
              prefixIcon:
                  Icon(icon, color: AppColors.iconDefault, size: 17),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
            ),
          ),
        );
      }),
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

            // ── Customer banner ─────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.18), width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle),
                      child: Center(
                        child: Text(
                          widget.customerName.isNotEmpty
                              ? widget.customerName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.customerName.capitalize(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 1),
                          const Text(
                            'Contact List',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isLoading)
                      Text(
                        '${_contacts.length} contact${_contacts.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: AppColors.primary.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: _isLoading
                  ? _buildSkeletonList(hPad)
                  : _errorMessage != null
                      ? _buildError()
                      : _contacts.isEmpty
                          ? _buildEmpty()
                          : _buildContactList(hPad),
            ),
          ],
        ),
      ),

      // ── FAB: Add contact ──────────────────────────────────────────────────
      floatingActionButton: widget.readOnly // ← NEW: Hide FAB if read-only
          ? null
          : FloatingActionButton(
              onPressed: _showAddContactDialog,
              backgroundColor: AppColors.primary,
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 24),
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
            'Contacts',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: isTablet ? 20 : 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _fetchContacts,
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

  // ── Contact list ───────────────────────────────────────────────────────────
  Widget _buildContactList(double hPad) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 80),
      itemCount: _contacts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _contactCard(_contacts[i]),
    );
  }

  // ── Contact card ───────────────────────────────────────────────────────────
  Widget _contactCard(Contact c) {
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
        children: [
          // ── Avatar ──────────────────────────────────────────────────────
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: AppColors.primaryLight, shape: BoxShape.circle),
            child: Center(
              child: Text(
                c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ── Name + phone ─────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name.capitalize(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (c.phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        c.phone,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Action icons: Edit + Delete ──────────────────────────────────
          if (!widget.readOnly) // ← NEW: Hide actions if read-only
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionIcon(
                  icon:    Icons.edit_outlined,
                  color:   AppColors.primary,
                  bgColor: AppColors.primaryLight,
                  onTap:   () => _showEditContactDialog(c),
                ),
                const SizedBox(width: 7),
                _actionIcon(
                  icon:    Icons.delete_outline_rounded,
                  color:   AppColors.error,
                  bgColor: const Color(0xFFFFF1F1),
                  onTap:   () => _showDeleteDialog(c),
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
        width: 32,
        height: 32,
        decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }

  // ── Skeleton ───────────────────────────────────────────────────────────────
  Widget _buildSkeletonList(double hPad) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 80),
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
        children: [
          _ShimmerBox(width: 40, height: 40, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(width: double.infinity, height: 13, radius: 4),
                const SizedBox(height: 6),
                _ShimmerBox(width: 130, height: 11, radius: 4),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _ShimmerBox(width: 32, height: 32, radius: 8),
          const SizedBox(width: 7),
          _ShimmerBox(width: 32, height: 32, radius: 8),
        ],
      ),
    );
  }

  // ── Empty ──────────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.contacts_outlined,
              size: 56, color: AppColors.border),
          const SizedBox(height: 14),
          const Text(
            'No contacts yet',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap the + button to add a contact',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
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
            onPressed: _fetchContacts,
            icon: const Icon(Icons.refresh_rounded,
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
  final double width;
  final double height;
  final double radius;

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
          width:  widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EDF5),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
}