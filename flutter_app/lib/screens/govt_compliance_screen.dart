import 'package:flutter/material.dart';
import '../services/api_service.dart';

class GovtComplianceScreen extends StatefulWidget {
  const GovtComplianceScreen({super.key});

  @override
  State<GovtComplianceScreen> createState() => _GovtComplianceScreenState();
}

class _GovtComplianceScreenState extends State<GovtComplianceScreen> {
  List<dynamic> _pendingGdms = [];
  bool _isLoading = false;
  final Set<int> _selectedGdmIds = {};
  
  bool _isVerifying = false;
  bool _isHealing = false;
  bool _isGeneratingCewb = false;
  String? _activeVehicleNo;
  String _gdmSearchQuery = '';
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _fetchPendingGdms();
  }

  Future<void> _fetchPendingGdms() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final branch = ApiService.activeBranch.isNotEmpty ? ApiService.activeBranch : 'MAIN';
      final res = await ApiService.getPendingGdmsForCewb(branch);
      if (mounted) {
        setState(() {
          _pendingGdms = res;
          _selectedGdmIds.clear();
          _activeVehicleNo = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load pending GDMs: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleSelection(int gdmId, String vehicleNo) {
    setState(() {
      _errorMessage = null;
      _successMessage = null;

      if (_selectedGdmIds.contains(gdmId)) {
        _selectedGdmIds.remove(gdmId);
        if (_selectedGdmIds.isEmpty) {
          _activeVehicleNo = null;
        }
      } else {
        if (_activeVehicleNo != null && _activeVehicleNo != vehicleNo) {
          _errorMessage = 'Multi-Vehicle Constraint: You can only bundle GDMs for the same Lorry ($vehicleNo vs $_activeVehicleNo) into a Consolidated E-Way Bill.';
          return;
        }
        _selectedGdmIds.add(gdmId);
        _activeVehicleNo = vehicleNo;
      }
    });
  }

  List<dynamic> get _selectedGdms => _pendingGdms.where((gdm) => _selectedGdmIds.contains(gdm['id'])).toList();

  List<dynamic> get _allSelectedGcs {
    final List<dynamic> gcs = [];
    for (var gdm in _selectedGdms) {
      if (gdm['gcs'] != null) {
        for (var gc in gdm['gcs']) {
          final gcNum = gc['gcNumber']?.toString().toUpperCase() ?? '';
          final isBell = gcNum.startsWith('BELL');
          gcs.add({
            ...gc,
            'gdmNumber': gdm['gdmNumber'],
            'gdmDate': gdm['date'],
            'companyString': isBell ? 'BELL' : 'AP'
          });
        }
      }
    }
    return gcs;
  }

  int get _totalArticlesInStaging {
    int total = 0;
    for (var gc in _allSelectedGcs) {
      final goods = gc['goods'] as List<dynamic>?;
      if (goods != null && goods.isNotEmpty) {
        for (var item in goods) {
          total += (item['articles'] as num?)?.toInt() ?? 0;
        }
      } else {
        total += (gc['totalArticles'] as num?)?.toInt() ?? 0;
      }
    }
    return total;
  }

  Future<void> _handleVerify() async {
    final gcs = _allSelectedGcs;
    if (gcs.isEmpty) return;

    final ewbsToVerify = gcs
        .where((gc) => gc['ewbNumber'] != null || gc['privateMark'] != null)
        .map((gc) => {
              'ewbNo': gc['ewbNumber'] ?? gc['privateMark'],
              'company': gc['companyString']
            })
        .toList();

    if (ewbsToVerify.isEmpty) {
      setState(() => _errorMessage = 'No E-Way Bill numbers found to verify in the selected GDMs.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await ApiService.bulkVerifyEwaybills(ewbsToVerify);
      if (mounted) {
        setState(() {
          _successMessage = 'Successfully verified ${ewbsToVerify.length} E-Way Bills against the NIC Portal!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Verification failed: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _handleHeal() async {
    final gcs = _allSelectedGcs;
    if (gcs.isEmpty || _activeVehicleNo == null) return;

    setState(() {
      _isHealing = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final vNo = _activeVehicleNo!.replaceAll(RegExp(r'[^A-Z0-9]', caseSensitive: false), '');
      await ApiService.bulkHealEwaybills(gcs, vNo);
      if (mounted) {
        setState(() {
          _successMessage = 'Auto-Healed Part-B on NIC Portal for lorry $vNo across ${gcs.length} consignments!';
        });
      }
      await _fetchPendingGdms();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Auto-Heal failed: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isHealing = false);
    }
  }

  Future<void> _handleGenerateCEWB() async {
    final gcs = _allSelectedGcs;
    if (gcs.isEmpty || _activeVehicleNo == null) return;

    final validEwbsAP = gcs
        .where((gc) => gc['companyString'] == 'AP' && (gc['privateMark'] != null || gc['ewbNumber'] != null))
        .map((gc) => (gc['privateMark'] ?? gc['ewbNumber']).toString())
        .toList();

    final validEwbsBELL = gcs
        .where((gc) => gc['companyString'] == 'BELL' && (gc['privateMark'] != null || gc['ewbNumber'] != null))
        .map((gc) => (gc['privateMark'] ?? gc['ewbNumber']).toString())
        .toList();

    if (validEwbsAP.isEmpty && validEwbsBELL.isEmpty) {
      setState(() => _errorMessage = 'No valid E-Way Bills found in staging. Please enter or auto-heal EWBs first.');
      return;
    }

    setState(() {
      _isGeneratingCewb = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final vNo = _activeVehicleNo!.replaceAll(RegExp(r'[^A-Z0-9]', caseSensitive: false), '');
      final now = DateTime.now();
      final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      
      final basePayload = {
        'vehicleNo': vNo,
        'fromPlace': 'Sivakasi',
        'transDocNo': 'TRP-${now.millisecondsSinceEpoch ~/ 1000}',
        'transDocDate': dateStr,
      };

      final List<String> generatedCewbs = [];

      if (validEwbsAP.isNotEmpty) {
        final resAP = await ApiService.generateCewb('AP', {...basePayload, 'ewbNos': validEwbsAP});
        if (resAP['cEwbNo'] != null) {
          generatedCewbs.add('AP: ${resAP['cEwbNo']}');
        }
      }

      if (validEwbsBELL.isNotEmpty) {
        final resBELL = await ApiService.generateCewb('BELL', {...basePayload, 'ewbNos': validEwbsBELL});
        if (resBELL['cEwbNo'] != null) {
          generatedCewbs.add('BELL: ${resBELL['cEwbNo']}');
        }
      }

      if (generatedCewbs.isNotEmpty) {
        final cewbString = generatedCewbs.join(' | ');
        await ApiService.attachMasterCewb(_selectedGdmIds.toList(), cewbString);
        if (mounted) {
          setState(() {
            _successMessage = 'Consolidated Master CEWB Created & Attached: $cewbString';
          });
          await _fetchPendingGdms();
        }
      } else {
        if (mounted) {
          setState(() => _errorMessage = 'Failed to generate CEWBs from government portal response.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'CEWB Generation failed: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isGeneratingCewb = false);
    }
  }

  void _showConsignmentDetailsModal(Map<String, dynamic> gc) {
    final gcNumber = gc['gcNumber']?.toString() ?? 'N/A';
    final gdmNumber = gc['gdmNumber']?.toString() ?? 'N/A';
    final ewb = gc['ewbNumber'] ?? gc['privateMark'] ?? 'Not Assigned';
    final consignorName = gc['consignor']?['name'] ?? gc['consignorName'] ?? 'N/A';
    final consigneeName = gc['consignee']?['name'] ?? gc['consigneeName'] ?? 'N/A';
    final city = gc['consignee']?['city'] ?? gc['consigneeCity'] ?? gc['city'] ?? 'N/A';
    final goods = gc['goods'] as List<dynamic>? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(28),
        constraints: const BoxConstraints(maxWidth: 680),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, -4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gcNumber,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Attached in GDM: $gdmNumber',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _modalDetailRow('E-Way Bill No', ewb, isCode: true),
                  const Divider(height: 16),
                  _modalDetailRow('Consignor (Sender)', consignorName),
                  const Divider(height: 16),
                  _modalDetailRow('Consignee (Receiver)', consigneeName),
                  const Divider(height: 16),
                  _modalDetailRow('Destination Station', city),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (goods.isNotEmpty) ...[
              const Text('CONSIGNMENT GOODS BREAKDOWN',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(1.5),
                      2: FlexColumnWidth(1.5),
                    },
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                        children: [
                          Padding(padding: EdgeInsets.all(10), child: Text('DESCRIPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                          Padding(padding: EdgeInsets.all(10), child: Text('ARTICLES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                          Padding(padding: EdgeInsets.all(10), child: Text('WEIGHT (KG)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                        ],
                      ),
                      ...goods.map((item) {
                        return TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.all(10), child: Text(item['description']?.toString() ?? 'General Goods', style: const TextStyle(fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(10), child: Text('${item['articles'] ?? 0}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                            Padding(padding: const EdgeInsets.all(10), child: Text('${item['weight'] ?? 0}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Close Inspection', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modalDetailRow(String label, String value, {bool isCode = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              fontFamily: isCode ? 'monospace' : null,
              color: isCode ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildSwissCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
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

  @override
  Widget build(BuildContext context) {
    final filteredGdms = _pendingGdms.where((gdm) {
      if (_gdmSearchQuery.isEmpty) return true;
      final query = _gdmSearchQuery.toLowerCase();
      final gdmNum = (gdm['gdmNumber'] ?? '').toString().toLowerCase();
      final vehicle = (gdm['vehicle']?['vehicleNumber'] ?? gdm['vehicleNo'] ?? '').toString().toLowerCase();
      return gdmNum.contains(query) || vehicle.contains(query);
    }).toList();

    final gcs = _allSelectedGcs;

    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.8),
          ),
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9), Color(0xFFEEF2F6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1300),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Executive Cockpit Header
                  _buildHeaderCockpit(),

                  const SizedBox(height: 18),

                  // 2. Alert Feedback Banners
                  if (_errorMessage != null) ...[
                    _buildAlertBanner(
                      icon: Icons.error_outline_rounded,
                      message: _errorMessage!,
                      color: const Color(0xFFBE123C),
                      bg: const Color(0xFFFFE4E6),
                      border: const Color(0xFFFECDD3),
                      onClose: () => setState(() => _errorMessage = null),
                    ),
                    const SizedBox(height: 14),
                  ],

                  if (_successMessage != null) ...[
                    _buildAlertBanner(
                      icon: Icons.check_circle_outline_rounded,
                      message: _successMessage!,
                      color: const Color(0xFF047857),
                      bg: const Color(0xFFD1FAE5),
                      border: const Color(0xFFA7F3D0),
                      onClose: () => setState(() => _successMessage = null),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 3. Real-Time Compliance Stats Bar
                  _buildLiveStatsRow(gcs),

                  const SizedBox(height: 20),

                  // 4. Dual Panel Staging Workspace
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 900;
                      return Flex(
                        direction: isNarrow ? Axis.vertical : Axis.horizontal,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Panel: Pending GDMs Queue
                          Expanded(
                            flex: isNarrow ? 0 : 5,
                            child: _buildPendingGdmsPanel(filteredGdms),
                          ),
                          SizedBox(width: isNarrow ? 0 : 20, height: isNarrow ? 20 : 0),
                          // Right Panel: CEWB Staging & Consolidation Matrix
                          Expanded(
                            flex: isNarrow ? 0 : 7,
                            child: _buildCewbStagingPanel(gcs),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCockpit() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.gavel_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'GOVT COMPLIANCE HUB',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified_rounded, color: Color(0xFF34D399), size: 12),
                            SizedBox(width: 4),
                            Text(
                              'NIC PORTAL 1.4',
                              style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Multi-Lorry Consolidated E-Way Bill (CEWB) generator & automated Part-B vehicle assignment.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.share_location_rounded, color: Color(0xFF60A5FA), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'BRANCH: ${ApiService.activeBranch.isNotEmpty ? ApiService.activeBranch : "MAIN"}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _fetchPendingGdms,
                icon: _isLoading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Sync Queue'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBanner({
    required IconData icon,
    required String message,
    required Color color,
    required Color bg,
    required Color border,
    required VoidCallback onClose,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 18, color: color),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStatsRow(List<dynamic> stagedGcs) {
    int validEwbCount = 0;
    int missingEwbCount = 0;
    for (var gc in stagedGcs) {
      if (gc['privateMark'] != null || gc['ewbNumber'] != null) {
        validEwbCount++;
      } else {
        missingEwbCount++;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 750;
        final cardWidth = isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 36) / 4;

        final metrics = [
          {
            'label': 'PENDING DISPATCH GDMs',
            'value': '${_pendingGdms.length}',
            'sub': 'Queued in warehouse',
            'icon': Icons.local_shipping_outlined,
            'color': const Color(0xFF6366F1),
            'bg': const Color(0xFFEEF2FF),
          },
          {
            'label': 'STAGED FOR CEWB',
            'value': '${_selectedGdmIds.length} GDMs (${stagedGcs.length} GCs)',
            'sub': 'Active truck payload',
            'icon': Icons.checklist_rtl_rounded,
            'color': const Color(0xFF0284C7),
            'bg': const Color(0xFFF0F9FF),
          },
          {
            'label': 'ACTIVE TRANSPORT LORRY',
            'value': _activeVehicleNo ?? 'None Locked',
            'sub': _activeVehicleNo != null ? 'Single vehicle lock active' : 'Select a GDM below',
            'icon': Icons.directions_car_rounded,
            'color': _activeVehicleNo != null ? const Color(0xFFD97706) : const Color(0xFF64748B),
            'bg': _activeVehicleNo != null ? const Color(0xFFFFFBEB) : const Color(0xFFF1F5F9),
          },
          {
            'label': 'E-WAY BILL INTEGRITY',
            'value': '$validEwbCount Valid / $missingEwbCount Missing',
            'sub': missingEwbCount > 0 ? 'Action required: auto-heal' : 'Ready for consolidation',
            'icon': Icons.verified_user_outlined,
            'color': missingEwbCount > 0 ? const Color(0xFFE11D48) : const Color(0xFF10B981),
            'bg': missingEwbCount > 0 ? const Color(0xFFFFF1F2) : const Color(0xFFECFDF5),
          },
        ];

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: metrics.map((m) {
            return Container(
              width: cardWidth,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 10,
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
                      Text(
                        m['label'] as String,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: m['bg'] as Color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(m['icon'] as IconData, color: m['color'] as Color, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    m['value'] as String,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: m['color'] as Color,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m['sub'] as String,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPendingGdmsPanel(List<dynamic> filteredGdms) {
    return _buildSwissCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.local_shipping_rounded, color: Color(0xFF2563EB), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'PENDING GDM DISPATCH QUEUE',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        '${filteredGdms.length} Available',
                        style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Search Input
                TextField(
                  onChanged: (val) => setState(() => _gdmSearchQuery = val),
                  decoration: const InputDecoration(
                    hintText: 'Search GDM # or vehicle plate...',
                    prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                    fillColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // List of GDMs
          if (_isLoading && _pendingGdms.isEmpty)
            const SizedBox(
              height: 250,
              child: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
            )
          else if (filteredGdms.isEmpty)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Column(
                children: [
                  Icon(Icons.inventory_rounded, size: 40, color: Color(0xFFCBD5E1)),
                  SizedBox(height: 12),
                  Text('No Pending GDMs', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF475569))),
                  SizedBox(height: 4),
                  Text('All dispatch manifests are consolidated or none created.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: filteredGdms.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final gdm = filteredGdms[index];
                final gdmId = gdm['id'] as int? ?? 0;
                final gdmNumber = gdm['gdmNumber']?.toString() ?? 'GDM-#';
                final vehicleNo = gdm['vehicle']?['vehicleNumber'] ?? gdm['vehicleNo'] ?? 'UNKNOWN';
                final isSelected = _selectedGdmIds.contains(gdmId);
                final isDisabled = _activeVehicleNo != null && _activeVehicleNo != vehicleNo;
                final gcsCount = (gdm['gcs'] as List<dynamic>?)?.length ?? 0;
                final dateStr = gdm['date'] != null ? gdm['date'].toString().split('T').first : 'Today';

                return InkWell(
                  onTap: isDisabled ? null : () => _toggleSelection(gdmId, vehicleNo),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFEFF6FF)
                          : (isDisabled ? const Color(0xFFF8FAFC) : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF3B82F6)
                            : (isDisabled ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1)),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          onChanged: isDisabled ? null : (v) => _toggleSelection(gdmId, vehicleNo),
                          activeColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    gdmNumber,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      dateStr,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // License Plate
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.local_shipping_rounded, size: 12, color: Color(0xFF92400E)),
                                        const SizedBox(width: 4),
                                        Text(
                                          vehicleNo,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11,
                                            color: Color(0xFF92400E),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '$gcsCount Consignments',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCewbStagingPanel(List<dynamic> stagedGcs) {
    return _buildSwissCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.fact_check_rounded, color: Color(0xFF10B981), size: 22),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CEWB STAGING MATRIX',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 0.5),
                        ),
                        Text(
                          _activeVehicleNo != null
                              ? 'Active Truck: $_activeVehicleNo'
                              : 'Select GDMs from the queue on the left',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_activeVehicleNo != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Text(
                      '${stagedGcs.length} GCs Ready ($_totalArticlesInStaging Articles)',
                      style: const TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w800, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),

          // Table / Items
          if (stagedGcs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60, horizontal: 24),
              child: Column(
                children: [
                  Icon(Icons.layers_clear_rounded, size: 48, color: Color(0xFFCBD5E1)),
                  SizedBox(height: 12),
                  Text('Staging Area Empty', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF475569), fontSize: 15)),
                  SizedBox(height: 4),
                  Text('Check the boxes on the left to bundle GDMs for the same lorry.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
            )
          else ...[
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              color: const Color(0xFFF1F5F9),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('GC NUMBER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('GDM REF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF475569)))),
                  Expanded(flex: 3, child: Text('E-WAY BILL #', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF475569)))),
                  Expanded(flex: 4, child: Text('RECEIVER & DESTINATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF475569)), textAlign: TextAlign.right)),
                ],
              ),
            ),
            // Items
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stagedGcs.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final gc = stagedGcs[index];
                final gcNum = gc['gcNumber']?.toString() ?? 'GC-#';
                final gdmNum = gc['gdmNumber']?.toString() ?? 'GDM-#';
                final ewb = gc['privateMark'] ?? gc['ewbNumber'];
                final consignee = gc['consignee']?['name'] ?? gc['consigneeName'] ?? 'N/A';
                final city = gc['consignee']?['city'] ?? gc['city'] ?? '';
                final isBell = gc['companyString'] == 'BELL';

                return InkWell(
                  onTap: () => _showConsignmentDetailsModal(gc),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    child: Row(
                      children: [
                        // GC # + Company Tag
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isBell ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: isBell ? const Color(0xFFA7F3D0) : const Color(0xFFBFDBFE)),
                                ),
                                child: Text(
                                  isBell ? 'BELL' : 'AP',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: isBell ? const Color(0xFF065F46) : const Color(0xFF1E40AF),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  gcNum,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // GDM Ref
                        Expanded(
                          flex: 2,
                          child: Text(
                            gdmNum,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ),
                        // EWB
                        Expanded(
                          flex: 3,
                          child: ewb != null
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: Text(
                                    ewb.toString(),
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF047857),
                                    ),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF1F2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFECDD3)),
                                  ),
                                  child: const Text(
                                    'Missing EWB',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFBE123C)),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                        ),
                        // Receiver
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                consignee,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                              ),
                              if (city.isNotEmpty)
                                Text(
                                  city,
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],

          // Action Toolbar
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                // Verify Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (stagedGcs.isEmpty || _isVerifying || _isHealing || _isGeneratingCewb)
                        ? null
                        : _handleVerify,
                    icon: _isVerifying
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1D4ED8)))
                        : const Icon(Icons.shield_outlined, size: 16),
                    label: const Text('Verify NIC'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEFF6FF),
                      foregroundColor: const Color(0xFF1D4ED8),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Auto-Heal Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (stagedGcs.isEmpty || _isVerifying || _isHealing || _isGeneratingCewb)
                        ? null
                        : _handleHeal,
                    icon: _isHealing
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_fix_high_rounded, size: 16),
                    label: const Text('Auto-Heal Part-B'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Master CEWB Button
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: (stagedGcs.isEmpty || _isVerifying || _isHealing || _isGeneratingCewb)
                        ? null
                        : _handleGenerateCEWB,
                    icon: _isGeneratingCewb
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.verified_rounded, size: 18),
                    label: const Text('Generate Master CEWB'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
