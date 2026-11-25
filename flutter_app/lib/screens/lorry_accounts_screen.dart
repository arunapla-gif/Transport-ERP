import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LorryAccountsScreen extends StatefulWidget {
  const LorryAccountsScreen({super.key});

  @override
  State<LorryAccountsScreen> createState() => _LorryAccountsScreenState();
}

class _LorryAccountsScreenState extends State<LorryAccountsScreen> {
  bool _isLoading = false;

  final TextEditingController _billNumberController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  final TextEditingController _transporterNameController = TextEditingController();
  final TextEditingController _lorryNumberController = TextEditingController();
  final TextEditingController _fromLocationController = TextEditingController();
  final TextEditingController _toLocationController = TextEditingController();
  final TextEditingController _gcNumbersController = TextEditingController();

  final TextEditingController _grossFreightController = TextEditingController();
  final TextEditingController _advancePaidController = TextEditingController();
  final TextEditingController _commissionController = TextEditingController();
  final TextEditingController _shortageController = TextEditingController();
  final TextEditingController _tdsController = TextEditingController();

  String _paymentMode = 'Bank Transfer';
  String _status = 'Approved';
  final TextEditingController _referenceNoController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dateController.text = DateTime.now().toIso8601String().split('T')[0];
    _billNumberController.text = 'LFS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  }

  @override
  void dispose() {
    _billNumberController.dispose();
    _dateController.dispose();
    _transporterNameController.dispose();
    _lorryNumberController.dispose();
    _fromLocationController.dispose();
    _toLocationController.dispose();
    _gcNumbersController.dispose();
    _grossFreightController.dispose();
    _advancePaidController.dispose();
    _commissionController.dispose();
    _shortageController.dispose();
    _tdsController.dispose();
    _referenceNoController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  double get _gross => double.tryParse(_grossFreightController.text.trim()) ?? 0.0;
  double get _advance => double.tryParse(_advancePaidController.text.trim()) ?? 0.0;
  double get _commission => double.tryParse(_commissionController.text.trim()) ?? 0.0;
  double get _shortage => double.tryParse(_shortageController.text.trim()) ?? 0.0;
  double get _tds => double.tryParse(_tdsController.text.trim()) ?? 0.0;

  double get _totalDeductions => _advance + _commission + _shortage + _tds;
  double get _netBalance => _gross - _totalDeductions;

  void _applyTdsPercentage(double percent) {
    if (_gross > 0) {
      final calculated = (_gross * (percent / 100.0));
      setState(() {
        _tdsController.text = calculated.toStringAsFixed(2);
      });
    }
  }

  void _handleReset() {
    setState(() {
      _billNumberController.text = 'LFS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      _dateController.text = DateTime.now().toIso8601String().split('T')[0];
      _transporterNameController.clear();
      _lorryNumberController.clear();
      _fromLocationController.clear();
      _toLocationController.clear();
      _gcNumbersController.clear();
      _grossFreightController.clear();
      _advancePaidController.clear();
      _commissionController.clear();
      _shortageController.clear();
      _tdsController.clear();
      _paymentMode = 'Bank Transfer';
      _status = 'Approved';
      _referenceNoController.clear();
      _remarksController.clear();
    });
  }

  Future<void> _handleSave() async {
    if (_lorryNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the lorry / vehicle registration number.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    if (_gross <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid gross contract freight amount.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final combinedRemarks = [
        if (_referenceNoController.text.trim().isNotEmpty) 'Ref/UTR: ${_referenceNoController.text.trim()}',
        if (_remarksController.text.trim().isNotEmpty) _remarksController.text.trim(),
      ].join(' | ');

      final payload = {
        'billNumber': _billNumberController.text.trim(),
        'date': _dateController.text.trim(),
        'transporterName': _transporterNameController.text.trim(),
        'lorryNumber': _lorryNumberController.text.trim().toUpperCase(),
        'fromLocation': _fromLocationController.text.trim(),
        'toLocation': _toLocationController.text.trim(),
        'gcNumbers': _gcNumbersController.text.trim(),
        'grossFreight': _gross,
        'advancePaid': _advance,
        'commission': _commission,
        'shortage': _shortage,
        'tds': _tds,
        'netBalance': _netBalance,
        'paymentMode': _paymentMode,
        'status': _status,
        'remarks': combinedRemarks,
      };

      await ApiService.saveFreightBill(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Lorry Settlement ${_billNumberController.text} Saved Successfully!',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _handleReset();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save lorry settlement: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildGlassCard({required Widget child, Color? bgColor, Color? borderColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
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

  Widget _buildDenseInput(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    String? hintText,
    String? prefixText,
    Color? highlightColor,
    int flex = 1,
    Widget? suffix,
  }) {
    final activeColor = highlightColor ?? const Color(0xFFD97706);
    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 44,
            child: TextFormField(
              controller: controller,
              keyboardType: isNumber
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              onChanged: (v) => setState(() {}),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13, fontWeight: FontWeight.normal),
                prefixText: prefixText,
                prefixStyle: TextStyle(fontWeight: FontWeight.w900, color: activeColor, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  borderSide: BorderSide(color: activeColor, width: 1.8),
                ),
                suffixIcon: suffix,
              ),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: highlightColor ?? const Color(0xFF0F172A),
              ),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Cockpit Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF78350F), Color(0xFFB45309), Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB45309).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Lorry Freight Settlement & Accounts',
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
                                  color: const Color(0xFFFEF3C7).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFDE68A).withValues(alpha: 0.4)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_rounded, size: 12, color: Color(0xFFFEF3C7)),
                                    SizedBox(width: 5),
                                    Text(
                                      'TRANSPORTER LEDGER',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 10,
                                        color: Color(0xFFFEF3C7),
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
                            'Contracted hire clearance, advance deductions, TDS Sec 194C withholding & net payment vouchers',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.amber.shade100.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long_rounded, size: 16, color: Colors.white70),
                          const SizedBox(width: 8),
                          Text(
                            _billNumberController.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Executive Financial KPI Summary Row
              Row(
                children: [
                  Expanded(
                    child: _buildGlassCard(
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.handshake_outlined, color: Color(0xFF2563EB), size: 24),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'GROSS CONTRACT FREIGHT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '₹ ${_gross.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF2563EB),
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _buildGlassCard(
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.remove_circle_outline_rounded,
                                color: Color(0xFFEF4444), size: 24),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TOTAL DEDUCTIONS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '₹ ${_totalDeductions.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFEF4444),
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _buildGlassCard(
                      bgColor: _netBalance >= 0
                          ? const Color(0xFF10B981).withValues(alpha: 0.04)
                          : const Color(0xFFEF4444).withValues(alpha: 0.04),
                      borderColor: _netBalance >= 0
                          ? const Color(0xFF10B981).withValues(alpha: 0.3)
                          : const Color(0xFFEF4444).withValues(alpha: 0.3),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _netBalance >= 0
                                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                  : const Color(0xFFEF4444).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              _netBalance >= 0 ? Icons.account_balance_wallet_rounded : Icons.warning_amber_rounded,
                              color: _netBalance >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _netBalance >= 0 ? 'NET BALANCE PAYABLE' : 'TRANSPORTER OVERPAID',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _netBalance >= 0 ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '₹ ${_netBalance.abs().toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: _netBalance >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // 1. TOP RIBBON: Bill Details & Audit Status
              _buildGlassCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _buildDenseInput(
                            'SETTLEMENT BILL NUMBER',
                            _billNumberController,
                            highlightColor: const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 16),
                          _buildDenseInput(
                            'SETTLEMENT DATE',
                            _dateController,
                            suffix: IconButton(
                              icon: const Icon(Icons.calendar_today_rounded, size: 16),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.tryParse(_dateController.text) ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _dateController.text = picked.toIso8601String().split('T')[0];
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'SETTLEMENT STATUS',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 44,
                                  child: DropdownButtonFormField<String>(
                                    value: _status,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                                        borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.8),
                                      ),
                                    ),
                                    items: ['Draft', 'Approved', 'Disbursed', 'On Hold']
                                        .map((s) => DropdownMenuItem(
                                              value: s,
                                              child: Text(
                                                s,
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (v) => setState(() => _status = v!),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'STATUS: ',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: const BoxDecoration(color: Color(0xFFD97706), shape: BoxShape.circle),
                          ),
                          Text(
                            _status,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),

              // 2. TRIP & TRANSPORTER IDENTITY
              _buildGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'STEP 1',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  color: Color(0xFFD97706),
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'TRUCK & TRANSPORTER IDENTIFICATION',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: Color(0xFF0F172A),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.pin_drop_outlined, color: Color(0xFFD97706), size: 20),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _buildDenseInput(
                          'TRANSPORTER / OWNER NAME',
                          _transporterNameController,
                          hintText: 'e.g., Southern Roadlines / Suresh Kumar',
                          flex: 2,
                        ),
                        const SizedBox(width: 16),
                        _buildDenseInput(
                          'LORRY NUMBER (RC)',
                          _lorryNumberController,
                          hintText: 'e.g., TN 38 BJ 1234',
                          highlightColor: const Color(0xFFD97706),
                          flex: 1,
                        ),
                        const SizedBox(width: 16),
                        _buildDenseInput(
                          'ATTACHED GC / BILTY NUMBERS',
                          _gcNumbersController,
                          hintText: 'e.g., GC-1002, GC-1003',
                          flex: 2,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildDenseInput(
                          'ORIGIN LOCATION',
                          _fromLocationController,
                          hintText: 'e.g., Coimbatore Central Godown',
                        ),
                        const SizedBox(width: 16),
                        _buildDenseInput(
                          'DESTINATION LOCATION',
                          _toLocationController,
                          hintText: 'e.g., Chennai Koyambedu Hub',
                        ),
                        const Spacer(),
                      ],
                    )
                  ],
                ),
              ),

              // 3. FINANCIAL CALCULATIONS & TDS BREAKDOWN
              _buildGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'STEP 2',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  color: Color(0xFF059669),
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'FINANCIAL RECONCILIATION & TDS WITHHOLDING',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: Color(0xFF0F172A),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        // Quick TDS Helpers
                        Row(
                          children: [
                            const Text(
                              'Quick TDS (Sec 194C):',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () => _applyTdsPercentage(1.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: const Text(
                                  '1% (Indiv/HUF)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () => _applyTdsPercentage(2.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: const Text(
                                  '2% (Corporate)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    Row(
                      children: [
                        _buildDenseInput(
                          'GROSS FREIGHT (₹)',
                          _grossFreightController,
                          isNumber: true,
                          prefixText: '₹ ',
                          highlightColor: const Color(0xFF2563EB),
                          hintText: '0.00',
                        ),
                        const SizedBox(width: 12),
                        _buildDenseInput(
                          'ADVANCE PAID (₹)',
                          _advancePaidController,
                          isNumber: true,
                          prefixText: '₹ ',
                          hintText: '0.00',
                        ),
                        const SizedBox(width: 12),
                        _buildDenseInput(
                          'COMMISSION / BROKERAGE (₹)',
                          _commissionController,
                          isNumber: true,
                          prefixText: '₹ ',
                          hintText: '0.00',
                        ),
                        const SizedBox(width: 12),
                        _buildDenseInput(
                          'SHORTAGE CLAIM (₹)',
                          _shortageController,
                          isNumber: true,
                          prefixText: '₹ ',
                          hintText: '0.00',
                        ),
                        const SizedBox(width: 12),
                        _buildDenseInput(
                          'TDS AMOUNT (₹)',
                          _tdsController,
                          isNumber: true,
                          prefixText: '₹ ',
                          hintText: '0.00',
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 18),

                    // Payment details & Bottom Action Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'DISBURSEMENT INSTRUMENT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 44,
                                child: DropdownButtonFormField<String>(
                                  value: _paymentMode,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                                      borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.8),
                                    ),
                                  ),
                                  items: ['Bank Transfer', 'Cash', 'Cheque', 'UPI / QR']
                                      .map((s) => DropdownMenuItem(
                                            value: s,
                                            child: Text(
                                              s,
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (v) => setState(() => _paymentMode = v!),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        _buildDenseInput(
                          'UTR / CHQ / REF NO.',
                          _referenceNoController,
                          hintText: 'e.g., UTR-8829104812',
                          flex: 2,
                        ),
                        const SizedBox(width: 14),
                        _buildDenseInput(
                          'NARRATION / REMARKS',
                          _remarksController,
                          hintText: 'Settlement particulars or bank note',
                          flex: 3,
                        ),
                        const SizedBox(width: 16),

                        // Net Balance Display Card
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'NET PAYABLE AMOUNT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: _netBalance >= 0
                                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                    : const Color(0xFFEF4444).withValues(alpha: 0.12),
                                border: Border.all(
                                  color: _netBalance >= 0
                                      ? const Color(0xFF10B981).withValues(alpha: 0.35)
                                      : const Color(0xFFEF4444).withValues(alpha: 0.35),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '₹ ${_netBalance.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: _netBalance >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),

                        // Action Buttons
                        SizedBox(
                          height: 44,
                          child: OutlinedButton(
                            onPressed: _handleReset,
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            child: const Text(
                              'Reset',
                              style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _handleSave,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check_circle_outline_rounded, size: 18),
                            label: Text(_isLoading ? 'SAVING...' : 'DISBURSE & SAVE'),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              backgroundColor: const Color(0xFFD97706),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        )
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
