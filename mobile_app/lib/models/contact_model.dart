class LocalContact {
  final String id;
  final String normalizedPhone;
  final String displayName;
  final int sourcesCount;
  final int updatedAt;

  LocalContact({
    required this.id,
    required this.normalizedPhone,
    required this.displayName,
    required this.sourcesCount,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'normalized_phone': normalizedPhone,
      'display_name': displayName,
      'sources_count': sourcesCount,
      'updated_at': updatedAt,
    };
  }

  factory LocalContact.fromMap(Map<String, dynamic> map) {
    return LocalContact(
      id: map['id'] ?? '',
      normalizedPhone: map['normalized_phone'] ?? '',
      displayName: map['display_name'] ?? '',
      sourcesCount: map['sources_count'] ?? 1,
      updatedAt: map['updated_at'] ?? 0,
    );
  }
}

class RawContactItemDto {
  final String rawName;
  final String rawPhone;
  final String normalizedPhone;

  RawContactItemDto({
    required this.rawName,
    required this.rawPhone,
    required this.normalizedPhone,
  });

  Map<String, dynamic> toJson() {
    return {
      'raw_name': rawName,
      'raw_phone': rawPhone,
      'normalized_phone': normalizedPhone,
    };
  }
}
