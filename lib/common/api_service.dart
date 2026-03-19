import 'package:http/http.dart' as http;
import 'theme.dart';

class ApiService {
  /// Base URL for the entire app.
  /// Import this file and use [ApiService.baseUrl] + your endpoint.
  static const String baseUrl = 'http://192.168.1.123:8080/website/crm_backend';

  /// Standard response handler for global errors (e.g., 403 Forbidden).
  static void _handleResponse(http.BaseResponse response) {
    if (response.statusCode == 403) {
      AppSnackBar.show(null, 'you have no permission to access this module', isError: true);
    }
  }

  /// Wrapper for http.get with global error handling.
  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final response = await http.get(url, headers: headers);
    _handleResponse(response);
    return response;
  }

  /// Wrapper for http.post with global error handling.
  static Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body}) async {
    final response = await http.post(url, headers: headers, body: body);
    _handleResponse(response);
    return response;
  }

  /// Wrapper for http.put with global error handling.
  static Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body}) async {
    final response = await http.put(url, headers: headers, body: body);
    _handleResponse(response);
    return response;
  }

  /// Wrapper for http.delete with global error handling.
  static Future<http.Response> delete(Uri url, {Map<String, String>? headers, Object? body}) async {
    final response = await http.delete(url, headers: headers, body: body);
    _handleResponse(response);
    return response;
  }

  /// Wrapper for multipart requests with global error handling.
  static Future<http.Response> sendMultipart(http.MultipartRequest request) async {
    final streamedRes = await request.send();
    final response = await http.Response.fromStream(streamedRes);
    _handleResponse(response);
    return response;
  }
}