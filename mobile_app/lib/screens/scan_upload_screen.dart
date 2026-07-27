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
  Set<int> _selectedIndices = {};
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
        _selectedIndices = Set.from(List.generate(contacts.length, (i) => i));
        _statusMessage = "สแกนสำเร็จ! พบบุคลากร/รายชื่อทั้งหมด ${contacts.length} รายชื่อ";
      });
    } catch (e) {
      setState(() {
        _statusMessage = "ไม่สามารถสแกนรายชื่อได้: ${e.toString()}";
      });
      if (mounted) {
        _showErrorDialog("สแกนรายชื่อล้มเหลว", e.toString());
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIndices.length == _scannedContacts.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices = Set.from(List.generate(_scannedContacts.length, (i) => i));
      }
    });
  }

  void _showErrorDialog(String title, String details) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(title, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Text(details, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
            onPressed: () => Navigator.pop(context),
            child: const Text('ตกลง (OK)', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadContacts() async {
    final selectedContacts = _selectedIndices.map((i) => _scannedContacts[i]).toList();
    if (selectedContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกรายชื่ออย่างน้อย 1 รายชื่อเพื่ออัปโหลด'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgressRatio = 0.0;
      _uploadPercentText = "0%";
      _statusMessage = "กำลังเตรียมการอัปโหลด...";
    });

    try {
      final result = await ApiService.uploadContacts(
        selectedContacts,
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
        _showErrorDialog("เกิดข้อผิดพลาดในการอัปโหลด", e.toString());
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
        title: const Text('สแกน & เลือกอัปโหลดรายชื่อ'),
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // PDPA Notice Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.amber, size: 32),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'การแจ้งเตือน PDPA: ระบบจะรวบรวมรายชื่อเพื่อสร้างเป็นสมุดโทรศัพท์กลางสำหรับบุคลากรภายในองค์กรเท่านั้น',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Scan / Upload Progress / Selectable Contact List Area
            Expanded(
              child: _scannedContacts.isEmpty
                  ? Container(
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
                          else
                            const Icon(
                              Icons.contact_phone_outlined,
                              size: 64,
                              color: Color(0xFF38BDF8),
                            ),
                          const SizedBox(height: 16),
                          Text(
                            _statusMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Selection Status Header & Toggle
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'เลือกแล้ว ${_selectedIndices.length} / ${_scannedContacts.length} รายชื่อ',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _toggleSelectAll,
                                icon: Icon(
                                  _selectedIndices.length == _scannedContacts.length
                                      ? Icons.deselect_sharp
                                      : Icons.select_all_sharp,
                                  size: 18,
                                  color: const Color(0xFF38BDF8),
                                ),
                                label: Text(
                                  _selectedIndices.length == _scannedContacts.length ? 'ไม่เลือกเลย' : 'เลือกทั้งหมด',
                                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Uploading Progress Indicator Box
                        if (_isUploading)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'กำลังอัปโหลด... ${(_uploadProgressRatio * 100).toInt()}%',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: _uploadProgressRatio,
                                    minHeight: 10,
                                    backgroundColor: Colors.white10,
                                    color: const Color(0xFFA855F7),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // List of Scanned Contacts with Checkboxes
                        Expanded(
                          child: ListView.builder(
                            itemCount: _scannedContacts.length,
                            itemBuilder: (context, index) {
                              final item = _scannedContacts[index];
                              final isSelected = _selectedIndices.contains(index);

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF38BDF8).withOpacity(0.5) : Colors.white10,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: CheckboxListTile(
                                  value: isSelected,
                                  activeColor: const Color(0xFF38BDF8),
                                  checkColor: Colors.black,
                                  onChanged: (bool? val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedIndices.add(index);
                                      } else {
                                        _selectedIndices.remove(index);
                                      }
                                    });
                                  },
                                  title: Text(
                                    item.rawName,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    item.normalizedPhone,
                                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12),
                                  ),
                                  secondary: CircleAvatar(
                                    backgroundColor: const Color(0xFF38BDF8).withOpacity(0.2),
                                    child: Text(
                                      item.rawName.isNotEmpty ? item.rawName[0].toUpperCase() : '?',
                                      style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // Bottom Actions Buttons
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _isUploading ? null : _startScan,
                        icon: const Icon(Icons.refresh, color: Colors.grey),
                        label: const Text('สแกนใหม่', style: TextStyle(color: Colors.grey)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : _uploadContacts,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: Text('อัปโหลดที่เลือก (${_selectedIndices.length})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA855F7),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
