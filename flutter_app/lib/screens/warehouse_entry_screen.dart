import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/warehouse_inward.dart';
import '../models/consignor.dart';
import '../models/consignee.dart';
import '../models/godown.dart';
import '../services/api_service.dart';
import '../widgets/barcode_scanner_modal.dart';

class WarehouseEntryScreen extends StatefulWidget {
  const WarehouseEntryScreen({super.key});

  @override
  State<WarehouseEntryScreen> createState() => _WarehouseEntryScreenState();
}

class _WarehouseEntryScreenState extends State<WarehouseEntryScreen> {
  final ScrollController _scrollController = ScrollController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isFetchingEwb = false;
  bool _isSaving = false;
  bool _isLoadingTodayInwards = false;

  final TextEditingController _ewbController = TextEditingController();
  final TextEditingController _consignorNameController = TextEditingController();
  final TextEditingController _consignorPhoneController = TextEditingController();
  final TextEditingController _consigneeNameController = TextEditingController();
  final TextEditingController _consigneeCityController = TextEditingController();
  final TextEditingController _articlesController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  final FocusNode _consignorFocusNode = FocusNode();
  final FocusNode _consigneeFocusNode = FocusNode();

  // Search and filter for Today's Inwards
  final TextEditingController _searchFilterController = TextEditingController();
  String _searchFilter = '';
  String _selectedBayFilter = 'ALL';

  Godown? _selectedGodown;

  List<Godown> _godowns = [];
  List<Consignor> _consignors = [];
  List<Consignee> _consignees = [];

  List<WarehouseInward> _todayInwards = [];
  WarehouseInward? _recentEntry;

  int? _editingInwardId;
  int? _editingReceiptNo;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchFilterController.addListener(() {
      setState(() {
        _searchFilter = _searchFilterController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _ewbController.dispose();
    _consignorNameController.dispose();
    _consignorPhoneController.dispose();
    _consigneeNameController.dispose();
    _consigneeCityController.dispose();
    _articlesController.dispose();
    _remarksController.dispose();
    _consignorFocusNode.dispose();
    _consigneeFocusNode.dispose();
    _searchFilterController.dispose();
    super.dispose();
  }

  String get _todayDateParam {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadInitialData() async {
    try {
      final futures = await Future.wait([
        ApiService.getGodowns(),
        ApiService.getConsignors(),
        ApiService.getConsignees(),
        ApiService.getWarehouseStatement(date: _todayDateParam, page: 1, limit: 100),
      ]);

      setState(() {
        final gList = futures[0] as List<dynamic>;
        _godowns = gList.map((e) => Godown.fromJson(e)).toList();
        _consignors = futures[1] as List<Consignor>;
        _consignees = futures[2] as List<Consignee>;

        final statementRes = futures[3] as Map<String, dynamic>;
        final rawList = statementRes['data'] is List ? statementRes['data'] as List<dynamic> : [];
        _todayInwards = rawList.map((e) => WarehouseInward.fromJson(e)).toList();

        if (_todayInwards.isNotEmpty) {
          _recentEntry = _todayInwards.first;
        }

        if (_godowns.isNotEmpty && _selectedGodown == null) {
          _selectedGodown = _godowns.first;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading warehouse data: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTodayInwardsOnly() async {
    setState(() => _isLoadingTodayInwards = true);
    try {
      final statementRes = await ApiService.getWarehouseStatement(
        date: _todayDateParam,
        page: 1,
        limit: 100,
      );
      final rawList = statementRes['data'] is List ? statementRes['data'] as List<dynamic> : [];
      setState(() {
        _todayInwards = rawList.map((e) => WarehouseInward.fromJson(e)).toList();
        if (_todayInwards.isNotEmpty && _recentEntry == null) {
          _recentEntry = _todayInwards.first;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh today inwards: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingTodayInwards = false);
    }
  }

  Future<String> _getRefinedCity(String? pincode, String? fallbackCity) async {
    if (pincode == null || pincode.isEmpty) return (fallbackCity ?? '').trim().toUpperCase();
    try {
      final postOffices = await ApiService.verifyPincode(pincode);
      if (postOffices.isNotEmpty && postOffices[0]['District'] != null) {
        return postOffices[0]['District'].toString().toUpperCase();
      }
    } catch (_) {}
    return (fallbackCity ?? '').trim().toUpperCase();
  }

  Future<void> _processEwbData(Map<String, dynamic> ewbData) async {
    if (ewbData['fromTrdName'] != null) {
      final cnorName = ewbData['fromTrdName'].toString().replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();
      _consignorNameController.text = cnorName;

      try {
        final existingCnor = _consignors.firstWhere((c) => c.name.toUpperCase() == cnorName);
        _consignorPhoneController.text = existingCnor.phone ?? '';
      } catch (_) {
        try {
          final refinedCity = await _getRefinedCity(
            ewbData['fromPincode']?.toString(),
            ewbData['fromPlace'] ?? ewbData['fromAddr2'],
          );
          final newCnor = await ApiService.saveConsignor({
            'name': cnorName,
            'gstin': ewbData['fromGstin'] ?? '',
            'address': [ewbData['fromAddr1'], ewbData['fromAddr2']]
                .where((e) => e != null && e.toString().isNotEmpty)
                .join(', '),
            'city': refinedCity,
            'state': ewbData['fromStateCode']?.toString() ?? '',
            'pincode': ewbData['fromPincode']?.toString() ?? '',
            'migrationType': 'EWB_LITE_WH'
          });
          _consignors.add(newCnor);
        } catch (_) {}
      }
    }

    if (ewbData['toTrdName'] != null) {
      final cneeName = ewbData['toTrdName'].toString().replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();
      _consigneeNameController.text = cneeName;

      try {
        final existingCnee = _consignees.firstWhere((c) => c.name.toUpperCase() == cneeName);
        _consigneeCityController.text = existingCnee.city?.toUpperCase() ?? '';
      } catch (_) {
        try {
          final refinedCity = await _getRefinedCity(
            ewbData['toPincode']?.toString(),
            ewbData['toPlace'] ?? ewbData['toAddr2'],
          );
          final newCnee = await ApiService.saveConsignee({
            'name': cneeName,
            'gstin': ewbData['toGstin'] ?? '',
            'address': [ewbData['toAddr1'], ewbData['toAddr2']]
                .where((e) => e != null && e.toString().isNotEmpty)
                .join(', '),
            'city': refinedCity,
            'state': ewbData['toStateCode']?.toString() ?? '',
            'pincode': ewbData['toPincode']?.toString() ?? '',
            'migrationType': 'EWB_LITE_WH'
          });
          _consignees.add(newCnee);
          _consigneeCityController.text = refinedCity;
        } catch (e) {
          _consigneeCityController.text = ewbData['toPlace']?.toString().toUpperCase() ?? '';
        }
      }
    } else if (ewbData['toPlace'] != null) {
      _consigneeCityController.text = ewbData['toPlace'].toString().toUpperCase();
    }

    if (ewbData['itemList'] != null && ewbData['itemList'] is List) {
      int totalQty = 0;
      for (var item in (ewbData['itemList'] as List)) {
        totalQty += int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
      }
      _articlesController.text = totalQty.toString();
    }
  }

  Future<void> _fetchEwb() async {
    final ewb = _ewbController.text.trim();
    if (ewb.isEmpty) return;

    setState(() => _isFetchingEwb = true);
    try {
      final data = await ApiService.fetchEWayBill(ewb.replaceAll(' ', ''));
      await _processEwbData(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text('E-Way Bill $ewb successfully decoded and filled!'),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('EWB Fetch Failed: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingEwb = false);
    }
  }

  Future<void> _handleInward() async {
    if (!_formKey.currentState!.validate() || _selectedGodown == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all mandatory fields (Consignor, Consignee, Articles, Godown)'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = {
        'ewayBillNo': _ewbController.text.trim(),
        'consignorName': _consignorNameController.text.trim(),
        if (_editingInwardId == null) 'consignorPhone': _consignorPhoneController.text.trim(),
        'consigneeName': _consigneeNameController.text.trim(),
        'consigneeCity': _consigneeCityController.text.trim(),
        'articles': int.tryParse(_articlesController.text.trim()) ?? 0,
        'godownNo': _selectedGodown!.name,
        'remarks': _remarksController.text.trim(),
      };

      final saved = await ApiService.saveWarehouseInward(payload, id: _editingInwardId);
      final savedEntry = WarehouseInward.fromJson(saved);

      if (mounted) {
        final isUpdating = _editingInwardId != null;
        setState(() {
          _recentEntry = savedEntry;

          if (isUpdating) {
            final idx = _todayInwards.indexWhere((e) => e.id == savedEntry.id);
            if (idx != -1) {
              _todayInwards[idx] = savedEntry;
            } else {
              _todayInwards.insert(0, savedEntry);
            }
          } else {
            _todayInwards.insert(0, savedEntry);
          }

          _editingInwardId = null;
          _editingReceiptNo = null;

          // Clear form
          _ewbController.clear();
          _consignorNameController.clear();
          _consignorPhoneController.clear();
          _consigneeNameController.clear();
          _consigneeCityController.clear();
          _articlesController.clear();
          _remarksController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(isUpdating
                    ? 'Receipt #${savedEntry.receiptNo} updated successfully!'
                    : 'Inward stock allocated to ${savedEntry.godownNo}! (Receipt #${savedEntry.receiptNo})'),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save inward stock: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _startEdit(WarehouseInward entry) {
    setState(() {
      _editingInwardId = entry.id;
      _editingReceiptNo = entry.receiptNo;
      _ewbController.text = entry.ewayBillNo ?? '';
      _consignorNameController.text = entry.consignorName;
      _consignorPhoneController.text = entry.consignorPhone ?? '';
      _consigneeNameController.text = entry.consigneeName;
      _consigneeCityController.text = entry.consigneeCity ?? '';
      _articlesController.text = entry.articles.toString();
      _remarksController.text = entry.remarks ?? '';

      try {
        _selectedGodown = _godowns.firstWhere((g) => g.name == entry.godownNo);
      } catch (_) {}
    });

    _scrollController.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
  }

  void _cancelEdit() {
    setState(() {
      _editingInwardId = null;
      _editingReceiptNo = null;
      _ewbController.clear();
      _consignorNameController.clear();
      _consignorPhoneController.clear();
      _consigneeNameController.clear();
      _consigneeCityController.clear();
      _articlesController.clear();
      _remarksController.clear();
    });
  }

  void _confirmDelete(WarehouseInward entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Delete Inward Receipt', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete Inward Receipt #${entry.receiptNo?.toString().padLeft(5, '0') ?? entry.id} (${entry.articles} articles for ${entry.consigneeName})?\n\nThis will remove the item from warehouse stock.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              if (entry.id == null) return;
              try {
                await ApiService.deleteWarehouseInward(entry.id!);
                setState(() {
                  _todayInwards.removeWhere((e) => e.id == entry.id);
                  if (_recentEntry?.id == entry.id) {
                    _recentEntry = _todayInwards.isNotEmpty ? _todayInwards.first : null;
                  }
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Receipt #${entry.receiptNo} deleted successfully'),
                      backgroundColor: const Color(0xFF059669),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $e'),
                      backgroundColor: const Color(0xFFDC2626),
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _copyDetails(WarehouseInward entry) {
    final rec = entry.receiptNo?.toString().padLeft(5, '0') ?? 'N/A';
    final ewbPart = entry.ewayBillNo != null && entry.ewayBillNo!.isNotEmpty ? " | EWB: ${entry.ewayBillNo!}" : "";
    final text =
        'Receipt #$rec: ${entry.consignorName} -> ${entry.consigneeName} (${entry.consigneeCity ?? ""}) | ${entry.articles} Pkgs | Godown: ${entry.godownNo}$ewbPart';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Receipt #$rec summary copied to clipboard!'),
          ],
        ),
        backgroundColor: const Color(0xFF334155),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleWhatsApp(WarehouseInward entry) async {
    final receiptNo = entry.receiptNo?.toString() ?? 'N/A';
    final cityStr = entry.consigneeCity != null ? '(${entry.consigneeCity})' : '';
    final ewbStr = entry.ewayBillNo?.isNotEmpty == true ? '📄 *E-Way Bill*: ${entry.ewayBillNo}\n' : '';
    final dateStr = entry.createdAt != null
        ? '${entry.createdAt!.day.toString().padLeft(2, '0')}/${entry.createdAt!.month.toString().padLeft(2, '0')}/${entry.createdAt!.year}'
        : '';

    final text = '''
📦 *ARUNACHALAM TRANSPORT ERP*
*Warehouse Inward Receipt #${receiptNo.padLeft(5, '0')}*
----------------------------------------
📅 *Date*: $dateStr
🏢 *From*: ${entry.consignorName}
👤 *To*: ${entry.consigneeName} $cityStr
📦 *Total Articles*: *${entry.articles} Box(es)*
$ewbStr----------------------------------------
✅ *Inward Stock Received at Warehouse*
⚠️ *Note: Final confirmation subject to office verification.*
''';

    final cleanPhone = entry.consignorPhone?.replaceAll(RegExp(r'\D'), '') ?? '';
    final uri = Uri.parse(cleanPhone.isNotEmpty
        ? 'https://wa.me/91$cleanPhone?text=${Uri.encodeComponent(text)}'
        : 'https://wa.me/?text=${Uri.encodeComponent(text)}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    }
  }

  List<WarehouseInward> get _filteredTodayInwards {
    return _todayInwards.where((item) {
      if (_selectedBayFilter != 'ALL') {
        if (item.godownNo != _selectedBayFilter) return false;
      }

      if (_searchFilter.isNotEmpty) {
        final cnor = item.consignorName.toLowerCase();
        final cnee = item.consigneeName.toLowerCase();
        final city = (item.consigneeCity ?? '').toLowerCase();
        final ewb = (item.ewayBillNo ?? '').toLowerCase();
        final recNo = (item.receiptNo?.toString() ?? '').toLowerCase();
        final remarks = (item.remarks ?? '').toLowerCase();
        final bay = item.godownNo.toLowerCase();

        final match = cnor.contains(_searchFilter) ||
            cnee.contains(_searchFilter) ||
            city.contains(_searchFilter) ||
            ewb.contains(_searchFilter) ||
            recNo.contains(_searchFilter) ||
            remarks.contains(_searchFilter) ||
            bay.contains(_searchFilter);
        if (!match) return false;
      }
      return true;
    }).toList();
  }

  int get _todayTotalArticles {
    return _filteredTodayInwards.fold<int>(0, (sum, item) => sum + item.articles);
  }

  Set<String> get _todayBays {
    return _todayInwards.map((e) => e.godownNo).where((b) => b.isNotEmpty).toSet();
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    final local = dt.toLocal();
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.trim().isNotEmpty) {
        final text = data.text!.trim();
        setState(() {
          _ewbController.text = text;
        });
        _fetchEwb();
      }
    } catch (_) {}
  }

  Widget _buildGlassCard({
    required Widget child,
    Color? bgColor,
    Color? borderColor,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 20),
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor ?? const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title, {IconData? icon, Color color = const Color(0xFF4F46E5), Widget? action, bool isMobile = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: isMobile ? 13 : 14,
                      color: const Color(0xFF0F172A),
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  List<Consignor> _filterConsignors(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      return _consignors.take(10).toList();
    }
    return _consignors.where((c) {
      final nameMatch = c.name.toLowerCase().contains(clean);
      final phoneMatch = c.phone != null && c.phone!.toLowerCase().contains(clean);
      final cityMatch = c.city != null && c.city!.toLowerCase().contains(clean);
      final gstinMatch = c.gstin != null && c.gstin!.toLowerCase().contains(clean);
      final addrMatch = c.address != null && c.address!.toLowerCase().contains(clean);
      return nameMatch || phoneMatch || cityMatch || gstinMatch || addrMatch;
    }).take(25).toList();
  }

  List<Consignee> _filterConsignees(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      return _consignees.take(10).toList();
    }
    return _consignees.where((c) {
      final nameMatch = c.name.toLowerCase().contains(clean);
      final phoneMatch = c.phone != null && c.phone!.toLowerCase().contains(clean);
      final cityMatch = c.city != null && c.city!.toLowerCase().contains(clean);
      final gstinMatch = c.gstin != null && c.gstin!.toLowerCase().contains(clean);
      final addrMatch = c.address != null && c.address!.toLowerCase().contains(clean);
      return nameMatch || phoneMatch || cityMatch || gstinMatch || addrMatch;
    }).take(25).toList();
  }

  void _applyPartySelection(dynamic party, {required bool isConsignor}) {
    setState(() {
      if (isConsignor && party is Consignor) {
        _consignorNameController.text = party.name;
        if (party.phone != null && party.phone!.isNotEmpty) {
          _consignorPhoneController.text = party.phone!;
        }
      } else if (!isConsignor && party is Consignee) {
        _consigneeNameController.text = party.name;
        if (party.city != null && party.city!.isNotEmpty) {
          _consigneeCityController.text = party.city!.toUpperCase();
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Selected ${isConsignor ? "Consignor" : "Consignee"}: ${party.name}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openPartySearchSheet({required bool isConsignor}) async {
    final title = isConsignor ? 'Search Consignor / Sender' : 'Search Consignee / Receiver';
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _PartySearchDialog(
          isConsignor: isConsignor,
          title: title,
          initialConsignors: _consignors,
          initialConsignees: _consignees,
          onSelected: (party) => _applyPartySelection(party, isConsignor: isConsignor),
          onCustomNameSelected: (name) {
            setState(() {
              if (isConsignor) {
                _consignorNameController.text = name;
              } else {
                _consigneeNameController.text = name;
              }
            });
          },
        ),
      );
    } else {
      await showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: _PartySearchDialog(
            isConsignor: isConsignor,
            title: title,
            initialConsignors: _consignors,
            initialConsignees: _consignees,
            onSelected: (party) => _applyPartySelection(party, isConsignor: isConsignor),
            onCustomNameSelected: (name) {
              setState(() {
                if (isConsignor) {
                  _consignorNameController.text = name;
                } else {
                  _consigneeNameController.text = name;
                }
              });
            },
          ),
        ),
      );
    }
  }

  Widget _buildConsignorAutocomplete({required bool isMobile, required BoxConstraints constraints}) {
    return RawAutocomplete<Consignor>(
      focusNode: _consignorFocusNode,
      textEditingController: _consignorNameController,
      displayStringForOption: (c) => c.name,
      optionsBuilder: (TextEditingValue textEditingValue) {
        return _filterConsignors(textEditingValue.text);
      },
      onSelected: (Consignor selection) {
        _consignorNameController.text = selection.name;
        if (selection.phone != null && selection.phone!.isNotEmpty) {
          _consignorPhoneController.text = selection.phone!;
        }
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 250,
                maxWidth: isMobile ? (constraints.maxWidth - 32) : 420,
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final c = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.business_rounded, size: 16, color: Color(0xFF4F46E5)),
                    ),
                    title: Text(
                      c.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B)),
                    ),
                    subtitle: (c.city != null && c.city!.isNotEmpty) || (c.phone != null && c.phone!.isNotEmpty)
                        ? Text(
                            [
                              if (c.phone != null && c.phone!.isNotEmpty) '📞 ${c.phone}',
                              if (c.city != null && c.city!.isNotEmpty) '📍 ${c.city}',
                              if (c.gstin != null && c.gstin!.isNotEmpty) 'GST: ${c.gstin}',
                            ].join('  •  '),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          )
                        : null,
                    onTap: () => onSelected(c),
                  );
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: _inputDeco(
            'Consignor / Sender Firm *',
            icon: Icons.business_rounded,
            hintText: 'Search firm, phone, city, or GSTIN',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                    tooltip: 'Clear',
                    onPressed: () {
                      controller.clear();
                      setState(() {});
                    },
                  ),
                InkWell(
                  onTap: () => _openPartySearchSheet(isConsignor: true),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_rounded, size: 16, color: Color(0xFF4F46E5)),
                        SizedBox(width: 4),
                        Text(
                          'SEARCH',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4F46E5),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          onChanged: (_) => setState(() {}),
        );
      },
    );
  }

  Widget _buildConsigneeAutocomplete({required bool isMobile, required BoxConstraints constraints}) {
    return RawAutocomplete<Consignee>(
      focusNode: _consigneeFocusNode,
      textEditingController: _consigneeNameController,
      displayStringForOption: (c) => c.name,
      optionsBuilder: (TextEditingValue textEditingValue) {
        return _filterConsignees(textEditingValue.text);
      },
      onSelected: (Consignee selection) {
        _consigneeNameController.text = selection.name;
        if (selection.city != null && selection.city!.isNotEmpty) {
          _consigneeCityController.text = selection.city!.toUpperCase();
        }
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 250,
                maxWidth: isMobile ? (constraints.maxWidth - 32) : 420,
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final c = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person_pin_rounded, size: 16, color: Color(0xFF0D9488)),
                    ),
                    title: Text(
                      c.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B)),
                    ),
                    subtitle: (c.city != null && c.city!.isNotEmpty) || (c.phone != null && c.phone!.isNotEmpty)
                        ? Text(
                            [
                              if (c.city != null && c.city!.isNotEmpty) '📍 ${c.city}',
                              if (c.phone != null && c.phone!.isNotEmpty) '📞 ${c.phone}',
                              if (c.gstin != null && c.gstin!.isNotEmpty) 'GST: ${c.gstin}',
                            ].join('  •  '),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          )
                        : null,
                    onTap: () => onSelected(c),
                  );
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: _inputDeco(
            'Consignee / Receiver Firm *',
            icon: Icons.person_pin_rounded,
            hintText: 'Search receiver, city, phone, or GSTIN',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                    tooltip: 'Clear',
                    onPressed: () {
                      controller.clear();
                      setState(() {});
                    },
                  ),
                InkWell(
                  onTap: () => _openPartySearchSheet(isConsignor: false),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF99F6E4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_rounded, size: 16, color: Color(0xFF0D9488)),
                        SizedBox(width: 4),
                        Text(
                          'SEARCH',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0D9488),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          onChanged: (_) => setState(() {}),
        );
      },
    );
  }

  InputDecoration _inputDeco(String label, {IconData? icon, String? hintText, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600),
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13, fontWeight: FontWeight.normal),
      prefixIcon: icon != null ? Icon(icon, size: 18, color: const Color(0xFF64748B)) : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.8),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isMobile = false,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12 : 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 8 : 12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: isMobile ? 18 : 22),
            ),
            SizedBox(width: isMobile ? 10 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isMobile ? 9.5 : 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: isMobile ? 17 : 20,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileInwardCard(WarehouseInward entry) {
    final isEditingThis = _editingInwardId == entry.id;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEditingThis ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
          width: isEditingThis ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Receipt #, Time, Bay
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: Text(
                      '#${entry.receiptNo?.toString().padLeft(5, '0') ?? entry.id}',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4338CA), fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(entry.createdAt),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warehouse_rounded, size: 12, color: Color(0xFF475569)),
                    const SizedBox(width: 4),
                    Text(
                      entry.godownNo,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF334155), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Parties route
          Text(
            entry.consignorName,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
          ),
          if (entry.consignorPhone != null && entry.consignorPhone!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                'Phone: ${entry.consignorPhone}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: Color(0xFF0D9488)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${entry.consigneeName}${entry.consigneeCity != null && entry.consigneeCity!.isNotEmpty ? " (${entry.consigneeCity!.toUpperCase()})" : ""}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0D9488)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Chips: Articles & EWB
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.inventory_2_rounded, size: 12, color: Color(0xFF059669)),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.articles} Packages',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF065F46), fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (entry.ewayBillNo != null && entry.ewayBillNo!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.qr_code_2_rounded, size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        entry.ewayBillNo!,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, fontFamily: 'monospace', color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          if (entry.remarks != null && entry.remarks!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Note: ${entry.remarks}',
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
              ),
            ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Actions Row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                  label: const Text('WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _handleWhatsApp(entry),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _startEdit(entry),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF64748B)),
                tooltip: 'Copy Info',
                onPressed: () => _copyDetails(entry),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Color(0xFFDC2626)),
                tooltip: 'Delete Entry',
                onPressed: () => _confirmDelete(entry),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
    }

    final filtered = _filteredTodayInwards;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        return SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 24,
            vertical: isMobile ? 14 : 24,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1220),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Cockpit Banner
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 24,
                      vertical: isMobile ? 16 : 20,
                    ),
                    margin: EdgeInsets.only(bottom: isMobile ? 16 : 24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(isMobile ? 18 : 22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF312E81).withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                        ),
                                        child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Warehouse Inward',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF34D399),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${_godowns.length} Bays',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Mobile dock scanner, E-Way Bill decoder & instant WhatsApp dispatch',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: const Color(0xFFE0E7FF).withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                ),
                                child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'Warehouse Inward & Parcel Hub',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFC7D2FE).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFA5B4FC).withValues(alpha: 0.4)),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.inventory_2_rounded, size: 12, color: Color(0xFFE0E7FF)),
                                              SizedBox(width: 5),
                                              Text(
                                                'GODOWN LOGISTICS',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 10,
                                                  color: Color(0xFFE0E7FF),
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Rapid E-Way Bill barcode decoding, godown bay allocation & instant consignee dispatch notification',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: const Color(0xFFE0E7FF).withValues(alpha: 0.85),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF34D399),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF34D399).withValues(alpha: 0.6),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${_godowns.length} Active Godowns',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),

                  // Scanner / E-Way Bill Barcode Section
                  _buildGlassCard(
                    padding: EdgeInsets.all(isMobile ? 16 : 22),
                    margin: EdgeInsets.only(bottom: isMobile ? 16 : 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          'Rapid E-Way Bill Barcode & Decoder',
                          icon: Icons.qr_code_scanner_rounded,
                          color: const Color(0xFF4F46E5),
                          isMobile: isMobile,
                        ),
                        if (isMobile) ...[
                          TextFormField(
                            controller: _ewbController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDeco(
                              '12-digit E-Way Bill Number',
                              icon: Icons.barcode_reader,
                              hintText: 'e.g., 231456789012',
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Color(0xFF059669)),
                                    tooltip: 'Scan Camera Barcode / QR',
                                    onPressed: () async {
                                      final scanned = await BarcodeScannerModal.show(
                                        context,
                                        title: 'Scan E-Way Bill',
                                        subtitle: 'Point camera at E-Way Bill QR or Barcode',
                                      );
                                      if (scanned != null && scanned.isNotEmpty) {
                                        _ewbController.text = scanned;
                                        _fetchEwb();
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.content_paste_rounded, size: 18, color: Color(0xFF4F46E5)),
                                    tooltip: 'Paste & Decode',
                                    onPressed: _pasteFromClipboard,
                                  ),
                                ],
                              ),
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 1.5,
                              color: Color(0xFF0F172A),
                            ),
                            onFieldSubmitted: (_) => _fetchEwb(),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Color(0xFF059669)),
                              label: const Text(
                                'SCAN E-WAY BILL WITH CAMERA',
                                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5, fontSize: 13, color: Color(0xFF059669)),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                                backgroundColor: const Color(0xFFECFDF5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () async {
                                final scanned = await BarcodeScannerModal.show(
                                  context,
                                  title: 'Scan E-Way Bill',
                                  subtitle: 'Point camera at E-Way Bill QR or Barcode',
                                );
                                if (scanned != null && scanned.isNotEmpty) {
                                  _ewbController.text = scanned;
                                  _fetchEwb();
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              icon: _isFetchingEwb
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.bolt_rounded, size: 20),
                              label: Text(
                                _isFetchingEwb ? 'FETCHING EWB...' : 'DECODE & AUTO-FILL E-WAY BILL',
                                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5, fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _isFetchingEwb ? null : _fetchEwb,
                            ),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _ewbController,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDeco(
                                    '12-digit E-Way Bill Number',
                                    icon: Icons.barcode_reader,
                                    hintText: 'e.g., 231456789012 or scan barcode',
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.content_paste_rounded, size: 18, color: Color(0xFF4F46E5)),
                                      tooltip: 'Paste from clipboard',
                                      onPressed: _pasteFromClipboard,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    letterSpacing: 2,
                                    color: Color(0xFF0F172A),
                                  ),
                                  onFieldSubmitted: (_) => _fetchEwb(),
                                ),
                              ),
                              const SizedBox(width: 14),
                              ElevatedButton.icon(
                                icon: _isFetchingEwb
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.bolt_rounded, size: 20),
                                label: Text(
                                  _isFetchingEwb ? 'FETCHING EWB...' : 'DECODE & FILL',
                                  style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                                  backgroundColor: const Color(0xFF4F46E5),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: _isFetchingEwb ? null : _fetchEwb,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Recent Inward Quick WhatsApp Dispatch Card (Instant floor action)
                  if (_recentEntry != null)
                    Container(
                      margin: EdgeInsets.only(bottom: isMobile ? 16 : 22),
                      padding: EdgeInsets.all(isMobile ? 14 : 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Recent Inward Receipt #${_recentEntry!.receiptNo?.toString().padLeft(5, '0') ?? _recentEntry!.id}',
                                    style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF14532D), fontSize: 13),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF86EFAC)),
                                ),
                                child: Text(
                                  _recentEntry!.godownNo,
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF15803D), fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_recentEntry!.consignorName} ➔ ${_recentEntry!.consigneeName}${_recentEntry!.consigneeCity != null && _recentEntry!.consigneeCity!.isNotEmpty ? " (${_recentEntry!.consigneeCity})" : ""}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_recentEntry!.articles} Box(es) received into storage bay',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                              label: const Text('DISPATCH WHATSAPP RECEIPT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: () => _handleWhatsApp(_recentEntry!),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Inward Form (with Edit banner if editing)
                  _buildGlassCard(
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    margin: EdgeInsets.only(bottom: isMobile ? 16 : 24),
                    borderColor: _editingInwardId != null ? const Color(0xFFF59E0B) : null,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Edit Mode Alert Banner
                          if (_editingInwardId != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 18),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.edit_note_rounded, color: Color(0xFFD97706), size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Editing Mode: Updating Receipt #${_editingReceiptNo?.toString().padLeft(5, '0') ?? _editingInwardId}.',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF92400E)),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _cancelEdit,
                                    icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF92400E)),
                                    label: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF92400E), fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: _buildSectionHeader(
                                  _editingInwardId != null
                                      ? 'Edit Details (Receipt #${_editingReceiptNo?.toString().padLeft(5, '0')})'
                                      : 'Inward Consignment & Godown Bay',
                                  icon: Icons.warehouse_rounded,
                                  color: _editingInwardId != null ? const Color(0xFFD97706) : const Color(0xFF0D9488),
                                  isMobile: isMobile,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _editingInwardId != null ? _cancelEdit : () {
                                  _ewbController.clear();
                                  _consignorNameController.clear();
                                  _consignorPhoneController.clear();
                                  _consigneeNameController.clear();
                                  _consigneeCityController.clear();
                                  _articlesController.clear();
                                  _remarksController.clear();
                                },
                                icon: Icon(
                                  _editingInwardId != null ? Icons.close_rounded : Icons.refresh_rounded,
                                  size: 16,
                                  color: const Color(0xFF64748B),
                                ),
                                label: Text(
                                  _editingInwardId != null ? 'Cancel' : 'Clear Form',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B), fontSize: 12),
                                ),
                              ),
                            ],
                          ),

                          // Consignor & Consignor Phone
                          if (isMobile) ...[
                            _buildConsignorAutocomplete(isMobile: true, constraints: constraints),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _consignorPhoneController,
                              keyboardType: TextInputType.phone,
                              decoration: _inputDeco(
                                'Consignor Phone (for WhatsApp receipt)',
                                icon: Icons.phone_rounded,
                                hintText: '10-digit mobile number',
                              ),
                            ),
                          ] else ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildConsignorAutocomplete(isMobile: false, constraints: constraints),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _consignorPhoneController,
                                    decoration: _inputDeco(
                                      'Consignor Phone',
                                      icon: Icons.phone_rounded,
                                      hintText: '10-digit mobile number',
                                    ),
                                    keyboardType: TextInputType.phone,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Consignee & Destination City
                          if (isMobile) ...[
                            _buildConsigneeAutocomplete(isMobile: true, constraints: constraints),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _consigneeCityController,
                              decoration: _inputDeco(
                                'Destination City / Zone',
                                icon: Icons.location_city_rounded,
                                hintText: 'e.g., CHENNAI',
                              ),
                            ),
                          ] else ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildConsigneeAutocomplete(isMobile: false, constraints: constraints),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _consigneeCityController,
                                    decoration: _inputDeco(
                                      'Destination City / Zone',
                                      icon: Icons.location_city_rounded,
                                      hintText: 'e.g., CHENNAI',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Package Quantity & Godown Destination
                          if (isMobile) ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: _articlesController,
                                  decoration: _inputDeco(
                                    'Total Articles / Boxes *',
                                    icon: Icons.inventory_2_rounded,
                                    hintText: 'e.g., 25',
                                  ),
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                ),
                                const SizedBox(height: 8),
                                // Quick increment chips
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      ...[1, 5, 10, 25, 50, 100].map((inc) {
                                        return Padding(
                                          padding: const EdgeInsets.only(right: 6.0),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(8),
                                            onTap: () {
                                              final current = int.tryParse(_articlesController.text.trim()) ?? 0;
                                              _articlesController.text = (current + inc).toString();
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                              ),
                                              child: Text(
                                                '+$inc',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF334155),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => _articlesController.text = '',
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEE2E2),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFFECACA)),
                                          ),
                                          child: const Text(
                                            'Clear',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFFDC2626),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<Godown>(
                              value: _selectedGodown,
                              decoration: _inputDeco('Storage Godown / Bay *', icon: Icons.warehouse_rounded),
                              items: _godowns
                                  .map((g) => DropdownMenuItem(
                                        value: g,
                                        child: Row(
                                          children: [
                                            const Icon(Icons.shelves, size: 16, color: Color(0xFF4F46E5)),
                                            const SizedBox(width: 8),
                                            Text(
                                              g.name,
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedGodown = v),
                              validator: (v) => v == null ? 'Required' : null,
                            ),
                          ] else ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TextFormField(
                                        controller: _articlesController,
                                        decoration: _inputDeco(
                                          'Total Articles / Boxes *',
                                          icon: Icons.inventory_2_rounded,
                                          hintText: 'e.g., 25',
                                        ),
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                      ),
                                      const SizedBox(height: 6),
                                      // Quick increment chips
                                      Wrap(
                                        spacing: 6,
                                        children: [1, 5, 10, 25, 50].map((inc) {
                                          return InkWell(
                                            borderRadius: BorderRadius.circular(6),
                                            onTap: () {
                                              final current = int.tryParse(_articlesController.text.trim()) ?? 0;
                                              _articlesController.text = (current + inc).toString();
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                              ),
                                              child: Text(
                                                '+$inc',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF475569),
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      DropdownButtonFormField<Godown>(
                                        value: _selectedGodown,
                                        decoration: _inputDeco('Storage Godown / Bay *', icon: Icons.warehouse_rounded),
                                        items: _godowns
                                            .map((g) => DropdownMenuItem(
                                                  value: g,
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.shelves, size: 16, color: Color(0xFF4F46E5)),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        g.name,
                                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                                      ),
                                                    ],
                                                  ),
                                                ))
                                            .toList(),
                                        onChanged: (v) => setState(() => _selectedGodown = v),
                                        validator: (v) => v == null ? 'Required' : null,
                                      ),
                                      const SizedBox(height: 28),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 14),

                          // Remarks
                          TextFormField(
                            controller: _remarksController,
                            maxLines: isMobile ? 2 : 1,
                            decoration: _inputDeco(
                              'Handling Instructions & Damage Notes',
                              icon: Icons.notes_rounded,
                              hintText: 'e.g., Fragile, handle with care, stored in Bay A-3',
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Action Buttons
                          if (isMobile) ...[
                            if (_editingInwardId != null) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        foregroundColor: const Color(0xFF64748B),
                                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: _cancelEdit,
                                      child: const Text('CANCEL EDIT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      icon: _isSaving
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Icon(Icons.save_rounded, size: 18),
                                      label: Text(
                                        _isSaving ? 'UPDATING...' : 'UPDATE INWARD',
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        backgroundColor: const Color(0xFFD97706),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: _isSaving ? null : _handleInward,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton.icon(
                                  icon: _isSaving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.check_circle_rounded, size: 20),
                                  label: Text(
                                    _isSaving ? 'ALLOCATING STOCK...' : 'CONFIRM & ALLOCATE INWARD STOCK',
                                    style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5, fontSize: 13),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF059669),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: _isSaving ? null : _handleInward,
                                ),
                              ),
                            ],
                          ] else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (_editingInwardId != null) ...[
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    label: const Text('CANCEL EDIT', style: TextStyle(fontWeight: FontWeight.w800)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                                      foregroundColor: const Color(0xFF64748B),
                                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    onPressed: _cancelEdit,
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                ElevatedButton.icon(
                                  icon: _isSaving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : Icon(_editingInwardId != null ? Icons.save_rounded : Icons.check_circle_rounded, size: 20),
                                  label: Text(
                                    _isSaving
                                        ? (_editingInwardId != null ? 'UPDATING...' : 'ALLOCATING STOCK...')
                                        : (_editingInwardId != null ? 'UPDATE INWARD ENTRY' : 'CONFIRM & ALLOCATE INWARD STOCK'),
                                    style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                                    backgroundColor: _editingInwardId != null ? const Color(0xFFD97706) : const Color(0xFF059669),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  onPressed: _isSaving ? null : _handleInward,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // KPI Metrics Cards (Today's Summary)
                  Padding(
                    padding: EdgeInsets.only(bottom: isMobile ? 16.0 : 24.0),
                    child: isMobile
                        ? Column(
                            children: [
                              Row(
                                children: [
                                  _buildKpiCard(
                                    title: "TODAY'S INWARDS",
                                    value: "${_todayInwards.length}",
                                    subtitle: "Consignments",
                                    icon: Icons.receipt_long_rounded,
                                    color: const Color(0xFF4F46E5),
                                    isMobile: true,
                                  ),
                                  const SizedBox(width: 10),
                                  _buildKpiCard(
                                    title: "TOTAL ARTICLES",
                                    value: "$_todayTotalArticles",
                                    subtitle: "Pkgs Received",
                                    icon: Icons.inventory_2_rounded,
                                    color: const Color(0xFF0D9488),
                                    isMobile: true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _buildKpiCard(
                                    title: "ACTIVE BAYS",
                                    value: "${_todayBays.length}",
                                    subtitle: "Storage Bays",
                                    icon: Icons.warehouse_rounded,
                                    color: const Color(0xFFF59E0B),
                                    isMobile: true,
                                  ),
                                  const SizedBox(width: 10),
                                  _buildKpiCard(
                                    title: "EWB LINKED",
                                    value: "${_todayInwards.where((e) => e.ewayBillNo != null && e.ewayBillNo!.isNotEmpty).length}",
                                    subtitle: "Verified Barcodes",
                                    icon: Icons.qr_code_2_rounded,
                                    color: const Color(0xFF059669),
                                    isMobile: true,
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              _buildKpiCard(
                                title: "TODAY'S INWARDS",
                                value: "${_todayInwards.length}",
                                subtitle: "Consignments Received",
                                icon: Icons.receipt_long_rounded,
                                color: const Color(0xFF4F46E5),
                              ),
                              const SizedBox(width: 16),
                              _buildKpiCard(
                                title: "TOTAL ARTICLES",
                                value: "$_todayTotalArticles",
                                subtitle: "Boxes / Packages",
                                icon: Icons.inventory_2_rounded,
                                color: const Color(0xFF0D9488),
                              ),
                              const SizedBox(width: 16),
                              _buildKpiCard(
                                title: "ACTIVE BAYS",
                                value: "${_todayBays.length}",
                                subtitle: "Godown Storage Bays",
                                icon: Icons.warehouse_rounded,
                                color: const Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 16),
                              _buildKpiCard(
                                title: "EWB LINKED",
                                value: "${_todayInwards.where((e) => e.ewayBillNo != null && e.ewayBillNo!.isNotEmpty).length}",
                                subtitle: "Verified Barcodes",
                                icon: Icons.qr_code_2_rounded,
                                color: const Color(0xFF059669),
                              ),
                            ],
                          ),
                  ),

                  // Today's Inward Consignments Log & Quick Action Panel
                  _buildGlassCard(
                    padding: EdgeInsets.all(isMobile ? 14 : 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _buildSectionHeader(
                                "Today's Inward Consignments (${filtered.length})",
                                icon: Icons.history_rounded,
                                color: const Color(0xFF4F46E5),
                                isMobile: isMobile,
                              ),
                            ),
                            Row(
                              children: [
                                if (!isMobile)
                                  Text(
                                    "Date: ${_todayDateParam.split('-').reversed.join('/')}",
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: _isLoadingTodayInwards ? null : _fetchTodayInwardsOnly,
                                  icon: _isLoadingTodayInwards
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                                        )
                                      : const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF4F46E5)),
                                  tooltip: "Refresh Inward Log",
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Search & Bay Filter Toolbar
                        if (isMobile) ...[
                          TextField(
                            controller: _searchFilterController,
                            decoration: InputDecoration(
                              hintText: 'Search Party, City, EWB, Receipt #...',
                              hintStyle: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13),
                              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                              suffixIcon: _searchFilter.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 16),
                                      onPressed: () => _searchFilterController.clear(),
                                    )
                                  : null,
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedBayFilter,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                items: [
                                  const DropdownMenuItem(value: 'ALL', child: Text('All Godown Storage Bays')),
                                  ..._godowns.map((g) => DropdownMenuItem(value: g.name, child: Text('Filter: ${g.name}'))),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedBayFilter = val);
                                },
                              ),
                            ),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _searchFilterController,
                                  decoration: InputDecoration(
                                    hintText: 'Search by Consignor, Consignee, City, EWB, Receipt #...',
                                    hintStyle: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13),
                                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                                    suffixIcon: _searchFilter.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear_rounded, size: 16),
                                            onPressed: () => _searchFilterController.clear(),
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedBayFilter,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                    items: [
                                      const DropdownMenuItem(value: 'ALL', child: Text('All Godown Bays')),
                                      ..._godowns.map((g) => DropdownMenuItem(value: g.name, child: Text(g.name))),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedBayFilter = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),

                        // List / Table
                        if (filtered.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.inbox_rounded, size: 36, color: Color(0xFF94A3B8)),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _searchFilter.isNotEmpty
                                      ? 'No inwards matching "$_searchFilter"'
                                      : 'No inward consignments recorded today yet.',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _searchFilter.isNotEmpty
                                      ? 'Try clearing the search query or bay filter.'
                                      : 'Scan an E-Way Bill or fill the form above to allocate stock into bays.',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          )
                        else if (isMobile)
                          // Mobile Native Card Feed
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              return _buildMobileInwardCard(filtered[index]);
                            },
                          )
                        else
                          // Desktop Wide Table
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(minWidth: 1120),
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                    headingRowHeight: 44,
                                    dataRowMinHeight: 52,
                                    dataRowMaxHeight: 64,
                                    horizontalMargin: 16,
                                    columnSpacing: 20,
                                    columns: const [
                                      DataColumn(
                                        label: Text(
                                          'RECEIPT #',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'TIME',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'CONSIGNOR (SENDER)',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'CONSIGNEE & DESTINATION',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'ARTICLES',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'GODOWN BAY',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'E-WAY BILL',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'ACTIONS',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5),
                                        ),
                                      ),
                                    ],
                                    rows: filtered.map((entry) {
                                      final isEditingThis = _editingInwardId == entry.id;
                                      return DataRow(
                                        color: isEditingThis
                                            ? WidgetStateProperty.all(const Color(0xFFFEF3C7).withValues(alpha: 0.4))
                                            : null,
                                        cells: [
                                          // Receipt #
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEEF2FF),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFC7D2FE)),
                                              ),
                                              child: Text(
                                                '#${entry.receiptNo?.toString().padLeft(5, '0') ?? entry.id}',
                                                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4338CA), fontSize: 13),
                                              ),
                                            ),
                                          ),

                                          // Time
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF94A3B8)),
                                                const SizedBox(width: 5),
                                                Text(
                                                  _formatTime(entry.createdAt),
                                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF475569)),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Consignor
                                          DataCell(
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 190),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    entry.consignorName,
                                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (entry.consignorPhone != null && entry.consignorPhone!.isNotEmpty)
                                                    Text(
                                                      entry.consignorPhone!,
                                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          // Consignee & City
                                          DataCell(
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 200),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    entry.consigneeName,
                                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (entry.consigneeCity != null && entry.consigneeCity!.isNotEmpty)
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFF0D9488)),
                                                        const SizedBox(width: 3),
                                                        Text(
                                                          entry.consigneeCity!.toUpperCase(),
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w800,
                                                            color: Color(0xFF0D9488),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          // Articles
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFECFDF5),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFA7F3D0)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.inventory_2_rounded, size: 13, color: Color(0xFF059669)),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    '${entry.articles} Pkgs',
                                                    style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF065F46), fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          // Godown Bay
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.warehouse_rounded, size: 13, color: Color(0xFF475569)),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    entry.godownNo,
                                                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF334155), fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          // E-Way Bill
                                          DataCell(
                                            entry.ewayBillNo != null && entry.ewayBillNo!.isNotEmpty
                                                ? Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF8FAFC),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                                    ),
                                                    child: Text(
                                                      entry.ewayBillNo!,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 11,
                                                        fontFamily: 'monospace',
                                                        color: Color(0xFF334155),
                                                      ),
                                                    ),
                                                  )
                                                : const Text('-', style: TextStyle(color: Color(0xFF94A3B8))),
                                          ),

                                          // Actions
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF16A34A)),
                                                  tooltip: 'WhatsApp Receipt',
                                                  onPressed: () => _handleWhatsApp(entry),
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                                                  tooltip: 'Edit Consignment',
                                                  onPressed: () => _startEdit(entry),
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF64748B)),
                                                  tooltip: 'Copy Info',
                                                  onPressed: () => _copyDetails(entry),
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                                  tooltip: 'Delete Entry',
                                                  onPressed: () => _confirmDelete(entry),
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
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
          ),
        );
      },
    );
  }
}

class _PartySearchDialog extends StatefulWidget {
  final bool isConsignor;
  final String title;
  final List<Consignor> initialConsignors;
  final List<Consignee> initialConsignees;
  final Function(dynamic) onSelected;
  final Function(String) onCustomNameSelected;

  const _PartySearchDialog({
    required this.isConsignor,
    required this.title,
    required this.initialConsignors,
    required this.initialConsignees,
    required this.onSelected,
    required this.onCustomNameSelected,
  });

  @override
  State<_PartySearchDialog> createState() => _PartySearchDialogState();
}

class _PartySearchDialogState extends State<_PartySearchDialog> {
  final TextEditingController _queryController = TextEditingController();
  List<dynamic> _filteredList = [];
  bool _isSearchingServer = false;

  @override
  void initState() {
    super.initState();
    _applyLocalFilter('');
    _queryController.addListener(() {
      _applyLocalFilter(_queryController.text);
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _applyLocalFilter(String q) {
    final clean = q.trim().toLowerCase();
    setState(() {
      if (widget.isConsignor) {
        if (clean.isEmpty) {
          _filteredList = widget.initialConsignors.take(20).toList();
        } else {
          _filteredList = widget.initialConsignors.where((c) {
            final nameMatch = c.name.toLowerCase().contains(clean);
            final phoneMatch = c.phone != null && c.phone!.toLowerCase().contains(clean);
            final cityMatch = c.city != null && c.city!.toLowerCase().contains(clean);
            final gstinMatch = c.gstin != null && c.gstin!.toLowerCase().contains(clean);
            final addrMatch = c.address != null && c.address!.toLowerCase().contains(clean);
            return nameMatch || phoneMatch || cityMatch || gstinMatch || addrMatch;
          }).take(50).toList();
        }
      } else {
        if (clean.isEmpty) {
          _filteredList = widget.initialConsignees.take(20).toList();
        } else {
          _filteredList = widget.initialConsignees.where((c) {
            final nameMatch = c.name.toLowerCase().contains(clean);
            final phoneMatch = c.phone != null && c.phone!.toLowerCase().contains(clean);
            final cityMatch = c.city != null && c.city!.toLowerCase().contains(clean);
            final gstinMatch = c.gstin != null && c.gstin!.toLowerCase().contains(clean);
            final addrMatch = c.address != null && c.address!.toLowerCase().contains(clean);
            return nameMatch || phoneMatch || cityMatch || gstinMatch || addrMatch;
          }).take(50).toList();
        }
      }
    });
  }

  Future<void> _searchServer() async {
    final q = _queryController.text.trim();
    if (q.isEmpty) return;

    setState(() {
      _isSearchingServer = true;
    });

    try {
      if (widget.isConsignor) {
        final results = await ApiService.getConsignors(query: q, limit: 100);
        if (mounted && _queryController.text.trim() == q) {
          setState(() {
            _filteredList = results;
          });
        }
      } else {
        final results = await ApiService.getConsignees(query: q, limit: 100);
        if (mounted && _queryController.text.trim() == q) {
          setState(() {
            _filteredList = results;
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearchingServer = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final primaryColor = widget.isConsignor ? const Color(0xFF4F46E5) : const Color(0xFF0D9488);
    final accentBg = widget.isConsignor ? const Color(0xFFEEF2FF) : const Color(0xFFF0FDFA);
    final queryText = _queryController.text.trim();

    return Container(
      width: isMobile ? double.infinity : 560,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
        maxWidth: 620,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isMobile
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle for mobile
          if (isMobile)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    widget.isConsignor ? Icons.business_rounded : Icons.person_pin_rounded,
                    color: primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Text(
                        'Search across Name, Phone, City, and GSTIN',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              controller: _queryController,
              autofocus: true,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Type firm name, 10-digit phone, city, or GSTIN...',
                hintStyle: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13, fontWeight: FontWeight.normal),
                prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 20),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_queryController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                        onPressed: () => _queryController.clear(),
                      ),
                    IconButton(
                      icon: _isSearchingServer
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.cloud_sync_rounded, size: 20, color: primaryColor),
                      tooltip: 'Deep Search Master DB',
                      onPressed: _searchServer,
                    ),
                  ],
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
              onSubmitted: (_) => _searchServer(),
            ),
          ),

          // Count info bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${_filteredList.length} matching parties found',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                ),
                const Spacer(),
                if (queryText.isNotEmpty)
                  GestureDetector(
                    onTap: _searchServer,
                    child: Text(
                      'Deep search DB ➔',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Custom Name Quick Option if query is typed
          if (queryText.isNotEmpty && !_filteredList.any((p) => p.name.toString().toLowerCase() == queryText.toLowerCase()))
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.edit_note_rounded, color: Color(0xFFD97706), size: 22),
                title: Text(
                  'Use "$queryText" as unregistered name',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF92400E)),
                ),
                subtitle: const Text(
                  'Tap to fill this custom walk-in name into the form',
                  style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFFD97706)),
                onTap: () {
                  widget.onCustomNameSelected(queryText);
                  Navigator.of(context).pop();
                },
              ),
            ),

          // Results List
          Flexible(
            child: _filteredList.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search_rounded, size: 48, color: Colors.blueGrey.shade200),
                        const SizedBox(height: 12),
                        Text(
                          queryText.isEmpty ? 'No parties available' : 'No matches found for "$queryText"',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        if (queryText.isNotEmpty) ...[
                          Text(
                            'You can tap "Use \'$queryText\'" above or click below to search the master database.',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.cloud_sync_rounded, size: 16),
                            label: const Text('Search Master DB Server', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            onPressed: _searchServer,
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filteredList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final party = _filteredList[index];
                      final name = party.name as String;
                      final phone = party.phone as String?;
                      final city = party.city as String?;
                      final gstin = party.gstin as String?;
                      final address = party.address as String?;

                      return InkWell(
                        onTap: () {
                          widget.onSelected(party);
                          Navigator.of(context).pop();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: accentBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      widget.isConsignor ? Icons.business_rounded : Icons.person_pin_rounded,
                                      size: 16,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
                                ],
                              ),
                              if ((phone != null && phone.isNotEmpty) ||
                                  (city != null && city.isNotEmpty) ||
                                  (gstin != null && gstin.isNotEmpty)) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    if (phone != null && phone.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFA7F3D0)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.phone_rounded, size: 12, color: Color(0xFF059669)),
                                            const SizedBox(width: 4),
                                            Text(
                                              phone,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF065F46),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (city != null && city.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0F9FF),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFBAE6FD)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFF0284C7)),
                                            const SizedBox(width: 4),
                                            Text(
                                              city.toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF075985),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (gstin != null && gstin.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: Text(
                                          'GST: $gstin',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                              if (address != null && address.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
