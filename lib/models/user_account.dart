import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class UserAccount {
  final String uid;
  final String email;
  final String password;
  final String role;
  final String status;
  final String name;
  final String address;
  final String grade;
  final String lrn;
  final String character;
  final String gender;
  final String profilePhotoUrl;

  const UserAccount({
    this.uid = '',
    required this.email,
    this.password = '',
    required this.role,
    required this.status,
    required this.name,
    required this.address,
    this.grade = '',
    required this.lrn,
    this.character = 'boy',
    this.gender = '',
    this.profilePhotoUrl = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'status': status,
      'name': name,
      'address': address,
      if (grade.isNotEmpty) 'grade': grade,
      'lrn': lrn,
      'character': character,
      'profilePhotoUrl': profilePhotoUrl,
      if (gender.trim().isNotEmpty) 'gender': gender.trim(),
    };
  }

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      uid: json['uid']?.toString() ?? '',
      email: json['email']?.toString().trim().toLowerCase() ?? '',
      password: json['password']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      grade: json['grade']?.toString() ?? '',
      lrn: json['lrn']?.toString() ?? '',
      character: json['character']?.toString().toLowerCase() == 'girl'
          ? 'girl'
          : 'boy',
      gender: json['gender']?.toString().trim() ?? '',
      profilePhotoUrl: json['profilePhotoUrl']?.toString() ?? '',
    );
  }

  UserAccount copyWith({
    String? uid,
    String? email,
    String? password,
    String? role,
    String? status,
    String? name,
    String? address,
    String? grade,
    String? lrn,
    String? character,
    String? gender,
    String? profilePhotoUrl,
  }) {
    return UserAccount(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      status: status ?? this.status,
      name: name ?? this.name,
      address: address ?? this.address,
      grade: grade ?? this.grade,
      lrn: lrn ?? this.lrn,
      character: character ?? this.character,
      gender: gender ?? this.gender,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
    );
  }

  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isTeacher => role.toLowerCase() == 'teacher';
  bool get isPending => status.toLowerCase() == 'pending';

  static const String prefsKey = 'user_accounts';

  static Future<List<UserAccount>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(prefsKey);
    if (jsonString == null || jsonString.isEmpty) return [];

    try {
      final list = jsonDecode(jsonString) as List<dynamic>;
      return list
          .map((item) => UserAccount.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<UserAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(accounts.map((e) => e.toJson()).toList());
    await prefs.setString(prefsKey, jsonString);
  }

  static Future<void> ensureDefaultAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    final List<UserAccount> accounts = [];

    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        accounts.addAll(list
            .map((item) => UserAccount.fromJson(item as Map<String, dynamic>))
            .toList());
      } catch (_) {
        accounts.clear();
      }
    } else {
      final oldEmail = prefs.getString('user_email');
      final oldPassword = prefs.getString('user_password');
      if (oldEmail != null && oldPassword != null) {
        accounts.add(UserAccount(
          email: oldEmail.trim().toLowerCase(),
          password: oldPassword,
          role: 'student',
          status: 'approved',
          name: prefs.getString('user_name') ?? '',
          address: prefs.getString('user_address') ?? '',
          lrn: prefs.getString('user_lrn') ?? '',
        ));
      }
    }

    if (!accounts.any((a) => a.isAdmin)) {
      accounts.insert(
        0,
        const UserAccount(
          email: 'admin@admin.com',
          password: 'admin123',
          role: 'admin',
          status: 'approved',
          name: 'Administrator',
          address: '',
          lrn: '',
        ),
      );
    }

    await saveAll(accounts);

    if (raw == null) {
      await prefs.remove('user_email');
      await prefs.remove('user_password');
      await prefs.remove('user_name');
      await prefs.remove('user_address');
      await prefs.remove('user_lrn');
    }
  }

  static List<UserAccount> sortAccountsByDisplayName(
    Iterable<UserAccount> accounts,
  ) {
    final sortedAccounts = accounts.toList();
    String displayName(UserAccount account) {
      final name = account.name.trim();
      return name.isEmpty ? account.email.trim() : name;
    }

    sortedAccounts.sort((left, right) {
      final nameComparison = displayName(left)
          .toLowerCase()
          .compareTo(displayName(right).toLowerCase());
      if (nameComparison != 0) return nameComparison;

      final leftEmail = left.email.trim().toLowerCase();
      final rightEmail = right.email.trim().toLowerCase();
      final emailComparison = leftEmail.compareTo(rightEmail);
      if (emailComparison != 0) return emailComparison;
      return left.uid.compareTo(right.uid);
    });
    return sortedAccounts;
  }
}
