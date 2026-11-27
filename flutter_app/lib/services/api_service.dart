import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/consignor.dart';
import '../models/consignee.dart';
import '../models/vehicle.dart';
import '../models/driver.dart';
import '../models/gc.dart';
import '../models/unit_model.dart';

class ApiService {
  // Production Railway URL or custom compile-time URL via --dart-define=API_URL=...
  static const String _compileTimeApiUrl = String.fromEnvironment('API_URL');
  static const String _prodRailwayUrl = 'https://transport-erp-production.up.railway.app/api';
  static const String _defaultLocalUrl = 'http://localhost:5005/api';
  static const String _defaultAndroidEmulatorUrl = 'http://10.0.2.2:5005/api';

  static String baseUrl = _defaultLocalUrl;

  /// Initialize Base URL based on platform or stored user preference
  static Future<void> initBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('custom_api_base_url');
      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        baseUrl = savedUrl.trim();
        return;
      }
    } catch (_) {}

    // 1. If explicit compile-time API_URL was provided, use it
    if (_compileTimeApiUrl.isNotEmpty) {
      baseUrl = _compileTimeApiUrl;
      return;
    }

    // 2. In release/production builds, automatically route to the live cloud backend
    if (kReleaseMode) {
      baseUrl = _prodRailwayUrl;
      return;
    }

    // 3. Local development auto-detection (Android emulator vs Desktop/Web)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      baseUrl = _defaultAndroidEmulatorUrl;
    } else {
      baseUrl = _defaultLocalUrl;
    }
  }

  /// Configure a custom backend endpoint (for LAN IPs, Physical Android/iOS, or Cloud API)
  static Future<void> setCustomBaseUrl(String newUrl) async {
    final clean = newUrl.trim();
    if (clean.isNotEmpty) {
      baseUrl = clean;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('custom_api_base_url', baseUrl);
      } catch (_) {}
    }
  }

  static final http.Client _client = http.Client();
  static String? authToken;
  static String activeBranch = 'MAIN';
  static VoidCallback? onUnauthorized;

  // In-memory TTL cache (5 min) for static/semi-static master lists
  static const Duration _masterCacheTtl = Duration(minutes: 5);
  static List<dynamic>? _godownsCache;
  static DateTime? _godownsCacheTime;
  static List<dynamic>? _hsnCache;
  static DateTime? _hsnCacheTime;
  static List<dynamic>? _companiesCache;
  static DateTime? _companiesCacheTime;
  static List<UnitModel>? _unitsCache;
  static DateTime? _unitsCacheTime;

  static void clearMasterCache() {
    _godownsCache = null;
    _godownsCacheTime = null;
    _hsnCache = null;
    _hsnCacheTime = null;
    _companiesCache = null;
    _companiesCacheTime = null;
    _unitsCache = null;
    _unitsCacheTime = null;
  }

  static bool _isCacheValid(DateTime? timestamp) =>
      timestamp != null && DateTime.now().difference(timestamp) < _masterCacheTtl;

  static void _handleUnauthorized(int statusCode) {
    if (statusCode == 401) {
      authToken = null;
      onUnauthorized?.call();
    }
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-branch-id': activeBranch,
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

  // Auth: Login with User ID (int or 'admin') and PIN
  static Future<Map<String, dynamic>> login(dynamic userId, String pin) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/login'),
          headers: _headers,
          body: jsonEncode({'userId': userId, 'pin': pin}),
        )
        .timeout(const Duration(seconds: 20));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      authToken = data['token'];
      if (data['branch'] != null) {
        final b = data['branch'].toString();
        activeBranch = b.toUpperCase() == 'ALL' ? 'MAIN' : b;
      }
      return data;
    } else {
      throw Exception(data['error'] ?? 'Login failed');
    }
  }

  // Auth: Fetch Active Users for POS-style login
  static Future<List<dynamic>> getPublicUsers() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/public/users'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch users');
    }
  }

  // Ensure authenticated
  static Future<void> _ensureAuth() async {
    if (authToken == null || authToken!.isEmpty) {
      throw Exception('Session expired or authentication required. Please log in.');
    }
  }

  // Health Check
  static Future<bool> checkHealth() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- CONSIGNORS ---
  static Future<List<Consignor>> getConsignors({String query = '', int limit = 5000}) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/consignors?branch=$activeBranch&page=1&limit=$limit&q=${Uri.encodeComponent(query)}');
    final response = await _client.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List rawList = decoded is Map ? (decoded['data'] ?? []) : decoded;
      return rawList.map((item) => Consignor.fromJson(Map<String, dynamic>.from(item))).toList();
    } else {
      throw Exception('Failed to load consignors (${response.statusCode}): ${response.body}');
    }
  }

  static Future<Consignor> saveConsignor(Map<String, dynamic> data, {int? id}) async {
    await _ensureAuth();
    final isUpdate = id != null && id > 0;
    final uri = Uri.parse(isUpdate ? '$baseUrl/consignors/$id' : '$baseUrl/consignors');
    final method = isUpdate ? _client.put : _client.post;

    final response = await method(uri, headers: _headers, body: jsonEncode(data));
    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Consignor.fromJson(Map<String, dynamic>.from(decoded));
    } else {
      throw Exception(decoded['error'] ?? 'Failed to save consignor');
    }
  }

  static Future<void> deleteConsignor(int id) async {
    await _ensureAuth();
    final response = await _client.delete(Uri.parse('$baseUrl/consignors/$id'), headers: _headers);
    if (response.statusCode != 200) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error'] ?? 'Failed to delete consignor');
    }
  }

  // --- CONSIGNEES ---
  static Future<List<Consignee>> getConsignees({String query = '', int limit = 5000}) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/consignees?branch=$activeBranch&page=1&limit=$limit&q=${Uri.encodeComponent(query)}');
    final response = await _client.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List rawList = decoded is Map ? (decoded['data'] ?? []) : decoded;
      return rawList.map((item) => Consignee.fromJson(Map<String, dynamic>.from(item))).toList();
    } else {
      throw Exception('Failed to load consignees (${response.statusCode}): ${response.body}');
    }
  }

  static Future<Consignee> saveConsignee(Map<String, dynamic> data, {int? id}) async {
    await _ensureAuth();
    final isUpdate = id != null && id > 0;
    final uri = Uri.parse(isUpdate ? '$baseUrl/consignees/$id' : '$baseUrl/consignees');
    final method = isUpdate ? _client.put : _client.post;

    final response = await method(uri, headers: _headers, body: jsonEncode(data));
    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Consignee.fromJson(Map<String, dynamic>.from(decoded));
    } else {
      throw Exception(decoded['error'] ?? 'Failed to save consignee');
    }
  }

  static Future<void> deleteConsignee(int id) async {
    await _ensureAuth();
    final response = await _client.delete(Uri.parse('$baseUrl/consignees/$id'), headers: _headers);
    if (response.statusCode != 200) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error'] ?? 'Failed to delete consignee');
    }
  }

  // --- VEHICLES ---
  static Future<List<Vehicle>> getVehicles({String query = '', int limit = 500}) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/vehicles?page=1&limit=$limit&q=${Uri.encodeComponent(query)}');
    final response = await _client.get(uri, headers: _headers);
    _handleUnauthorized(response.statusCode);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List rawList = decoded is Map ? (decoded['data'] ?? []) : decoded;
      return rawList.map((item) => Vehicle.fromJson(Map<String, dynamic>.from(item))).toList();
    } else {
      throw Exception('Failed to load vehicles (${response.statusCode}): ${response.body}');
    }
  }

  static Future<Vehicle> saveVehicle(Map<String, dynamic> data, {int? id}) async {
    await _ensureAuth();
    final isUpdate = id != null && id > 0;
    final uri = Uri.parse(isUpdate ? '$baseUrl/vehicles/$id' : '$baseUrl/vehicles');
    final method = isUpdate ? _client.put : _client.post;

    final response = await method(uri, headers: _headers, body: jsonEncode(data));
    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Vehicle.fromJson(Map<String, dynamic>.from(decoded));
    } else {
      throw Exception(decoded['error'] ?? 'Failed to save vehicle');
    }
  }

  static Future<void> deleteVehicle(int id) async {
    await _ensureAuth();
    final response = await _client.delete(Uri.parse('$baseUrl/vehicles/$id'), headers: _headers);
    if (response.statusCode != 200) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error'] ?? 'Failed to delete vehicle');
    }
  }

  // --- DRIVERS ---
  static Future<List<Driver>> getDrivers({String query = ''}) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/drivers?page=1&limit=50&q=$query');
    final response = await _client.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List rawList = decoded is Map ? (decoded['data'] ?? []) : decoded;
      return rawList.map((item) => Driver.fromJson(Map<String, dynamic>.from(item))).toList();
    } else {
      throw Exception('Failed to load drivers (${response.statusCode}): ${response.body}');
    }
  }

  static Future<Driver> saveDriver(Map<String, dynamic> data, {int? id}) async {
    await _ensureAuth();
    final isUpdate = id != null && id > 0;
    final uri = Uri.parse(isUpdate ? '$baseUrl/drivers/$id' : '$baseUrl/drivers');
    final method = isUpdate ? _client.put : _client.post;

    final response = await method(uri, headers: _headers, body: jsonEncode(data));
    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Driver.fromJson(Map<String, dynamic>.from(decoded));
    } else {
      throw Exception(decoded['error'] ?? 'Failed to save driver');
    }
  }

  static Future<void> deleteDriver(int id) async {
    await _ensureAuth();
    final response = await _client.delete(Uri.parse('$baseUrl/drivers/$id'), headers: _headers);
    if (response.statusCode != 200) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error'] ?? 'Failed to delete driver');
    }
  }

  // --- GOODS CONSIGNMENT (GC) ---
  static Future<String> getNextGcNumber({String mode = 'A'}) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/gcs/next-number?mode=$mode&branch=$activeBranch');
    final response = await _client.get(uri, headers: _headers);
    _handleUnauthorized(response.statusCode);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final nextNo = decoded['nextNumber']?.toString();
      if (nextNo != null && nextNo.isNotEmpty) return nextNo;
    }
    throw Exception('Failed to fetch next GC number from server (${response.statusCode})');
  }

  static Future<List<Gc>> getGcs({String query = '', int page = 1, int limit = 50}) async {
    final raw = await getGcsRaw(query: query, page: page, limit: limit);
    return raw.map((json) => Gc.fromJson(json)).toList();
  }

  static Future<List<dynamic>> getGcsRaw({String query = '', int page = 1, int limit = 50}) async {
    await _ensureAuth();
    final uri = Uri.parse(
      '$baseUrl/gcs?branch=$activeBranch&page=$page&limit=$limit&searchQuery=${Uri.encodeComponent(query)}',
    );
    final response = await _client.get(uri, headers: _headers);
    _handleUnauthorized(response.statusCode);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List rawList = decoded is Map ? (decoded['data'] ?? []) : decoded;
      return rawList.map((item) => Map<String, dynamic>.from(item)).toList();
    } else {
      throw Exception('Failed to load GCs (${response.statusCode}): ${response.body}');
    }
  }

  static Future<Gc> createGc(Map<String, dynamic> data) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/gcs');
    final response = await _client.post(uri, headers: _headers, body: jsonEncode(data));
    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Gc.fromJson(Map<String, dynamic>.from(decoded));
    } else {
      throw Exception(decoded['error'] ?? 'Failed to create GC');
    }
  }

  static Future<Gc> updateGc(int id, Map<String, dynamic> data) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/gcs/$id');
    final response = await _client.put(uri, headers: _headers, body: jsonEncode(data));
    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Gc.fromJson(Map<String, dynamic>.from(decoded));
    } else {
      throw Exception(decoded['error'] ?? 'Failed to update GC');
    }
  }

  // --- REPORTS ---
  static Future<Map<String, dynamic>> getReportAggregations(String queryParams) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/reports/aggregations?$queryParams');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch report aggregations');
    }
  }

  static Future<Map<String, dynamic>> getReportGcs(String queryParams) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/gcs?$queryParams');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch report GCs');
    }
  }

  static Future<Map<String, dynamic>> getReportGdms(String queryParams) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/gdms?$queryParams');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch report GDMs');
    }
  }

  static Future<Map<String, dynamic>> getGcDetails(String gcNumber) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/gcs/$gcNumber');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch GC details');
    }
  }

  static Future<Map<String, dynamic>> fetchEWayBill(String ewbNumber, {String? company}) async {
    await _ensureAuth();
    final query = company != null && company.isNotEmpty ? '?company=$company' : '';
    final uri = Uri.parse('$baseUrl/ewaybill/$ewbNumber$query');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch E-Way Bill details');
    }
  }

  static Future<void> reassignTransporter(String ewbNo, String currentCompany, String targetCompany) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/ewaybill/reassign');
    final body = jsonEncode({
      'ewbNo': ewbNo,
      'currentCompany': currentCompany,
      'targetCompany': targetCompany,
    });
    final response = await _client.post(uri, headers: _headers, body: body);
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to reassign transporter');
    }
  }

  // --- GDMs ---
  static Future<Map<String, dynamic>> getNextGdmNumber(String companyMode) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/gdms/next-number?branch=$activeBranch&mode=$companyMode');
    final response = await _client.get(uri, headers: _headers);
    _handleUnauthorized(response.statusCode);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch next GDM number (${response.statusCode})');
    }
  }

  static Future<List<dynamic>> getRecentGdms({int page = 1, int limit = 10, String query = ''}) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/gdms?branch=$activeBranch&page=$page&limit=$limit&searchQuery=${Uri.encodeComponent(query)}');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded['data'] ?? [];
    } else {
      throw Exception('Failed to load recent GDMs');
    }
  }

  static Future<Map<String, dynamic>> getGdmDetails(String gdmNumber) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/gdms/$gdmNumber');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load GDM');
    }
  }

  static Future<Gc> fetchGc(String gcNumber) async {
    final raw = await fetchGcRaw(gcNumber);
    return Gc.fromJson(raw);
  }

  static Future<Map<String, dynamic>> fetchGcRaw(String gcNumber) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/gcs/$gcNumber');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'GC Not Found');
    }
  }

  static Future<void> saveGdm(Map<String, dynamic> data, {int? id}) async {
    await _ensureAuth();
    final isUpdate = id != null && id > 0;
    final uri = Uri.parse(isUpdate ? '$baseUrl/gdms/$id' : '$baseUrl/gdms');
    final method = isUpdate ? _client.put : _client.post;

    final response = await method(uri, headers: _headers, body: jsonEncode(data));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to save GDM');
    }
  }

  // --- Fastag / Vahan DL ---
  static Future<Map<String, dynamic>> verifyDL(String dlNumber, String dob) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/fastag/dl');
    final response = await _client.post(uri, headers: _headers, body: jsonEncode({
      'dlNumber': dlNumber.replaceAll(RegExp(r'[\s-]'), ''),
      'dob': dob,
    }));
    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return decoded['data'];
    } else {
      throw Exception(decoded['error'] ?? 'Failed to verify Driving License');
    }
  }

  // --- Godowns ---
  static Future<List<dynamic>> getGodowns({bool forceRefresh = false}) async {
    if (!forceRefresh && _godownsCache != null && _isCacheValid(_godownsCacheTime)) {
      return List<dynamic>.from(_godownsCache!);
    }
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/godowns');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final list = List<dynamic>.from(jsonDecode(response.body) ?? []);
      _godownsCache = list;
      _godownsCacheTime = DateTime.now();
      return List<dynamic>.from(list);
    } else {
      throw Exception('Failed to fetch godowns');
    }
  }

  static Future<void> createGodown(Map<String, dynamic> payload) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/godowns');
    final response = await _client.post(uri, headers: _headers, body: jsonEncode(payload));
    if (response.statusCode != 200 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error'] ?? 'Failed to create godown');
    }
    _godownsCache = null;
  }

  static Future<void> updateGodown(int id, Map<String, dynamic> payload) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/godowns/$id');
    final response = await _client.put(uri, headers: _headers, body: jsonEncode(payload));
    if (response.statusCode != 200) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error'] ?? 'Failed to update godown');
    }
    _godownsCache = null;
  }

  static Future<void> deleteGodown(int id) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/godowns/$id');
    final response = await _client.delete(uri, headers: _headers);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete godown');
    }
    _godownsCache = null;
  }

  // --- Pincode ---
  static Future<List<dynamic>> verifyPincode(String pincode) async {
    final uri = Uri.parse('https://api.postalpincode.in/pincode/$pincode');
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded.isNotEmpty && decoded[0]['Status'] == 'Success') {
        return decoded[0]['PostOffice'] ?? [];
      }
      return [];
    } else {
      throw Exception('Failed to fetch pincode details');
    }
  }

  // --- Warehouse Inward ---
  static Future<Map<String, dynamic>> saveWarehouseInward(Map<String, dynamic> data, {int? id}) async {
    await _ensureAuth();
    final isUpdate = id != null && id > 0;
    final uri = Uri.parse(isUpdate ? '$baseUrl/warehouse-inward/$id' : '$baseUrl/warehouse-inward');
    final method = isUpdate ? _client.put : _client.post;

    final response = await method(uri, headers: _headers, body: jsonEncode(data));
    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded;
    } else {
      throw Exception(decoded['error'] ?? 'Failed to save warehouse entry');
    }
  }

  static Future<List<dynamic>> getRecentWarehouseInward({int limit = 1}) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/warehouse-inward?limit=$limit');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['data'] != null) {
        return decoded['data'];
      }
      return decoded is List ? decoded : [];
    } else {
      throw Exception('Failed to fetch recent warehouse entries');
    }
  }

  static Future<Map<String, dynamic>> getWarehouseStatement({required String date, int page = 1, int limit = 50}) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/warehouse-inward?date=$date&page=$page&limit=$limit');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else if (decoded is List) {
        return {'data': decoded, 'total': decoded.length, 'totalPages': 1};
      }
      return {'data': [], 'total': 0, 'totalPages': 1};
    } else {
      throw Exception('Failed to fetch warehouse statement');
    }
  }

  static Future<void> deleteWarehouseInward(int id) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/warehouse-inward/$id');
    final response = await _client.delete(uri, headers: _headers);
    if (response.statusCode != 200) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error'] ?? 'Failed to delete warehouse inward entry');
    }
  }


  // --- Trip Settlement ---
  static Future<List<dynamic>> getTrips() async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/trips');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) ?? [];
    } else {
      throw Exception('Failed to fetch trips');
    }
  }

  static Future<Map<String, dynamic>> saveTrip(Map<String, dynamic> payload) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/trips');
    final response = await _client.post(uri, headers: _headers, body: jsonEncode(payload));
    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded;
    } else {
      throw Exception(decoded['error'] ?? 'Failed to save trip');
    }
  }

  static Future<List<dynamic>> getGdmsUnassigned() async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/gdms-unassigned');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) ?? [];
    } else {
      throw Exception('Failed to fetch unassigned GDMs');
    }
  }

  // --- Govt Compliance ---
  static Future<List<dynamic>> getPendingGdmsForCewb(String branch) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/gdms/pending-cewb?branch=$branch');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) ?? [];
    } else {
      throw Exception('Failed to fetch pending GDMs');
    }
  }

  static Future<void> bulkVerifyEwaybills(List<Map<String, dynamic>> ewbs) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/ewaybill/bulk-verify');
    final response = await _client.post(uri, headers: _headers, body: jsonEncode({'ewbs': ewbs}));
    if (response.statusCode != 200) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error'] ?? 'Failed to bulk verify E-Way bills');
    }
  }

  static Future<void> bulkHealEwaybills(List<dynamic> gcs, String vehicleNo) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/ewaybill/bulk-heal');
    final response = await _client.post(uri, headers: _headers, body: jsonEncode({'gcs': gcs, 'vehicleNo': vehicleNo}));
    if (response.statusCode != 200) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error'] ?? 'Failed to auto-heal E-Way bills');
    }
  }

  static Future<Map<String, dynamic>> generateCewb(String company, Map<String, dynamic> payload) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/ewaybill/cewb?company=$company');
    final response = await _client.post(uri, headers: _headers, body: jsonEncode(payload));
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error'] ?? 'Failed to generate CEWB');
    }
  }

  static Future<void> attachMasterCewb(List<int> gdmIds, String cewbNumber) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/gdms/attach-master-cewb');
    final response = await _client.post(uri, headers: _headers, body: jsonEncode({
      'gdmIds': gdmIds,
      'cewbNumber': cewbNumber
    }));
    if (response.statusCode != 200) {
      throw Exception('Failed to attach Master CEWB');
    }
  }

  // --- HSN ---
  static Future<List<dynamic>> getHsnList({bool forceRefresh = false}) async {
    if (!forceRefresh && _hsnCache != null && _isCacheValid(_hsnCacheTime)) {
      return List<dynamic>.from(_hsnCache!);
    }
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/hsn');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final list = decoded is List ? List<dynamic>.from(decoded) : <dynamic>[];
      _hsnCache = list;
      _hsnCacheTime = DateTime.now();
      return List<dynamic>.from(list);
    } else {
      throw Exception('Failed to fetch HSN list');
    }
  }

  static Future<void> createHsn(Map<String, dynamic> payload) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/hsn');
    final response = await _client.post(uri, headers: _headers, body: jsonEncode(payload));
    if (response.statusCode != 200 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error'] ?? 'Failed to create HSN');
    }
    _hsnCache = null;
  }

  static Future<void> updateHsn(int id, Map<String, dynamic> payload) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/hsn/$id');
    final response = await _client.put(uri, headers: _headers, body: jsonEncode(payload));
    if (response.statusCode != 200) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error'] ?? 'Failed to update HSN');
    }
    _hsnCache = null;
  }

  static Future<void> deleteHsn(int id) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/hsn/$id');
    final response = await _client.delete(uri, headers: _headers);
    if (response.statusCode != 200 && response.statusCode != 204) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error'] ?? 'Failed to delete HSN');
    }
    _hsnCache = null;
  }

  static Future<Map<String, dynamic>> settleTrip(int tripId, Map<String, dynamic> payload) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/trips/$tripId/settle');
    final response = await _client.post(uri, headers: _headers, body: jsonEncode(payload));
    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded;
    } else {
      throw Exception(decoded['error'] ?? 'Failed to settle trip');
    }
  }

  static Future<Map<String, dynamic>> saveFreightBill(Map<String, dynamic> payload) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/freight-bills');
    final response = await _client.post(uri, headers: _headers, body: jsonEncode(payload));
    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded;
    } else {
      throw Exception(decoded['error'] ?? 'Failed to save freight bill');
    }
  }

  static Future<Map<String, dynamic>> updateGcFreight(int id, Map<String, dynamic> payload) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/gcs/$id/freight');
    final response = await _client.put(uri, headers: _headers, body: jsonEncode(payload));
    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return decoded is Map<String, dynamic> ? decoded : {};
    } else {
      throw Exception(decoded['error'] ?? 'Failed to update GC freight');
    }
  }


  // --- Party Accounts ---
  static Future<Map<String, dynamic>> getPartyLedger(String partyType, String partyId, {int page = 1, int limit = 50}) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/party-ledger/$partyType/$partyId?page=$page&limit=$limit');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) ?? {};
    } else {
      throw Exception('Failed to fetch party ledger');
    }
  }

  static Future<void> savePartyPayment(Map<String, dynamic> payload) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/party-payments');
    final response = await _client.post(uri, headers: _headers, body: jsonEncode(payload));
    if (response.statusCode != 200 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error'] ?? 'Failed to record payment');
    }
  }



  static Future<Map<String, dynamic>> getDriversPaginated({int page = 1, int limit = 50, String q = ''}) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/drivers?page=$page&limit=$limit&q=${Uri.encodeComponent(q)}');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded;
    } else {
      throw Exception('Failed to fetch drivers');
    }
  }

  static Future<void> createDriver(Map<String, dynamic> payload) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/drivers');
    final response = await _client.post(uri, headers: _headers, body: jsonEncode(payload));
    if (response.statusCode != 200 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error'] ?? 'Failed to create driver');
    }
  }

  static Future<void> updateDriver(int id, Map<String, dynamic> payload) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/drivers/$id');
    final response = await _client.put(uri, headers: _headers, body: jsonEncode(payload));
    if (response.statusCode != 200) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error'] ?? 'Failed to update driver');
    }
  }



  static Future<List<dynamic>> getParties(String endpoint, {int page = 1, int limit = 50, String q = ''}) async {
    final res = await getPartiesPaginated(endpoint, page: page, limit: limit, q: q);
    return res['data'] as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getPartiesPaginated(String endpoint, {int page = 1, int limit = 50, String q = ''}) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/$endpoint?branch=$activeBranch&page=$page&limit=$limit&q=${Uri.encodeComponent(q)}');
    final response = await _client.get(uri, headers: _headers);
    _handleUnauthorized(response.statusCode);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return {
          'data': decoded,
          'total': decoded.length,
          'hasMore': false,
        };
      }
      final List<dynamic> list = decoded['data'] ?? [];
      return {
        'data': list,
        'total': decoded['total'] ?? list.length,
        'hasMore': decoded['hasMore'] == true,
      };
    } else {
      throw Exception('Failed to fetch $endpoint');
    }
  }

  static Future<Map<String, dynamic>> getPartyDuplicates(String endpoint) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/$endpoint/duplicates');
    final response = await _client.get(uri, headers: _headers);
    _handleUnauthorized(response.statusCode);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to scan duplicate $endpoint');
  }

  static Future<Map<String, dynamic>> mergeParties(
      String endpoint, int keepId, List<int> mergeIds) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/$endpoint/merge');
    final response = await _client.post(
      uri,
      headers: _headers,
      body: jsonEncode({'keepId': keepId, 'mergeIds': mergeIds}),
    );
    _handleUnauthorized(response.statusCode);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return decoded;
    }
    throw Exception(decoded['error'] ?? 'Failed to merge $endpoint');
  }

  static Future<void> restoreParty(String endpoint, int id) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/$endpoint/$id/restore');
    final response = await _client.put(uri, headers: _headers);
    _handleUnauthorized(response.statusCode);
    if (response.statusCode != 200) {
      throw Exception('Failed to restore party');
    }
  }

  static Future<Map<String, dynamic>> trackVehicleFastag(String vehicleNumber) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/fastag/track');
    final response = await _client.post(
      uri,
      headers: _headers,
      body: jsonEncode({'vehicleNumber': vehicleNumber}),
    );
    _handleUnauthorized(response.statusCode);
    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    } else {
      throw Exception(decoded['error'] ?? 'Failed to track vehicle FASTag');
    }
  }

  static Future<void> createParty(String endpoint, Map<String, dynamic> payload) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/$endpoint');
    final response = await _client.post(uri, headers: _headers, body: jsonEncode(payload));
    if (response.statusCode != 200 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error'] ?? 'Failed to create party');
    }
  }

  static Future<void> updateParty(String endpoint, int id, Map<String, dynamic> payload) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/$endpoint/$id');
    final response = await _client.put(uri, headers: _headers, body: jsonEncode(payload));
    if (response.statusCode != 200) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error'] ?? 'Failed to update party');
    }
  }

  static Future<void> deleteParty(String endpoint, int id) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/$endpoint/$id');
    final response = await _client.delete(uri, headers: _headers);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete party');
    }
  }

  static Future<Map<String, dynamic>> verifyGST(String gstin) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/appyflow-gst/$gstin');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      try {
        final decoded = jsonDecode(response.body);
        final errMsg = decoded['message'] ?? decoded['error']?.toString() ?? 'Failed to verify GST. Raw: ${response.body}';
        throw Exception(errMsg);
      } catch (e) {
        if (e is FormatException) {
          throw Exception('Failed to verify GST: ${response.statusCode}. Raw: ${response.body}');
        }
        rethrow;
      }
    }
  }

  // --- Company Master ---
  static Future<List<dynamic>> getCompanies({bool forceRefresh = false}) async {
    if (!forceRefresh && _companiesCache != null && _isCacheValid(_companiesCacheTime)) {
      return List<dynamic>.from(_companiesCache!);
    }
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/companies');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final list = decoded is List ? List<dynamic>.from(decoded) : <dynamic>[];
      _companiesCache = list;
      _companiesCacheTime = DateTime.now();
      return List<dynamic>.from(list);
    } else {
      throw Exception('Failed to fetch companies');
    }
  }

  static Future<Map<String, dynamic>> saveCompany(Map<String, dynamic> data, {int? id}) async {
    await _ensureAuth();
    final isUpdate = id != null && id > 0;
    final uri = Uri.parse(isUpdate ? '$baseUrl/companies/$id' : '$baseUrl/companies');
    final response = isUpdate
        ? await _client.put(uri, headers: _headers, body: jsonEncode(data))
        : await _client.post(uri, headers: _headers, body: jsonEncode(data));
    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      _companiesCache = null;
      return decoded is Map<String, dynamic> ? decoded : {};
    } else {
      throw Exception(decoded['error'] ?? 'Failed to save company');
    }
  }

  static Future<void> deleteCompany(int id) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/companies/$id');
    final response = await _client.delete(uri, headers: _headers);
    if (response.statusCode != 200) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error'] ?? 'Failed to delete company');
    }
    _companiesCache = null;
  }


  // --- Daily Accounts ---
  static Future<Map<String, dynamic>> getDailyTransactions({int page = 1, int limit = 50}) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/daily-transactions?page=$page&limit=$limit');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) ?? {};
    } else {
      throw Exception('Failed to fetch daily transactions');
    }
  }

  static Future<void> saveDailyTransaction(Map<String, dynamic> payload) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/daily-transactions');
    final response = await _client.post(uri, headers: _headers, body: jsonEncode(payload));
    if (response.statusCode != 200 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error'] ?? 'Failed to record transaction');
    }
  }

  static Future<void> deleteDailyTransaction(int id) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/daily-transactions/$id');
    final response = await _client.delete(uri, headers: _headers);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete transaction');
    }
  }

  // Get vehicles for search panel
  static Future<Map<String, dynamic>> getVehiclesPaginated({int page = 1, int limit = 50, String q = ''}) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/vehicles?page=$page&limit=$limit&q=${Uri.encodeComponent(q)}');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {'data': decoded, 'hasMore': false, 'total': (decoded as List).length};
    } else {
      throw Exception('Failed to fetch vehicles');
    }
  }

  static Future<void> createVehicle(Map<String, dynamic> payload) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/vehicles');
    final response = await _client.post(uri, headers: _headers, body: jsonEncode(payload));
    if (response.statusCode != 200 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error'] ?? 'Failed to create vehicle');
    }
  }

  static Future<void> updateVehicle(int id, Map<String, dynamic> payload) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/vehicles/$id');
    final response = await _client.put(uri, headers: _headers, body: jsonEncode(payload));
    if (response.statusCode != 200) {
      final decoded = jsonDecode(response.body);
      throw Exception(decoded['error'] ?? 'Failed to update vehicle');
    }
  }



  static Future<Map<String, dynamic>> fetchRcDetails(String vehicleNumber) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/fastag/rc');
    final response = await _client.post(uri, headers: _headers, body: jsonEncode({'vehicleNumber': vehicleNumber}));
    final decoded = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return decoded['data'] ?? decoded;
    } else {
      throw Exception(decoded['error'] ?? 'Failed to fetch RC details');
    }
  }

  // --- UNITS ---
  static Future<List<UnitModel>> getUnits({bool forceRefresh = false}) async {
    if (!forceRefresh && _unitsCache != null && _isCacheValid(_unitsCacheTime)) {
      return List<UnitModel>.from(_unitsCache!);
    }
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/units');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List rawList = decoded is List ? decoded : (decoded['data'] ?? []);
      final list = rawList.map((item) => UnitModel.fromJson(Map<String, dynamic>.from(item))).toList();
      _unitsCache = list;
      _unitsCacheTime = DateTime.now();
      return List<UnitModel>.from(list);
    } else {
      return [];
    }
  }

  static Future<Map<String, dynamic>> saveUnit(Map<String, dynamic> data, {int? id}) async {
    await _ensureAuth();
    final isUpdate = id != null && id > 0;
    final uri = Uri.parse(isUpdate ? '$baseUrl/units/$id' : '$baseUrl/units');
    final response = isUpdate
        ? await _client.put(uri, headers: _headers, body: jsonEncode(data))
        : await _client.post(uri, headers: _headers, body: jsonEncode(data));
    if (response.statusCode == 200 || response.statusCode == 201) {
      _unitsCache = null;
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } else {
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      throw Exception(decoded['error'] ?? 'Failed to save unit');
    }
  }

  static Future<void> deleteUnit(int id) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/units/$id');
    final response = await _client.delete(uri, headers: _headers);
    if (response.statusCode != 200 && response.statusCode != 204) {
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      throw Exception(decoded['error'] ?? 'Failed to delete unit');
    }
    _unitsCache = null;
  }

  // --- ADMIN & SESSIONS ---
  static Future<List<dynamic>> getAdminUsers() async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/admin/users');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded is List ? decoded : [];
    } else {
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      throw Exception(decoded['error'] ?? 'Failed to fetch users');
    }
  }

  static Future<Map<String, dynamic>> saveAdminUser(Map<String, dynamic> data, {int? id}) async {
    await _ensureAuth();
    final isUpdate = id != null && id > 0;
    final uri = Uri.parse(isUpdate ? '$baseUrl/admin/users/$id' : '$baseUrl/admin/users');
    final method = isUpdate ? _client.put : _client.post;
    final response = await method(uri, headers: _headers, body: jsonEncode(data));
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded is Map<String, dynamic> ? decoded : {};
    } else {
      throw Exception(decoded['error'] ?? 'Failed to save user');
    }
  }

  static Future<void> deleteAdminUser(int id) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/admin/users/$id');
    final response = await _client.delete(uri, headers: _headers);
    if (response.statusCode != 200 && response.statusCode != 204) {
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      throw Exception(decoded['error'] ?? 'Failed to delete user');
    }
  }

  static Future<List<dynamic>> getAdminSessions() async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/admin/sessions');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded is List ? decoded : [];
    } else {
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      throw Exception(decoded['error'] ?? 'Failed to fetch sessions');
    }
  }

  static Future<void> revokeAdminSession(int id) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/admin/sessions/$id');
    final response = await _client.delete(uri, headers: _headers);
    if (response.statusCode != 200 && response.statusCode != 204) {
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      throw Exception(decoded['error'] ?? 'Failed to revoke session');
    }
  }

  static String getAdminBackupUrl() {
    final token = authToken ?? '';
    return '$baseUrl/admin/backup?token=$token';
  }

  // --- AUDIT LOGS ---
  static Future<List<dynamic>> getAuditLogs({String? search, String? action, int limit = 500}) async {
    await _ensureAuth();
    final queryParams = <String, String>{
      'limit': limit.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (action != null && action != 'ALL') 'action': action,
    };
    final uri = Uri.parse('$baseUrl/audit-logs').replace(queryParameters: queryParams);
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded is List ? decoded : [];
    } else {
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      throw Exception(decoded['error'] ?? 'Failed to fetch audit logs');
    }
  }

  // --- SYSTEM HEALTH & TECHNOLOGY USAGE ---
  static Future<Map<String, dynamic>> getSystemHealth() async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/system/health');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } else {
      return {};
    }
  }

  static Future<List<dynamic>> getSystemHealthHistory() async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/system/health/history');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['data'] is List) {
        return decoded['data'];
      }
      return decoded is List ? decoded : [];
    } else {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getUsageStats() async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/usage/stats');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } else {
      return {};
    }
  }

  static Future<Map<String, dynamic>> runSandboxTest() async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/usage/sandbox-test');
    final response = await _client.post(uri, headers: _headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } else {
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      throw Exception(decoded['error'] ?? 'Sandbox test failed');
    }
  }

  // --- Godown Planner & AI ---
  static Future<List<dynamic>> getGodownStock() async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/godown-stock');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded is List ? decoded : [];
    } else {
      throw Exception('Failed to fetch godown stock');
    }
  }

  static Future<Map<String, dynamic>> queryGodownAi(Map<String, dynamic> payload) async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/godown-ai');
    final response = await _client.post(uri, headers: _headers, body: jsonEncode(payload));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } else {
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      throw Exception(decoded['error'] ?? decoded['reply'] ?? 'Failed to query Godown AI');
    }
  }

  // --- Legacy MDB Access ---
  static Future<List<String>> getLegacyCompanies() async {
    await _ensureAuth();
    final uri = Uri.parse('$baseUrl/legacy-mdb/companies');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final raw = decoded['companies'];
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return [];
    } else {
      throw Exception('Failed to load MS Access folders');
    }
  }

  static Future<List<String>> getLegacyFinancialYears(String company) async {
    await _ensureAuth();
    final encoded = Uri.encodeComponent(company);
    final uri = Uri.parse('$baseUrl/legacy-mdb/$encoded/financial-years');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final raw = decoded['years'];
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return [];
    } else {
      return [];
    }
  }

  static Future<List<dynamic>> getLegacyMdbData(String company, String tab, {String? fy}) async {
    await _ensureAuth();
    final encComp = Uri.encodeComponent(company);
    final query = (fy != null && fy.isNotEmpty) ? '?fy=${Uri.encodeComponent(fy)}' : '';
    final uri = Uri.parse('$baseUrl/legacy-mdb/$encComp/$tab$query');
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded['data'];
      return data is List ? data : [];
    } else {
      throw Exception('Failed to load $tab data from MS Access');
    }
  }

  // --- Remote Scanner Hub ---
  static Future<void> pushRemoteScan(String code, String data) async {
    final uri = Uri.parse('$baseUrl/scanner/push');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code, 'data': data}),
    );
    if (response.statusCode != 200) {
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      throw Exception(decoded['error'] ?? 'Failed to send scan to PC');
    }
  }

  static Future<Map<String, dynamic>> pollRemoteScan(String code) async {
    final uri = Uri.parse('$baseUrl/scanner/poll?code=${Uri.encodeComponent(code)}');
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } else {
      return {'status': 'waiting'};
    }
  }
}
