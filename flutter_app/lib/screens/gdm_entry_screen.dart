import 'package:flutter/material.dart';
import '../models/gdm.dart';
import '../models/gc.dart';
import '../models/vehicle.dart';
import '../services/api_service.dart';

class GdmEntryScreen extends StatefulWidget {
  final Gdm? initialGdm;

  const GdmEntryScreen({super.key, this.initialGdm});

  @override
  State<GdmEntryScreen> createState() => _GdmEntryScreenState();
}

class _GdmEntryScreenState extends State<GdmEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoadingMasters = true;
  bool _isSubmitting = false;

  String _gdmCompanyMode = 'A'; // AP by default
  String _gdmNumber = '';
  
  // Header Details
  final DateTime _date = DateTime.now();
  final TimeOfDay _time = TimeOfDay.now();
  final TextEditingController _fromLocationController = TextEditingController(text: 'Sivakasi');
  final TextEditingController _toNameController = TextEditingController(text: 'AS PER BILLS');
  final TextEditingController _deliveryAtController = TextEditingController();
  final TextEditingController _cewbNumberController = TextEditingController();

  // Lorry Details
  List<Vehicle> _vehicles = [];
  Vehicle? _selectedVehicle;
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
  final List<Gc> _linkedGcs = [];
  
  String _freightMode = 'Use Individual GC Freight';
  final TextEditingController _overallRateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final vehicles = await ApiService.getVehicles();
      setState(() {
        _vehicles = vehicles;
      });

      if (widget.initialGdm != null) {
        // Edit Mode Loading logic would go here
      } else {
        await _fetchNextGdmNumber();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading masters: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMasters = false);
      }
    }
  }

  Future<void> _fetchNextGdmNumber() async {
    try {
      final res = await ApiService.getNextGdmNumber(_gdmCompanyMode);
      final prefix = _gdmCompanyMode == 'A' ? 'AP-' : 'BELL-';
      setState(() {
        _gdmNumber = prefix + (res['nextNumber']?.toString() ?? '1001');
      });
    } catch (_) {}
  }

  Future<void> _verifyDL() async {
    if (_licenseController.text.isEmpty || _dobController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('License Number and DOB required')));
      return;
    }

    setState(() => _isFetchingDl = true);
    try {
      final data = await ApiService.verifyDL(_licenseController.text, _dobController.text);
      setState(() {
        _dlData = data;
        if (_driverNameController.text.isEmpty && data['owner_name'] != null && !data['owner_name'].toString().contains('*')) {
          _driverNameController.text = data['owner_name'];
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('DL Verified successfully'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('DL Verification Failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isFetchingDl = false);
    }
  }

  Future<void> _addGc() async {
    final text = _searchGcController.text.trim().toUpperCase();
    if (text.isEmpty) return;
    
    // Auto strip prefix if present
    String rawGc = text;
    if (rawGc.startsWith('AP-') || rawGc.startsWith('BELL-')) {
      rawGc = rawGc.replaceFirst(RegExp(r'^(AP-|BELL-)'), '');
    }
    
    final prefix = _gdmCompanyMode == 'A' ? 'AP-' : 'BELL-';
    final fullGcNumber = prefix + rawGc;
    
    _searchGcController.clear(); // Ready for next scan

    if (_linkedGcs.any((gc) => gc.gcNumber == fullGcNumber)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('GC $fullGcNumber is already added!')));
      return;
    }

    try {
      final gc = await ApiService.fetchGc(fullGcNumber);
      
      if (gc.gdmId != null) {
        throw Exception('GC ${gc.gcNumber} is already attached to a GDM.');
      }
      if (gc.status == 'Cancelled') {
        throw Exception('GC ${gc.gcNumber} is cancelled and cannot be added.');
      }

      setState(() {
        _linkedGcs.add(gc);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('GC ${gc.gcNumber} added!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  void _removeGc(int index) {
    setState(() {
      _linkedGcs.removeAt(index);
    });
  }

  double _calculateTotalFreight() {
    if (_freightMode == 'Overall Rate for GDM') {
      return double.tryParse(_overallRateController.text) ?? 0.0;
    }
    double total = 0;
    for (var gc in _linkedGcs) {
      total += gc.freightTotal;
    }
    return total;
  }

  int _calculateTotalArticles() {
    int total = 0;
    for (var gc in _linkedGcs) {
      for (var item in gc.goods) {
        total += item.articleCount ?? 0;
      }
    }
    return total;
  }

  Future<void> _saveGDM(String status) async {
    if (_linkedGcs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one GC')));
      return;
    }
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a Lorry')));
      return;
    }

    setState(() => _isSubmitting = true);
    
    try {
      final payload = {
        'gdmNumber': _gdmNumber,
        'date': _date.toIso8601String().split('T')[0],
        'time': '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
        'fromLocation': _fromLocationController.text,
        'toName': _toNameController.text,
        'deliveryAt': _deliveryAtController.text,
        'vehicleId': _selectedVehicle!.id,
        'driverName': _driverNameController.text,
        'driverPhone': _driverPhoneController.text,
        'startKm': _startKmController.text,
        'memoAmount': _calculateTotalFreight(),
        'cewbNumber': _cewbNumberController.text,
        'gcIds': _linkedGcs.map((g) => g.id).toList(),
        'status': status,
        'dlData': _dlData != null ? {
          'licenseNumber': _licenseController.text.replaceAll(RegExp(r'[\s-]'), '').toUpperCase(),
          'dob': _dobController.text,
          'name': _dlData!['owner_name'],
          'phone': _driverPhoneController.text,
          'rto': _dlData!['rto'],
          'status': _dlData!['status'],
          'validityNt': _dlData!['validity_nt'],
          'validityTr': _dlData!['validity_tr'],
          'vehicleClasses': _dlData!['vehicle_classes'],
        } : null,
      };

      await ApiService.saveGdm(payload, id: widget.initialGdm?.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('GDM $_gdmNumber saved successfully!'), backgroundColor: Colors.green));
        // Reset form
        setState(() {
          _linkedGcs.clear();
          _selectedVehicle = null;
          _driverNameController.clear();
          _driverPhoneController.clear();
          _startKmController.clear();
          _licenseController.clear();
          _dobController.clear();
          _dlData = null;
        });
        _fetchNextGdmNumber();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save GDM: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildCompanyToggleItem(String label, String code, Color activeColor) {
    final isSelected = _gdmCompanyMode == code;
    return InkWell(
      onTap: () {
        if (_linkedGcs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clear linked GCs before changing company entity')));
          return;
        }
        setState(() {
          _gdmCompanyMode = code;
          _fetchNextGdmNumber();
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {IconData? icon, Color color = const Color(0xFF10B981)}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
          ],
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Color(0xFF0F172A),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwissCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
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

  InputDecoration _inputDeco(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      prefixIcon: icon != null ? Icon(icon, size: 18, color: const Color(0xFF64748B)) : null,
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
        borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMasters) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card matching Login / Dashboard Signature
            Container(
              padding: const EdgeInsets.all(22),
              margin: const EdgeInsets.only(bottom: 24),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 640;
                  return Flex(
                    direction: isCompact ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: isCompact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: isCompact ? 0 : 1,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _gdmCompanyMode == 'A'
                                      ? const [Color(0xFF2563EB), Color(0xFF1D4ED8)]
                                      : const [Color(0xFF059669), Color(0xFF047857)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_gdmCompanyMode == 'A' ? const Color(0xFF2563EB) : const Color(0xFF059669)).withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 26),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    children: [
                                      const Text(
                                        'Goods Despatch Manifest (GDM)',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F172A),
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _gdmCompanyMode == 'A' ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: _gdmCompanyMode == 'A' ? const Color(0xFFBFDBFE) : const Color(0xFFA7F3D0),
                                          ),
                                        ),
                                        child: Text(
                                          _gdmNumber,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: _gdmCompanyMode == 'A' ? const Color(0xFF1D4ED8) : const Color(0xFF047857),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Assemble consignments, verify driver VAHAN credentials, and dispatch lorry',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isCompact) const SizedBox(height: 14),
                      // Segmented AP / BELL Entity Switch
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildCompanyToggleItem('AP', 'A', const Color(0xFF2563EB)),
                            _buildCompanyToggleItem('BELL', 'B', const Color(0xFF059669)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            LayoutBuilder(
              builder: (context, constraints) {
                final isStacked = constraints.maxWidth < 880;
                final leftColumn = _buildSwissCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Lorry Details', icon: Icons.local_shipping_outlined, color: const Color(0xFF0D9488)),
                        DropdownButtonFormField<Vehicle>(
                          value: _selectedVehicle,
                          decoration: _inputDeco('Select Vehicle *', icon: Icons.directions_car_rounded),
                          items: _vehicles.map((v) => DropdownMenuItem(value: v, child: Text(v.vehicleNumber))).toList(),
                          onChanged: (v) {
                            setState(() {
                              _selectedVehicle = v;
                              _driverNameController.text = v?.ownerName ?? '';
                              _driverPhoneController.text = v?.ownerPhone ?? '';
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _driverNameController,
                          decoration: _inputDeco('Driver Name', icon: Icons.person_rounded),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _driverPhoneController,
                          decoration: _inputDeco('Driver Phone', icon: Icons.phone_rounded),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _startKmController,
                          decoration: _inputDeco('Start KM Reading', icon: Icons.speed_rounded),
                          keyboardType: TextInputType.number,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Divider(color: Color(0xFFE2E8F0)),
                        ),
                        _buildSectionHeader('DL Verification (VAHAN)', icon: Icons.verified_user_rounded, color: const Color(0xFF2563EB)),
                        TextFormField(
                          controller: _licenseController,
                          decoration: _inputDeco('Driving License Number', icon: Icons.badge_rounded),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _dobController,
                          decoration: _inputDeco('Driver DOB (YYYY-MM-DD)', icon: Icons.calendar_today_rounded),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: _isFetchingDl
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)))
                                : const Icon(Icons.verified_user_rounded, size: 18),
                            label: Text(_isFetchingDl ? 'Verifying...' : 'Verify via VAHAN API', style: const TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEFF6FF),
                              foregroundColor: const Color(0xFF1D4ED8),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: Color(0xFFBFDBFE)),
                              ),
                            ),
                            onPressed: _isFetchingDl ? null : _verifyDL,
                          ),
                        ),
                        if (_dlData != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                                      const SizedBox(width: 6),
                                      Text('Verified: ${_dlData!['owner_name']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('RTO: ${_dlData!['rto'] ?? 'N/A'}', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                                  Text('Classes: ${_dlData!['vehicle_classes']?.join(", ") ?? 'N/A'}', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                                  Text('Transport Validity: ${_dlData!['validity_tr'] ?? 'N/A'}', style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                final rightColumn = Column(
                  children: [
                      _buildSwissCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader('GDM Destination & Document Details', icon: Icons.description_outlined, color: const Color(0xFF3B82F6)),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _fromLocationController,
                                    decoration: _inputDeco('From Location', icon: Icons.location_on_rounded),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _toNameController,
                                    decoration: _inputDeco('To Name (Party)', icon: Icons.business_rounded),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _deliveryAtController,
                                    decoration: _inputDeco('Delivery At (City)', icon: Icons.location_city_rounded),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _cewbNumberController,
                                    decoration: _inputDeco('Consolidated EWB No.', icon: Icons.assignment_rounded),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _buildSwissCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSectionHeader('Despatch List (${_linkedGcs.length} GCs)', icon: Icons.format_list_bulleted_rounded, color: const Color(0xFF10B981)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: DropdownButton<String>(
                                    underline: const SizedBox.shrink(),
                                    value: _freightMode,
                                    items: ['Use Individual GC Freight', 'Overall Rate for GDM']
                                        .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))))
                                        .toList(),
                                    onChanged: (v) => setState(() => _freightMode = v!),
                                  ),
                                ),
                              ],
                            ),
                            if (_freightMode == 'Overall Rate for GDM')
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: TextFormField(
                                  controller: _overallRateController,
                                  decoration: _inputDeco('Overall Lorry Freight Rate', icon: Icons.currency_rupee_rounded),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) => setState(() {}),
                                ),
                              ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _searchGcController,
                                    decoration: _inputDeco('Scan or Type GC Number to Link', icon: Icons.qr_code_scanner),
                                    onFieldSubmitted: (_) => _addGc(),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                ElevatedButton.icon(
                                  onPressed: _addGc,
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('LINK GC', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            if (_linkedGcs.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(32.0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Center(
                                  child: Text('No GCs added yet. Scan a GC barcode or type its number to link.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(2),
                                    1: FlexColumnWidth(2.5),
                                    2: FlexColumnWidth(2.5),
                                    3: FlexColumnWidth(1.2),
                                    4: FlexColumnWidth(1.5),
                                    5: FlexColumnWidth(0.8),
                                  },
                                  children: [
                                    const TableRow(
                                      decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                                      children: [
                                        Padding(padding: EdgeInsets.all(10.0), child: Text('GC No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                                        Padding(padding: EdgeInsets.all(10.0), child: Text('Consignor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                                        Padding(padding: EdgeInsets.all(10.0), child: Text('Consignee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                                        Padding(padding: EdgeInsets.all(10.0), child: Text('Articles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                                        Padding(padding: EdgeInsets.all(10.0), child: Text('Freight', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                                        Padding(padding: EdgeInsets.all(10.0), child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                                      ],
                                    ),
                                    ..._linkedGcs.asMap().entries.map((entry) {
                                      final idx = entry.key;
                                      final gc = entry.value;
                                      int arts = gc.goods.fold(0, (sum, g) => sum + (g.articleCount ?? 0));
                                      return TableRow(
                                        decoration: BoxDecoration(
                                          color: idx % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                                        ),
                                        children: [
                                          Padding(padding: const EdgeInsets.all(10.0), child: Text(gc.gcNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)))),
                                          Padding(padding: const EdgeInsets.all(10.0), child: Text(gc.consignorName, style: const TextStyle(fontSize: 12))),
                                          Padding(padding: const EdgeInsets.all(10.0), child: Text(gc.consigneeName, style: const TextStyle(fontSize: 12))),
                                          Padding(padding: const EdgeInsets.all(10.0), child: Text(arts.toString(), style: const TextStyle(fontWeight: FontWeight.w700))),
                                          Padding(padding: const EdgeInsets.all(10.0), child: Text('₹${gc.freightTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                            onPressed: () => _removeGc(idx),
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.inventory_2_rounded, size: 18, color: Color(0xFF16A34A)),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Total Articles: ${_calculateTotalArticles()} Boxes',
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF15803D)),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Memo Freight: ₹${_calculateTotalFreight().toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF15803D)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.save_outlined, size: 18),
                                  label: const Text('SAVE AS DRAFT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF475569),
                                    side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _isSubmitting ? null : () => _saveGDM('Created'),
                                ),
                                const SizedBox(width: 14),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF059669), Color(0xFF047857)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF059669).withValues(alpha: 0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.white),
                                    label: const Text('SUBMIT FINAL GDM', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, fontSize: 13, color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: _isSubmitting ? null : () => _saveGDM('Submitted'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                if (isStacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      leftColumn,
                      const SizedBox(height: 20),
                      rightColumn,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 1, child: leftColumn),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: rightColumn),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
