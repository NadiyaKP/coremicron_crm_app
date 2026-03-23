import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'theme.dart';

const String kTokenKey   = 'auth_token';
const String kWsIdKey    = 'workspace_id';

class ApiService {
  /// Base URL for the entire app.
  /// Import this file and use [ApiService.baseUrl] + your endpoint.
  static const String baseUrl = 'https://192.168.1.123';

  /// Standard response handler for global errors (e.g., 403 Forbidden)
  /// and extracting session cookies.
  static Future<void> _handleResponse(http.BaseResponse response) async {
    debugPrint('📥  ApiService: [${response.statusCode}] ${response.request?.url}');
    
    if (response.statusCode == 403) {
      AppSnackBar.show(null, 'you have no permission to access this module', isError: true);
    }
  }

  /// Helper to inject session headers.
  static Future<Map<String, String>> _getHeaders(Map<String, String>? headers, {Uri? url}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(kTokenKey) ?? '';
    final newHeaders = Map<String, String>.from(headers ?? {});
    
    // Add content type if not present
    if (!newHeaders.containsKey('Content-Type')) {
      newHeaders['Content-Type'] = 'application/json';
    }
    // Keep Content-Type as it's standard for JSON APIs

    final isLogin = url?.path.endsWith('/auth/login.php') ?? false;

    if (isLogin) {
      newHeaders['X-Client'] = 'flutter';
    } else if (token.isNotEmpty) {
      newHeaders['Authorization'] = 'Bearer $token';
    }

    debugPrint('   🔑  Headers: $newHeaders');
    return newHeaders;
  }

  /// Wrapper for http.get with global error handling.
  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    try {
      final finalHeaders = await _getHeaders(headers, url: url);
      final response = await http.get(url, headers: finalHeaders);
      await _handleResponse(response);
      return response;
    } catch (e) {
      debugPrint('❌  ApiService.get Error: $e');
      rethrow;
    }
  }

  static Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body}) async {
    try {
      final finalHeaders = await _getHeaders(headers, url: url);
      final response = await http.post(url, headers: finalHeaders, body: body);
      await _handleResponse(response);
      return response;
    } catch (e) {
      debugPrint('❌  ApiService.post Error: $e');
      rethrow;
    }
  }

  static Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body}) async {
    final finalHeaders = await _getHeaders(headers, url: url);
    final response = await http.put(url, headers: finalHeaders, body: body);
    await _handleResponse(response);
    return response;
  }

  static Future<http.Response> delete(Uri url, {Map<String, String>? headers, Object? body}) async {
    final finalHeaders = await _getHeaders(headers, url: url);
    final response = await http.delete(url, headers: finalHeaders, body: body);
    await _handleResponse(response);
    return response;
  }

  static Future<http.Response> sendMultipart(http.MultipartRequest request) async {
    try {
      final finalHeaders = await _getHeaders(request.headers, url: request.url);
      request.headers.addAll(finalHeaders);

      final streamedRes = await request.send();
      final response = await http.Response.fromStream(streamedRes);
      await _handleResponse(response);
      return response;
    } catch (e) {
      debugPrint('❌  ApiService.sendMultipart Error: $e');
      rethrow;
    }
  }
}