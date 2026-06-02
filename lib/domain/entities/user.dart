class User {
  final String id;
  final String name;
  final String? email;
  final String phone;
  final UserRole role;
  final String? estateId;
  final String? blockId;
  final String profilePictureUrl;

  User({
    required this.id,
    required this.name,
    this.email,
    required this.phone,
    required this.role,
    this.estateId,
    this.blockId,
    this.profilePictureUrl = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'role': role.name,
    'estate_id': estateId,
    'block_id': blockId,
    'profile_picture_url': profilePictureUrl,
  };

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.fieldWorker,
      ),
      estateId: json['estate_id'],
      blockId: json['block_id'],
      profilePictureUrl: json['profile_picture_url'] ?? '',
    );
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isSupervisor => role == UserRole.supervisor;
  bool get isFieldWorker => role == UserRole.fieldWorker;
}

enum UserRole {
  admin,
  supervisor,
  fieldWorker;

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.supervisor:
        return 'Supervisor';
      case UserRole.fieldWorker:
        return 'Field Worker';
    }
  }
}