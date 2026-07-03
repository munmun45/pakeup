import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAccount {
  const AdminAccount({
    required this.id,
    required this.role,
    required this.pages,
    this.name,
    this.phone,
    this.notes,
    this.isActive = true,
  });

  final String id;
  final String role;
  final List<String> pages;
  final String? name;
  final String? phone;
  final String? notes;
  final bool isActive;

  bool get isSuperAdmin => role == 'super_admin';
  String get displayName => name?.trim().isNotEmpty == true ? name! : id;

  factory AdminAccount.fromJson(Map<String, dynamic> json) {
    return AdminAccount(
      id: json['id'] as String,
      role: json['role'] as String? ?? 'admin',
      pages: (json['pages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class AdminUsersRepository {
  AdminUsersRepository(this._client);

  final SupabaseClient _client;

  List<T> _parseList<T>(
    dynamic result,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (result == null) return [];
    final list = result as List<dynamic>;
    return list
        .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<AdminAccount>> listAdmins(String callerId) async {
    final result = await _client.rpc<dynamic>(
      'list_admin_users',
      params: {'caller_id': callerId},
    );
    return _parseList(result, AdminAccount.fromJson);
  }

  Future<void> createAdmin({
    required String callerId,
    required String newId,
    required String password,
    required List<String> pageKeys,
    String? name,
    String? phone,
    String? notes,
  }) async {
    await _client.rpc(
      'create_admin_user',
      params: {
        'caller_id': callerId,
        'new_id': newId.trim(),
        'new_pass': password,
        'page_keys': pageKeys,
        'admin_name': name?.trim(),
        'admin_phone': phone?.trim(),
        'admin_notes': notes?.trim(),
      },
    );
  }

  Future<void> updateAdmin({
    required String callerId,
    required String targetId,
    required List<String> pageKeys,
    String? name,
    String? phone,
    String? notes,
    String? newId,
    String? newPassword,
  }) async {
    await _client.rpc(
      'update_admin_user',
      params: {
        'caller_id': callerId,
        'target_id': targetId,
        'page_keys': pageKeys,
        'admin_name': name?.trim(),
        'admin_phone': phone?.trim(),
        'admin_notes': notes?.trim(),
        'new_id': newId?.trim(),
        'new_pass': newPassword?.trim(),
      },
    );
  }

  Future<void> deleteAdmin({
    required String callerId,
    required String targetId,
  }) async {
    await _client.rpc(
      'delete_admin_user',
      params: {
        'caller_id': callerId,
        'target_id': targetId,
      },
    );
  }

  Future<void> setAdminActive({
    required String callerId,
    required String targetId,
    required bool active,
  }) async {
    await _client.rpc(
      'set_admin_active',
      params: {
        'caller_id': callerId,
        'target_id': targetId,
        'active': active,
      },
    );
  }
}
