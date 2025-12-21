class Tenant {
  final int? id;
  final String firstName;
  final String lastName;
  final String nationality;
  final String docType;
  final String docNumber;
  final bool isDeleted;

  Tenant({
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
      id: map['id'],
      firstName: map['first_name'],
      lastName: map['last_name'],
      nationality: map['nationality'],
      docType: map['doc_type'],
      docNumber: map['doc_number'],
      isDeleted: map['is_deleted'] == 1,
    );
  }
}

class RoomRegistration {
  final int? id;
  final int tenantId;
  final String roomNumber;
  final DateTime checkInDate;
  final bool isDeleted;

  RoomRegistration({
    this.id,
    required this.tenantId,
    required this.roomNumber,
    required this.checkInDate,
    this.isDeleted = false,
  });

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
      id: map['id'],
      tenantId: map['tenant_id'],
      roomNumber: map['room_number'],
      checkInDate: DateTime.parse(map['check_in_date']),
      isDeleted: map['is_deleted'] == 1,
    );
  }
}
