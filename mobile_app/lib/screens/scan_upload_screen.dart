import 'package:flutter/material.dart';
import '../models/contact_model.dart';
import '../services/contact_service.dart';
import '../services/api_service.dart';
import 'global_search_screen.dart';
import 'login_screen.dart';

class ScanUploadScreen extends StatefulWidget {
  const ScanUploadScreen({Key? key}) : super(key: key);

  @override
  State<ScanUploadScreen> createState() => _ScanUploadScreenState();
}

class _ScanUploadScreenState extends State<ScanUploadScreen> {
  List<RawContactItemDto> _scannedContacts = [];
  bool _isScanning = false;
  bool _isUploading = false;
  String _statusMessage = "กดปุ่มเพื่อเริ่มสแกนรายชื่อในโทรศัพท์เครื่องนี้";

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _statusMessage = "กำลังสแกนรายชื่อในเครื่อง...";
    });

    try {
      List<RawContactItemDto> contacts = await NativeContactService.scanDeviceContacts();
      setState(() {
        _scannedContacts = contacts;
        _statusMessage = "สแกนสำเร็จ! พบบุคลากร/รายชื่อทั้งหมด ${contacts.length} รายชื่อ";
      });
    } catch (e) {
      setState(() {
        _statusMessage = "ไม่สามารถสแกนรายชื่อได้: ${e.toString()}";
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("สแกนไม่สำเร็จ: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _uploadContacts() async {
    if (_scannedContacts.isEmpty) return;

    setState(() {
      _isUploading = true;
      _statusMessage = "กำลังอัปโหลดรายชื่อขึ้นฐานข้อมูลกลาง...";
    });

    try {
      final result = await ApiService.uploadContacts(_scannedContacts);
      await ApiService.syncGlobalContacts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("อัปโหลดสำเร็จ! เพิ่มใหม่ ${result['data']['inserted_new']} รายชื่อ"),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = "อัปโหลดล้มเหลว: ${e.toString()}";
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("เกิดข้อผิดพลาด: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<bool> _showExitDialog() async {
    return (await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text('ออกจากระบบ / ออกจากแอป', style: TextStyle(color: Colors.white)),
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
          title: const Text('Permission & Upload Center'),
          backgroundColor: const Color(0xFF1E293B),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_outlined, color: Colors.redAccent),
              onPressed: _showExitDialog,
              tooltip: 'ออกจากระบบ',
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // PDPA Notice Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.amber, size: 36),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'การแจ้งเตือน PDPA: ระบบจะรวบรวมรายชื่อเพื่อสร้างเป็นสมุดโทรศัพท์กลางสำหรับบุคลากรภายในองค์กรเท่านั้น',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Scan Status Box
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isScanning || _isUploading)
                        const CircularProgressIndicator(color: Color(0xFF38BDF8))
                      else
                        Icon(
                          _scannedContacts.isNotEmpty ? Icons.check_circle_outline : Icons.contact_phone_outlined,
                          size: 64,
                          color: const Color(0xFF38BDF8),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              if (_scannedContacts.isEmpty)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isScanning ? null : _startScan,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('อนุญาตสิทธิ์ & สแกนรายชื่อในเครื่อง'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38BDF8),
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
                        );
                      },
                      child: const Text('ข้ามไปยังหน้าค้นหารายชื่อ ➔', style: TextStyle(color: Color(0xFF38BDF8))),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : _uploadContacts,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('อัปโหลดรายชื่อขึ้นระบบกลาง (Upload to Cloud)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA855F7),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
                        );
                      },
                      child: const Text('ไปหน้าค้นหารายชื่อส่วนกลาง ➔', style: TextStyle(color: Color(0xFF38BDF8))),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
