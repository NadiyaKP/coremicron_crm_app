import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:coremicron_crm_app/common/api_service.dart' show ApiService, AppSnackBar;
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/screens/ticket/amc_details.dart' show AmcScheduleItem;
import 'package:coremicron_crm_app/common/string_extensions.dart';

class _Employee {
  final String id;
  final String name;
  final String phone;
  final String employeeId;
  _Employee({required this.id, required this.name, required this.phone, required this.employeeId});
}

class AssignAmcPage extends StatefulWidget {
  final AmcScheduleItem schedule;
  const AssignAmcPage({super.key, required this.schedule});

  @override
  State<AssignAmcPage> createState() => _AssignAmcPageState();
}

class _AssignAmcPageState extends State<AssignAmcPage> {
  bool _isSaving = false;

  // Employee autocomplete
  final _employeeCtrl = TextEditingController();
  final _employeeFocus = FocusNode();
  _Employee? _selectedEmployee;
  List<_Employee> _allEmployees = [];
  List<_Employee> _employeeSuggestions = [];
  bool _employeesLoaded = false;
  Timer? _employeeDebounce;
  final _employeeLayerLink = LayerLink();
  OverlayEntry? _employeeOverlay;

  // Work description
  final _workCtrl = TextEditingController();
  final _workFocus = FocusNode();

  // Speech to text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _baseSpeechText = '';

  // Image upload
  File? _pickedImage;
  String? _serverImage;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _employeeFocus.addListener(() {
      if (!_employeeFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 150), _removeEmployeeOverlay);
      }
      setState(() {});
    });
    _workFocus.addListener(() => setState(() {}));
    _initSpeech();
    _preFill();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize();
    if (mounted) setState(() {});
  }

  void _startListening() async {
    if (!_speechAvailable) {
      AppSnackBar.show(context, 'Speech recognition not available.', isError: true);
      return;
    }
    _baseSpeechText = _workCtrl.text.trim();
    if (_baseSpeechText.isNotEmpty) _baseSpeechText += ' ';
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _workCtrl.text = _baseSpeechText + result.recognizedWords;
          _workCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _workCtrl.text.length));
        });
      },
      listenFor: const Duration(minutes: 1),
      pauseFor: const Duration(seconds: 10),
      localeId: 'en_US',
      cancelOnError: false,
      partialResults: true,
    );
    _speech.statusListener = (status) {
      if ((status == 'done' || status == 'notListening') && _isListening && mounted) {
        _restartListening();
      }
    };
  }

  void _stopListening() async {
    setState(() => _isListening = false);
    await _speech.stop();
  }

  void _restartListening() async {
    if (!_isListening || !mounted) return;
    _baseSpeechText = _workCtrl.text.trim();
    if (_baseSpeechText.isNotEmpty) _baseSpeechText += ' ';
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _workCtrl.text = _baseSpeechText + result.recognizedWords;
          _workCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _workCtrl.text.length));
        });
      },
      listenFor: const Duration(minutes: 1),
      pauseFor: const Duration(seconds: 10),
      localeId: 'en_US',
      cancelOnError: false,
      partialResults: true,
    );
  }

  void _preFill() {
    // Fill work description if present
    if (widget.schedule.toDo != null && widget.schedule.toDo!.isNotEmpty) {
      _workCtrl.text = widget.schedule.toDo!;
    }
    
    // Fill server image if present
    if (widget.schedule.image != null && widget.schedule.image!.isNotEmpty) {
      _serverImage = widget.schedule.image;
    }
    
    // Fill employee if both ID and name are present
    if (widget.schedule.assignId != null && 
        widget.schedule.assignId!.isNotEmpty && 
        widget.schedule.employeeName != null &&
        widget.schedule.employeeName!.isNotEmpty) {
      _selectedEmployee = _Employee(
        id: widget.schedule.assignId!,
        name: widget.schedule.employeeName!,
        phone: '',
        employeeId: '',
      );
      _employeeCtrl.text = widget.schedule.employeeName!.capitalize();
    }
  }

  @override
  void dispose() {
    _removeEmployeeOverlay();
    _employeeDebounce?.cancel();
    _employeeCtrl.dispose();
    _workCtrl.dispose();
    _employeeFocus.dispose();
    _workFocus.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) {
      setState(() {
        _pickedImage = File(file.path);
        _serverImage = null;
      });
    }
  }

  Future<void> _loadEmployees() async {
    if (_employeesLoaded) return;
    try {
      final url = Uri.parse('${ApiService.baseUrl}/api/employee/list.php?view=dropdown');
      final res = await ApiService.get(url).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        final list = data['data'] as List? ?? [];
        _allEmployees = list.map((e) => _Employee(
          id: e['id'] ?? '',
          name: e['employee_name'] ?? '',
          phone: e['phone_number'] ?? '',
          employeeId: e['employee_id'] ?? '',
        )).toList();
        _employeesLoaded = true;
      }
    } catch (_) {}
  }

  void _onEmployeeChanged(String query) {
    _selectedEmployee = null;
    _employeeDebounce?.cancel();
    _employeeDebounce = Timer(const Duration(milliseconds: 250), () async {
      await _loadEmployees();
      final q = query.trim().toLowerCase();
      if (q.isEmpty) { _removeEmployeeOverlay(); return; }
      _employeeSuggestions = _allEmployees.where((e) =>
          e.name.toLowerCase().contains(q) ||
          e.phone.contains(q) ||
          e.employeeId.toLowerCase().contains(q)).toList();
      _employeeSuggestions.isNotEmpty ? _showEmployeeDropdown() : _removeEmployeeOverlay();
    });
  }

  void _showEmployeeDropdown() {
    _removeEmployeeOverlay();
    _employeeOverlay = OverlayEntry(
      builder: (_) => Positioned(
        width: _employeeLayerLink.leaderSize?.width ?? 300,
        child: CompositedTransformFollower(
          link: _employeeLayerLink,
          showWhenUnlinked: false,
          offset: Offset(0, (_employeeLayerLink.leaderSize?.height ?? 48) + 4),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _employeeSuggestions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderLight),
                  itemBuilder: (_, i) => _employeeTile(_employeeSuggestions[i]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_employeeOverlay!);
  }

  void _removeEmployeeOverlay() {
    _employeeOverlay?.remove();
    _employeeOverlay = null;
  }

  void _selectEmployee(_Employee e) {
    _removeEmployeeOverlay();
    setState(() {
      _selectedEmployee = e;
      _employeeCtrl.text = e.name.capitalize();
    });
    FocusScope.of(context).requestFocus(_workFocus);
  }

  Widget _employeeTile(_Employee e) {
    return InkWell(
      onTap: () => _selectEmployee(e),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
              child: Center(
                child: Text(e.name.isNotEmpty ? e.name[0].toUpperCase() : 'E',
                  style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.name.capitalize(), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600)),
                  Text(e.phone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedEmployee == null) {
      AppSnackBar.show(context, 'Please select an employee.', isError: true);
      return;
    }
    if (_workCtrl.text.trim().isEmpty) {
      AppSnackBar.show(context, 'Please enter the work description.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final url = Uri.parse('${ApiService.baseUrl}/api/ticket/amc_assign.php');
      final req = http.MultipartRequest('POST', url);

      req.fields['schedule_id'] = widget.schedule.scheduleId;
      req.fields['assign_id'] = _selectedEmployee!.id;
      req.fields['to_do'] = _workCtrl.text.trim();

      if (_pickedImage != null) {
        final ext = _pickedImage!.path.split('.').last.toLowerCase();
        final mimeType = (ext == 'png') ? 'image/png' : 'image/jpeg';
        req.files.add(await http.MultipartFile.fromPath('image', _pickedImage!.path, contentType: MediaType.parse(mimeType)));
      }

      final res = await ApiService.sendMultipart(req).timeout(const Duration(seconds: 30));
      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['success'] == true) {
        Navigator.pop(context, true);
        AppSnackBar.show(null, 'AMC Schedule assigned successfully.', isError: false);
      } else {
        AppSnackBar.show(context, data['message'] ?? 'Failed to assign.', isError: true);
      }
    } catch (_) {
      AppSnackBar.show(context, 'Something went wrong.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Assign AMC Schedule', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('ASSIGN TO'),
            const SizedBox(height: 8),
            CompositedTransformTarget(
              link: _employeeLayerLink,
              child: TextField(
                controller: _employeeCtrl,
                focusNode: _employeeFocus,
                onChanged: _onEmployeeChanged,
                decoration: _fieldDecoration('Select Employee', Icons.person_search_rounded, _employeeFocus.hasFocus),
              ),
            ),
            const SizedBox(height: 24),
            _sectionLabel('WORK DESCRIPTION'),
            const SizedBox(height: 8),
            _buildWorkField(),
            const SizedBox(height: 24),
            _sectionLabel('ATTACHMENT (Optional)'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: (_pickedImage != null || _serverImage != null)
                  ? () => _viewImage()
                  : _pickImage,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity, height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight, width: 1.5),
                    ),
                    child: _pickedImage != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_pickedImage!, fit: BoxFit.cover))
                        : _serverImage != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_serverImage!, fit: BoxFit.cover))
                            : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate_outlined, size: 32, color: AppColors.textSecondary), SizedBox(height: 8), Text('Add Image', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))]),
                  ),
                  if (_pickedImage != null || _serverImage != null)
                    Positioned(
                      bottom: 6, right: 6,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(8)),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.swap_horiz_rounded, size: 14, color: Colors.white), SizedBox(width: 4), Text('Change', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Assignment', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5));

  void _viewImage() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: _pickedImage != null
                    ? Image.file(_pickedImage!)
                    : Image.network(_serverImage!),
              ),
            ),
            Positioned(
              top: 40, right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _workFocus.hasFocus ? AppColors.primary : AppColors.borderLight, width: _workFocus.hasFocus ? 1.8 : 1.5),
      ),
      child: Column(
        children: [
          TextField(
            controller: _workCtrl,
            focusNode: _workFocus,
            maxLines: 4,
            minLines: 4,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Type or click speak button…',
              hintStyle: TextStyle(color: AppColors.textHint, fontSize: 13.5),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.borderLight))),
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isListening)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary)),
                        SizedBox(width: 8),
                        Text('Listening…', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                GestureDetector(
                  onTap: _isListening ? _stopListening : _startListening,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(color: _isListening ? AppColors.primary : AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Icon(_isListening ? Icons.stop_rounded : Icons.mic_none_rounded, size: 16, color: _isListening ? Colors.white : AppColors.primary),
                        const SizedBox(width: 6),
                        Text(_isListening ? 'STOP' : 'SPEAK', style: TextStyle(color: _isListening ? Colors.white : AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint, IconData icon, bool hasFocus) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: hasFocus ? AppColors.primary : AppColors.textSecondary),
      filled: true, fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderLight, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderLight, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.8)),
    );
  }
}
