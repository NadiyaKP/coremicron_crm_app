import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService, kTokenKey;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/screens/login.dart' show kTokenKey;
import 'package:coremicron_crm_app/screens/to-do/employee_response/employee_responses.dart';

class GiveEmployeeResponsePage extends StatefulWidget {
  final EmployeeResponse response;
  const GiveEmployeeResponsePage({super.key, required this.response});

  @override
  State<GiveEmployeeResponsePage> createState() => _GiveEmployeeResponsePageState();
}

class _GiveEmployeeResponsePageState extends State<GiveEmployeeResponsePage> {
  final TextEditingController _messageCtrl = TextEditingController();
  final TextEditingController _responseCtrl = TextEditingController();
  File? _selectedImage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _messageCtrl.text = widget.response.message;
    // Removed response prefilling as per user request
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _responseCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitResponse() async {
    if (_responseCtrl.text.trim().isEmpty) {
      AppSnackBar.show(context, 'Please enter a response', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final url = Uri.parse('${ApiService.baseUrl}/api/ticket/communication_reply.php');
      final request = http.MultipartRequest('POST', url);

      request.fields['communication_id'] = widget.response.communicationId;
      request.fields['response_text'] = _responseCtrl.text.trim();

      if (_selectedImage != null) {
        final stream = http.ByteStream(_selectedImage!.openRead());
        final length = await _selectedImage!.length();
        final multipartFile = http.MultipartFile(
          'image',
          stream,
          length,
          filename: _selectedImage!.path.split('/').last,
          contentType: MediaType('image', 'jpeg'), // Or detect dynamically
        );
        request.files.add(multipartFile);
      }

      final response = await ApiService.sendMultipart(request).timeout(const Duration(seconds: 30));

      debugPrint('📥  [SUBMIT RESPONSE] ${response.statusCode}  ${response.body}');

      if (response.statusCode == 200) {
        AppSnackBar.show(context, 'Response submitted successfully');
        Navigator.pop(context, true);
      } else {
        AppSnackBar.show(context, 'Failed to submit response: ${response.reasonPhrase}', isError: true);
      }
    } catch (e) {
      debugPrint('❌  [SUBMIT RESPONSE] Error: $e');
      AppSnackBar.show(context, 'An error occurred. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final hPad = isTablet ? size.width * 0.08 : 20.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(isTablet, hPad),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Message'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _messageCtrl,
              readOnly: true,
            ),
            const SizedBox(height: 24),
            _buildLabel('Response'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _responseCtrl,
              hintText: 'Type your response here',
            ),
            const SizedBox(height: 24),
            _buildAttachmentSection(),
            const SizedBox(height: 40),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isTablet, double hPad) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leadingWidth: 70,
      leading: Center(
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.border, width: 1.2),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: AppColors.textPrimary),
          ),
        ),
      ),
      title: Text(
        'Give Response',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: isTablet ? 20 : 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: AppColors.borderLight, height: 1),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    bool readOnly = false,
    String? hintText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: readOnly ? AppColors.borderLight.withOpacity(0.3) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        minLines: 1,
        maxLines: null,
        style: TextStyle(
          color: readOnly ? AppColors.textSecondary : AppColors.textPrimary,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildAttachmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Add attachment'),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1.2, style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 32),
                const SizedBox(height: 8),
                Text(
                  _selectedImage == null ? 'Select image from gallery' : 'Change Image',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        if (_selectedImage != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(_selectedImage!, width: 60, height: 60, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedImage!.path.split('/').last,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _selectedImage = null),
                  icon: const Icon(Icons.cancel_outlined, color: AppColors.error, size: 20),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: AppButtonStyles.outline.copyWith(
              padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 16)),
            ),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitResponse,
            style: AppButtonStyles.primary.copyWith(
              padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 16)),
            ),
            child: _isSubmitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Submit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
