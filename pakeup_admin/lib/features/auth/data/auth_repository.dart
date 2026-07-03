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
    required this.pages,
    this.name,
    this.phone,
    this.notes,
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final AdminRole role;
  final List<String> pages;
  final String? name;
  final String? phone;
  final String? notes;
  final bool isActive;
  final DateTime? createdAt;

  String get displayName {
    if (name != null && name!.trim().isNotEmpty) return name!;
    return role.label;
  }

  bool get isSuperAdmin => role == AdminRole.superAdmin;

  bool canAccess(String pageKey) {
    if (isSuperAdmin) return true;
    return pages.contains(pageKey);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.value,
        'pages': pages,
        'name': name,
        'phone': phone,
        'notes': notes,
        'is_active': isActive,
        'created_at': createdAt?.toIso8601String(),
      };

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: json['id'] as String,
        role: AdminRole.fromValue(json['role'] as String? ?? 'admin'),
        pages: (json['pages'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        name: json['name'] as String?,
        phone: json['phone'] as String?,
        notes: json['notes'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: _parseDate(json['created_at']),
      );
}

class AdminProfile {
  const AdminProfile({
    required this.id,
    required this.role,
    required this.pages,
    this.name,
    this.phone,
    this.notes,
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final AdminRole role;
  final List<String> pages;
  final String? name;
  final String? phone;
  final String? notes;
  final bool isActive;
  final DateTime? createdAt;

  bool get isSuperAdmin => role == AdminRole.superAdmin;

  String get displayName {
    if (name != null && name!.trim().isNotEmpty) return name!;
    return id;
  }

  factory AdminProfile.fromJson(Map<String, dynamic> json) => AdminProfile(
        id: json['id'] as String,
        role: AdminRole.fromValue(json['role'] as String? ?? 'admin'),
        pages: (json['pages'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        name: json['name'] as String?,
        phone: json['phone'] as String?,
        notes: json['notes'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: _parseDate(json['created_at']),
      );
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
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

    if (data['error'] == 'deactivated') {
      throw AuthException('This admin account has been deactivated.');
    }

    final adminId = data['id'] as String?;
    if (adminId == null || adminId.isEmpty) {
      throw AuthException('Invalid admin id or password.');
    }

    final pages = (data['pages'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final user = AdminUser(
      id: adminId,
      role: AdminRole.fromValue(data['role'] as String? ?? 'admin'),
      pages: pages,
      name: data['name'] as String?,
      phone: data['phone'] as String?,
      notes: data['notes'] as String?,
      isActive: data['is_active'] as bool? ?? true,
      createdAt: _parseDate(data['created_at']),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.sessionKey, jsonEncode(user.toJson()));

    return user;
  }

  Future<AdminProfile> getProfile(String adminId) async {
    final result = await _client.rpc<dynamic>(
      'get_admin_profile',
      params: {'caller_id': adminId},
    );

    final data = result is Map<String, dynamic>
        ? result
        : Map<String, dynamic>.from(result as Map);

    return AdminProfile.fromJson(data);
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
