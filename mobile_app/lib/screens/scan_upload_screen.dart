import 'package:flutter/material.dart';
import '../models/contact_model.dart';
import '../services/contact_service.dart';
import '../services/api_service.dart';

class ScanUploadScreen extends StatefulWidget {
  const ScanUploadScreen({Key? key}) : super(key: key);

  @override
  State<ScanUploadScreen> createState() => _ScanUploadScreenState();
}

class _ScanUploadScreenState extends State<ScanUploadScreen> {
  List<RawContactItemDto> _scannedContacts = [];
  bool _isScanning = false;
  bool _isUploading = false;
  double _uploadProgressRatio = 0.0; // 0.0 to 1.0
  String _uploadPercentText = "";
  String _statusMessage = "กดปุ่มด้านล่างเพื่อเริ่มสแกนรายชื่อในโทรศัพท์เครื่องนี้";

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _uploadProgressRatio = 0.0;
      _uploadPercentText = "";
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
      _uploadProgressRatio = 0.0;
      _uploadPercentText = "0%";
      _statusMessage = "กำลังเตรียมการอัปโหลด...";
    });

    try {
      final result = await ApiService.uploadContacts(
        _scannedContacts,
        onProgress: (processed, total, percentage) {
          if (mounted) {
            setState(() {
              _uploadProgressRatio = (percentage / 100.0).clamp(0.0, 1.0);
              _uploadPercentText = "${percentage.toInt()}% ($processed/$total รายชื่อ)";
              _statusMessage = "กำลังทยอยอัปโหลดขึ้น Cloud... $_uploadPercentText";
            });
          }
        },
      );

      setState(() => _statusMessage = "กำลังซิงก์ข้อมูลลงเครื่องเพื่อใช้งานออฟไลน์...");
      try {
        await ApiService.syncGlobalContacts();
      } catch (syncError) {
        debugPrint("Sync non-fatal error: $syncError");
      }

      if (mounted) {
        int newCount = result['inserted_new'] ?? 0;
        int mergedCount = result['merged_existing'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("อัปโหลดสำเร็จ 100%! เพิ่มใหม่ $newCount รายชื่อ (รวมข้อมูลเดิม $mergedCount)"),
            backgroundColor: Colors.green,
          ),
        );

        // Pop back to Global Search Screen
        Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('สแกน & อัปโหลดรายชื่อ'),
        backgroundColor: const Color(0xFF1E293B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
          tooltip: 'กลับหน้าค้นหา',
        ),
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

            // Scan & Progress Status Box
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
                    if (_isScanning)
                      const CircularProgressIndicator(color: Color(0xFF38BDF8))
                    else if (_isUploading) ...[
                      // Uploading Progress Indicator + Percentage %
                      SizedBox(
                        height: 80,
                        width: 80,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: _uploadProgressRatio,
                              strokeWidth: 7,
                              backgroundColor: Colors.white10,
                              color: const Color(0xFFA855F7),
                            ),
                            Center(
                              child: Text(
                                '${(_uploadProgressRatio * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _uploadProgressRatio,
                            minHeight: 12,
                            backgroundColor: Colors.white10,
                            color: const Color(0xFFA855F7),
                          ),
                        ),
                      ),
                    ] else
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
              )
            else
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
          ],
        ),
      ),
    );
  }
}
