import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/consignee.dart';
import '../models/gc.dart';
import '../models/gdm.dart';
import '../models/unit_model.dart';
import '../models/vehicle.dart';
import '../services/api_service.dart';
import '../services/pdf_service.dart';
import '../widgets/barcode_scanner_modal.dart';

class _GdmGcRow {
  final Gc gc;
  final Map<String, dynamic> raw;
  final String ewbStatus; // 'VALID', 'EXPIRING', 'EXPIRED', 'NONE'
  final String? ewbValidUpto;

  _GdmGcRow({
    required this.gc,
    required this.raw,
    required this.ewbStatus,
    this.ewbValidUpto,
  });
}

class GdmEntryScreen extends StatefulWidget {
  final Gdm? initialGdm;

  const GdmEntryScreen({super.key, this.initialGdm});

  @override
  State<GdmEntryScreen> createState() => _GdmEntryScreenState();
}

class _GdmEntryScreenState extends State<GdmEntryScreen> {
  static const Color _indigo50 = Color(0xFFEEF2FF);
  static const Color _indigo100 = Color(0xFFE0E7FF);
  static const Color _indigo600 = Color(0xFF4F46E5);
  static const Color _indigo700 = Color(0xFF4338CA);
  static const Color _emerald50 = Color(0xFFECFDF5);
  static const Color _emerald600 = Color(0xFF059669);
  static const Color _emerald700 = Color(0xFF047857);
  static const Color _slate50 = Color(0xFFF8FAFC);
  static const Color _slate100 = Color(0xFFF1F5F9);
  static const Color _slate200 = Color(0xFFE2E8F0);
  static const Color _slate300 = Color(0xFFCBD5E1);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate900 = Color(0xFF0F172A);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormState>();

  bool _isLoadingMasters = true;
  bool _isSubmitting = false;
  bool _isAddingGc = false;

  int? _activeGdmId;
  String _gdmCompanyMode = 'A'; // 'A' = AP, 'B' = BELL
  String _gdmNumber = '';

  // Header Details
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  late final TextEditingController _fromLocationController;
  final TextEditingController _toNameController = TextEditingController(text: 'AS PER BILLS');
  final TextEditingController _deliveryAtController = TextEditingController();
  final TextEditingController _cewbNumberController = TextEditingController();

  // Consignee Mode
  String _consigneeMode = 'Multiple Consignee';
  List<Consignee> _consignees = [];
  Consignee? _selectedConsignee;
  int _consigneeAutoEpoch = 0;

  // Lorry Details
  List<Vehicle> _vehicles = [];
  Vehicle? _selectedVehicle;
  int _vehicleAutoEpoch = 0;
  final TextEditingController _driverNameController = TextEditingController();
  final TextEditingController _driverPhoneController = TextEditingController();
  final TextEditingController _startKmController = TextEditingController();

  // DL Verification
  final TextEditingController _licenseController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  bool _isFetchingDl = false;
  Map<String, dynamic>? _dlData;

  // Despatch List
  final TextEditingController _searchGcController = TextEditingController();
  final FocusNode _gcScanFocusNode = FocusNode();
  final List<_GdmGcRow> _linkedGcs = [];
  List<UnitModel> _units = [];

  String _freightMode = 'Use Individual GC Freight';
  final TextEditingController _overallRateController = TextEditingController();

  // Recent GDMs Drawer
  List<dynamic> _recentGdms = [];
  bool _isLoadingHistory = false;
  String _historyQuery = '';

  String get _defaultFromLocation =>
      ApiService.activeBranch == 'AP_BNG' ? 'Bengaluru' : 'Sivakasi';

  @override
  void initState() {
    super.initState();
    _fromLocationController = TextEditingController(text: _defaultFromLocation);
    _loadInitialData();
  }

  @override
  void dispose() {
    _fromLocationController.dispose();
    _toNameController.dispose();
    _deliveryAtController.dispose();
    _cewbNumberController.dispose();
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    _startKmController.dispose();
    _licenseController.dispose();
    _dobController.dispose();
    _searchGcController.dispose();
    _gcScanFocusNode.dispose();
    _overallRateController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        ApiService.getVehicles(),
        ApiService.getConsignees(),
        ApiService.getUnits(),
      ]);
      if (!mounted) return;
      setState(() {
        _vehicles = results[0] as List<Vehicle>;
        _consignees = results[1] as List<Consignee>;
        _units = results[2] as List<UnitModel>;
      });

      if (widget.initialGdm != null) {
        await _loadGdmForEdit(widget.initialGdm!.gdmNumber);
      } else {
        await _fetchNextGdmNumber();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading masters: ${_cleanError(e)}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMasters = false);
      }
    }
  }

  String _cleanError(Object e) => e.toString().replaceAll('Exception:', '').trim();

  Future<void> _fetchNextGdmNumber() async {
    try {
      final res = await ApiService.getNextGdmNumber(_gdmCompanyMode);
      final prefix = _gdmCompanyMode == 'A' ? 'AP-' : 'BELL-';
      if (mounted) {
        setState(() {
          _gdmNumber = prefix + (res['nextNumber']?.toString() ?? '1001');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _gdmNumber = 'ERROR');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch next GDM number: ${_cleanError(e)}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _fetchRecentGdms() async {
    setState(() => _isLoadingHistory = true);
    try {
      final list = await ApiService.getRecentGdms(limit: 25, query: _historyQuery);
      if (mounted) setState(() => _recentGdms = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load recent GDMs: ${_cleanError(e)}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _loadGdmForEdit(String gdmNumber) async {
    setState(() => _isLoadingHistory = true);
    try {
      final raw = await ApiService.getGdmDetails(gdmNumber);
      final gcsRaw = (raw['gcs'] as List?) ?? [];
      final loadedRows = gcsRaw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return _buildGcRowFromRaw(m);
      }).toList();

      String inferredMode = 'A';
      final gdmNoStr = raw['gdmNumber']?.toString() ?? gdmNumber;
      if (gdmNoStr.startsWith('BELL-') || (loadedRows.isNotEmpty && loadedRows.first.gc.gcNumber.startsWith('BELL-'))) {
        inferredMode = 'B';
      }

      Vehicle? matchedVehicle;
      final vid = raw['vehicleId'] is int ? raw['vehicleId'] as int : int.tryParse(raw['vehicleId']?.toString() ?? '');
      if (vid != null) {
        try {
          matchedVehicle = _vehicles.firstWhere((v) => v.id == vid);
        } catch (_) {}
      }

      DateTime parsedDate = DateTime.now();
      if (raw['date'] != null) {
        parsedDate = DateTime.tryParse(raw['date'].toString()) ?? DateTime.now();
      }
      TimeOfDay parsedTime = TimeOfDay.now();
      final timeStr = raw['time']?.toString() ?? '';
      if (timeStr.contains(':')) {
        final parts = timeStr.split(':');
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) parsedTime = TimeOfDay(hour: h, minute: m);
      }

      if (!mounted) return;
      setState(() {
        _activeGdmId = raw['id'] is int ? raw['id'] as int : int.tryParse(raw['id']?.toString() ?? '');
        _gdmCompanyMode = inferredMode;
        _gdmNumber = gdmNoStr;
        _date = parsedDate;
        _time = parsedTime;
        _fromLocationController.text = raw['fromLocation']?.toString() ?? _defaultFromLocation;
        _toNameController.text = raw['toName']?.toString() ?? 'AS PER BILLS';
        _deliveryAtController.text = raw['deliveryAt']?.toString() ?? '';
        _cewbNumberController.text = raw['cewbNumber']?.toString() ?? '';
        _selectedVehicle = matchedVehicle;
        _vehicleAutoEpoch++;
        _driverNameController.text = raw['driverName']?.toString() ?? '';
        _driverPhoneController.text = raw['driverPhone']?.toString() ?? '';
        _startKmController.text = raw['startKm']?.toString() ?? '';
        _freightMode = raw['freightMode']?.toString() ?? 'Use Individual GC Freight';
        _overallRateController.text = (raw['overallRate'] ?? raw['memoAmount'] ?? '').toString();
        _linkedGcs
          ..clear()
          ..addAll(loadedRows);
        _consigneeMode = 'Multiple Consignee';
        _selectedConsignee = null;
        _consigneeAutoEpoch++;
      });

      _scaffoldKey.currentState?.closeEndDrawer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loaded $gdmNoStr for editing'), backgroundColor: _indigo600),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load GDM: ${_cleanError(e)}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  _GdmGcRow _buildGcRowFromRaw(Map<String, dynamic> raw) {
    final gc = Gc.fromJson(raw);
    final ewbRaw = raw['ewbRawData'] is Map ? raw['ewbRawData'] as Map : null;
    final validUptoStr = (ewbRaw?['validUpto'] ?? ewbRaw?['ewbValidUpto'] ?? raw['ewbValidUpto'])?.toString();
    String ewbStatus = 'NONE';

    if ((gc.ewbNumber ?? '').trim().isNotEmpty) {
      ewbStatus = 'VALID';
      final parsedExpiry = _parseIndianDateTime(validUptoStr);
      if (parsedExpiry != null) {
        final diff = parsedExpiry.difference(DateTime.now());
        if (diff.isNegative) {
          ewbStatus = 'EXPIRED';
        } else if (diff.inHours <= 12) {
          ewbStatus = 'EXPIRING';
        }
      }
    }

    return _GdmGcRow(
      gc: gc,
      raw: raw,
      ewbStatus: ewbStatus,
      ewbValidUpto: validUptoStr,
    );
  }

  DateTime? _parseIndianDateTime(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    final iso = DateTime.tryParse(s.trim());
    if (iso != null) return iso;
    // Handle DD/MM/YYYY or DD-MM-YYYY (with optional HH:MM:SS AM/PM)
    final match = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)?)?', caseSensitive: false)
        .firstMatch(s.trim());
    if (match == null) return null;
    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = int.parse(match.group(3)!);
    int hour = int.tryParse(match.group(4) ?? '23') ?? 23;
    final minute = int.tryParse(match.group(5) ?? '59') ?? 59;
    final ampm = match.group(7)?.toUpperCase();
    if (ampm == 'PM' && hour < 12) hour += 12;
    if (ampm == 'AM' && hour == 12) hour = 0;
    return DateTime(year, month, day, hour, minute);
  }

  // --- DL Verification & Validation ---
  bool _hasHeavyTransportClass(Map<String, dynamic> dl) {
    const heavyKeywords = ['TRANS', 'HTV', 'HMV', 'HGMV', 'MGV', 'MGMV', 'TRV'];
    final classes = dl['vehicle_classes'] ?? dl['cov_details'] ?? dl['classes'];
    final joined = classes is List
        ? classes.map((e) => e.toString().toUpperCase()).join(' ')
        : (classes?.toString().toUpperCase() ?? '');
    return heavyKeywords.any((k) => joined.contains(k));
  }

  bool _isTrExpired(Map<String, dynamic> dl) {
    final tr = dl['validity_tr']?.toString();
    if (tr == null || tr.isEmpty || tr.toUpperCase() == 'N/A') return true;
    final dt = _parseIndianDateTime(tr);
    if (dt == null) return false;
    return dt.isBefore(DateTime.now());
  }

  Future<void> _verifyDL() async {
    final dlNo = _licenseController.text.trim().toUpperCase();
    final dob = _dobController.text.trim();
    if (dlNo.isEmpty || dob.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('License Number and DOB are required'), backgroundColor: Colors.orange),
      );
      return;
    }
    _licenseController.text = dlNo;

    setState(() => _isFetchingDl = true);
    try {
      final data = await ApiService.verifyDL(dlNo, dob);
      final hasHeavy = _hasHeavyTransportClass(data);
      final trExpired = _isTrExpired(data);
      if (!mounted) return;
      setState(() {
        _dlData = data;
        if (_driverNameController.text.isEmpty &&
            data['owner_name'] != null &&
            !data['owner_name'].toString().contains('*')) {
          _driverNameController.text = data['owner_name'].toString();
        }
      });

      if (trExpired) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WARNING: Driver Transport Validity (TR) is expired or missing!'), backgroundColor: Colors.red),
        );
      } else if (!hasHeavy) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WARNING: DL does not list Heavy/Transport vehicle class (TRANS/HTV/HMV).'), backgroundColor: Colors.orange),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('DL Verified: Eligible for Heavy Transport'), backgroundColor: _emerald600),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('DL Verification Failed: ${_cleanError(e)}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingDl = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Future<void> _pickDob() async {
    final initial = DateTime.tryParse(_dobController.text) ?? DateTime(1990, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1945),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _dobController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _addGc([String? overrideValue]) async {
    if (_isAddingGc) return;
    final text = (overrideValue ?? _searchGcController.text).trim().toUpperCase();
    if (text.isEmpty) return;

    String rawGc = text;
    if (rawGc.startsWith('AP-')) rawGc = rawGc.substring(3);
    if (rawGc.startsWith('BELL-')) rawGc = rawGc.substring(5);

    final prefix = _gdmCompanyMode == 'A' ? 'AP-' : 'BELL-';
    final targetGcNo = prefix + rawGc;

    _searchGcController.clear();

    if (_linkedGcs.any((item) => item.gc.gcNumber == targetGcNo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GC $targetGcNo is already in this manifest'), backgroundColor: Colors.orange),
      );
      _gcScanFocusNode.requestFocus();
      return;
    }

    setState(() => _isAddingGc = true);
    try {
      final raw = await ApiService.fetchGcRaw(targetGcNo);
      final row = _buildGcRowFromRaw(raw);
      final gc = row.gc;

      if (gc.gdmId != null && gc.gdmId != _activeGdmId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('GC ${gc.gcNumber} is already dispatched on another GDM!'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      if (gc.status == 'Cancelled') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('GC ${gc.gcNumber} is Cancelled!'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      // Single Consignee Group Enforcement
      if (_consigneeMode == 'Single Consignee' && _selectedConsignee != null) {
        final targetRootId = _selectedConsignee!.parentId ?? _selectedConsignee!.id;
        Consignee? gcConsignee;
        if (gc.consigneeId != null) {
          try {
            gcConsignee = _consignees.firstWhere((c) => c.id == gc.consigneeId);
          } catch (_) {}
        }
        final gcRootId = gcConsignee?.parentId ?? gc.consigneeId;
        if (gcRootId != null && gcRootId != targetRootId) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Single Consignee mode: ${gc.gcNumber} belongs to "${gc.consigneeName}", not "${_selectedConsignee!.name}".'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _linkedGcs.add(row);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_cleanError(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingGc = false);
        _gcScanFocusNode.requestFocus();
      }
    }
  }

  void _removeGc(int index) {
    setState(() => _linkedGcs.removeAt(index));
  }

  // --- Package Category & Freight Calculations ---
  String _classifyUnit(String? unitText) {
    final u = (unitText ?? '').toLowerCase();
    for (final m in _units) {
      if (m.description.toLowerCase() == u) {
        final cat = m.category.toLowerCase();
        if (cat.contains('case') || cat.contains('box')) return 'CASES';
        if (cat.contains('carton')) return 'CARTONS';
        if (cat.contains('bundle')) return 'BUNDLES';
      }
    }
    if (u.contains('carton') || u.contains('c/n')) return 'CARTONS';
    if (u.contains('bundle') || u.contains('bd/s')) return 'BUNDLES';
    if (u.contains('case') || u.contains('box') || u.contains('c/s')) return 'CASES';
    return 'OTHERS';
  }

  Map<String, int> _calculatePackageBreakdown() {
    int cases = 0, cartons = 0, bundles = 0, others = 0;
    for (final row in _linkedGcs) {
      for (final item in row.gc.goods) {
        final qty = item.articleCount ?? 0;
        switch (_classifyUnit(item.units)) {
          case 'CASES':
            cases += qty;
            break;
          case 'CARTONS':
            cartons += qty;
            break;
          case 'BUNDLES':
            bundles += qty;
            break;
          default:
            others += qty;
            break;
        }
      }
    }
    return {
      'cases': cases,
      'cartons': cartons,
      'bundles': bundles,
      'others': others,
      'total': cases + cartons + bundles + others,
    };
  }

  double _calculateTotalFreight() {
    if (_freightMode == 'Set Overall Rate') {
      return double.tryParse(_overallRateController.text) ?? 0.0;
    }
    double sum = 0.0;
    for (final row in _linkedGcs) {
      sum += row.gc.freightTotal;
    }
    return sum;
  }

  Future<void> _printGdmPdf(Map<String, dynamic> gdmData, {String format = 'gdm'}) async {
    try {
      final bytes = await PdfService.generateGdmsPdf([gdmData], format: format);
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: '${gdmData['gdmNumber'] ?? 'GDM'}_$format.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: ${_cleanError(e)}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveGDM(String status) async {
    if (_gdmNumber.trim().isEmpty || _gdmNumber == 'ERROR') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GDM Number is missing. Please retry fetching next GDM number.'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_linkedGcs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one GC to the manifest!'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Vehicle!'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final memoAmount = _calculateTotalFreight();
      final payload = {
        'gdmNumber': _gdmNumber,
        'branch': ApiService.activeBranch,
        'date': _date.toIso8601String(),
        'time': '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
        'vehicleId': _selectedVehicle!.id,
        'driverName': _driverNameController.text.trim(),
        'driverPhone': _driverPhoneController.text.trim(),
        'startKm': int.tryParse(_startKmController.text.trim()),
        'fromLocation': _fromLocationController.text.trim(),
        'toName': _toNameController.text.trim(),
        'deliveryAt': _deliveryAtController.text.trim(),
        'memoAmount': memoAmount,
        'freightMode': _freightMode,
        'overallRate': double.tryParse(_overallRateController.text.trim()) ?? 0,
        'cewbNumber': _cewbNumberController.text.trim().isEmpty ? null : _cewbNumberController.text.trim(),
        'status': status,
        'gcIds': _linkedGcs.map((r) => r.gc.id).whereType<int>().toList(),
      };

      final saved = await ApiService.saveGdm(payload, id: _activeGdmId);

      // Build printable map including linked GCs & vehicle details
      final printable = Map<String, dynamic>.from(saved);
      printable['gdmNumber'] ??= _gdmNumber;
      printable['vehicle'] ??= _selectedVehicle!.toJson();
      printable['gcs'] ??= _linkedGcs.map((r) => r.raw).toList();

      if (!mounted) return;
      _showPostSaveDialog(printable, status: status);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save Failed: ${_cleanError(e)}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showPostSaveDialog(Map<String, dynamic> gdmData, {required String status}) {
    final gdmNo = gdmData['gdmNumber']?.toString() ?? _gdmNumber;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: _emerald600, size: 26),
            const SizedBox(width: 10),
            Expanded(child: Text(_activeGdmId != null ? 'GDM Updated' : 'GDM $status')),
          ],
        ),
        content: Text(
          'GDM Number: $gdmNo\nVehicle: ${_selectedVehicle?.vehicleNumber ?? '-'}\nConsignments: ${_linkedGcs.length} GCs',
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.print_rounded, size: 16),
            label: const Text('Print GDM'),
            onPressed: () => _printGdmPdf(gdmData, format: 'gdm'),
          ),
          if ((gdmData['cewbNumber']?.toString() ?? '').isNotEmpty)
            OutlinedButton.icon(
              icon: const Icon(Icons.assignment_rounded, size: 16),
              label: const Text('Print CEWB'),
              onPressed: () => _printGdmPdf(gdmData, format: 'cewb'),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _indigo600, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _resetForm();
            },
            child: const Text('New GDM'),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _activeGdmId = null;
      _linkedGcs.clear();
      _selectedVehicle = null;
      _vehicleAutoEpoch++;
      _selectedConsignee = null;
      _consigneeAutoEpoch++;
      _consigneeMode = 'Multiple Consignee';
      _date = DateTime.now();
      _time = TimeOfDay.now();
      _fromLocationController.text = _defaultFromLocation;
      _toNameController.text = 'AS PER BILLS';
      _deliveryAtController.clear();
      _cewbNumberController.clear();
      _driverNameController.clear();
      _driverPhoneController.clear();
      _startKmController.clear();
      _licenseController.clear();
      _dobController.clear();
      _dlData = null;
      _freightMode = 'Use Individual GC Freight';
      _overallRateController.clear();
    });
    _fetchNextGdmNumber();
  }

  void _switchCompanyMode(String mode) {
    if (_activeGdmId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company mode is locked while editing an existing GDM.'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_linkedGcs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remove all GCs before switching company mode!'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_gdmCompanyMode == mode) return;
    setState(() => _gdmCompanyMode = mode);
    _fetchNextGdmNumber();
  }

  Widget _buildCompanyToggleItem(String label, String mode, Color activeColor) {
    final isSelected = _gdmCompanyMode == mode;
    final locked = _activeGdmId != null;
    return InkWell(
      onTap: () => _switchCompanyMode(mode),
      borderRadius: BorderRadius.circular(7),
      child: Opacity(
        opacity: locked && !isSelected ? 0.45 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: isSelected
                ? [BoxShadow(color: _slate900.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isSelected ? activeColor : _slate500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _slate200),
        boxShadow: [
          BoxShadow(color: _indigo600.withValues(alpha: 0.03), blurRadius: 14, offset: const Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, {Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _slate100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _slate900)),
            ],
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildHistoryDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      width: 360,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _slate200))),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, color: _indigo600, size: 20),
                  const SizedBox(width: 8),
                  const Text('Recent GDMs', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _slate900)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: _slate500),
                    onPressed: () => _scaffoldKey.currentState?.closeEndDrawer(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Search GDM No / Vehicle...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      ),
                      onChanged: (v) => _historyQuery = v,
                      onSubmitted: (_) => _fetchRecentGdms(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _fetchRecentGdms,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _indigo50,
                      foregroundColor: _indigo700,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    child: const Text('Find', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _slate200),
            Expanded(
              child: _isLoadingHistory
                  ? const Center(child: CircularProgressIndicator())
                  : _recentGdms.isEmpty
                      ? const Center(child: Text('No recent GDMs found.', style: TextStyle(color: _slate500, fontSize: 13)))
                      : ListView.builder(
                          itemCount: _recentGdms.length,
                          itemBuilder: (context, index) {
                            final g = Map<String, dynamic>.from(_recentGdms[index] as Map);
                            final gdmNo = g['gdmNumber']?.toString() ?? '';
                            final vehNo = g['vehicle']?['vehicleNumber']?.toString() ?? 'No Vehicle';
                            final gcsCount = (g['gcs'] as List?)?.length ?? 0;
                            final dateStr = g['date']?.toString().split('T').first ?? '';
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _slate50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _slate200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(gdmNo, style: const TextStyle(fontWeight: FontWeight.w800, color: _indigo700, fontSize: 13)),
                                      Text(dateStr, style: const TextStyle(fontSize: 11, color: _slate500)),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text('$vehNo  •  $gcsCount GCs  •  ${g['toName'] ?? ''}',
                                      style: const TextStyle(fontSize: 11.5, color: _slate700),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.print_outlined, size: 14, color: _slate700),
                                        label: const Text('Print', style: TextStyle(fontSize: 11.5, color: _slate700)),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () async {
                                          try {
                                            final full = await ApiService.getGdmDetails(gdmNo);
                                            await _printGdmPdf(full, format: 'gdm');
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(this.context).showSnackBar(
                                                SnackBar(content: Text('Print failed: ${_cleanError(e)}'), backgroundColor: Colors.red),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                      TextButton.icon(
                                        icon: const Icon(Icons.edit_outlined, size: 14, color: _indigo600),
                                        label: const Text('Edit', style: TextStyle(fontSize: 11.5, color: _indigo600, fontWeight: FontWeight.w700)),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () => _loadGdmForEdit(gdmNo),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEwbBadge(String status) {
    switch (status) {
      case 'VALID':
        return _miniPill('EWB OK', _emerald50, _emerald700);
      case 'EXPIRING':
        return _miniPill('EXPIRING', const Color(0xFFFFFBEB), const Color(0xFFB45309));
      case 'EXPIRED':
        return _miniPill('EXPIRED', const Color(0xFFFFF1F2), const Color(0xFFBE123C));
      default:
        return _miniPill('NO EWB', _slate100, _slate500);
    }
  }

  Widget _miniPill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
      child: Text(text, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: fg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMasters) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: _indigo600)));
    }

    final pkg = _calculatePackageBreakdown();
    final totalFreight = _calculateTotalFreight();
    final expiredCount = _linkedGcs.where((r) => r.ewbStatus == 'EXPIRED').length;
    final expiringCount = _linkedGcs.where((r) => r.ewbStatus == 'EXPIRING').length;
    final dateStr = '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}';
    final timeStr = '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _slate50,
      endDrawer: _buildHistoryDrawer(),
      body: Column(
        children: [
          // 1. Slim Sticky Top Header Ribbon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(bottom: BorderSide(color: _slate200)),
              boxShadow: [
                BoxShadow(color: _slate900.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width > 40 ? MediaQuery.of(context).size.width - 40 : 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          _activeGdmId != null ? 'Edit GDM' : 'New GDM',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.4, color: _indigo600),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: _slate100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _slate200),
                          ),
                          child: Row(
                            children: [
                              _buildCompanyToggleItem('AP', 'A', _indigo700),
                              const SizedBox(width: 3),
                              _buildCompanyToggleItem('BELL', 'B', _emerald700),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _gdmCompanyMode == 'A' ? _indigo50 : _emerald50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _gdmCompanyMode == 'A' ? _indigo100 : const Color(0xFFA7F3D0)),
                          ),
                          child: Text(
                            _gdmNumber.isEmpty ? '...' : _gdmNumber,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: _gdmCompanyMode == 'A' ? _indigo700 : _emerald700,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        if (_gdmNumber == 'ERROR') ...[
                          const SizedBox(width: 6),
                          TextButton.icon(
                            onPressed: _fetchNextGdmNumber,
                            icon: const Icon(Icons.refresh_rounded, size: 14),
                            label: const Text('Retry', style: TextStyle(fontSize: 11.5)),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        if (_activeGdmId != null) ...[
                          OutlinedButton.icon(
                            onPressed: _resetForm,
                            icon: const Icon(Icons.add_rounded, size: 15),
                            label: const Text('New Blank GDM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _slate700,
                              side: const BorderSide(color: _slate300),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        OutlinedButton.icon(
                          icon: const Icon(Icons.history_rounded, size: 16, color: _indigo600),
                          label: const Text('Recent GDMs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _slate900)),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: _slate300),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            _fetchRecentGdms();
                            _scaffoldKey.currentState?.openEndDrawer();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      inputDecorationTheme: InputDecorationTheme(
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _slate200)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _indigo600, width: 1.6)),
                        labelStyle: const TextStyle(fontSize: 12.5, color: _slate500),
                      ),
                    ),
                    child: Form(
                      key: _formKey,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 820;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Top Row: Lorry Details (left) + Delivery Memo (right)
                              if (isWide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 5, child: _buildLorryCard()),
                                    const SizedBox(width: 14),
                                    Expanded(flex: 6, child: _buildMemoCard(dateStr, timeStr)),
                                  ],
                                )
                              else ...[
                                _buildLorryCard(),
                                const SizedBox(height: 14),
                                _buildMemoCard(dateStr, timeStr),
                              ],
                              const SizedBox(height: 14),

                              // Full-Width Despatch List Card
                              _buildDespatchListCard(pkg, totalFreight, expiredCount, expiringCount),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLorryCard() {
    final hasDl = _dlData != null;
    final hasHeavy = hasDl ? _hasHeavyTransportClass(_dlData!) : true;
    final trExpired = hasDl ? _isTrExpired(_dlData!) : false;
    final dlHealthy = hasDl && hasHeavy && !trExpired;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Lorry & Driver Details', Icons.local_shipping_outlined, _indigo600),
          // Searchable Vehicle Autocomplete (↑↓ + Enter)
          KeyedSubtree(
            key: ValueKey('veh_auto_$_vehicleAutoEpoch'),
            child: Autocomplete<Vehicle>(
              displayStringForOption: (v) => v.vehicleNumber,
              initialValue: _selectedVehicle != null
                  ? TextEditingValue(text: _selectedVehicle!.vehicleNumber)
                  : TextEditingValue.empty,
              optionsBuilder: (textEditingValue) {
                final q = textEditingValue.text.trim().toLowerCase();
                if (q.isEmpty) return _vehicles.take(25);
                return _vehicles.where((v) =>
                    v.vehicleNumber.toLowerCase().contains(q) ||
                    (v.ownerName?.toLowerCase().contains(q) ?? false));
              },
              onSelected: (v) {
                setState(() {
                  _selectedVehicle = v;
                  _driverNameController.text = v.ownerName ?? '';
                  _driverPhoneController.text = v.ownerPhone ?? '';
                });
                _gcScanFocusNode.requestFocus();
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => onFieldSubmitted(),
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Number *',
                    hintText: 'Type vehicle no (↑↓ + Enter)...',
                    prefixIcon: Icon(Icons.directions_bus_outlined, size: 17),
                  ),
                  onChanged: (val) {
                    if (_selectedVehicle != null && val != _selectedVehicle!.vehicleNumber) {
                      setState(() => _selectedVehicle = null);
                    }
                  },
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                final highlightedIndex = AutocompleteHighlightedOption.of(context);
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (ctx, index) {
                          final v = options.elementAt(index);
                          final isHi = index == highlightedIndex;
                          if (isHi) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (ctx.mounted) Scrollable.ensureVisible(ctx, alignment: 0.5);
                            });
                          }
                          return InkWell(
                            onTap: () => onSelected(v),
                            child: Container(
                              color: isHi ? _indigo50 : Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    v.vehicleNumber,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isHi ? FontWeight.w800 : FontWeight.w700,
                                      color: isHi ? _indigo700 : _slate900,
                                    ),
                                  ),
                                  if ((v.ownerName?.isNotEmpty ?? false) || (v.type?.isNotEmpty ?? false))
                                    Text(
                                      [if (v.type?.isNotEmpty ?? false) v.type!, if (v.ownerName?.isNotEmpty ?? false) v.ownerName!].join(' • '),
                                      style: const TextStyle(fontSize: 11, color: _slate500),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _driverNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Driver Name'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _driverPhoneController,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Driver Phone'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 105,
                child: TextFormField(
                  controller: _startKmController,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Start KM'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // VAHAN DL Verification Strip
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _slate50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VAHAN DL VERIFICATION (OPTIONAL)',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _slate500, letterSpacing: 0.4),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _licenseController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'DL Number', hintText: 'TN67...'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _dobController,
                        readOnly: true,
                        onTap: _pickDob,
                        decoration: const InputDecoration(
                          labelText: 'DOB',
                          hintText: 'YYYY-MM-DD',
                          suffixIcon: Icon(Icons.calendar_today_rounded, size: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isFetchingDl ? null : _verifyDL,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _indigo600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isFetchingDl
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Verify', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                if (hasDl) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: dlHealthy ? _emerald50 : const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: dlHealthy ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              dlHealthy ? Icons.verified_rounded : Icons.warning_amber_rounded,
                              size: 14,
                              color: dlHealthy ? _emerald700 : const Color(0xFFBE123C),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                dlHealthy
                                    ? 'Transport Eligible • ${_dlData!['owner_name'] ?? 'Verified'}'
                                    : trExpired
                                        ? 'TR Validity Expired • ${_dlData!['owner_name'] ?? ''}'
                                        : 'Missing Heavy/Transport Class • ${_dlData!['owner_name'] ?? ''}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: dlHealthy ? _emerald700 : const Color(0xFFBE123C),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'TR Valid Upto: ${_dlData!['validity_tr'] ?? 'N/A'}  •  Classes: ${_dlData!['vehicle_classes'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 11,
                            color: trExpired ? const Color(0xFFBE123C) : _slate700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoCard(String dateStr, String timeStr) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Delivery Memo Details',
            Icons.description_outlined,
            _emerald600,
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Multiple Consignee', label: Text('Multi', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: 'Single Consignee', label: Text('Single', style: TextStyle(fontSize: 11))),
              ],
              selected: {_consigneeMode},
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
              ),
              onSelectionChanged: (set) {
                setState(() {
                  _consigneeMode = set.first;
                  if (_consigneeMode == 'Multiple Consignee') {
                    _selectedConsignee = null;
                    _consigneeAutoEpoch++;
                    _toNameController.text = 'AS PER BILLS';
                  }
                });
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date *',
                      suffixIcon: Icon(Icons.calendar_today_rounded, size: 14),
                    ),
                    child: Text(dateStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: _pickTime,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Time *',
                      suffixIcon: Icon(Icons.access_time_rounded, size: 14),
                    ),
                    child: Text(timeStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _fromLocationController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'From Station *'),
                ),
              ),
            ],
          ),
          if (_consigneeMode == 'Single Consignee') ...[
            const SizedBox(height: 10),
            KeyedSubtree(
              key: ValueKey('gdm_cnee_auto_$_consigneeAutoEpoch'),
              child: Autocomplete<Consignee>(
                displayStringForOption: (c) => c.name,
                initialValue: _selectedConsignee != null
                    ? TextEditingValue(text: _selectedConsignee!.name)
                    : TextEditingValue.empty,
                optionsBuilder: (val) {
                  final q = val.text.trim().toLowerCase();
                  if (q.isEmpty) return const Iterable<Consignee>.empty();
                  return _consignees.where((c) =>
                      c.name.toLowerCase().contains(q) ||
                      (c.gstin?.toLowerCase().contains(q) ?? false));
                },
                onSelected: (c) {
                  setState(() {
                    _selectedConsignee = c;
                    _toNameController.text = c.name;
                    if (c.city != null && c.city!.isNotEmpty) {
                      _deliveryAtController.text = c.city!;
                    }
                  });
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => onFieldSubmitted(),
                    decoration: const InputDecoration(
                      labelText: 'Select Single Consignee *',
                      hintText: 'Type consignee name or GSTIN (↑↓ + Enter)...',
                      prefixIcon: Icon(Icons.search_rounded, size: 17),
                    ),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  final hi = AutocompleteHighlightedOption.of(context);
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220, maxWidth: 400),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (ctx, index) {
                            final c = options.elementAt(index);
                            final isHi = index == hi;
                            if (isHi) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (ctx.mounted) Scrollable.ensureVisible(ctx, alignment: 0.5);
                              });
                            }
                            return InkWell(
                              onTap: () => onSelected(c),
                              child: Container(
                                color: isHi ? _emerald50 : Colors.transparent,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Text(
                                  '${c.name}${c.city != null && c.city!.isNotEmpty ? ' • ${c.city}' : ''}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isHi ? FontWeight.w800 : FontWeight.w600,
                                    color: isHi ? _emerald700 : _slate900,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _toNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'To Name / Destination'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _deliveryAtController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Delivery At (City / Hub)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _cewbNumberController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Consolidated E-Way Bill (CEWB) No. (Optional)',
              prefixIcon: Icon(Icons.assignment_outlined, size: 17),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDespatchListCard(Map<String, int> pkg, double totalFreight, int expiredCount, int expiringCount) {
    final prefix = _gdmCompanyMode == 'A' ? 'AP-' : 'BELL-';
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.list_alt_rounded, size: 18, color: _indigo600),
                  const SizedBox(width: 8),
                  Text(
                    'Despatch List (${_linkedGcs.length} GCs)',
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _slate900),
                  ),
                ],
              ),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _freightMode,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Freight Mode'),
                      items: const [
                        DropdownMenuItem(value: 'Use Individual GC Freight', child: Text('Individual GC Freight', style: TextStyle(fontSize: 12.5))),
                        DropdownMenuItem(value: 'Set Overall Rate', child: Text('Set Overall Rate', style: TextStyle(fontSize: 12.5))),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _freightMode = v);
                      },
                    ),
                  ),
                  if (_freightMode == 'Set Overall Rate')
                    SizedBox(
                      width: 130,
                      child: TextFormField(
                        controller: _overallRateController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Overall ₹'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // GC Scan / Add Input Bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: _gdmCompanyMode == 'A' ? _indigo50 : _emerald50,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                  border: Border.all(color: _gdmCompanyMode == 'A' ? _indigo100 : const Color(0xFFA7F3D0)),
                ),
                child: Text(
                  prefix,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: _gdmCompanyMode == 'A' ? _indigo700 : _emerald700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _searchGcController,
                  focusNode: _gcScanFocusNode,
                  decoration: const InputDecoration(
                    hintText: 'Scan or type GC Number (press Enter to link)...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(8))),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
                      borderSide: BorderSide(color: _slate200),
                    ),
                  ),
                  onSubmitted: (_) => _addGc(),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _isAddingGc
                    ? null
                    : () async {
                        final scanned = await BarcodeScannerModal.show(
                          context,
                          title: 'Scan GC Barcode / QR',
                          subtitle: 'Scan a GC receipt to add to this GDM',
                        );
                        if (scanned != null && scanned.isNotEmpty) {
                          _addGc(scanned);
                        }
                      },
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 17, color: _indigo600),
                label: const Text('Scan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _slate900)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  side: const BorderSide(color: _slate300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isAddingGc ? null : () => _addGc(),
                icon: _isAddingGc
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add_link_rounded, size: 17),
                label: const Text('Link GC', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _indigo600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          if (expiredCount > 0 || expiringCount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: expiredCount > 0 ? const Color(0xFFFFF1F2) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: expiredCount > 0 ? const Color(0xFFFECDD3) : const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: expiredCount > 0 ? const Color(0xFFBE123C) : const Color(0xFFB45309),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'E-Way Bill Alert: $expiredCount expired, $expiringCount expiring within 12h.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: expiredCount > 0 ? const Color(0xFFBE123C) : const Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Full-Width Horizontal-Scrollable Table
          if (_linkedGcs.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _slate50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _slate200),
              ),
              child: const Text(
                'No GCs linked yet. Type or scan a GC number above to build the manifest.',
                style: TextStyle(fontSize: 13, color: _slate500, fontWeight: FontWeight.w500),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 980),
                child: DataTable(
                  headingRowColor: const WidgetStatePropertyAll(_slate100),
                  headingRowHeight: 38,
                  dataRowMinHeight: 46,
                  dataRowMaxHeight: 62,
                  columnSpacing: 18,
                  columns: const [
                    DataColumn(label: Text('GC NO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _slate700))),
                    DataColumn(label: Text('CONSIGNOR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _slate700))),
                    DataColumn(label: Text('CONSIGNEE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _slate700))),
                    DataColumn(label: Text('PKGS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _slate700))),
                    DataColumn(label: Text('EWB STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _slate700))),
                    DataColumn(label: Text('FREIGHT (₹)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _slate700))),
                    DataColumn(label: Text('', style: TextStyle(fontSize: 11))),
                  ],
                  rows: _linkedGcs.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final row = entry.value;
                    final gc = row.gc;
                    final qty = gc.goods.fold<int>(0, (s, item) => s + (item.articleCount ?? 0));
                    return DataRow(
                      cells: [
                        DataCell(Text(gc.gcNumber, style: const TextStyle(fontWeight: FontWeight.w800, color: _indigo700, fontSize: 12.5))),
                        DataCell(Text(gc.consignorName, style: const TextStyle(fontSize: 12.5))),
                        DataCell(Text(gc.consigneeName, style: const TextStyle(fontSize: 12.5))),
                        DataCell(Text('$qty', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildEwbBadge(row.ewbStatus),
                                  if ((row.ewbValidUpto ?? '').trim().isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      row.ewbValidUpto!.trim(),
                                      style: const TextStyle(fontSize: 10, color: _slate500, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ],
                              ),
                              if ((gc.ewbNumber ?? '').trim().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  gc.ewbNumber!
                                      .replaceAll(RegExp(r'\s+'), '')
                                      .replaceAllMapped(RegExp(r'^(\d{4})(\d{4})(\d{4})$'), (m) => '${m[1]} ${m[2]} ${m[3]}'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                    color: _slate700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        DataCell(Text('₹${gc.freightTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFE11D48)),
                            tooltip: 'Remove GC',
                            onPressed: () => _removeGc(idx),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: _slate200),
          const SizedBox(height: 12),

          // Totals Breakdown + Action Buttons (Responsive Wrap)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTotalBadge('TOTAL PKGS', '${pkg['total']}', _indigo600),
                  _buildTotalBadge('C/S', '${pkg['cases']}', _emerald600),
                  _buildTotalBadge('C/N', '${pkg['cartons']}', const Color(0xFF0284C7)),
                  _buildTotalBadge('BD/S', '${pkg['bundles']}', const Color(0xFFD97706)),
                  if ((pkg['others'] ?? 0) > 0) _buildTotalBadge('OTH', '${pkg['others']}', _slate700),
                  _buildTotalBadge('FREIGHT', '₹${totalFreight.toStringAsFixed(0)}', const Color(0xFF047857)),
                ],
              ),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => _saveGDM('Draft'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _slate700,
                      side: const BorderSide(color: _slate300),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Save Draft', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : () => _saveGDM('Dispatched'),
                    icon: _isSubmitting
                        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline_rounded, size: 17),
                    label: Text(
                      _activeGdmId != null ? 'Update GDM' : 'Submit Final GDM',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _indigo600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: _slate500)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}
