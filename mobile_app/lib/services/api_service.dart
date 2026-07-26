import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/contact_model.dart';
import 'local_db_service.dart';

class ApiService {
  static String? _inMemoryToken;
  static const _storage = FlutterSecureStorage();

  // Local PC IP Address for Real Devices & Emulators
  static String serverIp = '192.168.1.11';

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000/api/v1';
    }
    return 'http://$serverIp:8000/api/v1';
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

  /// 1. Login API
  static Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

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

  /// 2. Upload Contacts API
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
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Upload failed (${response.statusCode}): ${response.body}");
    }
  }

  /// 3. Sync Contacts API
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
    );

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
