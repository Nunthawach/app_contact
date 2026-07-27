import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/contact_model.dart';
import '../services/local_db_service.dart';
import '../services/api_service.dart';
import 'scan_upload_screen.dart';
import 'login_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({Key? key}) : super(key: key);

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  List<LocalContact> _contacts = [];
  final _searchController = TextEditingController();
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _performSearch('');
    _triggerBackgroundSync();
  }

  Future<void> _performSearch(String query) async {
    final results = await LocalDatabaseService.searchContacts(query);
    setState(() {
      _contacts = results;
    });
  }

  Future<void> _triggerBackgroundSync() async {
    setState(() => _isSyncing = true);
    try {
      await ApiService.syncGlobalContacts();
      await _performSearch(_searchController.text);
    } catch (_) {
      // Offline fallback silently keeps local database
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถเปิดระบบโทรออกสำหรับ $phoneNumber ได้')),
        );
      }
    }
  }

  Future<bool> _showExitDialog() async {
    return (await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text('ออกจากระบบ', style: TextStyle(color: Colors.white)),
            content: const Text('คุณต้องการออกจากระบบ และกลับสู่หน้าเข้าสู่ระบบหรือไม่?', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () {
                  Navigator.of(context).pop(false);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text('ออกจากระบบ', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        )) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _showExitDialog,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          title: const Text('สมุดโทรศัพท์องค์กร (Directory)'),
          backgroundColor: const Color(0xFF1E293B),
          actions: [
            // Sync Button
            IconButton(
              icon: _isSyncing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync),
              onPressed: _triggerBackgroundSync,
              tooltip: 'Sync รายชื่อล่าสุด',
            ),
            // Upload & Scan Button (Requested by User)
            IconButton(
              icon: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF38BDF8)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanUploadScreen()),
                );
              },
              tooltip: 'สแกน & อัปโหลดรายชื่อ',
            ),
            // Logout Button
            IconButton(
              icon: const Icon(Icons.logout_outlined, color: Colors.redAccent),
              onPressed: _showExitDialog,
              tooltip: 'ออกจากระบบ',
            ),
          ],
        ),
        body: Column(
          children: [
            // Search Input Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: _performSearch,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'พิมพ์ค้นหาชื่อ หรือเบอร์โทรศัพท์ (Partial Match)...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF38BDF8)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            _performSearch('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Offline Status Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'โหมดค้นหาความเร็วสูง (SQLite Local DB) - พบ ${_contacts.length} รายชื่อ',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Contact Result List
            Expanded(
              child: _contacts.isEmpty
                  ? const Center(
                      child: Text('ไม่พบรายชื่อที่ค้นหา', style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.builder(
                      itemCount: _contacts.length,
                      itemBuilder: (context, index) {
                        final item = _contacts[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF38BDF8),
                              child: Text(
                                item.displayName.isNotEmpty ? item.displayName[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              item.displayName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              item.normalizedPhone,
                              style: const TextStyle(color: Color(0xFF38BDF8)),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.phone_forwarded, color: Color(0xFF10B981)),
                              onPressed: () => _makeCall(item.normalizedPhone),
                              tooltip: 'โทรออก (Click-to-Call)',
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
