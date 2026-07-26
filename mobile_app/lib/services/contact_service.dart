import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/contact_model.dart';

class NativeContactService {
  /// Request Permission and Scan device contacts
  static Future<List<RawContactItemDto>> scanDeviceContacts() async {
    if (kIsWeb) {
      // Mock contacts for Web browser testing
      return [
        RawContactItemDto(rawName: 'สมชาย เอกเทค (IT Support)', rawPhone: '081-234-5678', normalizedPhone: '0812345678'),
        RawContactItemDto(rawName: 'คุณวิภา การตลาด', rawPhone: '089-999-8888', normalizedPhone: '0899998888'),
        RawContactItemDto(rawName: 'ช่างเอก ระบบเครือข่าย', rawPhone: '082-111-2222', normalizedPhone: '0821112222'),
        RawContactItemDto(rawName: 'คุณนภา ฝ่ายบัญชี', rawPhone: '086-555-4444', normalizedPhone: '0865554444'),
        RawContactItemDto(rawName: 'พี่กิตติ ฝ่ายบุคคล (HR)', rawPhone: '084-777-3333', normalizedPhone: '0847773333'),
      ];
    }

    // Native Mobile Contacts Fetching
    var status = await Permission.contacts.request();
    if (!status.isGranted) {
      throw Exception("Permission denied for accessing contacts");
    }

    List<Contact> contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );

    List<RawContactItemDto> resultList = [];
    for (var contact in contacts) {
      for (var phone in contact.phones) {
        String normalized = normalizePhoneNumber(phone.number);
        if (normalized.isNotEmpty && contact.displayName.isNotEmpty) {
          resultList.add(RawContactItemDto(
            rawName: contact.displayName,
            rawPhone: phone.number,
            normalizedPhone: normalized,
          ));
        }
      }
    }
    return resultList;
  }

  /// Phone Normalization Helper
  static String normalizePhoneNumber(String raw) {
    String cleaned = raw.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('+66')) {
      cleaned = '0${cleaned.substring(3)}';
    }
    return cleaned;
  }
}
