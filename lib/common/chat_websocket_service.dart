import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coremicron_crm_app/common/api_service.dart';

class ChatWebSocketService {
  static final ChatWebSocketService _instance = ChatWebSocketService._internal();
  factory ChatWebSocketService() => _instance;
  ChatWebSocketService._internal();

  WebSocket? _ws;
  bool _isConnected = false;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isConnected) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(kWsIdKey) ?? '';
      
      if (userId.isEmpty) {
        debugPrint('⚠️  ChatWebSocketService: No ws_id found');
        return;
      }

      final wsUrl = ApiService.baseUrl
          .replaceFirst('https://', 'ws://')
          .replaceFirst('http://', 'ws://') + ':8000';
      
      debugPrint('🔌  ChatWebSocketService: Connecting to $wsUrl ...');
      
      _ws = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 10));
      _isConnected = true;
      debugPrint('✅  ChatWebSocketService: Connected');

      // 1. Auth
      _ws!.add(jsonEncode({
        'type': 'auth',
        'user_id': userId,
      }));

      // 2. Listen
      _ws!.listen(
        (data) {
          try {
            final Map<String, dynamic> msg = jsonDecode(data);
            _messageController.add(msg);
          } catch (e) {
            debugPrint('⚠️  ChatWebSocketService: Error parsing message: $e');
          }
        },
        onDone: () {
          debugPrint('❌  ChatWebSocketService: Disconnected');
          _isConnected = false;
          _ws = null;
          _reconnect();
        },
        onError: (e) {
          debugPrint('❌  ChatWebSocketService Error: $e');
          _isConnected = false;
          _ws = null;
          _reconnect();
        },
      );
    } catch (e) {
      debugPrint('❌  ChatWebSocketService Connection Failed: $e');
      _isConnected = false;
      _reconnect();
    }
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isConnected) connect();
    });
  }

  void dispose() {
    _ws?.close();
    _isConnected = false;
  }
}
