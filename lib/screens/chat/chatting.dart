import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coremicron_crm_app/common/api_service.dart';
import 'package:coremicron_crm_app/common/theme.dart';
import 'package:coremicron_crm_app/common/string_extensions.dart';
import 'package:coremicron_crm_app/common/chat_websocket_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class ChattingPage extends StatefulWidget {
  final String username;
  final String employeeName;
  final String employeeId;
  final String? conversationId;

  const ChattingPage({
    super.key,
    required this.username,
    required this.employeeName,
    required this.employeeId,
    this.conversationId,
  });

  @override
  State<ChattingPage> createState() => _ChattingPageState();
}

class _ChattingPageState extends State<ChattingPage> {
  String? _convId;
  List<dynamic> _messages = [];
  bool _isLoading = false;
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ImagePicker _picker = ImagePicker();
  StreamSubscription? _wsSub;

  // Staging
  File? _pendingFile;
  final Set<dynamic> _downloadingIds = {};

  @override
  void initState() {
    super.initState();
    _convId = widget.conversationId;
    if (_convId == null) {
      _startChat();
    } else {
      _fetchMessages();
    }
    _listenToWebSocket();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _wsSub?.cancel();
    super.dispose();
  }

  void _listenToWebSocket() {
    _wsSub = ChatWebSocketService().messageStream.listen((msg) {
      if (msg['type'] == 'chat_message') {
        if (msg['conversation_id'] == _convId) {
          _onReceiveMessage(msg);
        }
      }
    });
  }

  void _onReceiveMessage(dynamic msg) {
    if (!mounted) return;
    setState(() {
      _messages.add({
        'id': msg['message_id'],
        'sender_id': msg['sender_id'],
        'message': msg['message'],
        'file_path': msg['file'],
        'message_type': msg['file'] != null ? 'file' : 'text',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
    _scrollToBottom();
  }

  Future<void> _startChat() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${ApiService.baseUrl}/api/chat/start.php');
      final res = await ApiService.post(url, body: jsonEncode({
        'employee_id': widget.employeeId,
      })).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['success'] == true) {
        setState(() {
          _convId = data['conversation_id'];
        });
        _fetchMessages();
      } else {
        AppSnackBar.show(context, data['message'] ?? 'Failed to start chat', isError: true);
      }
    } catch (e) {
      AppSnackBar.show(context, 'Error starting chat', isError: true);
    } finally {
      if (mounted && _convId == null) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMessages() async {
    if (_convId == null) return;
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${ApiService.baseUrl}/api/chat/messages.php?conversation_id=$_convId');
      final res = await ApiService.get(url).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['success'] == true) {
        setState(() {
          _messages = data['data'] ?? [];
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error fetching messages: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({String? message}) async {
    if (_convId == null) return;
    final msgText = message?.trim() ?? '';
    if (msgText.isEmpty && _pendingFile == null) return;

    final url = Uri.parse('${ApiService.baseUrl}/api/chat/send.php');
    
    try {
      final req = http.MultipartRequest('POST', url);
      req.fields['conversation_id'] = _convId!;
      if (msgText.isNotEmpty) req.fields['message'] = msgText;
      
      if (_pendingFile != null) {
        req.files.add(await http.MultipartFile.fromPath('file', _pendingFile!.path));
      }

      final response = await ApiService.sendMultipart(req);
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        setState(() {
          _msgCtrl.clear();
          _pendingFile = null;
        });
        _fetchMessages();
      } else {
        AppSnackBar.show(context, data['message'] ?? 'Failed to send', isError: true);
      }
    } catch (e) {
      AppSnackBar.show(context, 'Failed to send message', isError: true);
    }
  }

  Future<void> _pickImage() async {
    final XFile? img = await _picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() => _pendingFile = File(img.path));
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() => _pendingFile = File(result.files.single.path!));
    }
  }

  Future<void> _downloadAndOpenFile(dynamic msgId, String url, String fileName, {bool shouldShare = false}) async {
    if (_downloadingIds.contains(msgId)) return;
    
    setState(() => _downloadingIds.add(msgId));
    try {
      final response = await http.get(Uri.parse(url));
      
      File? file;
      if (Platform.isAndroid && !shouldShare) {
        // Try to save to a more public external directory on Android
        final externalDirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
        if (externalDirs != null && externalDirs.isNotEmpty) {
           file = File('${externalDirs.first.path}/$fileName');
        }
      }
      
      // Fallback to temp/documents
      if (file == null) {
        final dir = await getTemporaryDirectory();
        file = File('${dir.path}/$fileName');
      }

      await file.writeAsBytes(response.bodyBytes);

      if (shouldShare) {
        await Share.shareXFiles([XFile(file.path)], text: fileName);
      } else {
        final ext = fileName.split('.').last.toLowerCase();
        if (ext == 'zip' || ext == 'rar' || ext == '7z') {
          AppSnackBar.show(context, 'Saved to ${file.path}');
          // For ZIPs, we usually just show it in the Downloads folder or share it
          // Since opening might fail if no ZIP app is installed, we offer share as well
          await Share.shareXFiles([XFile(file.path)], text: fileName);
        } else {
          AppSnackBar.show(context, 'Opening $fileName...');
          final result = await OpenFilex.open(file.path);
          if (result.type != ResultType.done) {
            // If failed to open, fallback to share
            await Share.shareXFiles([XFile(file.path)], text: fileName);
          }
        }
      }
    } catch (e) {
      AppSnackBar.show(context, 'Error processing file: $e', isError: true);
    } finally {
      if (mounted) setState(() => _downloadingIds.remove(msgId));
    }
  }

  String _formatTime(String? createdAt) {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final m = dt.minute.toString().padLeft(2, '0');
      final p = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $p';
    } catch (_) {
      return '';
    }
  }

  String _formatDate(String? createdAt) {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final date = DateTime(dt.year, dt.month, dt.day);

      if (date == today) return 'Today';
      if (date == yesterday) return 'Yesterday';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5DDD5), 
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              child: Text(
                widget.employeeName.isNotEmpty ? widget.employeeName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.employeeName.capitalize(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetchMessages),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg['sender_id'] != widget.employeeId;
                      
                      final showDate = index == 0 || _formatDate(msg['created_at']) != _formatDate(_messages[index - 1]['created_at']);

                      return Column(
                        children: [
                          if (showDate)
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _formatDate(msg['created_at']),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54),
                              ),
                            ),
                          _buildMessageBubble(msg, isMe),
                        ],
                      );
                    },
                  ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(dynamic msg, bool isMe) {
    final String text = msg['message'] ?? '';
    final type = msg['message_type'] ?? 'text';
    final filePath = msg['file_path'];
    final time = _formatTime(msg['created_at']);
    final bool isImage = filePath != null && (filePath.endsWith('.jpg') || filePath.endsWith('.jpeg') || filePath.endsWith('.png'));

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () {
          if (filePath != null && filePath.toString().isNotEmpty) {
            final fullUrl = '${ApiService.baseUrl}/$filePath';
            if (isImage) {
               _viewFullScreenImage(msg['id'], fullUrl);
            } else {
               _downloadAndOpenFile(msg['id'], fullUrl, filePath.split('/').last);
            }
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(isMe ? 12 : 0),
              bottomRight: Radius.circular(isMe ? 0 : 12),
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (type == 'file' || (filePath != null && filePath.toString().isNotEmpty))
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      isImage
                          ? Hero(
                              tag: filePath,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  '${ApiService.baseUrl}/$filePath', 
                                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.insert_drive_file, size: 24, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    filePath?.split('/').last ?? 'File',
                                    style: const TextStyle(fontSize: 13, decoration: TextDecoration.underline),
                                  ),
                                ),
                              ],
                            ),
                      if (_downloadingIds.contains(msg['id']))
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            shape: isImage ? BoxShape.rectangle : BoxShape.circle,
                            borderRadius: isImage ? BorderRadius.circular(8) : null,
                          ),
                          child: const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (text.isNotEmpty)
                Text(
                  text,
                  style: const TextStyle(fontSize: 14.5, color: Colors.black87),
                ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                   Text(
                    time,
                    style: TextStyle(fontSize: 10, color: Colors.black.withOpacity(0.4)),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.done_all_rounded, size: 14, color: Colors.black.withOpacity(0.3)), // Removed blue color
                  ]
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewFullScreenImage(dynamic msgId, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, setInnerState) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              actions: [
                if (_downloadingIds.contains(msgId))
                   const Padding(
                     padding: EdgeInsets.symmetric(horizontal: 16),
                     child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                   )
                else ...[
                  IconButton(
                    icon: const Icon(Icons.share_rounded),
                    onPressed: () async {
                      setInnerState(() {}); 
                      await _downloadAndOpenFile(msgId, url, url.split('/').last, shouldShare: true);
                      if (context.mounted) setInnerState(() {});
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded),
                    onPressed: () async {
                      setInnerState(() {}); 
                      await _downloadAndOpenFile(msgId, url, url.split('/').last);
                      if (context.mounted) setInnerState(() {});
                    },
                  ),
                ],
              ],
            ),
            body: Center(
              child: InteractiveViewer(
                child: Image.network(url),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_pendingFile != null) _buildPendingAttachmentPreview(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: Colors.white,
          child: SafeArea(
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.attach_file, color: AppColors.textSecondary), onPressed: _pickFile),
                IconButton(icon: const Icon(Icons.camera_alt, color: AppColors.textSecondary), onPressed: _pickImage),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Type a message',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      maxLines: 4,
                      minLines: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () => _sendMessage(message: _msgCtrl.text),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingAttachmentPreview() {
    final fileName = _pendingFile!.path.split('/').last;
    final bool isImage = fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') || fileName.endsWith('.png');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: isImage
                ? Image.file(_pendingFile!, width: 40, height: 40, fit: BoxFit.cover)
                : const Icon(Icons.insert_drive_file, size: 32, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => setState(() => _pendingFile = null),
          ),
        ],
      ),
    );
  }
}
