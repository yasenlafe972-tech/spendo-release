class PersonAccountModel {
  final String id;
  final String personId;
  final String service;
  final String email;
  final String password;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PersonAccountModel({
    required this.id,
    required this.personId,
    required this.service,
    required this.email,
    required this.password,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'person_id': personId,
      'service': service,
      'email': email,
      'password': password,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PersonAccountModel.fromMap(Map<String, dynamic> map) {
    return PersonAccountModel(
      id: map['id'] as String,
      personId: map['person_id'] as String,
      service: map['service'] as String,
      email: map['email'] as String,
      password: map['password'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  PersonAccountModel copyWith({
    String? id,
    String? personId,
    String? service,
    String? email,
    String? password,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PersonAccountModel(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      service: service ?? this.service,
      email: email ?? this.email,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
