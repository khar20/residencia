class Tenant {
  final int? id;
  final String firstName;
  final String lastName;
  final String nationality;
  final String docType;
  final String docNumber;
  final bool isDeleted;

  const Tenant({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.nationality,
    required this.docType,
    required this.docNumber,
    this.isDeleted = false,
  });

  // Helper to display full name
  String get fullName => '$firstName $lastName';

  Tenant copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? nationality,
    String? docType,
    String? docNumber,
    bool? isDeleted,
  }) {
    return Tenant(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      nationality: nationality ?? this.nationality,
      docType: docType ?? this.docType,
      docNumber: docNumber ?? this.docNumber,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'nationality': nationality,
      'doc_type': docType,
      'doc_number': docNumber,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory Tenant.fromMap(Map<String, dynamic> map) {
    return Tenant(
      id: map['id'] as int?,
      firstName: map['first_name']?.toString() ?? '',
      lastName: map['last_name']?.toString() ?? '',
      nationality: map['nationality']?.toString() ?? '',
      docType: map['doc_type']?.toString() ?? '',
      docNumber: map['doc_number']?.toString() ?? '',
      isDeleted: (map['is_deleted'] as int?) == 1,
    );
  }

  @override
  String toString() {
    return 'Tenant(id: $id, name: $fullName, doc: $docNumber)';
  }
}

class RoomRegistration {
  final int? id;
  final int tenantId;
  final String roomNumber;
  final DateTime checkInDate;
  final bool isDeleted;

  const RoomRegistration({
    this.id,
    required this.tenantId,
    required this.roomNumber,
    required this.checkInDate,
    this.isDeleted = false,
  });

  RoomRegistration copyWith({
    int? id,
    int? tenantId,
    String? roomNumber,
    DateTime? checkInDate,
    bool? isDeleted,
  }) {
    return RoomRegistration(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      roomNumber: roomNumber ?? this.roomNumber,
      checkInDate: checkInDate ?? this.checkInDate,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'room_number': roomNumber,
      'check_in_date': checkInDate.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory RoomRegistration.fromMap(Map<String, dynamic> map) {
    return RoomRegistration(
      id: map['id'] as int?,
      tenantId: map['tenant_id'] as int,
      roomNumber: map['room_number']?.toString() ?? '',
      checkInDate:
          DateTime.tryParse(map['check_in_date'].toString()) ?? DateTime.now(),
      isDeleted: (map['is_deleted'] as int?) == 1,
    );
  }

  @override
  String toString() {
    return 'Registration(id: $id, room: $roomNumber, date: $checkInDate)';
  }
}
