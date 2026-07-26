import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/contact_model.dart';
import 'local_db_service.dart';

class ApiService {
  static String? _inMemoryToken;
  static const _storage = FlutterSecureStorage();

  // Production Server URL on Render Cloud
  static const String liveServerUrl = 'https://enterprise-contact.onrender.com/api/v1';

  static String get baseUrl {
    return liveServerUrl;
  }

  static Future<String?> getToken() async {
    if (_inMemoryToken != null && _inMemoryToken!.isNotEmpty) {
      return _inMemoryToken;
    }
    try {
      String? token = await _storage.read(key: 'jwt_token');
      if (token != null && token.isNotEmpty) {
        _inMemoryToken = token;
        return token;
      }
    } catch (e) {
      debugPrint("Storage read error: $e");
    }
    return _inMemoryToken;
  }

  static Future<void> saveToken(String token) async {
    _inMemoryToken = token;
    try {
      await _storage.write(key: 'jwt_token', value: token);
    } catch (e) {
      debugPrint("Storage write error: $e");
    }
  }

  /// 1. Register API
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    required String department,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password.trim(),
          'full_name': fullName.trim(),
          'department': department.trim(),
        }),
      ).timeout(const Duration(seconds: 45));

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        String token = data['access_token'];
        await saveToken(token);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['detail'] ?? 'การสมัครสมาชิกล้มเหลว'};
      }
    } catch (e) {
      debugPrint("Register error: $e");
      return {'success': false, 'message': 'ไม่สามารถเชื่อมต่อได้: $e'};
    }
  }

  /// 2. Login API
  static Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String token = data['access_token'];
        await saveToken(token);
        return true;
      } else {
        debugPrint("Login HTTP failed: ${response.statusCode} ${response.body}");
      }
    } catch (e) {
      debugPrint("Login network error: $e");
    }
    return false;
  }

  /// 3. Upload Contacts API
  static Future<Map<String, dynamic>> uploadContacts(List<RawContactItemDto> contacts) async {
    String? token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Unauthorized: Token missing. Please log in again.");
    }

    final response = await http.post(
      Uri.parse('$baseUrl/contacts/upload'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'device_id': 'flutter_mobile_app',
        'contacts': contacts.map((c) => c.toJson()).toList(),
      }),
    ).timeout(const Duration(seconds: 45));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Upload failed (${response.statusCode}): ${response.body}");
    }
  }

  /// 4. Sync Contacts API
  static Future<int> syncGlobalContacts() async {
    String? token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Unauthorized: Token missing");
    }

    int lastSync = await LocalDatabaseService.getLastSyncTimestamp();

    final response = await http.get(
      Uri.parse('$baseUrl/contacts/sync?since=$lastSync'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 45));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List list = data['contacts'] ?? [];
      List<LocalContact> contacts = list.map((item) => LocalContact(
        id: item['id'],
        normalizedPhone: item['normalized_phone'],
        displayName: item['display_name'],
        sourcesCount: item['sources_count'],
        updatedAt: item['updated_at'],
      )).toList();

      if (contacts.isNotEmpty) {
        await LocalDatabaseService.batchSaveContacts(contacts);
      }
      return contacts.length;
    } else {
      throw Exception("Sync failed (${response.statusCode})");
    }
  }
}
