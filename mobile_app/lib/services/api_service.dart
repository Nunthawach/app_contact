import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/contact_model.dart';
import 'local_db_service.dart';

class ApiService {
  static String? _inMemoryToken;
  static String? _inMemoryRole;
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

  static Future<String> getUserRole() async {
    if (_inMemoryRole != null && _inMemoryRole!.isNotEmpty) {
      return _inMemoryRole!;
    }
    try {
      String? role = await _storage.read(key: 'user_role');
      if (role != null && role.isNotEmpty) {
        _inMemoryRole = role;
        return role;
      }
    } catch (e) {
      debugPrint("Role storage read error: $e");
    }
    return _inMemoryRole ?? 'employee';
  }

  static Future<void> saveTokenAndRole(String token, String role) async {
    _inMemoryToken = token;
    _inMemoryRole = role;
    try {
      await _storage.write(key: 'jwt_token', value: token);
      await _storage.write(key: 'user_role', value: role);
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
        String role = data['user_info']['role'] ?? 'employee';
        await saveTokenAndRole(token, role);
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
        String role = data['user_info']['role'] ?? 'employee';
        await saveTokenAndRole(token, role);
        return true;
      } else {
        debugPrint("Login HTTP failed: ${response.statusCode} ${response.body}");
      }
    } catch (e) {
      debugPrint("Login network error: $e");
    }
    return false;
  }

  /// 3. Upload Contacts API (Chunked Batching with Progress Callback)
  static Future<Map<String, dynamic>> uploadContacts(
    List<RawContactItemDto> contacts, {
    void Function(int processed, int total, double percentage)? onProgress,
  }) async {
    String? token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Unauthorized: Token missing. Please log in again.");
    }

    if (contacts.isEmpty) {
      if (onProgress != null) onProgress(0, 0, 100.0);
      return {'inserted_new': 0, 'merged_existing': 0};
    }

    int totalInserted = 0;
    int totalMerged = 0;
    const int chunkSize = 50;

    for (int i = 0; i < contacts.length; i += chunkSize) {
      int end = (i + chunkSize < contacts.length) ? i + chunkSize : contacts.length;
      List<RawContactItemDto> chunk = contacts.sublist(i, end);

      final response = await http.post(
        Uri.parse('$baseUrl/contacts/upload'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'device_id': 'flutter_mobile_app',
          'contacts': chunk.map((c) => c.toJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        totalInserted += (resData['inserted_new'] as int? ?? 0);
        totalMerged += (resData['merged_existing'] as int? ?? 0);

        if (onProgress != null) {
          double percentage = (end / contacts.length) * 100;
          onProgress(end, contacts.length, percentage);
        }
      } else {
        throw Exception("Batch upload failed (${response.statusCode}): ${response.body}");
      }
    }

    return {
      'inserted_new': totalInserted,
      'merged_existing': totalMerged,
    };
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

  /// 5. Admin Clear All Contacts API
  static Future<bool> clearAllContacts() async {
    String? token = await getToken();
    if (token == null || token.isEmpty) return false;

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/contacts/clear'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Clear local SQLite database as well
        await LocalDatabaseService.clearAllLocalContacts();
        return true;
      }
    } catch (e) {
      debugPrint("Clear contacts error: $e");
    }
    return false;
  }

  /// 6. Get Total Contacts Count in DB
  static Future<int> getContactsCount() async {
    String? token = await getToken();
    if (token == null || token.isEmpty) return 0;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/contacts/count'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['total_db_count'] as int? ?? 0;
      }
    } catch (e) {
      debugPrint("Get contacts count error: $e");
    }
    return 0;
  }
}
