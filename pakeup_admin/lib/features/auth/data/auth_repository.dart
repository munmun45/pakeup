import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';

enum AdminRole {
  superAdmin('super_admin', 'Super Admin'),
  admin('admin', 'Admin');

  const AdminRole(this.value, this.label);

  final String value;
  final String label;

  static AdminRole fromValue(String value) {
    return AdminRole.values.firstWhere(
      (r) => r.value == value,
      orElse: () => AdminRole.admin,
    );
  }
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.role,
  });

  final String id;
  final AdminRole role;

  String get name => role.label;
  bool get isSuperAdmin => role == AdminRole.superAdmin;

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.value,
      };

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: json['id'] as String,
        role: AdminRole.fromValue(json['role'] as String? ?? 'admin'),
      );
}

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Future<AdminUser?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.sessionKey);
    if (raw == null) return null;

    try {
      return AdminUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await prefs.remove(AppConstants.sessionKey);
      return null;
    }
  }

  Future<AdminUser> login({
    required String id,
    required String password,
  }) async {
    final result = await _client.rpc<dynamic>(
      'verify_admin',
      params: {
        'login_id': id.trim(),
        'login_pass': password,
      },
    );

    if (result == null) {
      throw AuthException('Invalid admin id or password.');
    }

    final data = result is Map<String, dynamic>
        ? result
        : Map<String, dynamic>.from(result as Map);

    final adminId = data['id'] as String?;
    final roleValue = data['role'] as String?;

    if (adminId == null || adminId.isEmpty) {
      throw AuthException('Invalid admin id or password.');
    }

    final user = AdminUser(
      id: adminId,
      role: AdminRole.fromValue(roleValue ?? 'admin'),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.sessionKey, jsonEncode(user.toJson()));

    return user;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.sessionKey);
  }
}

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
