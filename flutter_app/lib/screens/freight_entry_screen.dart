import 'package:flutter/material.dart';
import '../services/api_service.dart';

class FreightEntryScreen extends StatefulWidget {
  const FreightEntryScreen({super.key});

  @override
  State<FreightEntryScreen> createState() => _FreightEntryScreenState();
}

class _FreightEntryScreenState extends State<FreightEntryScreen> {
  final TextEditingController _searchGcController = TextEditingController();
  final TextEditingController _freightRateController = TextEditingController();
  final TextEditingController _advancePaidController = TextEditingController();
  final TextEditingController _freightNoteController = TextEditingController();

  String _companyMode = 'A'; // 'A' for AP, 'B' for BELL
  String _freightType = 'To Pay'; // 'To Pay', 'Paid', 'T.B.B.'
  String _freightFixed = 'No'; // 'Yes' or 'No'

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  Map<String, dynamic>? _activeGc;
  List<dynamic> _recentActivities = [];

  @override
  void initState() {
    super.initState();
    _fetchRecentActivities();
    _freightRateController.addListener(_onCalculationsChanged);
    _advancePaidController.addListener(_onCalculationsChanged);
  }

  @override
  void dispose() {
    _searchGcController.dispose();
    _freightRateController.dispose();
    _advancePaidController.dispose();
    _freightNoteController.dispose();
    super.dispose();
  }

  void _onCalculationsChanged() {
    setState(() {});
  }

  Future<void> _fetchRecentActivities() async {
    try {
      final gcs = await ApiService.getGcsRaw(page: 1, limit: 15);
      final priced = gcs.where((g) {
        final total = g['freightTotal'];
        return total != null && (double.tryParse(total.toString()) ?? 0) > 0;
      }).toList();
      if (mounted) {
        setState(() {
          _recentActivities = priced.take(8).toList();
        });
      }
    } catch (_) {
      // Best-effort load for recent entries
    }
  }

  Future<void> _handleSearch() async {
    final query = _searchGcController.text.trim();
    if (query.isEmpty) {
      setState(() => _errorMessage = 'Please enter a GC Number to search');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
      _activeGc = null;
    });

    final prefix = _companyMode == 'A' ? 'AP-' : 'BELL-';
    final fullNumber = query.toUpperCase().startsWith('AP-') || query.toUpperCase().startsWith('BELL-')
        ? query.toUpperCase()
        : '$prefix$query';

    try {
      final gc = await ApiService.fetchGcRaw(fullNumber);
      if (mounted) {
        setState(() {
          _activeGc = gc;
          _freightRateController.text = (gc['freightRate'] ?? '').toString();
          _advancePaidController.text = (gc['advancePaid'] ?? '').toString();
          _freightNoteController.text = (gc['freightNote'] ?? '').toString();
          _freightType = (gc['freightType'] ?? 'To Pay').toString();
          _freightFixed = (gc['freightFixed'] ?? 'No').toString();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'GC "$fullNumber" not found in database. Please verify the consignment number.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _totalArticles {
    if (_activeGc == null) return 0;
    final goods = _activeGc!['goods'] as List<dynamic>?;
    if (goods == null || goods.isEmpty) {
      return int.tryParse((_activeGc!['totalArticles'] ?? 0).toString()) ?? 0;
    }
    int sum = 0;
    for (var item in goods) {
      sum += int.tryParse((item['articles'] ?? item['articleCount'] ?? 0).toString()) ?? 0;
    }
    return sum > 0 ? sum : (int.tryParse((_activeGc!['totalArticles'] ?? 0).toString()) ?? 0);
  }

  double get _calculatedTotalFreight {
    if (_freightFixed == 'Yes') {
      return double.tryParse(_freightRateController.text) ?? 0.0;
    }
    final rate = double.tryParse(_freightRateController.text) ?? 0.0;
    final count = _totalArticles;
    return rate * count;
  }

  double get _calculatedBalance {
    final advance = double.tryParse(_advancePaidController.text) ?? 0.0;
    final bal = _calculatedTotalFreight - advance;
    return bal > 0 ? bal : 0.0;
  }

  Future<void> _handleSave() async {
    if (_activeGc == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final gcId = _activeGc!['id'] is int ? _activeGc!['id'] as int : int.parse(_activeGc!['id'].toString());
      final payload = {
        'freightFixed': _freightFixed,
        'freightType': _freightType,
        'freightRate': double.tryParse(_freightRateController.text) ?? 0.0,
        'freightTotal': _calculatedTotalFreight,
        'advancePaid': double.tryParse(_advancePaidController.text) ?? 0.0,
        'balanceFreight': _calculatedBalance,
        'freightNote': _freightNoteController.text.trim(),
      };

      await ApiService.updateGcFreight(gcId, payload);

      if (mounted) {
        setState(() {
          _successMessage = 'Consignment ${_activeGc!['gcNumber']} freight updated successfully!';
        });
        await _fetchRecentActivities();

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _successMessage = null;
              _activeGc = null;
              _searchGcController.clear();
              _freightRateController.clear();
              _advancePaidController.clear();
              _freightNoteController.clear();
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to update freight: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
              'Freight Valuation & Entry',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A), letterSpacing: -0.3),
            ),
            Text(
              'Post-booking consignment tariff calculation, payment terms, and freight balance settlement',
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
          IconButton(
            tooltip: 'Refresh Recent Feed',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569)),
            onPressed: _fetchRecentActivities,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Executive Cockpit Hero Banner
                _buildExecutiveCockpit(),
                const SizedBox(height: 20),

                // 2. Alert Messages
                if (_errorMessage != null) ...[
                  _buildAlertBox(
                    icon: Icons.error_outline_rounded,
                    message: _errorMessage!,
                    color: const Color(0xFFBE123C),
                    bg: const Color(0xFFFFF1F2),
                    border: const Color(0xFFFECDD3),
                    onClose: () => setState(() => _errorMessage = null),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_successMessage != null) ...[
                  _buildAlertBox(
                    icon: Icons.check_circle_outline_rounded,
                    message: _successMessage!,
                    color: const Color(0xFF047857),
                    bg: const Color(0xFFECFDF5),
                    border: const Color(0xFFA7F3D0),
                    onClose: () => setState(() => _successMessage = null),
                  ),
                  const SizedBox(height: 16),
                ],

                // 3. Search & Lookup Box
                _buildSearchCard(),
                const SizedBox(height: 20),

                // 4. GC Summary & Interactive Calculation
                if (_activeGc != null) ...[
                  _buildGcSummaryCard(),
                  const SizedBox(height: 20),
                  _buildFreightCalculationCard(),
                  const SizedBox(height: 28),
                ],

                // 5. Recent Activity Feed
                if (_activeGc == null) _buildRecentActivityTable(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExecutiveCockpit() {
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
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.calculate_rounded, color: Color(0xFF34D399), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'POST-BOOKING FREIGHT & TARIFF VALUATION',
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
                              Text('VALUATION READY', style: TextStyle(color: Color(0xFF34D399), fontSize: 9, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Calculate rates per article or fixed lumpsum, allocate advances, and generate balance freight terms',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
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
                title: 'ACTIVE PREFIX',
                value: _companyMode == 'A' ? 'AP (Arunachalam)' : 'BELL (Bell Logistics)',
                icon: Icons.business_rounded,
                iconColor: const Color(0xFF38BDF8),
              ),
              _buildCockpitKpi(
                title: 'PRICED IN CACHE',
                value: '${_recentActivities.length} consignments',
                icon: Icons.receipt_long_rounded,
                iconColor: const Color(0xFF34D399),
              ),
              _buildCockpitKpi(
                title: 'DEFAULT FORMULA',
                value: _freightFixed == 'Yes' ? 'Lumpsum Flat Total' : 'Rate × Articles Count',
                icon: Icons.functions_rounded,
                iconColor: const Color(0xFFFBBF24),
              ),
              _buildCockpitKpi(
                title: 'TARGET GC',
                value: _activeGc != null ? (_activeGc!['gcNumber'] ?? 'Loaded') : 'Awaiting Search',
                icon: Icons.qr_code_rounded,
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

  Widget _buildSearchCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONSIGNMENT LOOKUP (GC NUMBER)',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Company Toggle Pill
              Container(
                height: 44,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _companyMode = 'A'),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _companyMode == 'A' ? const Color(0xFF4F46E5) : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          'AP',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: _companyMode == 'A' ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _companyMode = 'B'),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _companyMode == 'B' ? const Color(0xFF059669) : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          'BELL',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: _companyMode == 'B' ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // GC Number Input
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: TextField(
                    controller: _searchGcController,
                    autofocus: true,
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 14),
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Text(
                          '${_companyMode == 'A' ? 'AP' : 'BELL'}-',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _companyMode == 'A' ? const Color(0xFF4F46E5) : const Color(0xFF059669),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      hintText: 'Enter GC Number (e.g. 1025)',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _handleSearch(),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Search Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: _isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.search_rounded, size: 18),
                label: Text(
                  _isLoading ? 'Searching...' : 'Find GC',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGcSummaryCard() {
    final gc = _activeGc!;
    final cnor = gc['consignor']?['name'] ?? gc['consignorName'] ?? 'N/A';
    final cnee = gc['consignee']?['name'] ?? gc['consigneeName'] ?? 'N/A';
    final gcDate = gc['date'] != null ? gc['date'].toString().split('T')[0] : 'N/A';
    final destination = gc['toPlace'] ?? gc['deliveryOffice'] ?? gc['godown'] ?? 'MAIN';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF4F46E5), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'CONSIGNMENT SUMMARY: ${gc['gcNumber']}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 0.3),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                onPressed: () => setState(() => _activeGc = null),
                tooltip: 'Clear active GC',
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildInfoTile('Consignor (Sender)', cnor, Icons.storefront_rounded),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoTile('Consignee (Receiver)', cnee, Icons.business_center_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoTile('Booking Date', gcDate, Icons.calendar_today_rounded),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoTile('Destination / Branch', destination, Icons.location_on_rounded),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoTile('Total Articles', '$_totalArticles pkgs', Icons.inventory_2_rounded, isHighlight: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isHighlight ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isHighlight ? const Color(0xFFC7D2FE) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isHighlight ? const Color(0xFF4F46E5) : const Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: isHighlight ? const Color(0xFF4338CA) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isHighlight ? const Color(0xFF1E1B4B) : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreightCalculationCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Icon(Icons.currency_rupee_rounded, color: Color(0xFF059669), size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'FREIGHT VALUATION & PAYMENT TERMS',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Freight Type & Fixed Switcher
          Row(
            children: [
              // Payment Type
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PAYMENT TERMS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _freightType,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'To Pay', child: Text('To Pay (Receiver Pays)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            DropdownMenuItem(value: 'Paid', child: Text('Paid (Sender Paid)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            DropdownMenuItem(value: 'T.B.B.', child: Text('T.B.B. (To Be Billed / Account)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _freightType = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Fixed Lumpsum?
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('FREIGHT CALCULATION MODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _freightFixed,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'No', child: Text('Per Article (Rate × Articles)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            DropdownMenuItem(value: 'Yes', child: Text('Fixed Lumpsum (Flat Total)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _freightFixed = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Numbers Row: Rate, Total, Advance, Balance
          Row(
            children: [
              // Rate Per Article / Lumpsum
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _freightFixed == 'Yes' ? 'FIXED TOTAL (₹)' : 'RATE / ARTICLE (₹)',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: TextField(
                        controller: _freightRateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: _freightFixed == 'Yes' ? '1500.00' : '50.00',
                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.currency_rupee, size: 16, color: Color(0xFF64748B)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Total Freight Display
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CALCULATED TOTAL (₹)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFC7D2FE)),
                      ),
                      child: Text(
                        '₹${_calculatedTotalFreight.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF4338CA)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Advance Received
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ADVANCE RECEIVED (₹)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: TextField(
                        controller: _advancePaidController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                          hintText: '0.00',
                          hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          prefixIcon: Icon(Icons.currency_rupee, size: 16, color: Color(0xFF64748B)),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Balance Display
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('BALANCE DUE (₹)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        '₹${_calculatedBalance.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFB45309)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Remarks/Note
          const Text('PAYMENT REMARKS & VALUATION NOTES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: TextField(
              controller: _freightNoteController,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              decoration: const InputDecoration(
                hintText: 'e.g. Paid via UPI / GPay, Balance to be collected on delivery in cash...',
                hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: Icon(Icons.notes_rounded, size: 18, color: Color(0xFF64748B)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),

          const SizedBox(height: 22),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 18),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _activeGc = null),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancel Valuation', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(
                  _isSaving ? 'Updating...' : 'Save Freight Entry',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.history_rounded, size: 18, color: Color(0xFF4F46E5)),
                ),
                const SizedBox(width: 10),
                const Text(
                  'RECENT FREIGHT VALUATIONS & PRICED CONSIGNMENTS',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          if (_recentActivities.isEmpty)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(
                child: Text('No priced GCs recorded yet in current session.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentActivities.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final gc = _recentActivities[index];
                final gcNo = gc['gcNumber'] ?? '';
                final cnee = gc['consignee']?['name'] ?? gc['consigneeName'] ?? '-';
                final total = double.tryParse((gc['freightTotal'] ?? 0).toString()) ?? 0.0;
                final advance = double.tryParse((gc['advancePaid'] ?? 0).toString()) ?? 0.0;
                final balance = double.tryParse((gc['balanceFreight'] ?? (total - advance)).toString()) ?? 0.0;
                final type = gc['freightType'] ?? 'To Pay';

                return InkWell(
                  onTap: () {
                    setState(() {
                      _activeGc = gc;
                      _freightRateController.text = (gc['freightRate'] ?? '').toString();
                      _advancePaidController.text = (gc['advancePaid'] ?? '').toString();
                      _freightNoteController.text = (gc['freightNote'] ?? '').toString();
                      _freightType = (gc['freightType'] ?? 'To Pay').toString();
                      _freightFixed = (gc['freightFixed'] ?? 'No').toString();
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        // GC Number
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
                        const SizedBox(width: 14),

                        // Consignee
                        Expanded(
                          flex: 2,
                          child: Text(
                            cnee,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ),

                        // Type Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: type == 'Paid'
                                ? const Color(0xFFECFDF5)
                                : type == 'T.B.B.'
                                    ? const Color(0xFFF5F3FF)
                                    : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: type == 'Paid'
                                  ? const Color(0xFFA7F3D0)
                                  : type == 'T.B.B.'
                                      ? const Color(0xFFDDD6FE)
                                      : const Color(0xFFFDE68A),
                            ),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: type == 'Paid'
                                  ? const Color(0xFF047857)
                                  : type == 'T.B.B.'
                                      ? const Color(0xFF6D28D9)
                                      : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),

                        // Total
                        SizedBox(
                          width: 110,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('TOTAL FREIGHT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF64748B))),
                              Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                            ],
                          ),
                        ),

                        // Balance
                        SizedBox(
                          width: 110,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('BALANCE DUE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF64748B))),
                              Text(
                                '₹${balance.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: balance > 0 ? const Color(0xFFB45309) : const Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 10),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
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

  Widget _buildAlertBox({
    required IconData icon,
    required String message,
    required Color color,
    required Color bg,
    required Color border,
    required VoidCallback onClose,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 16, color: color),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
