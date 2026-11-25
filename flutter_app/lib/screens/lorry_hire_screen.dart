import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/vehicle.dart';
import '../services/api_service.dart';

class LorryHireScreen extends StatefulWidget {
  const LorryHireScreen({super.key});

  @override
  State<LorryHireScreen> createState() => _LorryHireScreenState();
}

class _LorryHireScreenState extends State<LorryHireScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  List<Vehicle> _vehicles = [];
  Vehicle? _selectedVehicle;

  late String _tripNumber;
  String _sourcedBy = 'Direct';
  String _loadingPayer = 'Transport';

  final TextEditingController _lorryHireController = TextEditingController();
  final TextEditingController _advancePaidController = TextEditingController();
  final TextEditingController _brokerNameController = TextEditingController();
  final TextEditingController _loadingChargeController = TextEditingController();
  final TextEditingController _commissionAmountController = TextEditingController();
  final TextEditingController _commissionDetailsController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  static const List<Color> _themeGradient = [Color(0xFFD97706), Color(0xFFB45309)];
  static const Color _themePrimary = Color(0xFFD97706);

  @override
  void initState() {
    super.initState();
    _generateTripNumber();
    _loadVehicles();
  }

  @override
  void dispose() {
    _lorryHireController.dispose();
    _advancePaidController.dispose();
    _brokerNameController.dispose();
    _loadingChargeController.dispose();
    _commissionAmountController.dispose();
    _commissionDetailsController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _generateTripNumber() {
    _tripNumber = 'TRIP-${math.Random().nextInt(9000) + 1000}';
  }

  Future<void> _loadVehicles() async {
    try {
      final res = await ApiService.getVehicles();
      if (mounted) {
        setState(() {
          _vehicles = res;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load fleet vehicles: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSaveHire() async {
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an active fleet vehicle'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }
    if (_lorryHireController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the negotiated lorry hire amount'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final lorryHire = double.tryParse(_lorryHireController.text) ?? 0;
      final advancePaid = double.tryParse(_advancePaidController.text) ?? 0;

      final payload = {
        'tripNumber': _tripNumber,
        'vehicleId': _selectedVehicle!.id,
        'lorryHire': lorryHire,
        'advancePaid': advancePaid,
        'balanceAmount': lorryHire - advancePaid,
        'sourcedBy': _sourcedBy,
        'brokerName': _brokerNameController.text.trim(),
        'loadingPayer': _loadingPayer,
        'loadingCharge': double.tryParse(_loadingChargeController.text) ?? 0,
        'commissionAmount': double.tryParse(_commissionAmountController.text) ?? 0,
        'commissionDetails': _commissionDetailsController.text.trim(),
        'remarks': _remarksController.text.trim(),
        'gdmIds': [],
      };

      await ApiService.saveTrip(payload);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text('Lorry Hire Agreement for $_tripNumber locked & saved!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        
        setState(() {
          _generateTripNumber();
          _selectedVehicle = null;
          _sourcedBy = 'Direct';
          _loadingPayer = 'Transport';
          _lorryHireController.clear();
          _advancePaidController.clear();
          _brokerNameController.clear();
          _loadingChargeController.clear();
          _commissionAmountController.clear();
          _commissionDetailsController.clear();
          _remarksController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save Lorry Hire: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildSwissCard({required Widget child, Color? borderColor, Color? bgColor, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title, {IconData? icon, Color color = const Color(0xFFD97706)}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
          ],
          Text(
            title.toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: color, letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco({
    String? labelText,
    String? hintText,
    String? prefixText,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      prefixText: prefixText,
      prefixStyle: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: const Color(0xFF64748B)) : null,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _themePrimary, width: 1.8),
      ),
    );
  }

  Widget _buildSegmentedPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _themePrimary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _themePrimary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: isSelected ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: _themePrimary),
        ),
      );
    }

    final hire = double.tryParse(_lorryHireController.text) ?? 0;
    final advance = double.tryParse(_advancePaidController.text) ?? 0;
    final commission = double.tryParse(_commissionAmountController.text) ?? 0;
    final balance = hire - advance;
    final double advancePercent = hire > 0 ? ((advance / hire) * 100).clamp(0, 100) : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Executive Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
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
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: _themeGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _themePrimary.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.handshake_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lorry Hire & Trip Agreement',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Negotiated vehicle contracts, loading charges, broker commission & advance disbursement',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blueGrey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: Color(0xFFD97706), shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _tripNumber,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, fontFamily: 'monospace', color: Color(0xFF92400E)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Main 2-Column Cockpit
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Contract & Transit Parameters
                    Expanded(
                      flex: 6,
                      child: _buildSwissCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader('1. Vehicle & Logistics Contract', icon: Icons.local_shipping_rounded),
                            
                            // Vehicle Selector
                            DropdownButtonFormField<Vehicle>(
                              value: _selectedVehicle,
                              decoration: _inputDeco(labelText: 'ASSIGN FLEET VEHICLE *', prefixIcon: Icons.directions_bus_filled_rounded),
                              items: _vehicles.map((v) => DropdownMenuItem(
                                value: v,
                                child: Text(
                                  '${v.vehicleNumber}  •  ${v.type ?? 'Standard'}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              )).toList(),
                              onChanged: (v) => setState(() => _selectedVehicle = v),
                            ),
                            
                            // Selected Vehicle Identity Card
                            if (_selectedVehicle != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Owner: ${_selectedVehicle!.ownerName ?? 'Direct'}  |  Body: ${_selectedVehicle!.ladenType ?? 'Open'}  |  Phone: ${_selectedVehicle!.ownerPhone ?? '-'}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),

                            // Vehicle Sourcing Segmented Switch
                            const Text('VEHICLE SOURCING CHANNEL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildSegmentedPill(
                                  label: 'Direct Sourcing',
                                  isSelected: _sourcedBy == 'Direct',
                                  icon: Icons.person_rounded,
                                  onTap: () => setState(() => _sourcedBy = 'Direct'),
                                ),
                                const SizedBox(width: 10),
                                _buildSegmentedPill(
                                  label: 'Broker / Third-Party Transporter',
                                  isSelected: _sourcedBy == 'Broker',
                                  icon: Icons.business_center_rounded,
                                  onTap: () => setState(() => _sourcedBy = 'Broker'),
                                ),
                              ],
                            ),
                            if (_sourcedBy == 'Broker') ...[
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _brokerNameController,
                                decoration: _inputDeco(labelText: 'BROKER / TRANSPORTER AGENCY NAME', prefixIcon: Icons.badge_outlined),
                              ),
                            ],
                            const SizedBox(height: 20),

                            // Loading Charge Payer
                            const Text('LOADING CHARGE BORNE BY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildSegmentedPill(
                                  label: 'Transport (Us)',
                                  isSelected: _loadingPayer == 'Transport',
                                  onTap: () => setState(() => _loadingPayer = 'Transport'),
                                ),
                                _buildSegmentedPill(
                                  label: 'Lorry Owner',
                                  isSelected: _loadingPayer == 'Lorry Owner',
                                  onTap: () => setState(() => _loadingPayer = 'Lorry Owner'),
                                ),
                                _buildSegmentedPill(
                                  label: 'Consignor',
                                  isSelected: _loadingPayer == 'Consignor',
                                  onTap: () => setState(() => _loadingPayer = 'Consignor'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _loadingChargeController,
                              decoration: _inputDeco(labelText: 'LOADING CHARGE AMOUNT', prefixText: '₹ ', prefixIcon: Icons.currency_rupee_rounded),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 20),

                            // Remarks
                            TextFormField(
                              controller: _remarksController,
                              decoration: _inputDeco(
                                labelText: 'CONTRACT TERMS & SPECIAL TRANSIT REMARKS',
                                hintText: 'Transit route, detention clauses, toll allowances...',
                              ),
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),

                    // Right Column: Financial Settlement & Advance
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: [
                          _buildSwissCard(
                            borderColor: const Color(0xFFFDE68A),
                            bgColor: const Color(0xFFFFFBEB),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('2. Negotiated Financial Settlement', icon: Icons.payments_rounded, color: const Color(0xFFB45309)),
                                
                                // Total Lorry Hire Input
                                TextFormField(
                                  controller: _lorryHireController,
                                  decoration: InputDecoration(
                                    labelText: 'TOTAL AGREED LORRY HIRE *',
                                    labelStyle: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF78350F), fontSize: 12),
                                    prefixText: '₹ ',
                                    prefixStyle: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 20),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _themePrimary, width: 2)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                  onChanged: (v) => setState(() {}),
                                ),
                                const SizedBox(height: 16),

                                // Advance Paid Input
                                TextFormField(
                                  controller: _advancePaidController,
                                  decoration: InputDecoration(
                                    labelText: 'IMMEDIATE ADVANCE PAID (CASH / BANK)',
                                    labelStyle: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF065F46), fontSize: 12),
                                    prefixText: '₹ ',
                                    prefixStyle: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF059669), fontSize: 20),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 2)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                                  onChanged: (v) => setState(() {}),
                                ),
                                const SizedBox(height: 20),

                                // Balance Due Summary Tile
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFD97706).withValues(alpha: 0.08),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('NET BALANCE DUE ON DELIVERY', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF64748B), fontSize: 11, letterSpacing: 0.5)),
                                              const SizedBox(height: 2),
                                              Text(
                                                '₹ ${balance.toStringAsFixed(2)}',
                                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: advancePercent >= 50 ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '${advancePercent.toStringAsFixed(0)}% Advance',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: advancePercent >= 50 ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Brokerage & Commission Card
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.discount_rounded, size: 16, color: Color(0xFF64748B)),
                                          SizedBox(width: 6),
                                          Text('BROKER COMMISSION & EXTRA DEDUCTIONS', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontSize: 12)),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _commissionDetailsController,
                                        decoration: _inputDeco(labelText: 'COMMISSION TYPE / DETAILS', hintText: 'Broker commission, TDS or loading cut'),
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _commissionAmountController,
                                        decoration: _inputDeco(labelText: 'COMMISSION AMOUNT', prefixText: '₹ '),
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                        onChanged: (v) => setState(() {}),
                                      ),
                                      if (commission > 0) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Net payable after commission: ₹ ${(hire - commission).toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Save Action Button
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: _themeGradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: _themePrimary.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              icon: _isSaving
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.lock_rounded, size: 20),
                              label: Text(_isSaving ? 'LOCKING AGREEMENT...' : 'LOCK & SAVE LORRY HIRE'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
                              ),
                              onPressed: _isSaving ? null : _handleSaveHire,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
