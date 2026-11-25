import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  static const String _keyToken = 'auth_token';
  static const String _keyUserId = 'user_id_str';
  static const String _keyLegacyUserId = 'user_id';
  static const String _keyBranch = 'active_branch';
  static const String _keyAssignedBranch = 'assigned_branch';
  static const String _keyUserName = 'user_name';
  static const String _keyRole = 'user_role';

  static String? _token;
  static String _activeBranch = 'MAIN';
  static String _assignedBranch = 'MAIN';
  static String _userName = 'Admin';
  static String _role = 'worker';
  static dynamic _rawUserId = 1;

  static String? get token => _token;
  static String get activeBranch => _activeBranch;
  static String get assignedBranch => _assignedBranch;
  static String get userName => _userName;
  static String get role => _role;
  static int get userId => _rawUserId is int
      ? _rawUserId as int
      : (int.tryParse(_rawUserId.toString()) ?? 0);
  static bool get isAdmin =>
      _role.toLowerCase() == 'admin' || _assignedBranch.toUpperCase() == 'ALL';
  static bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  /// Initialize session from SharedPreferences on app startup
  static Future<bool> initSession() async {
    try {
      await ApiService.initBaseUrl();
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_keyToken);
      _activeBranch = prefs.getString(_keyBranch) ?? 'MAIN';
      _assignedBranch = prefs.getString(_keyAssignedBranch) ?? _activeBranch;
      _role = prefs.getString(_keyRole) ?? 'worker';
      _rawUserId = prefs.getString(_keyUserId) ?? prefs.getInt(_keyLegacyUserId) ?? 1;
      _userName = prefs.getString(_keyUserName) ?? 'Operator';

      if (_token != null && _token!.isNotEmpty) {
        ApiService.authToken = _token;
        ApiService.activeBranch = _activeBranch;
        return true;
      }
    } catch (e) {
      debugPrint('Error loading saved session: $e');
    }
    return false;
  }

  /// Switch active branch (for Admin / ALL-branch users) and persist
  static Future<void> setActiveBranch(String branch) async {
    _activeBranch = branch;
    ApiService.activeBranch = branch;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyBranch, branch);
    } catch (e) {
      debugPrint('Error saving active branch: $e');
    }
  }

  /// Perform login and persist auth data
  static Future<Map<String, dynamic>> login(dynamic userId, String pin) async {
    final data = await ApiService.login(userId, pin);
    _token = ApiService.authToken;
    _rawUserId = userId;

    final serverBranch = (data['branch'] ?? 'MAIN').toString();
    _assignedBranch = serverBranch;
    _activeBranch = serverBranch.toUpperCase() == 'ALL' ? 'MAIN' : serverBranch;
    ApiService.activeBranch = _activeBranch;

    _role = (data['role'] ?? 'worker').toString();
    _userName = (data['username'] ??
            data['user']?['name'] ??
            (userId == 'admin' ? 'System Admin' : 'Operator ($userId)'))
        .toString();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (_token != null) {
        await prefs.setString(_keyToken, _token!);
      }
      await prefs.setString(_keyUserId, _rawUserId.toString());
      await prefs.setString(_keyBranch, _activeBranch);
      await prefs.setString(_keyAssignedBranch, _assignedBranch);
      await prefs.setString(_keyUserName, _userName);
      await prefs.setString(_keyRole, _role);
    } catch (e) {
      debugPrint('Error persisting session: $e');
    }

    return data;
  }

  /// Logout and clear saved preferences
  static Future<void> logout() async {
    _token = null;
    _activeBranch = 'MAIN';
    _assignedBranch = 'MAIN';
    _role = 'worker';
    ApiService.authToken = null;
    ApiService.activeBranch = 'MAIN';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyToken);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyLegacyUserId);
      await prefs.remove(_keyBranch);
      await prefs.remove(_keyAssignedBranch);
      await prefs.remove(_keyUserName);
      await prefs.remove(_keyRole);
    } catch (e) {
      debugPrint('Error clearing session: $e');
    }
  }
}
