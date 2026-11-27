import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/consignor.dart';
import '../models/consignee.dart';
import '../services/api_service.dart';
import '../widgets/barcode_scanner_modal.dart';
import '../models/gc.dart';
import '../models/unit_model.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import '../services/pdf_service.dart';

class GcEntryItemRow {
  TextEditingController articlesController = TextEditingController();
  String unitCategory = 'Cases';
  String units = 'Cases of Fireworks';
  TextEditingController hsnController = TextEditingController(text: '3604');
  TextEditingController godownController = TextEditingController();
  TextEditingController descriptionController = TextEditingController(text: 'Fireworks');

  void dispose() {
    articlesController.dispose();
    hsnController.dispose();
    godownController.dispose();
    descriptionController.dispose();
  }
}

const Color kSlate50 = Color(0xFFF8FAFC);
const Color kSlate100 = Color(0xFFF1F5F9);
const Color kSlate200 = Color(0xFFE2E8F0);
const Color kSlate300 = Color(0xFFCBD5E1);
const Color kSlate400 = Color(0xFF94A3B8);
const Color kSlate500 = Color(0xFF64748B);
const Color kSlate600 = Color(0xFF475569);
const Color kSlate700 = Color(0xFF334155);
const Color kSlate800 = Color(0xFF1E293B);

const Color kIndigo50 = Color(0xFFEEF2FF);
const Color kIndigo100 = Color(0xFFE0E7FF);
const Color kIndigo600 = Color(0xFF4F46E5);
const Color kIndigo700 = Color(0xFF4338CA);

const Color kEmerald50 = Color(0xFFECFDF5);
const Color kEmerald100 = Color(0xFFD1FAE5);
const Color kEmerald200 = Color(0xFFA7F3D0);
const Color kEmerald600 = Color(0xFF059669);
const Color kEmerald700 = Color(0xFF047857);

const Color kAmber50 = Color(0xFFFFFBEB);
const Color kAmber100 = Color(0xFFFEF3C7);
const Color kAmber500 = Color(0xFFF59E0B);
const Color kAmber600 = Color(0xFFD97706);

const Color kViolet50 = Color(0xFFF5F3FF);
const Color kViolet500 = Color(0xFF8B5CF6);
const Color kViolet600 = Color(0xFF7C3AED);

const Color kRose50 = Color(0xFFFFF1F2);
const Color kRose100 = Color(0xFFFFE4E6);
const Color kRose600 = Color(0xFFE11D48);

class GcEntryScreen extends StatefulWidget {
  final Map<String, dynamic>? initialGc;
  const GcEntryScreen({super.key, this.initialGc});

  @override
  State<GcEntryScreen> createState() => _GcEntryScreenState();
}

class _GcEntryScreenState extends State<GcEntryScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final _formKey = GlobalKey<FormState>();
  
  // Drawer State
  String _searchEditGc = '';
  List<dynamic> _recentGcs = [];
  bool _isLoadingHistory = false;
  bool _showSenderPhone = false;
  bool _showReceiverPhone = false;

  // Core GC Details
  String _financialYear = '2026-2027';
  String _companyMode = 'A'; // AP by default
  String _gcNumber = 'Loading...';
  String _type = 'Regular';
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  String _status = 'Created';
  String? _linkedGdmNumber;
  Map<String, dynamic>? _fetchedEwbDetails;

  // Party & Invoice
  Consignor? _selectedConsignor;
  final TextEditingController _senderPhoneController = TextEditingController();
  Consignee? _selectedConsignee;
  final TextEditingController _receiverPhoneController = TextEditingController();
  DateTime _invoiceDate = DateTime.now();
  final TextEditingController _invoiceNumberController = TextEditingController();
  final TextEditingController _privateMarkController = TextEditingController();
  final TextEditingController _invoiceValueController = TextEditingController();
  final TextEditingController _ewbNumberController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  // Goods Details: 2-Tier Unit Hierarchy
  final List<GcEntryItemRow> _itemRows = [GcEntryItemRow()];
  Map<String, List<UnitModel>> _unitHierarchy = {
    'Cases': [
      UnitModel(id: 1, category: 'Cases', description: 'Cases of Fireworks', code: 'C/S', color: 'emerald', hsn: '3604', goodsDesc: 'Fireworks'),
      UnitModel(id: 2, category: 'Cases', description: 'Cases of Matches', code: 'C/S', color: 'emerald', hsn: '3605', goodsDesc: 'Safety Matches'),
    ],
    'Boxes': [
      UnitModel(id: 3, category: 'Boxes', description: 'Boxes of Fireworks', code: 'BOX', color: 'blue', hsn: '3604', goodsDesc: 'Fireworks'),
      UnitModel(id: 4, category: 'Boxes', description: 'Boxes of Matches', code: 'BOX', color: 'blue', hsn: '3605', goodsDesc: 'Safety Matches'),
      UnitModel(id: 5, category: 'Boxes', description: 'Boxes of Printing Materials', code: 'BOX', color: 'blue', hsn: '4911', goodsDesc: 'Printed Materials'),
    ],
    'Bundles': [
      UnitModel(id: 6, category: 'Bundles', description: 'Bundles of Printed Sheets', code: 'BDL', color: 'amber', hsn: '4911', goodsDesc: 'Paper / Printed Materials'),
      UnitModel(id: 7, category: 'Bundles', description: 'Bundles of Cartons', code: 'BDL', color: 'amber', hsn: '4819', goodsDesc: 'Empty Cartons'),
    ],
    'Bags': [
      UnitModel(id: 8, category: 'Bags', description: 'Bags of Chemicals', code: 'BAG', color: 'rose', hsn: '2800', goodsDesc: 'Industrial Chemicals'),
    ],
    'Cartons': [
      UnitModel(id: 9, category: 'Cartons', description: 'Cartons of Goods', code: 'CTN', color: 'slate', hsn: '3604', goodsDesc: 'General Merchandise'),
    ],
    'Drums': [
      UnitModel(id: 10, category: 'Drums', description: 'Drums of Raw Materials', code: 'DRM', color: 'indigo', hsn: '2800', goodsDesc: 'Liquid Chemicals'),
    ],
    'Other': [
      UnitModel(id: 11, category: 'Other', description: 'Loose / Misc Items', code: 'OTH', color: 'slate', hsn: '9999', goodsDesc: 'Sundry Goods'),
    ],
  };

  // Freight Details
  String _freightFixed = 'Yes';
  String _freightType = 'To Pay';
  final TextEditingController _freightController = TextEditingController();
  final TextEditingController _advancePaidController = TextEditingController();

  List<Consignor> _consignors = [];
  List<Consignee> _consignees = [];

  bool _isLoadingMasters = true;
  bool _isSubmitting = false;
  bool _isReassigning = false;
  int? _editingGcId;
  int _partyAutocompleteEpoch = 0;
  String _draftStatus = '';
  Timer? _autoSaveTimer;

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  void initState() {
    super.initState();
    _fetchMasterData();
    if (widget.initialGc != null) {
      _loadInitialGc(widget.initialGc!);
    } else {
      _loadDraft().then((_) => _fetchNextGcNumber());
      _autoSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveDraft());
    }
  }

  void _loadInitialGc(Map<String, dynamic> gc) {
    setState(() {
      _editingGcId = gc['id'] is int ? gc['id'] : int.tryParse(gc['id']?.toString() ?? '');
      _financialYear = gc['financialYear'] ?? '2026-2027';
      final rawGcNo = (gc['gcNumber'] ?? '').toString();
      if (rawGcNo.startsWith('BELL-')) {
        _companyMode = 'B';
        _gcNumber = rawGcNo.substring(5);
      } else if (rawGcNo.startsWith('AP-')) {
        _companyMode = 'A';
        _gcNumber = rawGcNo.substring(3);
      } else {
        _gcNumber = rawGcNo;
      }
      _type = gc['type'] ?? 'Regular';
      if (gc['date'] != null) _date = DateTime.tryParse(gc['date']) ?? DateTime.now();
      if (gc['time'] != null) {
        final parts = gc['time'].toString().split(':');
        if (parts.length == 2) _time = TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
      }
      _status = gc['status'] ?? 'Created';
      _ewbNumberController.text = gc['ewbNumber'] ?? '';
      
      if (gc['consignorId'] != null) {
        final cnorName = gc['consignor']?['name'] ?? gc['consignorName'] ?? '';
        _selectedConsignor = _consignors.cast<Consignor?>().firstWhere(
              (c) => c?.id == gc['consignorId'],
              orElse: () => Consignor(
                id: gc['consignorId'],
                name: cnorName.toString(),
                address: gc['consignor']?['address']?.toString(),
                gstin: gc['consignor']?['gstin']?.toString(),
                phone: gc['consignor']?['phone']?.toString(),
              ),
            );
      }
      _senderPhoneController.text = gc['senderContactPhone'] ?? '';
      _showSenderPhone = _senderPhoneController.text.trim().isNotEmpty;
      
      if (gc['consigneeId'] != null) {
        final cneeName = gc['consignee']?['name'] ?? gc['consigneeName'] ?? '';
        _selectedConsignee = _consignees.cast<Consignee?>().firstWhere(
              (c) => c?.id == gc['consigneeId'],
              orElse: () => Consignee(
                id: gc['consigneeId'],
                name: cneeName.toString(),
                address: gc['consignee']?['address']?.toString(),
                gstin: gc['consignee']?['gstin']?.toString(),
                phone: gc['consignee']?['phone']?.toString(),
              ),
            );
      }
      _receiverPhoneController.text = gc['receiverContactPhone'] ?? '';
      _showReceiverPhone = _receiverPhoneController.text.trim().isNotEmpty;
      _partyAutocompleteEpoch++;

      if (gc['invoiceDate'] != null) _invoiceDate = DateTime.tryParse(gc['invoiceDate']) ?? DateTime.now();
      _invoiceNumberController.text = gc['invoiceNumber'] ?? '';
      _privateMarkController.text = gc['privateMark'] ?? '';
      _invoiceValueController.text = gc['invoiceValue']?.toString() ?? '';

      _freightFixed = gc['freightFixed'] ?? 'Yes';
      _freightType = gc['freightType'] ?? 'To Pay';
      _freightController.text = (_freightFixed == 'No' ? gc['freightRate'] : gc['freightTotal'])?.toString() ?? gc['freightTotal']?.toString() ?? '';
      _advancePaidController.text = gc['advancePaid']?.toString() ?? '';
      _remarksController.text = gc['freightNote']?.toString() ?? '';
      
      _linkedGdmNumber = gc['gdm']?['gdmNumber'] ?? gc['gdmNumber'];

      // Goods
      final goods = gc['goods'] as List<dynamic>?;
      if (goods != null && goods.isNotEmpty) {
        for (final r in _itemRows) {
          r.dispose();
        }
        _itemRows.clear();
        for (var item in goods) {
          final row = GcEntryItemRow();
          row.articlesController.text = item['articles']?.toString() ?? item['articleCount']?.toString() ?? '';
          final rawUnit = item['units']?.toString() ?? 'Cases of Fireworks';
          String cat = item['unitCategory']?.toString() ?? 'Cases';
          if (item['unitCategory'] == null) {
            for (var entry in _unitHierarchy.entries) {
              if (entry.value.any((u) => u.description.toLowerCase() == rawUnit.toLowerCase())) {
                cat = entry.key;
                break;
              }
            }
          }
          row.unitCategory = cat;
          row.units = rawUnit;
          row.hsnController.text = item['hsn'] ?? '';
          row.godownController.text = item['godown'] ?? '';
          row.descriptionController.text = item['description'] ?? '';
          _itemRows.add(row);
        }
      }
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _invoiceNumberController.dispose();
    _privateMarkController.dispose();
    _invoiceValueController.dispose();
    _freightController.dispose();
    _advancePaidController.dispose();
    _senderPhoneController.dispose();
    _receiverPhoneController.dispose();
    _ewbNumberController.dispose();
    _remarksController.dispose();
    for (var row in _itemRows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _saveDraft() async {
    if (widget.initialGc != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = {
        'companyMode': _companyMode,
        'type': _type,
        'ewbNumber': _ewbNumberController.text,
        'invoiceNumber': _invoiceNumberController.text,
        'privateMark': _privateMarkController.text,
        'invoiceValue': _invoiceValueController.text,
        'advancePaid': _advancePaidController.text,
        'senderPhone': _senderPhoneController.text,
        'receiverPhone': _receiverPhoneController.text,
        'freightType': _freightType,
        'freightFixed': _freightFixed,
        'consignorId': _selectedConsignor?.id,
        'consigneeId': _selectedConsignee?.id,
        'goods': _itemRows.map((r) => {
          'articles': r.articlesController.text,
          'unitCategory': r.unitCategory,
          'units': r.units,
          'hsn': r.hsnController.text,
          'description': r.descriptionController.text,
        }).toList(),
      };
      await prefs.setString('gcDraft', jsonEncode(draft));
      if (mounted) {
        setState(() {
          _draftStatus = 'Draft saved ${TimeOfDay.now().format(context)}';
        });
      }
    } catch (e) {
      print('Draft save error: $e');
    }
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftStr = prefs.getString('gcDraft');
      if (draftStr != null) {
        final draft = jsonDecode(draftStr);
        setState(() {
          _companyMode = draft['companyMode'] ?? 'A';
          _type = draft['type'] ?? 'Regular';
          _ewbNumberController.text = draft['ewbNumber'] ?? '';
          _invoiceNumberController.text = draft['invoiceNumber'] ?? '';
          _privateMarkController.text = draft['privateMark'] ?? '';
          _invoiceValueController.text = draft['invoiceValue'] ?? '';
          _advancePaidController.text = draft['advancePaid'] ?? '';
          _senderPhoneController.text = draft['senderPhone'] ?? '';
          _receiverPhoneController.text = draft['receiverPhone'] ?? '';
          _freightType = draft['freightType'] ?? 'To Pay';
          _freightFixed = draft['freightFixed'] ?? 'Yes';
          
          if (draft['goods'] != null && (draft['goods'] as List).isNotEmpty) {
            for (final r in _itemRows) {
              r.dispose();
            }
            _itemRows.clear();
            for (var g in (draft['goods'] as List)) {
              final row = GcEntryItemRow();
              row.articlesController.text = g['articles'] ?? '10';
              final rawUnit = g['units']?.toString() ?? 'Cases of Fireworks';
              String cat = g['unitCategory']?.toString() ?? 'Cases';
              if (g['unitCategory'] == null) {
                for (var entry in _unitHierarchy.entries) {
                  if (entry.value.any((u) => u.description.toLowerCase() == rawUnit.toLowerCase())) {
                    cat = entry.key;
                    break;
                  }
                }
              }
              row.unitCategory = cat;
              row.units = rawUnit;
              row.hsnController.text = g['hsn'] ?? '';
              row.descriptionController.text = g['description'] ?? '';
              _itemRows.add(row);
            }
          }
          _draftStatus = 'Draft restored';
        });
      }
    } catch (e) {
      print('Draft load error: $e');
    }
  }

  Future<void> _fetchNextGcNumber() async {
    try {
      final num = await ApiService.getNextGcNumber(mode: _companyMode);
      if (mounted) setState(() => _gcNumber = num);
    } catch (e) {
      if (mounted) {
        setState(() => _gcNumber = 'ERROR');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not fetch next GC number: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _fetchMasterData() async {
    try {
      final results = await Future.wait([
        ApiService.getConsignors(),
        ApiService.getConsignees(),
        ApiService.getUnits(),
      ]);

      if (mounted) {
        setState(() {
          _consignors = results[0] as List<Consignor>;
          _consignees = results[1] as List<Consignee>;
          final unitsList = results[2] as List<UnitModel>;
          if (unitsList.isNotEmpty) {
            final Map<String, List<UnitModel>> hierarchy = {};
            for (var u in unitsList) {
              hierarchy.putIfAbsent(u.category, () => []).add(u);
            }
            _unitHierarchy = hierarchy;
          }
          _isLoadingMasters = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMasters = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load masters: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  GcEntryItemRow _createDefaultRow() {
    final row = GcEntryItemRow();
    final defaultCategory = _unitHierarchy.containsKey('Cases')
        ? 'Cases'
        : (_unitHierarchy.keys.isNotEmpty ? _unitHierarchy.keys.first : 'Cases');
    final defaultUnits = _unitHierarchy[defaultCategory]?.isNotEmpty == true
        ? _unitHierarchy[defaultCategory]!.first
        : null;
    row.unitCategory = defaultCategory;
    row.units = defaultUnits?.description ?? 'Cases of Fireworks';
    row.hsnController.text = defaultUnits?.hsn ?? '3604';
    row.godownController.text = '';
    row.descriptionController.text = defaultUnits?.goodsDesc ?? 'Fireworks';
    return row;
  }

  void _addItemRow() {
    setState(() {
      final row = _createDefaultRow();
      row.articlesController.text = '';
      _itemRows.add(row);
    });
  }

  void _removeItemRow(int index) {
    if (_itemRows.length > 1) {
      setState(() {
        final removed = _itemRows.removeAt(index);
        removed.dispose();
      });
    }
  }

  int get _calculatedTotalArticles {
    int count = 0;
    for (var row in _itemRows) {
      count += int.tryParse(row.articlesController.text) ?? 0;
    }
    return count;
  }

  Future<void> _fetchEwbDetails() async {
    final ewb = _ewbNumberController.text.trim();
    if (ewb.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter E-Way Bill Number first')));
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fetching EWB $ewb...')));
      
      final data = await ApiService.fetchEWayBill(
        ewb,
        company: _companyMode == 'B' ? 'BELL' : 'AP',
      );
      
      setState(() {
        _fetchedEwbDetails = data;
      });

      final detectedCompany = data['detectedCompany'];
      if (detectedCompany != null && detectedCompany != _companyMode) {
        setState(() {
          _companyMode = detectedCompany;
        });
        await _fetchNextGcNumber();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Switched to ${detectedCompany == 'A' ? 'AP' : 'BELL'} based on E-Way Bill.')));
      }
      
      final fromGstin = data['fromGstin']?.toString().toUpperCase() ?? '';
      final fromName = data['fromTrdName']?.toString().toUpperCase() ?? '';
      
      final toGstin = data['toGstin']?.toString().toUpperCase() ?? '';
      final toName = data['toTrdName']?.toString().toUpperCase() ?? '';
      
      final normalizedFromName = fromName.replaceAll(RegExp(r'\s+'), ' ').trim();
      final normalizedToName = toName.replaceAll(RegExp(r'\s+'), ' ').trim();

      Consignor? matchedCnor;
      try {
        matchedCnor = _consignors.firstWhere((c) =>
          (fromGstin.isNotEmpty && c.gstin?.trim().toUpperCase() == fromGstin) ||
          (normalizedFromName.isNotEmpty && c.name.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase() == normalizedFromName)
        );
      } catch (_) {
        if (normalizedFromName.isNotEmpty) {
           try {
             // EWB_LITE auto-creation
             final newCnor = await ApiService.saveConsignor({
               'name': normalizedFromName,
               'gstin': fromGstin,
               'address': [data['fromAddr1'], data['fromAddr2']].where((e) => e != null && e.toString().isNotEmpty).join(', '),
               'city': data['fromPlace'] ?? data['fromAddr2'] ?? '',
               'state': data['fromStateCode']?.toString() ?? '',
               'pincode': data['fromPincode']?.toString() ?? '',
               'migrationType': 'EWB_LITE'
             });
             _consignors.add(newCnor);
             matchedCnor = newCnor;
           } catch (e) {
             print('Auto-create consignor failed: $e');
           }
        }
      }
      
      Consignee? matchedCnee;
      try {
        matchedCnee = _consignees.firstWhere((c) =>
          (toGstin.isNotEmpty && c.gstin?.trim().toUpperCase() == toGstin) ||
          (normalizedToName.isNotEmpty && c.name.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase() == normalizedToName)
        );
      } catch (_) {
        if (normalizedToName.isNotEmpty) {
           try {
             final newCnee = await ApiService.saveConsignee({
               'name': normalizedToName,
               'gstin': toGstin,
               'address': [data['toAddr1'], data['toAddr2']].where((e) => e != null && e.toString().isNotEmpty).join(', '),
               'city': data['toPlace'] ?? data['toAddr2'] ?? '',
               'state': data['toStateCode']?.toString() ?? '',
               'pincode': data['toPincode']?.toString() ?? '',
               'migrationType': 'EWB_LITE'
             });
             _consignees.add(newCnee);
             matchedCnee = newCnee;
           } catch (e) {
             print('Auto-create consignee failed: $e');
           }
        }
      }

      setState(() {
        _invoiceNumberController.text = data['docNo'] ?? '';
        _invoiceValueController.text = data['totInvValue']?.toString() ?? '';
        _privateMarkController.text = ewb; // Legacy: privateMark gets EWB

        // Parse date
        final rawDate = data['docDate'] ?? data['documentDate'];
        if (rawDate != null) {
          if (rawDate.contains('/')) {
            final parts = rawDate.split('/');
            if (parts.length == 3) {
              _invoiceDate = DateTime.tryParse('${parts[2]}-${parts[1]}-${parts[0]}') ?? _invoiceDate;
            }
          } else if (rawDate.contains('-') && rawDate.split('-')[0].length == 2) {
            final parts = rawDate.split('-');
            _invoiceDate = DateTime.tryParse('${parts[2]}-${parts[1]}-${parts[0]}') ?? _invoiceDate;
          }
        }
        
        _selectedConsignor = matchedCnor;
        _selectedConsignee = matchedCnee;
        _partyAutocompleteEpoch++;

        if (data['itemList'] != null && data['itemList'] is List && data['itemList'].isNotEmpty) {
          for (final r in _itemRows) {
            r.dispose();
          }
          _itemRows.clear();
          for (var item in data['itemList']) {
            final row = GcEntryItemRow();
            row.descriptionController.text = item['productName'] ?? '';
            row.hsnController.text = item['hsnCode']?.toString() ?? '';
            row.articlesController.text = item['quantity']?.toString() ?? '1';
            _itemRows.add(row);
          }
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('E-Way Bill Details applied!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to fetch EWB: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _handleReassignTransporter() async {
    if (_fetchedEwbDetails == null) return;
    
    final currentCompany = (_fetchedEwbDetails!['detectedCompany'] ?? _fetchedEwbDetails!['company'] ?? _companyMode).toString();
    final isCurrentBell = currentCompany == 'B' || currentCompany == 'BELL';
    final targetCompany = isCurrentBell ? 'A' : 'B';
    final targetCompanyStr = targetCompany == 'A' ? 'AP' : 'BELL';
    final currentCompanyStr = isCurrentBell ? 'BELL' : 'AP';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reassign Transporter'),
        content: Text('Are you sure you want to officially reassign this E-Way Bill from $currentCompanyStr to $targetCompanyStr?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            child: const Text('Yes, Reassign')
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => _isReassigning = true);
      await ApiService.reassignTransporter(
        _fetchedEwbDetails!['ewbNo'] ?? _ewbNumberController.text, 
        currentCompanyStr, 
        targetCompanyStr
      );
      
      setState(() {
        _fetchedEwbDetails!['detectedCompany'] = targetCompany;
        _companyMode = targetCompany;
      });
      await _fetchNextGcNumber();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully reassigned E-Way Bill to $targetCompanyStr!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to reassign: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isReassigning = false);
    }
  }

  double get _calculatedTotalFreight {
    double rate = double.tryParse(_freightController.text) ?? 0;
    if (_freightFixed == 'No') {
      return _calculatedTotalArticles * rate;
    }
    return rate;
  }

  double get _calculatedBalance {
    final adv = double.tryParse(_advancePaidController.text) ?? 0;
    return max(0, _calculatedTotalFreight - adv);
  }

  bool get _showRateBox => !(_freightFixed == 'Yes' && _freightType == 'To Pay');
  bool get _showTotalAdvBalBox => _freightFixed == 'No';

  String get _freightLabel => _freightFixed == 'Yes' ? 'Freight Amount' : 'Freight Rate';

  int get _tallyTotal => _itemRows.fold(0, (sum, row) => sum + (int.tryParse(row.articlesController.text) ?? 0));
  int get _tallyBoxes => _itemRows.where((r) {
    final cat = r.unitCategory.toLowerCase();
    return cat == 'cases' || cat == 'boxes' || cat == 'cartons';
  }).fold(0, (sum, row) => sum + (int.tryParse(row.articlesController.text) ?? 0));
  int get _tallyBundles => _itemRows.where((r) {
    final cat = r.unitCategory.toLowerCase();
    return cat == 'bundles';
  }).fold(0, (sum, row) => sum + (int.tryParse(row.articlesController.text) ?? 0));
  int get _tallyBags => _itemRows.where((r) {
    final cat = r.unitCategory.toLowerCase();
    return cat == 'bags';
  }).fold(0, (sum, row) => sum + (int.tryParse(row.articlesController.text) ?? 0));

  String get _freightNote {
    if (_freightFixed == 'Yes' && _freightType == 'To Pay') {
      return "To Pay + Fixed: no freight details needed in GC. Freight will be handled in Freight Entry.";
    } else if (_freightFixed == 'Yes' && _freightType == 'Paid') {
      return "Paid + Fixed: freight amount is optional in GC. If entered, Freight Entry will pull it.";
    } else {
      return "Freight Fixed No: enter freight rate. Total = Total Goods × Freight. Advance and balance are calculated.";
    }
  }

  Future<void> _loadRecentGcs() async {
    setState(() => _isLoadingHistory = true);
    try {
      final res = await ApiService.getGcsRaw(limit: 10);
      setState(() => _recentGcs = res);
    } catch (e) {
      print('Failed to load recent GCs: $e');
    } finally {
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _loadGcForEdit(String searchTerm) async {
    final rawInput = searchTerm.trim();
    if (rawInput.isEmpty) return;

    final isDigitsOnly = RegExp(r'^\d+$').hasMatch(rawInput);
    final primaryPrefix = _companyMode == 'A' ? 'AP' : 'BELL';
    final altPrefix = _companyMode == 'A' ? 'BELL' : 'AP';
    final primaryTerm = isDigitsOnly ? '$primaryPrefix-$rawInput' : rawInput;

    try {
      setState(() => _isLoadingHistory = true);
      Map<String, dynamic> gcRaw;
      try {
        gcRaw = await ApiService.fetchGcRaw(primaryTerm);
      } catch (_) {
        if (!isDigitsOnly) rethrow;
        gcRaw = await ApiService.fetchGcRaw('$altPrefix-$rawInput');
      }
      _loadInitialGc(gcRaw);
      _scaffoldKey.currentState?.closeEndDrawer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Loaded ${gcRaw['gcNumber']} for editing.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('GC Not Found: $primaryTerm'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _saveGC() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gcNumber.trim().isEmpty || _gcNumber == 'ERROR' || _gcNumber == '...') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GC Number is missing. Please retry fetching next GC number.'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_selectedConsignor == null || _selectedConsignee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Consignor and Consignee'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final goods = _itemRows.map((row) {
        return {
          'articles': int.tryParse(row.articlesController.text) ?? 1,
          'units': row.units,
          'hsn': row.hsnController.text,
          'godown': row.godownController.text,
          'description': row.descriptionController.text.isEmpty ? 'Fireworks Packages' : row.descriptionController.text,
        };
      }).toList();

      final int? editId = _editingGcId ?? (widget.initialGc?['id'] is int ? widget.initialGc!['id'] as int : int.tryParse(widget.initialGc?['id']?.toString() ?? ''));
      final String prefix = _companyMode == 'A' ? 'AP-' : 'BELL-';
      final String fullGc = (_gcNumber.startsWith('AP-') || _gcNumber.startsWith('BELL-') || _gcNumber.startsWith('RET-'))
          ? _gcNumber
          : '$prefix$_gcNumber';
      if (_fetchedEwbDetails != null) {
        final String? ewbStatus = _fetchedEwbDetails!['status'];
        if (ewbStatus == 'REJ') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CRITICAL: E-Way Bill is REJECTED by Consignee!'), backgroundColor: Colors.red));
          setState(() => _isSubmitting = false);
          return;
        }
        if (ewbStatus == 'CNL') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CRITICAL: E-Way Bill is CANCELLED!'), backgroundColor: Colors.red));
          setState(() => _isSubmitting = false);
          return;
        }
      }

      final payload = {
        'gcNumber': fullGc,
        'financialYear': _financialYear,
        'type': _type,
        'date': _date.toIso8601String(),
        'time': '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
        'consignorId': _selectedConsignor?.id,
        'senderContactPhone': _showSenderPhone ? _senderPhoneController.text.trim() : '',
        'consigneeId': _selectedConsignee?.id,
        'receiverContactPhone': _showReceiverPhone ? _receiverPhoneController.text.trim() : '',
        'invoiceDate': _invoiceDate.toIso8601String(),
        'invoiceNumber': _invoiceNumberController.text,
        'privateMark': _privateMarkController.text,
        'invoiceValue': double.tryParse(_invoiceValueController.text) ?? 0,
        'freightFixed': _freightFixed,
        'freightType': _freightType,
        'freightRate': double.tryParse(_freightController.text) ?? 0,
        'freightTotal': _calculatedTotalFreight,
        'advancePaid': double.tryParse(_advancePaidController.text) ?? 0,
        'balanceFreight': _calculatedBalance,
        'freightNote': _remarksController.text.trim(),
        'ewbNumber': _fetchedEwbDetails != null
            ? (_fetchedEwbDetails!['ewayBillNo'] ?? _fetchedEwbDetails!['ewbNo'])?.toString()
            : (_ewbNumberController.text.isNotEmpty ? _ewbNumberController.text : null),
        'ewbRawData': _fetchedEwbDetails?['rawData'],
        'godown': goods.isNotEmpty ? goods.first['godown'] : null,
        'branch': ApiService.activeBranch,
        'goods': goods,
      };

      final Gc savedGc;
      if (editId != null) {
        savedGc = await ApiService.updateGc(editId, payload);
      } else {
        savedGc = await ApiService.createGc(payload);
      }

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _editingGcId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(editId == null ? 'GC Saved Successfully!' : 'GC Updated Successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        if (widget.initialGc != null) {
          Navigator.pop(context, savedGc);
        } else {
          _showSuccessDialog(savedGc);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save GC: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSuccessDialog(createdGc) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
              SizedBox(width: 10),
              Text('GC Created', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text('GC Receipt Number: ${createdGc.gcNumber}\nConsignor: ${createdGc.consignorName}\nConsignee: ${createdGc.consigneeName}'),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.print_rounded, size: 16),
              label: const Text('Print GC'),
              onPressed: () async {
                final pdfBytes = await PdfService.generateGcPdf([createdGc], ['CONSIGNOR', 'CONSIGNEE', 'DRIVER']);
                await Printing.layoutPdf(onLayout: (_) async => pdfBytes, name: '${createdGc.gcNumber}.pdf');
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(context);
                _clearForm();
              },
              child: const Text('Create Next GC'),
            ),
          ],
        );
      },
    );
  }

  void _showPreviewDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text('GC Preview: $_gcNumber', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Financial Year: $_financialYear'),
                Text('Type: $_type'),
                Text('Date: ${_formatDate(_date)} ${_time.format(context)}'),
                const Divider(),
                Text('Consignor: ${_selectedConsignor?.name ?? 'N/A'}'),
                Text('Consignee: ${_selectedConsignee?.name ?? 'N/A'}'),
                const Divider(),
                Text('Total Articles: $_calculatedTotalArticles'),
                Text('Total Freight: ₹${_calculatedTotalFreight.toStringAsFixed(2)}'),
                Text('Advance Paid: ₹${double.tryParse(_advancePaidController.text)?.toStringAsFixed(2) ?? '0.00'}'),
                Text('Balance Freight: ₹${_calculatedBalance.toStringAsFixed(2)}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTallyItem(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Color(0xFF64748B)),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color, height: 1.15),
          ),
        ],
      ),
    );
  }

  Map<String, Color> _colorForUnit(String? colorName) {
    switch (colorName?.toLowerCase()) {
      case 'emerald':
      case 'green':
        return {'bg': const Color(0xFFD1FAE5), 'text': const Color(0xFF047857), 'border': const Color(0xFFA7F3D0)};
      case 'blue':
        return {'bg': const Color(0xFFDBEAFE), 'text': const Color(0xFF1D4ED8), 'border': const Color(0xFFBFDBFE)};
      case 'amber':
      case 'orange':
        return {'bg': const Color(0xFFFEF3C7), 'text': const Color(0xFFB45309), 'border': const Color(0xFFFDE68A)};
      case 'rose':
      case 'red':
        return {'bg': const Color(0xFFFFE4E6), 'text': const Color(0xFFBE123C), 'border': const Color(0xFFFECDD3)};
      case 'indigo':
      case 'purple':
        return {'bg': const Color(0xFFEEF2FF), 'text': const Color(0xFF4338CA), 'border': const Color(0xFFC7D2FE)};
      default:
        return {'bg': const Color(0xFFF1F5F9), 'text': const Color(0xFF334155), 'border': const Color(0xFFCBD5E1)};
    }
  }

  Widget? _buildUnitBadge(String unitValue) {
    UnitModel? match;
    for (var list in _unitHierarchy.values) {
      for (var u in list) {
        if (u.description.toLowerCase() == unitValue.toLowerCase()) {
          match = u;
          break;
        }
      }
      if (match != null) break;
    }
    if (match == null || match.code.isEmpty) return null;
    final colors = _colorForUnit(match.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: colors['bg'],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors['border']!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 10, color: colors['text']),
          const SizedBox(width: 2),
          Text(
            match.code,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: colors['text'],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearForm() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gcDraft');
    if (!mounted) return;
    _formKey.currentState?.reset();
    _invoiceNumberController.clear();
    _privateMarkController.clear();
    _invoiceValueController.clear();
    _freightController.clear();
    _advancePaidController.clear();
    _senderPhoneController.clear();
    _receiverPhoneController.clear();
    _ewbNumberController.clear();
    _remarksController.clear();
    setState(() {
      _editingGcId = null;
      _selectedConsignor = null;
      _selectedConsignee = null;
      _fetchedEwbDetails = null;
      _linkedGdmNumber = null;
      _showSenderPhone = false;
      _showReceiverPhone = false;
      _date = DateTime.now();
      _time = TimeOfDay.now();
      _invoiceDate = DateTime.now();
      _partyAutocompleteEpoch++;
      for (var row in _itemRows) {
        row.dispose();
      }
      _itemRows.clear();
      _itemRows.add(_createDefaultRow());
    });
    _fetchNextGcNumber();
  }

  Widget _buildEwbBadge(String? status) {
    if (status == 'ACT') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.green.shade300)),
        child: Text('✅ ACTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
      );
    } else if (status == 'CNL') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.shade300)),
        child: Text('🚨 CANCELLED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
      );
    } else if (status == 'REJ') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.shade800)),
        child: const Text('🚨 REJECTED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
      );
    } else if (status == 'DIS') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.orange.shade300)),
        child: Text('⚠️ EXPIRED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
      );
    }
    return const SizedBox();
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, {Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.only(bottom: 8.0),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: Color(0xFF0F172A),
                ),
              ),
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
      surfaceTintColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: kSlate200)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: kIndigo600, size: 20),
                  const SizedBox(width: 8),
                  const Text('Manage GCs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kSlate800)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: kSlate500),
                    onPressed: () => _scaffoldKey.currentState?.closeEndDrawer(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        labelText: 'Search GC No...',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => _searchEditGc = val,
                      onSubmitted: (val) => _loadGcForEdit(val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _loadGcForEdit(_searchEditGc),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kIndigo50,
                      foregroundColor: kIndigo700,
                      elevation: 0,
                    ),
                    child: const Text('Edit'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: kSlate200),
            if (_isLoadingHistory)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Expanded(
                child: _recentGcs.isEmpty
                    ? const Center(
                        child: Text('No recent GCs found.', style: TextStyle(color: kSlate400, fontSize: 13)),
                      )
                    : ListView.builder(
                        itemCount: _recentGcs.length,
                        itemBuilder: (context, index) {
                          final gc = _recentGcs[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: kSlate200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      gc['gcNumber'] ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: kIndigo700, fontSize: 14),
                                    ),
                                    Text(
                                      gc['date'] != null ? gc['date'].toString().split('T')[0] : '',
                                      style: const TextStyle(fontSize: 11, color: kSlate400),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${gc['consignorName'] ?? 'Unknown'} → ${gc['consigneeName'] ?? 'Unknown'}',
                                  style: const TextStyle(fontSize: 12, color: kSlate600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.edit, size: 14, color: kIndigo600),
                                      label: const Text('Edit', style: TextStyle(fontSize: 12, color: kIndigo600)),
                                      onPressed: () => _loadGcForEdit(gc['gcNumber']),
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

  Widget _buildSwissCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMasters) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: kSlate50,
      endDrawer: _buildHistoryDrawer(),
      body: Column(
        children: [
          // 1. Header Ribbon
          // 1. Header Ribbon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width > 40 ? MediaQuery.of(context).size.width - 40 : 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                // Left: Title, draft status, toggle, EWB input
                Row(
                  children: [
                    const Text(
                      'New GC',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: kIndigo600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: kIndigo50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: kIndigo100),
                      ),
                      child: Text('FY $_financialYear', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kIndigo700)),
                    ),
                    if (widget.initialGc == null && _draftStatus.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          _draftStatus,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                    const SizedBox(width: 16),
                    if (widget.initialGc == null)
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () => setState(() {
                                _companyMode = 'A';
                                _fetchNextGcNumber();
                              }),
                              borderRadius: BorderRadius.circular(7),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _companyMode == 'A' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(7),
                                  boxShadow: _companyMode == 'A'
                                      ? [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
                                      : null,
                                ),
                                child: Text(
                                  'AP',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: _companyMode == 'A' ? kIndigo700 : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(() {
                                _companyMode = 'B';
                                _fetchNextGcNumber();
                              }),
                              borderRadius: BorderRadius.circular(7),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _companyMode == 'B' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(7),
                                  boxShadow: _companyMode == 'B'
                                      ? [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
                                      : null,
                                ),
                                child: Text(
                                  'BELL',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: _companyMode == 'B' ? const Color(0xFF047857) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 16),
                    // EWB Pill
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 8, right: 6),
                            child: Icon(Icons.flash_on_rounded, size: 16, color: Color(0xFF2563EB)),
                          ),
                          SizedBox(
                            width: 155,
                            height: 32,
                            child: TextFormField(
                              controller: _ewbNumberController,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                hintText: 'Enter E-Way Bill No',
                                hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                              ),
                              onFieldSubmitted: (_) => _fetchEwbDetails(),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Scan E-Way Bill QR / Barcode',
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: const EdgeInsets.all(4),
                            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: Color(0xFF2563EB)),
                            onPressed: () async {
                              final scanned = await BarcodeScannerModal.show(
                                context,
                                title: 'Scan E-Way Bill',
                                subtitle: 'Scan 12-digit EWB barcode or QR code',
                              );
                              if (scanned != null && scanned.isNotEmpty) {
                                _ewbNumberController.text = scanned;
                                _fetchEwbDetails();
                              }
                            },
                          ),
                          Container(
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                              ),
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _fetchEwbDetails,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                minimumSize: const Size(0, 32),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                              ),
                              child: const Text('Fetch EWB', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                            ),
                          ),
                          if (_fetchedEwbDetails != null) ...[
                            const SizedBox(width: 6),
                            _buildEwbBadge(_fetchedEwbDetails!['status']),
                            if (_fetchedEwbDetails!['detectedCompany'] != null || _fetchedEwbDetails!['company'] != null) ...[
                              const SizedBox(width: 6),
                              OutlinedButton(
                                onPressed: _isReassigning ? null : _handleReassignTransporter,
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: kAmber50,
                                  foregroundColor: kAmber600,
                                  side: const BorderSide(color: kAmber500),
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: const Size(0, 30),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(
                                  _isReassigning
                                      ? 'Reassigning...'
                                      : 'Reassign to ${(_fetchedEwbDetails!['detectedCompany'] == 'B' || _fetchedEwbDetails!['company'] == 'BELL') ? 'AP' : 'BELL'}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                // Right: GC Number & Manage GCs button
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _companyMode == 'A'
                              ? [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)]
                              : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _companyMode == 'A' ? const Color(0xFFC7D2FE) : const Color(0xFFA7F3D0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_companyMode == 'A' ? const Color(0xFF2563EB) : const Color(0xFF059669)).withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _companyMode == 'A' ? const Color(0xFF2563EB) : const Color(0xFF059669),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _companyMode == 'A' ? 'AP' : 'BELL',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: _companyMode == 'A' ? const Color(0xFF1D4ED8) : const Color(0xFF047857),
                            ),
                          ),
                          Text(
                            ' • $_gcNumber',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: _companyMode == 'A' ? const Color(0xFF1E3A8A) : const Color(0xFF065F46),
                              letterSpacing: 0.2,
                            ),
                          ),
                          if (_status.isNotEmpty && _status != 'Created') ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _status == 'Delivered'
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _status == 'Delivered'
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                          if (_linkedGdmNumber != null && _linkedGdmNumber!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'GDM: $_linkedGdmNumber',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF6D28D9),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.history_rounded, size: 16, color: kIndigo600),
                      label: const Text('Recent GCs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        _loadRecentGcs();
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
          // 2. Main Scrollable Form Content (max-w-6xl mx-auto)
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9), Color(0xFFEEF2F6)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: kIndigo600, width: 1.6),
                          ),
                          labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                          floatingLabelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kIndigo600),
                        ),
                      ),
                      child: Form(
                        key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card 1: Document Details
                        _buildSwissCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('Document Details', Icons.description_outlined, kIndigo600),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      value: _financialYear,
                                      decoration: const InputDecoration(labelText: 'Fin. Year *', border: OutlineInputBorder()),
                                      items: ['2026-2027', '2025-2026'].map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                                      onChanged: (v) => setState(() => _financialYear = v!),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2025), lastDate: DateTime(2030));
                                        if (picked != null) setState(() => _date = picked);
                                      },
                                      child: InputDecorator(
                                        decoration: const InputDecoration(labelText: 'Booking Date *', border: OutlineInputBorder()),
                                        child: Text(_formatDate(_date)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final picked = await showTimePicker(context: context, initialTime: _time);
                                        if (picked != null) setState(() => _time = picked);
                                      },
                                      child: InputDecorator(
                                        decoration: const InputDecoration(labelText: 'Time *', border: OutlineInputBorder()),
                                        child: Text(_time.format(context)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      value: _type,
                                      decoration: const InputDecoration(labelText: 'Type *', border: OutlineInputBorder()),
                                      items: ['Regular', 'Retail'].map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                                      onChanged: (v) => setState(() => _type = v!),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Card 2: Consignor & Consignee (Side by Side)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left: Consignor
                            Expanded(
                              child: _buildSwissCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionHeader(
                                      'Consignor',
                                      Icons.business_outlined,
                                      kIndigo600,
                                      trailing: InkWell(
                                        onTap: () => setState(() => _showSenderPhone = !_showSenderPhone),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: Checkbox(
                                                  value: _showSenderPhone,
                                                  onChanged: (v) => setState(() => _showSenderPhone = v ?? false),
                                                  activeColor: kIndigo600,
                                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Text('Phone', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    KeyedSubtree(
                                      key: ValueKey('cnor_auto_$_partyAutocompleteEpoch'),
                                      child: Autocomplete<Consignor>(
                                      displayStringForOption: (c) => c.name,
                                      initialValue: _selectedConsignor != null ? TextEditingValue(text: _selectedConsignor!.name) : TextEditingValue.empty,
                                      optionsBuilder: (TextEditingValue textEditingValue) {
                                        final q = textEditingValue.text.trim().toLowerCase();
                                        if (q.isEmpty) {
                                          return const Iterable<Consignor>.empty();
                                        }
                                        return _consignors.where((c) =>
                                            c.name.toLowerCase().contains(q) ||
                                            (c.gstin?.toLowerCase().contains(q) ?? false));
                                      },
                                      onSelected: (Consignor selection) {
                                        setState(() {
                                          _selectedConsignor = selection;
                                          _senderPhoneController.text = selection.phone ?? '';
                                        });
                                      },
                                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                        return TextFormField(
                                          controller: controller,
                                          focusNode: focusNode,
                                          decoration: const InputDecoration(
                                            labelText: 'Search Consignor *',
                                            border: OutlineInputBorder(),
                                            prefixIcon: Icon(Icons.search, size: 18),
                                            hintText: 'Type to search...',
                                          ),
                                          onChanged: (val) {
                                            if (_selectedConsignor != null && val != _selectedConsignor!.name) {
                                              setState(() => _selectedConsignor = null);
                                            }
                                          },
                                        );
                                      },
                                      optionsViewBuilder: (context, onSelected, options) {
                                        return Align(
                                          alignment: Alignment.topLeft,
                                          child: Material(
                                            elevation: 4.0,
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(maxHeight: 250, maxWidth: 300),
                                              child: ListView.builder(
                                                padding: EdgeInsets.zero,
                                                shrinkWrap: true,
                                                itemCount: options.length,
                                                itemBuilder: (BuildContext context, int index) {
                                                  final Consignor option = options.elementAt(index);
                                                  return InkWell(
                                                    onTap: () => onSelected(option),
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(16.0),
                                                      child: Text(option.name, style: const TextStyle(fontSize: 14)),
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
                                    if (_showSenderPhone) ...[
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _senderPhoneController,
                                        decoration: InputDecoration(
                                          labelText: 'Sender Phone (B2C)',
                                          hintText: _selectedConsignor?.phone ?? 'Enter mobile number',
                                          border: const OutlineInputBorder(),
                                          prefixIcon: const Icon(Icons.phone, size: 16),
                                        ),
                                        keyboardType: TextInputType.phone,
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.place_outlined, size: 16, color: Color(0xFF94A3B8)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _selectedConsignor?.address ?? 'No Address Selected',
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.3),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          _selectedConsignor?.gstin ?? 'No GSTIN',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontFamily: 'monospace'),
                                        ),
                                        if (_selectedConsignor?.gstin?.isNotEmpty == true) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFECFDF5),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFFA7F3D0)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.verified_rounded, size: 13, color: Color(0xFF059669)),
                                                SizedBox(width: 4),
                                                Text('VERIFIED GST', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF047857), letterSpacing: 0.3)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Right: Consignee
                            Expanded(
                              child: _buildSwissCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionHeader(
                                      'Consignee',
                                      Icons.location_on_outlined,
                                      const Color(0xFF059669),
                                      trailing: InkWell(
                                        onTap: () => setState(() => _showReceiverPhone = !_showReceiverPhone),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: Checkbox(
                                                  value: _showReceiverPhone,
                                                  onChanged: (v) => setState(() => _showReceiverPhone = v ?? false),
                                                  activeColor: const Color(0xFF059669),
                                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Text('Phone', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    KeyedSubtree(
                                      key: ValueKey('cnee_auto_$_partyAutocompleteEpoch'),
                                      child: Autocomplete<Consignee>(
                                      displayStringForOption: (c) => c.name,
                                      initialValue: _selectedConsignee != null ? TextEditingValue(text: _selectedConsignee!.name) : TextEditingValue.empty,
                                      optionsBuilder: (TextEditingValue textEditingValue) {
                                        final q = textEditingValue.text.trim().toLowerCase();
                                        if (q.isEmpty) {
                                          return const Iterable<Consignee>.empty();
                                        }
                                        return _consignees.where((c) =>
                                            c.name.toLowerCase().contains(q) ||
                                            (c.gstin?.toLowerCase().contains(q) ?? false));
                                      },
                                      onSelected: (Consignee selection) {
                                        setState(() {
                                          _selectedConsignee = selection;
                                          _receiverPhoneController.text = selection.phone ?? '';
                                        });
                                      },
                                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                        return TextFormField(
                                          controller: controller,
                                          focusNode: focusNode,
                                          decoration: const InputDecoration(
                                            labelText: 'Search Consignee *',
                                            border: OutlineInputBorder(),
                                            prefixIcon: Icon(Icons.search, size: 18),
                                            hintText: 'Type to search...',
                                          ),
                                          onChanged: (val) {
                                            if (_selectedConsignee != null && val != _selectedConsignee!.name) {
                                              setState(() => _selectedConsignee = null);
                                            }
                                          },
                                        );
                                      },
                                      optionsViewBuilder: (context, onSelected, options) {
                                        return Align(
                                          alignment: Alignment.topLeft,
                                          child: Material(
                                            elevation: 4.0,
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(maxHeight: 250, maxWidth: 300),
                                              child: ListView.builder(
                                                padding: EdgeInsets.zero,
                                                shrinkWrap: true,
                                                itemCount: options.length,
                                                itemBuilder: (BuildContext context, int index) {
                                                  final Consignee option = options.elementAt(index);
                                                  return InkWell(
                                                    onTap: () => onSelected(option),
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(16.0),
                                                      child: Text(option.name, style: const TextStyle(fontSize: 14)),
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
                                    if (_showReceiverPhone) ...[
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _receiverPhoneController,
                                        decoration: InputDecoration(
                                          labelText: 'Receiver Phone (B2C)',
                                          hintText: _selectedConsignee?.phone ?? 'Enter mobile number',
                                          border: const OutlineInputBorder(),
                                          prefixIcon: const Icon(Icons.phone, size: 16),
                                        ),
                                        keyboardType: TextInputType.phone,
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.place_outlined, size: 16, color: Color(0xFF94A3B8)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _selectedConsignee?.address ?? 'No Address Selected',
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.3),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          _selectedConsignee?.gstin ?? 'No GSTIN',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669), fontFamily: 'monospace'),
                                        ),
                                        if (_selectedConsignee?.gstin?.isNotEmpty == true) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFECFDF5),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFFA7F3D0)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.verified_rounded, size: 13, color: Color(0xFF059669)),
                                                SizedBox(width: 4),
                                                Text('VERIFIED GST', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF047857), letterSpacing: 0.3)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Card 3: Goods & Invoice Details
                        _buildSwissCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.inventory_2_outlined, size: 16, color: kAmber600),
                                      SizedBox(width: 6),
                                      Text(
                                        'Goods & Invoice Details',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kSlate800),
                                      ),
                                    ],
                                  ),
                                  // Inline Invoice inputs
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 100,
                                        child: TextFormField(
                                          controller: _invoiceNumberController,
                                          decoration: const InputDecoration(labelText: 'Inv No', border: OutlineInputBorder()),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 130,
                                        child: InkWell(
                                          onTap: () async {
                                            final picked = await showDatePicker(context: context, initialDate: _invoiceDate, firstDate: DateTime(2025), lastDate: DateTime(2030));
                                            if (picked != null) setState(() => _invoiceDate = picked);
                                          },
                                          child: InputDecorator(
                                            decoration: const InputDecoration(labelText: 'Inv Date', border: OutlineInputBorder()),
                                            child: Text(_formatDate(_invoiceDate)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 110,
                                        child: TextFormField(
                                          controller: _invoiceValueController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Value ₹',
                                            border: OutlineInputBorder(),
                                            filled: true,
                                            fillColor: kAmber50,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 110,
                                        child: TextFormField(
                                          controller: _privateMarkController,
                                          decoration: const InputDecoration(labelText: 'Weight/Mark', border: OutlineInputBorder()),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_fetchedEwbDetails?.containsKey('rawData') == true)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [kIndigo50, kViolet50]),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: kIndigo100),
                                  ),
                                  child: const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('✨ EWB Data Auto-Filled', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kIndigo700)),
                                      Text('Verify goods matching E-Way Bill items below.', style: TextStyle(fontSize: 11, color: kIndigo600)),
                                    ],
                                  ),
                                ),
                              // Grid Table Header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Row(
                                  children: [
                                    Expanded(flex: 1, child: Text('QTY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569), letterSpacing: 0.5))),
                                    SizedBox(width: 8),
                                    Expanded(flex: 2, child: Text('UNIT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569), letterSpacing: 0.5))),
                                    SizedBox(width: 8),
                                    Expanded(flex: 3, child: Text('UNIT DESC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569), letterSpacing: 0.5))),
                                    SizedBox(width: 8),
                                    Expanded(flex: 1, child: Text('HSN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569), letterSpacing: 0.5))),
                                    SizedBox(width: 8),
                                    Expanded(flex: 1, child: Text('GODOWN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569), letterSpacing: 0.5))),
                                    SizedBox(width: 8),
                                    Expanded(flex: 4, child: Text('DESCRIPTION OF GOODS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569), letterSpacing: 0.5))),
                                    SizedBox(width: 72),
                                  ],
                                ),
                              ),
                              // Grid Rows
                              ..._itemRows.asMap().entries.map((entry) {
                                final index = entry.key;
                                final row = entry.value;
                                final availableCategories = _unitHierarchy.keys.toList();
                                final availableSubUnits = _unitHierarchy[row.unitCategory] ?? [];
                                final unitBadge = _buildUnitBadge(row.units);

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 1,
                                        child: TextFormField(
                                          controller: row.articlesController,
                                          decoration: const InputDecoration(
                                            hintText: '0',
                                            border: OutlineInputBorder(),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                          ),
                                          keyboardType: TextInputType.number,
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: DropdownButtonFormField<String>(
                                          isExpanded: true,
                                          value: availableCategories.contains(row.unitCategory)
                                              ? row.unitCategory
                                              : (availableCategories.isNotEmpty ? availableCategories.first : null),
                                          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                                          items: availableCategories.map((cat) => DropdownMenuItem(
                                            value: cat,
                                            child: Text(cat, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                          )).toList(),
                                          onChanged: (newCat) {
                                            if (newCat == null) return;
                                            setState(() {
                                              row.unitCategory = newCat;
                                              final subOptions = _unitHierarchy[newCat] ?? [];
                                              final defaultItem = subOptions.isNotEmpty ? subOptions.first : null;
                                              if (defaultItem != null) {
                                                row.units = defaultItem.description;
                                                row.hsnController.text = defaultItem.hsn ?? '';
                                                row.descriptionController.text = defaultItem.goodsDesc ?? '';
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 3,
                                        child: DropdownButtonFormField<String>(
                                          isExpanded: true,
                                          value: availableSubUnits.any((u) => u.description == row.units)
                                              ? row.units
                                              : (availableSubUnits.isNotEmpty ? availableSubUnits.first.description : null),
                                          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                                          items: availableSubUnits.map((u) => DropdownMenuItem(
                                            value: u.description,
                                            child: Text(u.description, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                                          )).toList(),
                                          onChanged: (newUnit) {
                                            if (newUnit == null) return;
                                            setState(() {
                                              row.units = newUnit;
                                              final match = availableSubUnits.firstWhere(
                                                (u) => u.description == newUnit,
                                                orElse: () => availableSubUnits.first,
                                              );
                                              row.hsnController.text = match.hsn ?? '';
                                              row.descriptionController.text = match.goodsDesc ?? '';
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 1,
                                        child: TextFormField(
                                          controller: row.hsnController,
                                          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 1,
                                        child: TextFormField(
                                          controller: row.godownController,
                                          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 4,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                controller: row.descriptionController,
                                                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                                              ),
                                            ),
                                            if (unitBadge != null) ...[
                                              const SizedBox(width: 6),
                                              unitBadge,
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 72,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              icon: const Icon(Icons.add_circle, color: kIndigo600, size: 26),
                                              onPressed: _addItemRow,
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              icon: Icon(Icons.remove_circle, color: _itemRows.length > 1 ? kRose600 : kSlate300, size: 26),
                                              onPressed: _itemRows.length > 1 ? () => _removeItemRow(index) : null,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),

                        // Card 4: Freight Details
                        _buildSwissCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('Freight Details', Icons.local_shipping_outlined, Colors.teal),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      value: _freightFixed,
                                      decoration: const InputDecoration(labelText: 'Freight Fixed *', border: OutlineInputBorder()),
                                      items: ['Yes', 'No'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                                      onChanged: (val) => setState(() => _freightFixed = val!),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      value: _freightType,
                                      decoration: const InputDecoration(labelText: 'Freight Type *', border: OutlineInputBorder()),
                                      items: ['To Pay', 'Paid'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                                      onChanged: (val) => setState(() => _freightType = val!),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  if (_showRateBox)
                                    Expanded(
                                      child: TextFormField(
                                        controller: _freightController,
                                        decoration: InputDecoration(labelText: _freightLabel, border: const OutlineInputBorder()),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      ),
                                    ),
                                  if (_showRateBox) const SizedBox(width: 16),
                                  if (_showTotalAdvBalBox) ...[
                                    Expanded(
                                      child: TextFormField(
                                        key: ValueKey('tf_$_calculatedTotalFreight'),
                                        initialValue: _calculatedTotalFreight.toStringAsFixed(2),
                                        decoration: const InputDecoration(
                                          labelText: 'Total Freight',
                                          prefixText: '₹ ',
                                          border: OutlineInputBorder(),
                                          fillColor: Color(0xFFF8FAFC),
                                          filled: true,
                                        ),
                                        style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                        readOnly: true,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _advancePaidController,
                                        decoration: const InputDecoration(
                                          labelText: 'Advance Paid',
                                          prefixText: '₹ ',
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setState(() {}),
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                        validator: (v) {
                                          final adv = double.tryParse(v ?? '') ?? 0;
                                          if (adv > _calculatedTotalFreight) return 'Exceeds total';
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextFormField(
                                        key: ValueKey('bal_$_calculatedBalance'),
                                        initialValue: _calculatedBalance.toStringAsFixed(2),
                                        decoration: const InputDecoration(
                                          labelText: 'Balance Freight',
                                          prefixText: '₹ ',
                                          border: OutlineInputBorder(),
                                          fillColor: Color(0xFFEFF6FF),
                                          filled: true,
                                        ),
                                        style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                        readOnly: true,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(_freightNote, style: const TextStyle(color: kSlate500, fontStyle: FontStyle.italic, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

          // 3. Action Footer Sticky
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
              boxShadow: [
                BoxShadow(color: Color(0x0A0F172A), blurRadius: 10, offset: Offset(0, -3)),
              ],
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left: Remarks input
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _remarksController,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Remarks / Freight Note',
                          labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          prefixIcon: const Icon(Icons.note_alt_outlined, size: 16, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kIndigo600, width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Center: Compact Typographic Tallies
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTallyItem('TOTAL', _tallyTotal.toString(), kIndigo600, Icons.inventory_2_rounded),
                        const SizedBox(width: 6),
                        _buildTallyItem('BOXES', _tallyBoxes.toString(), const Color(0xFF059669), Icons.all_inbox_rounded),
                        const SizedBox(width: 6),
                        _buildTallyItem('BUNDLES', _tallyBundles.toString(), const Color(0xFFD97706), Icons.layers_rounded),
                        const SizedBox(width: 6),
                        _buildTallyItem('BAGS', _tallyBags.toString(), const Color(0xFFE11D48), Icons.shopping_bag_rounded),
                      ],
                    ),
                    const SizedBox(width: 14),
                    // Right: Buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton(
                          onPressed: _clearForm,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.visibility_outlined, size: 15, color: kIndigo600),
                          label: const Text('Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            backgroundColor: const Color(0xFFF8FAFC),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _showPreviewDialog,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [kIndigo600, kIndigo700],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(color: kIndigo600.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 17, color: Colors.white),
                            label: Text(
                              widget.initialGc == null ? 'Save GC' : 'Update GC',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _isSubmitting ? null : _saveGC,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
