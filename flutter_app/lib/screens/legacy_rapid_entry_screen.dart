import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/consignor.dart';
import '../models/consignee.dart';
import '../models/unit_model.dart';
import '../services/api_service.dart';

class LegacyRapidEntryScreen extends StatefulWidget {
  const LegacyRapidEntryScreen({super.key});

  @override
  State<LegacyRapidEntryScreen> createState() => _LegacyRapidEntryScreenState();
}

class _LegacyGoodsItem {
  int id;
  TextEditingController articlesController;
  String unitCategory;
  String units;
  TextEditingController hsnController;
  TextEditingController descriptionController;

  _LegacyGoodsItem({
    required this.id,
    required this.articlesController,
    this.unitCategory = 'Cases',
    this.units = 'Cases of Fireworks',
    required this.hsnController,
    required this.descriptionController,
  });
}

class _LegacyRapidEntryScreenState extends State<LegacyRapidEntryScreen> {
  // Form controllers
  late TextEditingController _gcNumberController;
  late TextEditingController _ewbNumberController;
  late TextEditingController _invoiceNumberController;
  late TextEditingController _invoiceValueController;
  final TextEditingController _tableSearchController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _companyMode = 'A'; // 'A' = AP, 'B' = BELL
  String _selectedGodown = 'Main Branch';
  List<dynamic> _godowns = [];

  // Consignor & Consignee
  List<Consignor> _consignors = [];
  List<Consignee> _consignees = [];
  Consignor? _selectedConsignor;
  Consignee? _selectedConsignee;
  bool _isNewConsignor = false;
  bool _isNewConsignee = false;

  // Units
  Map<String, List<Map<String, dynamic>>> _unitHierarchy = {
    'Cases': [
      {'label': 'Cases of Fireworks', 'code': 'C/S', 'hsn': '3604', 'goodsDesc': 'Legacy Goods'}
    ]
  };

  // Goods rows
  List<_LegacyGoodsItem> _goodsRows = [];

  // EWB extra data
  Map<String, dynamic>? _ewbRawData;
  bool _isFetchingEwb = false;
  bool _isReassigning = false;
  String? _reassignSuccess;

  // State flags
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  // Edit mode
  int? _editingId;

  // Session table records
  List<dynamic> _savedRecords = [];
  int _currentPage = 1;
  bool _hasMoreRecords = true;
  bool _isLoadingMore = false;
  String _tableSearchFilter = '';

  @override
  void initState() {
    super.initState();
    _gcNumberController = TextEditingController();
    _ewbNumberController = TextEditingController();
    _invoiceNumberController = TextEditingController();
    _invoiceValueController = TextEditingController();

    _initDefaultGoodsRow();
    _loadInitialData();
  }

  @override
  void dispose() {
    _gcNumberController.dispose();
    _ewbNumberController.dispose();
    _invoiceNumberController.dispose();
    _invoiceValueController.dispose();
    _tableSearchController.dispose();
    for (var g in _goodsRows) {
      g.articlesController.dispose();
      g.hsnController.dispose();
      g.descriptionController.dispose();
    }
    super.dispose();
  }

  void _initDefaultGoodsRow() {
    _goodsRows = [
      _LegacyGoodsItem(
        id: DateTime.now().millisecondsSinceEpoch,
        articlesController: TextEditingController(),
        unitCategory: 'Cases',
        units: 'Cases of Fireworks',
        hsnController: TextEditingController(text: '3604'),
        descriptionController: TextEditingController(text: 'Legacy Goods'),
      ),
    ];
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final godowns = await ApiService.getGodowns().catchError((_) => <dynamic>[]);
      final units = await ApiService.getUnits().catchError((_) => <UnitModel>[]);
      final consignors = await ApiService.getConsignors().catchError((_) => <Consignor>[]);
      final consignees = await ApiService.getConsignees().catchError((_) => <Consignee>[]);
      final records = await ApiService.getGcsRaw(page: 1, limit: 15).catchError((_) => <dynamic>[]);

      if (mounted) {
        // Parse unit hierarchy
        final hierarchy = <String, List<Map<String, dynamic>>>{};
        for (var u in units) {
          final cat = u.category.isNotEmpty ? u.category : 'General';
          if (!hierarchy.containsKey(cat)) hierarchy[cat] = [];
          hierarchy[cat]!.add({
            'label': u.description.isNotEmpty ? u.description : u.code,
            'code': u.code,
            'hsn': u.hsn ?? '3604',
            'goodsDesc': u.goodsDesc ?? 'Legacy Goods',
          });
        }
        if (hierarchy.isEmpty) {
          hierarchy['Cases'] = [
            {'label': 'Cases of Fireworks', 'code': 'C/S', 'hsn': '3604', 'goodsDesc': 'Legacy Goods'}
          ];
        }

        setState(() {
          _godowns = godowns;
          if (godowns.isNotEmpty) {
            _selectedGodown = godowns.first['name']?.toString() ?? 'Main Branch';
          }
          _unitHierarchy = hierarchy;
          _consignors = consignors;
          _consignees = consignees;
          _savedRecords = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load initial masters: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchRecentRecords({bool loadMore = false}) async {
    if (loadMore) {
      setState(() => _isLoadingMore = true);
    }
    try {
      final page = loadMore ? _currentPage + 1 : 1;
      final raw = await ApiService.getGcsRaw(page: page, limit: 15);
      if (mounted) {
        setState(() {
          if (loadMore) {
            _savedRecords.addAll(raw);
            _currentPage = page;
            _hasMoreRecords = raw.isNotEmpty;
            _isLoadingMore = false;
          } else {
            _savedRecords = raw;
            _currentPage = 1;
            _hasMoreRecords = raw.length >= 15;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _handleEwbLookup(String ewbInput) async {
    final ewbNo = ewbInput.replaceAll(RegExp(r'[^0-9]'), '');
    if (ewbNo.length < 12 || ewbNo.length > 15 || _isFetchingEwb) return;

    setState(() {
      _isFetchingEwb = true;
      _errorMessage = null;
    });

    try {
      final companyQuery = _companyMode == 'A' ? 'AP' : 'BELL';
      final ewbData = await ApiService.fetchEWayBill(ewbNo, company: companyQuery);

      if (mounted) {
        // Auto match or prepare consignor
        final fromGstin = ewbData['fromGstin']?.toString().toUpperCase();
        final fromName = ewbData['fromTrdName']?.toString();

        Consignor? matchedCnor;
        if (fromGstin != null || fromName != null) {
          for (var c in _consignors) {
            if (fromGstin != null && c.gstin?.toUpperCase() == fromGstin) {
              matchedCnor = c;
              break;
            }
            if (fromName != null && c.name.toLowerCase() == fromName.toLowerCase()) {
              matchedCnor = c;
              break;
            }
          }
        }

        // If not found, attempt to auto create or select
        bool newCnorCreated = false;
        if (matchedCnor == null && fromName != null && fromName.trim().isNotEmpty) {
          try {
            final newCnor = await ApiService.saveConsignor({
              'name': fromName.replaceAll(RegExp(r'\s+'), ' ').trim(),
              'gstin': fromGstin ?? '',
              'address': [ewbData['fromAddr1'], ewbData['fromAddr2']].where((e) => e != null && e.toString().isNotEmpty).join(', '),
              'city': ewbData['fromPlace']?.toString() ?? '',
              'state': ewbData['fromStateCode']?.toString() ?? '',
              'pincode': ewbData['fromPincode']?.toString() ?? '',
            });
            _consignors.insert(0, newCnor);
            matchedCnor = newCnor;
            newCnorCreated = true;
          } catch (_) {}
        }

        // Auto match or prepare consignee
        final toGstin = ewbData['toGstin']?.toString().toUpperCase();
        final toName = ewbData['toTrdName']?.toString();

        Consignee? matchedCnee;
        if (toGstin != null || toName != null) {
          for (var c in _consignees) {
            if (toGstin != null && c.gstin?.toUpperCase() == toGstin) {
              matchedCnee = c;
              break;
            }
            if (toName != null && c.name.toLowerCase() == toName.toLowerCase()) {
              matchedCnee = c;
              break;
            }
          }
        }

        bool newCneeCreated = false;
        if (matchedCnee == null && toName != null && toName.trim().isNotEmpty) {
          try {
            final newCnee = await ApiService.saveConsignee({
              'name': toName.replaceAll(RegExp(r'\s+'), ' ').trim(),
              'gstin': toGstin ?? '',
              'address': [ewbData['toAddr1'], ewbData['toAddr2']].where((e) => e != null && e.toString().isNotEmpty).join(', '),
              'city': ewbData['toPlace']?.toString() ?? '',
              'state': ewbData['toStateCode']?.toString() ?? '',
              'pincode': ewbData['toPincode']?.toString() ?? '',
            });
            _consignees.insert(0, newCnee);
            matchedCnee = newCnee;
            newCneeCreated = true;
          } catch (_) {}
        }

        // Invoice Number & Value
        if (ewbData['docNo'] != null) {
          _invoiceNumberController.text = ewbData['docNo'].toString();
        } else if (ewbData['documentNo'] != null) {
          _invoiceNumberController.text = ewbData['documentNo'].toString();
        }

        if (ewbData['totInvValue'] != null) {
          _invoiceValueController.text = ewbData['totInvValue'].toString();
        }

        // Detected Company Mode
        if (ewbData['detectedCompany'] != null) {
          _companyMode = ewbData['detectedCompany'] == 'BELL' ? 'B' : 'A';
        }

        setState(() {
          _ewbRawData = ewbData['rawData'] ?? ewbData;
          _selectedConsignor = matchedCnor;
          _selectedConsignee = matchedCnee;
          _isNewConsignor = newCnorCreated;
          _isNewConsignee = newCneeCreated;
          _isFetchingEwb = false;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to fetch E-Way Bill $ewbNo. Please enter fields manually.';
          _isFetchingEwb = false;
        });
      }
    }
  }

  Future<void> _handleReassignTransporter() async {
    final ewbNo = _ewbNumberController.text.trim();
    if (ewbNo.isEmpty) return;

    final currentComp = _companyMode == 'A' ? 'AP' : 'BELL';
    final targetComp = currentComp == 'BELL' ? 'AP' : 'BELL';

    setState(() => _isReassigning = true);
    try {
      await ApiService.reassignTransporter(ewbNo, currentComp, targetComp);
      if (mounted) {
        setState(() {
          _reassignSuccess = 'Reassigned to $targetComp successfully!';
          _companyMode = targetComp == 'BELL' ? 'B' : 'A';
          _isReassigning = false;
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _reassignSuccess = null);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Transporter reassignment failed: $e';
          _isReassigning = false;
        });
      }
    }
  }

  void _addGoodsRow() {
    final firstCat = _unitHierarchy.keys.isNotEmpty ? _unitHierarchy.keys.first : 'Cases';
    final firstItem = _unitHierarchy[firstCat]?.isNotEmpty == true ? _unitHierarchy[firstCat]!.first : null;

    setState(() {
      _goodsRows.add(
        _LegacyGoodsItem(
          id: DateTime.now().millisecondsSinceEpoch,
          articlesController: TextEditingController(),
          unitCategory: firstCat,
          units: firstItem?['label'] ?? 'Cases of Fireworks',
          hsnController: TextEditingController(text: firstItem?['hsn'] ?? '3604'),
          descriptionController: TextEditingController(text: firstItem?['goodsDesc'] ?? 'Legacy Goods'),
        ),
      );
    });
  }

  void _removeGoodsRow(int id) {
    if (_goodsRows.length <= 1) return;
    setState(() {
      final index = _goodsRows.indexWhere((g) => g.id == id);
      if (index >= 0) {
        _goodsRows[index].articlesController.dispose();
        _goodsRows[index].hsnController.dispose();
        _goodsRows[index].descriptionController.dispose();
        _goodsRows.removeAt(index);
      }
    });
  }

  void _handleEditRecord(dynamic record) {
    final gcNumber = (record['gcNumber'] ?? '').toString();
    String prefix = 'A';
    String rawNum = gcNumber;
    if (gcNumber.startsWith('AP-')) {
      prefix = 'A';
      rawNum = gcNumber.replaceFirst('AP-', '');
    } else if (gcNumber.startsWith('BELL-')) {
      prefix = 'B';
      rawNum = gcNumber.replaceFirst('BELL-', '');
    }

    _gcNumberController.text = rawNum;
    _ewbNumberController.text = record['ewbNumber']?.toString() ?? '';
    _invoiceNumberController.text = record['invoiceNumber']?.toString() ?? '';
    _invoiceValueController.text = record['invoiceValue']?.toString() ?? '';

    // Date
    if (record['date'] != null) {
      try {
        _selectedDate = DateTime.parse(record['date'].toString());
      } catch (_) {}
    }

    _companyMode = prefix;
    _selectedGodown = record['godown']?.toString() ?? _selectedGodown;

    // Consignor & Consignee
    final cnorId = record['consignorId'];
    final cneeId = record['consigneeId'];
    _selectedConsignor = _consignors.firstWhere((c) => c.id == cnorId, orElse: () => _consignors.isNotEmpty ? _consignors.first : Consignor(id: 0, name: record['consignor']?['name'] ?? ''));
    _selectedConsignee = _consignees.firstWhere((c) => c.id == cneeId, orElse: () => _consignees.isNotEmpty ? _consignees.first : Consignee(id: 0, name: record['consignee']?['name'] ?? ''));

    // Goods items
    final goods = record['goods'] as List?;
    if (goods != null && goods.isNotEmpty) {
      for (var r in _goodsRows) {
        r.articlesController.dispose();
        r.hsnController.dispose();
        r.descriptionController.dispose();
      }
      _goodsRows = goods.map((g) {
        return _LegacyGoodsItem(
          id: DateTime.now().millisecondsSinceEpoch + (g['id'] as int? ?? 0),
          articlesController: TextEditingController(text: (g['articleCount'] ?? g['articles'] ?? '').toString()),
          unitCategory: 'Cases',
          units: g['units']?.toString() ?? 'Cases of Fireworks',
          hsnController: TextEditingController(text: g['hsn']?.toString() ?? '3604'),
          descriptionController: TextEditingController(text: g['description']?.toString() ?? 'Legacy Goods'),
        );
      }).toList();
    }

    setState(() {
      _editingId = record['id'] as int?;
      _errorMessage = null;
      _successMessage = null;
    });
  }

  void _resetForm() {
    _gcNumberController.clear();
    _ewbNumberController.clear();
    _invoiceNumberController.clear();
    _invoiceValueController.clear();

    for (var g in _goodsRows) {
      g.articlesController.dispose();
      g.hsnController.dispose();
      g.descriptionController.dispose();
    }
    _initDefaultGoodsRow();

    setState(() {
      _editingId = null;
      _ewbRawData = null;
      _isNewConsignor = false;
      _isNewConsignee = false;
      _selectedConsignor = null;
      _selectedConsignee = null;
      _errorMessage = null;
      _successMessage = null;
    });
  }

  Future<void> _handleSaveRow() async {
    final gcNum = _gcNumberController.text.trim();
    if (gcNum.isEmpty) {
      setState(() => _errorMessage = 'GC Number is mandatory');
      return;
    }

    if (_selectedConsignor == null) {
      setState(() => _errorMessage = 'Please select or search Consignor');
      return;
    }

    if (_selectedConsignee == null) {
      setState(() => _errorMessage = 'Please select or search Consignee');
      return;
    }

    final hasValidGoods = _goodsRows.any((g) => int.tryParse(g.articlesController.text.trim()) != null && int.parse(g.articlesController.text.trim()) > 0);
    if (!hasValidGoods) {
      setState(() => _errorMessage = 'Please enter valid Articles count in Goods Details');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final prefix = _companyMode == 'A' ? 'AP' : 'BELL';
      final finalGcNumber = '$prefix-$gcNum';
      final dateStr = _formatDate(_selectedDate);

      final payload = {
        'financialYear': '2026-2027',
        'gcNumber': finalGcNumber,
        'type': 'Regular',
        'date': dateStr,
        'time': '12:00 PM',
        'godown': _selectedGodown,
        'status': 'Created',
        'consignorId': _selectedConsignor!.id,
        'consigneeId': _selectedConsignee!.id,
        'invoiceDate': dateStr,
        'invoiceNumber': _invoiceNumberController.text.trim(),
        'invoiceValue': double.tryParse(_invoiceValueController.text.trim()) ?? 0.0,
        'ewbNumber': _ewbNumberController.text.trim().isNotEmpty ? _ewbNumberController.text.trim() : null,
        'ewbRawData': _ewbRawData,
        'freightType': 'To Pay',
        'freightFixed': 'Yes',
        'freightRate': 0,
        'freightTotal': 0,
        'advancePaid': 0,
        'balanceFreight': 0,
        'goods': _goodsRows.map((g) => {
          'articles': int.tryParse(g.articlesController.text.trim()),
          'units': g.units,
          'hsn': g.hsnController.text.trim().isNotEmpty ? g.hsnController.text.trim() : '3604',
          'description': g.descriptionController.text.trim().isNotEmpty ? g.descriptionController.text.trim() : 'Legacy Goods',
        }).toList(),
      };

      if (_editingId != null) {
        await ApiService.updateGc(_editingId!, payload);
        _successMessage = 'GC $finalGcNumber updated successfully!';
      } else {
        await ApiService.createGc(payload);
        _successMessage = 'GC $finalGcNumber saved successfully!';
      }

      _resetForm();
      await _fetchRecentRecords();
    } catch (err) {
      setState(() {
        _errorMessage = err.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  int _calculateTotalSessionArticles() {
    int sum = 0;
    for (var r in _savedRecords) {
      final goods = r['goods'] as List?;
      if (goods != null) {
        for (var g in goods) {
          final count = g['articleCount'] ?? g['articles'];
          if (count != null) {
            sum += int.tryParse(count.toString()) ?? 0;
          }
        }
      }
    }
    return sum;
  }

  List<dynamic> _getFilteredRecords() {
    if (_tableSearchFilter.trim().isEmpty) return _savedRecords;
    final term = _tableSearchFilter.trim().toLowerCase();
    return _savedRecords.where((rec) {
      final gcNo = (rec['gcNumber'] ?? '').toString().toLowerCase();
      final cnor = (rec['consignor']?['name'] ?? rec['consignorName'] ?? '').toString().toLowerCase();
      final cnee = (rec['consignee']?['name'] ?? rec['consigneeName'] ?? '').toString().toLowerCase();
      final ewb = (rec['ewbNumber'] ?? '').toString().toLowerCase();
      final invNo = (rec['invoiceNumber'] ?? '').toString().toLowerCase();
      return gcNo.contains(term) || cnor.contains(term) || cnee.contains(term) || ewb.contains(term) || invNo.contains(term);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rapid Entry Console',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A), letterSpacing: -0.3),
            ),
            Text(
              'High-speed dense spreadsheet interface with real-time EWB sync',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
        actions: [
          if (_editingId != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFFEF3C7),
                  foregroundColor: const Color(0xFFB45309),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Cancel Edit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: _resetForm,
              ),
            ),
          IconButton(
            tooltip: 'Reload Records',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569)),
            onPressed: () => _fetchRecentRecords(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1380),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Executive Cockpit Hero Banner
                      _buildExecutiveCockpit(),
                      const SizedBox(height: 20),

                      // Banner when in Editing Mode
                      if (_editingId != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.edit_note_rounded, color: Color(0xFFD97706), size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Editing Mode Active for Record #$_editingId. Modifications will update this consignment directly.',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Color(0xFFB45309), size: 18),
                                onPressed: _resetForm,
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Alerts
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFECDD3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Color(0xFFBE123C), fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFBE123C)),
                                onPressed: () => setState(() => _errorMessage = null),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (_successMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF059669), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _successMessage!,
                                  style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF065F46)),
                                onPressed: () => setState(() => _successMessage = null),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Dense Entry Form Card
                      _buildDenseFormCard(),
                      const SizedBox(height: 28),

                      // Saved Session Records Table
                      _buildSavedRecordsTable(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildExecutiveCockpit() {
    final totalArticles = _calculateTotalSessionArticles();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.bolt_rounded, color: Color(0xFF818CF8), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'RAPID CONSIGNMENT DISPATCH CONSOLE',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(radius: 3, backgroundColor: Color(0xFF34D399)),
                              SizedBox(width: 5),
                              Text('HOT SYNC ACTIVE', style: TextStyle(color: Color(0xFF34D399), fontSize: 9, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Optimized high-density data pipeline for express bill generation and EWB auto-matching',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text('Reset Form', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: _resetForm,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Color(0xFF334155), height: 1),
          const SizedBox(height: 16),
          // Cockpit KPIs
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildCockpitKpi(
                title: 'SESSION RECORDS',
                value: '${_savedRecords.length}',
                icon: Icons.receipt_long_rounded,
                iconColor: const Color(0xFF38BDF8),
              ),
              _buildCockpitKpi(
                title: 'TOTAL ARTICLES',
                value: '$totalArticles pkgs',
                icon: Icons.inventory_2_rounded,
                iconColor: const Color(0xFF34D399),
              ),
              _buildCockpitKpi(
                title: 'ACTIVE PREFIX',
                value: _companyMode == 'A' ? 'AP (Arunachalam)' : 'BELL (Bell Logistics)',
                icon: Icons.business_rounded,
                iconColor: const Color(0xFFFBBF24),
              ),
              _buildCockpitKpi(
                title: 'CURRENT BRANCH',
                value: _selectedGodown,
                icon: Icons.warehouse_rounded,
                iconColor: const Color(0xFFA78BFA),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCockpitKpi({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDenseFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subheader
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_calendar_rounded, size: 18, color: Color(0xFF4F46E5)),
                const SizedBox(width: 8),
                const Text(
                  'EXPRESS DATA INPUT MATRIX',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF334155), letterSpacing: 0.5),
                ),
                const Spacer(),
                if (_isFetchingEwb) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                  ),
                  const SizedBox(width: 8),
                  const Text('Syncing E-Way Bill...', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                ] else ...[
                  const Text('Instant Auto-Calculations Enabled', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                ],
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Line 1: Date, Prefix, GC No, Smart EWB
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date
                    SizedBox(
                      width: 145,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('ENTRY DATE'),
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setState(() => _selectedDate = picked);
                              }
                            },
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              alignment: Alignment.centerLeft,
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF4F46E5)),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDate(_selectedDate),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Prefix (AP / BELL Segmented Toggle)
                    SizedBox(
                      width: 160,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('TRANSPORTER PREFIX'),
                          Container(
                            height: 40,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _companyMode = 'A'),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: _companyMode == 'A' ? const Color(0xFF4F46E5) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'AP',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          color: _companyMode == 'A' ? Colors.white : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _companyMode = 'B'),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: _companyMode == 'B' ? const Color(0xFF059669) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'BELL',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          color: _companyMode == 'B' ? Colors.white : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // GC Number
                    SizedBox(
                      width: 140,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('GC NUMBER'),
                          _buildDenseInput(
                            controller: _gcNumberController,
                            hint: '1025',
                            textColor: const Color(0xFF4F46E5),
                            fontWeight: FontWeight.w900,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Smart EWB (with auto fetch)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildFieldLabel('SMART EWB (12 DIGITS AUTO-FETCH)'),
                              if (_reassignSuccess != null)
                                Text(_reassignSuccess!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669)))
                              else if (_ewbRawData != null)
                                InkWell(
                                  onTap: _isReassigning ? null : _handleReassignTransporter,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                    ),
                                    child: Text(
                                      _isReassigning ? 'Reassigning...' : 'Switch to ${_companyMode == 'A' ? 'BELL' : 'AP'}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFD97706)),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          _buildDenseInput(
                            controller: _ewbNumberController,
                            hint: 'Type E-Way Bill (12–14 digits) for auto-fill...',
                            prefixIcon: Icons.qr_code_2_rounded,
                            onChanged: (val) {
                              final digits = val.replaceAll(RegExp(r'[^0-9]'), '');
                              if (digits.length == 12 || digits.length == 14) {
                                _handleEwbLookup(digits);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Line 2: Consignor & Consignee Selection Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Consignor Box
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.outbox_rounded, size: 14, color: Color(0xFF4F46E5)),
                                const SizedBox(width: 6),
                                _buildFieldLabel('CONSIGNOR (SENDER)'),
                                const Spacer(),
                                if (_isNewConsignor) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('AUTO SAVED', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ),
                            Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<Consignor>(
                                  value: _selectedConsignor,
                                  isExpanded: true,
                                  hint: const Text('Search & Select Consignor...', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                                  items: _consignors.map((c) {
                                    return DropdownMenuItem(
                                      value: c,
                                      child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() => _selectedConsignor = val);
                                  },
                                ),
                              ),
                            ),
                            if (_selectedConsignor != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(4)),
                                    child: Text(
                                      'GSTIN: ${_selectedConsignor!.gstin ?? '-'}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF4338CA)),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'City: ${_selectedConsignor!.city ?? '-'}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Consignee Box
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.move_to_inbox_rounded, size: 14, color: Color(0xFF059669)),
                                const SizedBox(width: 6),
                                _buildFieldLabel('CONSIGNEE (RECEIVER)'),
                                const Spacer(),
                                if (_isNewConsignee) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('AUTO SAVED', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ),
                            Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<Consignee>(
                                  value: _selectedConsignee,
                                  isExpanded: true,
                                  hint: const Text('Search & Select Consignee...', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                                  items: _consignees.map((c) {
                                    return DropdownMenuItem(
                                      value: c,
                                      child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() => _selectedConsignee = val);
                                  },
                                ),
                              ),
                            ),
                            if (_selectedConsignee != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
                                    child: Text(
                                      'GSTIN: ${_selectedConsignee!.gstin ?? '-'}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF065F46)),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'City: ${_selectedConsignee!.city ?? '-'}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Line 3: Invoice No, Invoice Value, Godown
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('INVOICE NUMBER'),
                          _buildDenseInput(controller: _invoiceNumberController, hint: 'INV-2026-001'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('INVOICE VALUE (₹)'),
                          _buildDenseInput(controller: _invoiceValueController, hint: '50000.00', keyboardType: TextInputType.number),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('TARGET GODOWN / DESTINATION BRANCH'),
                          Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _godowns.any((g) => g['name'] == _selectedGodown) ? _selectedGodown : (_godowns.isNotEmpty ? _godowns.first['name'] : 'Main Branch'),
                                isExpanded: true,
                                items: _godowns.map((g) {
                                  final name = g['name']?.toString() ?? 'Branch';
                                  return DropdownMenuItem(value: name, child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedGodown = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // EWB Raw Items Preview Box
                if (_ewbRawData?['itemList'] != null && (_ewbRawData!['itemList'] as List).isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(6)),
                              child: const Text('E-WAY BILL MANIFEST ITEMS', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                            ),
                            const SizedBox(width: 10),
                            const Text('Directly verified from GST E-Way Bill portal data', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF3730A3))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: (_ewbRawData!['itemList'] as List).map((item) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Text(
                                '${item['productName'] ?? 'Item'}: ${item['quantity']} ${item['qtyUnit']} (HSN: ${item['hsnCode']})',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 22),

                // Goods Details Dense Table
                _buildFieldLabel('CONSIGNMENT GOODS & PACKAGES BREAKDOWN'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      // Header Row
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(width: 85, child: Text('QTY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B)))),
                            SizedBox(width: 14),
                            SizedBox(width: 150, child: Text('CATEGORY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B)))),
                            SizedBox(width: 14),
                            SizedBox(width: 190, child: Text('UNIT SPECIFICATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B)))),
                            SizedBox(width: 14),
                            SizedBox(width: 95, child: Text('HSN CODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B)))),
                            SizedBox(width: 14),
                            Expanded(child: Text('GOODS DESCRIPTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B)))),
                            SizedBox(width: 44),
                          ],
                        ),
                      ),

                      // Rows
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _goodsRows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, idx) {
                          final row = _goodsRows[idx];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              children: [
                                // Qty
                                SizedBox(
                                  width: 85,
                                  child: _buildDenseInput(
                                    controller: row.articlesController,
                                    hint: '10',
                                    keyboardType: TextInputType.number,
                                    textColor: const Color(0xFF059669),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Category Dropdown
                                SizedBox(
                                  width: 150,
                                  child: Container(
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _unitHierarchy.containsKey(row.unitCategory) ? row.unitCategory : _unitHierarchy.keys.first,
                                        isExpanded: true,
                                        items: _unitHierarchy.keys.map((cat) {
                                          return DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)));
                                        }).toList(),
                                        onChanged: (newCat) {
                                          if (newCat != null) {
                                            setState(() {
                                              row.unitCategory = newCat;
                                              final firstDesc = _unitHierarchy[newCat]?.isNotEmpty == true ? _unitHierarchy[newCat]!.first : null;
                                              if (firstDesc != null) {
                                                row.units = firstDesc['label'] ?? '';
                                                row.hsnController.text = firstDesc['hsn'] ?? '3604';
                                                row.descriptionController.text = firstDesc['goodsDesc'] ?? 'Legacy Goods';
                                              }
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Unit Description Dropdown
                                SizedBox(
                                  width: 190,
                                  child: Container(
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: (_unitHierarchy[row.unitCategory] ?? []).any((u) => u['label'] == row.units)
                                            ? row.units
                                            : ((_unitHierarchy[row.unitCategory] ?? []).isNotEmpty ? _unitHierarchy[row.unitCategory]!.first['label'] : 'Cases of Fireworks'),
                                        isExpanded: true,
                                        items: (_unitHierarchy[row.unitCategory] ?? []).map((u) {
                                          return DropdownMenuItem(
                                            value: u['label'] as String,
                                            child: Text(u['label'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                                          );
                                        }).toList(),
                                        onChanged: (newUnits) {
                                          if (newUnits != null) {
                                            setState(() {
                                              row.units = newUnits;
                                              final match = (_unitHierarchy[row.unitCategory] ?? []).firstWhere((u) => u['label'] == newUnits, orElse: () => {});
                                              if (match.isNotEmpty) {
                                                row.hsnController.text = match['hsn'] ?? '3604';
                                                row.descriptionController.text = match['goodsDesc'] ?? 'Legacy Goods';
                                              }
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // HSN
                                SizedBox(
                                  width: 95,
                                  child: _buildDenseInput(controller: row.hsnController, hint: '3604'),
                                ),
                                const SizedBox(width: 14),

                                // Description
                                Expanded(
                                  child: _buildDenseInput(controller: row.descriptionController, hint: 'Goods description...'),
                                ),
                                const SizedBox(width: 10),

                                // Delete Row
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                  tooltip: 'Delete Line',
                                  onPressed: _goodsRows.length > 1 ? () => _removeGoodsRow(row.id) : null,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addGoodsRow,
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Color(0xFF4F46E5)),
                    label: const Text('Add Another Goods Line', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4F46E5))),
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),

                // Submit Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _resetForm,
                      icon: const Icon(Icons.clear_all_rounded, size: 18),
                      label: const Text('Clear Form', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    ),
                    const SizedBox(width: 14),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                      icon: _isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_rounded, size: 20),
                      label: Text(
                        _editingId != null ? 'Update Consignment' : 'Save Consignment Entry',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                      onPressed: _isSaving ? null : _handleSaveRow,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedRecordsTable() {
    final filtered = _getFilteredRecords();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: Row(
              children: [
                const Icon(Icons.table_chart_rounded, color: Color(0xFF4F46E5), size: 22),
                const SizedBox(width: 10),
                const Text(
                  'SAVED SESSION CONSIGNMENTS',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0F172A), letterSpacing: 0.5),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_savedRecords.length} records in cache',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF4F46E5)),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 280,
                  height: 38,
                  child: TextField(
                    controller: _tableSearchController,
                    onChanged: (val) => setState(() => _tableSearchFilter = val),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'Filter session records...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
                      suffixIcon: _tableSearchFilter.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _tableSearchController.clear();
                                setState(() => _tableSearchFilter = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          if (_savedRecords.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 40, color: Color(0xFFCBD5E1)),
                    SizedBox(height: 12),
                    Text('No records saved in current session yet.', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ] else if (filtered.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text('No session records matching your filter.', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
              ),
            ),
          ] else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                headingTextStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.5),
                dataTextStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                horizontalMargin: 22,
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('GC NUMBER')),
                  DataColumn(label: Text('DATE')),
                  DataColumn(label: Text('CONSIGNOR')),
                  DataColumn(label: Text('CONSIGNEE')),
                  DataColumn(label: Text('GODOWN')),
                  DataColumn(label: Text('E-WAY BILL')),
                  DataColumn(label: Text('INVOICE / VAL')),
                  DataColumn(label: Text('ARTICLES'), numeric: true),
                  DataColumn(label: Text('ACTION')),
                ],
                rows: filtered.map((rec) {
                  final gcNo = rec['gcNumber']?.toString() ?? '-';
                  final date = rec['date']?.toString().split('T').first ?? '-';
                  final cnor = rec['consignor']?['name'] ?? rec['consignorName'] ?? '-';
                  final cnee = rec['consignee']?['name'] ?? rec['consigneeName'] ?? '-';
                  final godown = rec['godown']?.toString() ?? '-';
                  final ewb = rec['ewbNumber']?.toString() ?? '-';
                  final invNo = rec['invoiceNumber']?.toString() ?? '-';
                  final invVal = rec['invoiceValue']?.toString() ?? '';
                  final goods = rec['goods'] as List?;
                  final articles = goods?.isNotEmpty == true ? (goods!.first['articleCount'] ?? goods.first['articles'] ?? '-') : '-';

                  return DataRow(
                    cells: [
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFC7D2FE)),
                          ),
                          child: Text(
                            gcNo,
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4338CA), fontSize: 12),
                          ),
                        ),
                      ),
                      DataCell(Text(date)),
                      DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 180), child: Text(cnor.toString(), overflow: TextOverflow.ellipsis))),
                      DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 180), child: Text(cnee.toString(), overflow: TextOverflow.ellipsis))),
                      DataCell(Text(godown)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(ewb, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
                            if (ewb.isNotEmpty && ewb != '-')
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF94A3B8)),
                                tooltip: 'Copy EWB',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: ewb));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('E-Way Bill copied to clipboard'), duration: Duration(seconds: 1)),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      DataCell(Text('$invNo ${invVal.isNotEmpty ? '(₹$invVal)' : ''}')),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Text(
                            articles.toString(),
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF047857), fontSize: 12),
                          ),
                        ),
                      ),
                      DataCell(
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEEF2FF),
                            foregroundColor: const Color(0xFF4F46E5),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.edit_rounded, size: 14),
                          label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          onPressed: () => _handleEditRecord(rec),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),

            if (_hasMoreRecords) ...[
              Padding(
                padding: const EdgeInsets.all(18),
                child: Center(
                  child: TextButton.icon(
                    onPressed: _isLoadingMore ? null : () => _fetchRecentRecords(loadMore: true),
                    icon: _isLoadingMore
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)))
                        : const Icon(Icons.expand_more_rounded, size: 18),
                    label: const Text('Load More Records', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildDenseInput({
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    Color textColor = const Color(0xFF0F172A),
    FontWeight fontWeight = FontWeight.w600,
    IconData? prefixIcon,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: 13, fontWeight: fontWeight, color: textColor),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 16, color: const Color(0xFF64748B)) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: InputBorder.none,
          isDense: true,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
