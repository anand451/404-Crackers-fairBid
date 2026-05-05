import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  const UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.aadhaarNumber,
    required this.panNumber,
    required this.dateOfBirth,
    required this.createdAt,
    required this.userType,
    required this.role,
    required this.status,
  });

  final String uid;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String aadhaarNumber;
  final String panNumber;
  final DateTime dateOfBirth;
  final DateTime createdAt;
  final String userType;
  final String role;
  final String status;

  bool get isAdmin => role == 'admin';
  bool get isBlocked => status == 'blocked';

  factory UserModel.fromMap(String uid, Map<String, dynamic> data) {
    return UserModel(
      uid: uid,
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phoneNumber: data['phone'] as String? ?? '',
      aadhaarNumber: data['aadhaar'] as String? ?? '',
      panNumber: data['pan'] as String? ?? '',
      dateOfBirth: _readDate(data['dob']),
      createdAt: _readDate(data['createdAt']),
      userType: data['userType'] as String? ?? 'Buyer',
      role: data['role'] as String? ?? 'user',
      status: data['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'phone': phoneNumber,
      'aadhaar': aadhaarNumber,
      'pan': panNumber,
      'dob': Timestamp.fromDate(dateOfBirth),
      'createdAt': Timestamp.fromDate(createdAt),
      'userType': userType,
      'role': role,
      'status': status,
    };
  }

  UserModel copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? aadhaarNumber,
    String? panNumber,
    DateTime? dateOfBirth,
    DateTime? createdAt,
    String? userType,
    String? role,
    String? status,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      panNumber: panNumber ?? this.panNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      createdAt: createdAt ?? this.createdAt,
      userType: userType ?? this.userType,
      role: role ?? this.role,
      status: status ?? this.status,
    );
  }

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime(2000);
    }
    return DateTime(2000);
  }
}
