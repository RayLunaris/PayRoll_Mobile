class UserModel {
  final String id;
  final String email;
  final String role;
  final String? employeeId;
  final bool? isActive;
  final String? lastLogin;
  final String? createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.role,
    this.employeeId,
    this.isActive,
    this.lastLogin,
    this.createdAt,
  });

  /// Strictly employee-only mobile portal check (Planning/01 §1, Planning/03 §Aturan Flutter #3)
  bool get isEmployee => role == 'employee';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      employeeId: json['employeeId'] as String?,
      isActive: json['isActive'] as bool?,
      lastLogin: json['lastLogin'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      if (employeeId != null) 'employeeId': employeeId,
      if (isActive != null) 'isActive': isActive,
      if (lastLogin != null) 'lastLogin': lastLogin,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }
}

