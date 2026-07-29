import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Future<Map<String, String>> _getHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');
    final token = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> get(String path) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('${ApiConstants.baseUrl}$path');
    final response = await http.get(uri, headers: headers);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('${ApiConstants.baseUrl}$path');
    final response = await http.post(uri, headers: headers, body: jsonEncode(body));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('${ApiConstants.baseUrl}$path');
    final response = await http.put(uri, headers: headers, body: jsonEncode(body));
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    throw Exception(data['message'] ?? 'API error ${response.statusCode}');
  }
}
