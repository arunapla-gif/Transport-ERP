import 'package:flutter/material.dart';
import '../services/api_service.dart';

class Party {
  final String id;
  final String name;

  Party({required this.id, required this.name});

  factory Party.fromJson(Map<String, dynamic> json) {
    return Party(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? 'Unknown',
    );
  }
}

class LedgerEntry {
  final String id;
  final DateTime date;
  final String reference;
  final String remarks;
  final String type; // 'DEBIT' or 'CREDIT'
  final double amount;
  final double balance;

  LedgerEntry({
    required this.id,
    required this.date,
    required this.reference,
    required this.remarks,
    required this.type,
    required this.amount,
    required this.balance,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      id: json['id'].toString(),
      date: DateTime.parse(json['date']),
      reference: json['reference']?.toString() ?? '',
      remarks: json['remarks']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      balance: double.tryParse(json['balance']?.toString() ?? '0') ?? 0,
    );
  }
}

class PartyAccountsScreen extends StatefulWidget {
  const PartyAccountsScreen({super.key});

  @override
  State<PartyAccountsScreen> createState() => _PartyAccountsScreenState();
}

class _PartyAccountsScreenState extends State<PartyAccountsScreen> {
  String _partyType = 'Consignee'; // 'Consignee' or 'Consignor'
  List<Party> _parties = [];
  Party? _selectedParty;

  List<LedgerEntry> _ledgerData = [];
  double _currentBalance = 0;
  bool _isLoadingLedger = false;
  int _page = 1;
  bool _hasMore = true;

  bool _isSavingPayment = false;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  String _paymentMode = 'Bank Transfer';
  String _dateText = DateTime.now().toIso8601String().split('T')[0];

  final ScrollController _scrollController = ScrollController();

  static const List<Color> _themeGradient = [Color(0xFF4F46E5), Color(0xFF3730A3)];
  static const Color _themePrimary = Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    _fetchParties();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _amountController.dispose();
    _referenceController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingLedger && _hasMore) {
      _fetchLedger(_page + 1);
    }
  }

  void _onPartyTypeChanged(String type) {
    setState(() {
      _partyType = type;
      _selectedParty = null;
      _ledgerData = [];
      _currentBalance = 0;
      _page = 1;
      _hasMore = true;
    });
    _fetchParties();
  }

  Future<void> _fetchParties() async {
    try {
      final endpoint = _partyType == 'Consignee' ? 'consignees' : 'consignors';
      final res = await ApiService.getParties(endpoint, limit: 500);
      if (mounted) {
        setState(() {
          _parties = res.map((e) => Party.fromJson(e)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load $_partyType profiles: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _fetchLedger(int pageNum) async {
    if (_selectedParty == null) return;
    setState(() => _isLoadingLedger = true);

    try {
      final endpoint = _partyType == 'Consignee' ? 'consignees' : 'consignors';
      final res = await ApiService.getPartyLedger(endpoint, _selectedParty!.id, page: pageNum, limit: 20);
      final List data = res['ledger'] ?? [];
      final newEntries = data.map((e) => LedgerEntry.fromJson(e)).toList();

      if (mounted) {
        setState(() {
          if (pageNum == 1) {
            _ledgerData = newEntries;
          } else {
            _ledgerData.addAll(newEntries);
          }
          _currentBalance = double.tryParse(res['currentBalance']?.toString() ?? '0') ?? 0;
          _page = pageNum;
          final totalPages = int.tryParse(res['totalPages']?.toString() ?? '1') ?? 1;
          _hasMore = (res['hasMore'] == true) || (pageNum < totalPages);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load ledger: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingLedger = false);
    }
  }

  Future<void> _handleRecordPayment() async {
    final amt = double.tryParse(_amountController.text);
    if (amt == null || amt <= 0 || _selectedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a party and enter a valid positive payment amount'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSavingPayment = true);
    try {
      final payload = {
        'partyType': _partyType.toLowerCase(),
        'partyId': _selectedParty!.id,
        'amount': amt,
        'paymentMode': _paymentMode,
        'reference': _referenceController.text.trim(),
        'remarks': _remarksController.text.trim(),
        'date': _dateText,
      };

      await ApiService.savePartyPayment(payload);
      _amountController.clear();
      _referenceController.clear();
      _remarksController.clear();
      await _fetchLedger(1);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text('Payment of ₹ ${amt.toStringAsFixed(2)} reconciled successfully!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record payment: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingPayment = false);
    }
  }

  Widget _buildGlassCard({required Widget child, Color? bgColor, Color? borderColor, EdgeInsetsGeometry? padding}) {
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

  InputDecoration _inputDeco({
    String? hintText,
    String? prefixText,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      prefixText: prefixText,
      prefixStyle: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: const Color(0xFF64748B)) : null,
      filled: true,
      fillColor: Colors.white,
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

  @override
  Widget build(BuildContext context) {
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
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Party Accounts & Statement Ledger',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Receivables & payables tracking, real-time running ledger statements & payment reconciliation',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blueGrey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Party Type Toggle Pills
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            _buildToggleBtn('Consignee', Icons.storefront_rounded),
                            _buildToggleBtn('Consignor', Icons.domain_rounded),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Selection & Payment Form
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          // Party Selector Card
                          _buildGlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _themePrimary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _partyType.toUpperCase(),
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: _themePrimary, letterSpacing: 1),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text('SELECT PARTY ACCOUNT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A), letterSpacing: 0.5)),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                DropdownButtonFormField<Party>(
                                  value: _selectedParty,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _themePrimary, width: 1.8)),
                                    hintText: 'Choose ${_partyType.toLowerCase()} profile...',
                                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                  ),
                                  items: _parties.map((p) => DropdownMenuItem(value: p, child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)))).toList(),
                                  onChanged: (p) {
                                    setState(() {
                                      _selectedParty = p;
                                    });
                                    _fetchLedger(1);
                                  },
                                ),
                                
                                // Hero Balance Tile
                                if (_selectedParty != null) ...[
                                  const SizedBox(height: 18),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: _currentBalance > 0
                                          ? const Color(0xFFFEF2F2)
                                          : (_currentBalance < 0 ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC)),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _currentBalance > 0
                                            ? const Color(0xFFFECACA)
                                            : (_currentBalance < 0 ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _currentBalance > 0 ? Icons.arrow_upward_rounded : (_currentBalance < 0 ? Icons.arrow_downward_rounded : Icons.check_circle_rounded),
                                              size: 14,
                                              color: _currentBalance > 0 ? const Color(0xFFDC2626) : (_currentBalance < 0 ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _currentBalance > 0 ? 'RECEIVABLE DUE (THEY OWE)' : (_currentBalance < 0 ? 'ADVANCE CREDIT (WE OWE)' : 'ACCOUNT SETTLED EVEN'),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 10,
                                                letterSpacing: 0.8,
                                                color: _currentBalance > 0 ? const Color(0xFFDC2626) : (_currentBalance < 0 ? const Color(0xFF15803D) : const Color(0xFF64748B)),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '₹ ${_currentBalance.abs().toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 32,
                                            color: _currentBalance > 0 ? const Color(0xFFDC2626) : (_currentBalance < 0 ? const Color(0xFF15803D) : const Color(0xFF0F172A)),
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Direct Payment Receipt Form
                          if (_selectedParty != null)
                            _buildGlassCard(
                              bgColor: const Color(0xFFF0FDF4),
                              borderColor: const Color(0xFFBBF7D0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'PAYMENT',
                                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Color(0xFF15803D), letterSpacing: 1),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Text('RECORD PAYMENT RECEIVED', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A), letterSpacing: 0.5)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  const Text('COLLECTION AMOUNT (₹) *', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _amountController,
                                    decoration: InputDecoration(
                                      prefixText: '₹ ',
                                      prefixStyle: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 18),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8)),
                                    ),
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                    onChanged: (v) => setState(() {}),
                                  ),
                                  const SizedBox(height: 14),
                                  
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('PAYMENT DATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5)),
                                            const SizedBox(height: 6),
                                            TextFormField(
                                              initialValue: _dateText,
                                              decoration: _inputDeco(prefixIcon: Icons.calendar_today_rounded),
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                              onChanged: (v) => _dateText = v,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('PAYMENT MODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5)),
                                            const SizedBox(height: 6),
                                            DropdownButtonFormField<String>(
                                              value: _paymentMode,
                                              decoration: InputDecoration(
                                                filled: true,
                                                fillColor: Colors.white,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8)),
                                              ),
                                              items: ['Bank Transfer', 'Cash', 'Cheque', 'UPI'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)))).toList(),
                                              onChanged: (v) => setState(() => _paymentMode = v!),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  
                                  const Text('REFERENCE / UTR / CHEQUE NUMBER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _referenceController,
                                    decoration: _inputDeco(hintText: 'e.g. NEFT-12345678 or CHQ-0012', prefixIcon: Icons.receipt_long_rounded),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  const SizedBox(height: 14),

                                  const Text('REMARKS / NARRATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _remarksController,
                                    decoration: _inputDeco(hintText: 'Optional settlement notes'),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  Container(
                                    width: double.infinity,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF059669), Color(0xFF10B981)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton.icon(
                                      onPressed: (_isSavingPayment || _amountController.text.isEmpty) ? null : _handleRecordPayment,
                                      icon: _isSavingPayment
                                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : const Icon(Icons.check_circle_outline_rounded, size: 20),
                                      label: Text(_isSavingPayment ? 'RECONCILING...' : 'RECONCILE & RECORD RECEIPT'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        shadowColor: Colors.transparent,
                                        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 24),
                    
                    // Right Column: Running Statement Ledger
                    Expanded(
                      flex: 8,
                      child: _buildGlassCard(
                        padding: EdgeInsets.zero,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Ledger Title Header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF8FAFC),
                                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: _themePrimary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(Icons.receipt_long_rounded, color: _themePrimary, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _selectedParty != null ? '${_selectedParty!.name} Statement' : 'Running Statement Ledger',
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                                            ),
                                            Text(
                                              _selectedParty != null
                                                  ? 'Complete chronological debit & credit transaction history'
                                                  : 'Select a party on the left to inspect transactions',
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${_ledgerData.length} Transactions',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              if (_selectedParty == null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFF1F5F9),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.person_search_rounded, size: 48, color: Color(0xFF94A3B8)),
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'No Party Account Selected',
                                          style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w800, fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Select a ${_partyType.toLowerCase()} on the left to view their live running ledger and record payments.',
                                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else if (_ledgerData.isEmpty && !_isLoadingLedger)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 80, horizontal: 24),
                                  child: Center(
                                    child: Text(
                                      'No transactions found for this party.\nPost new GC bilties or record advance receipts to populate.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600, height: 1.5),
                                    ),
                                  ),
                                )
                              else ...[
                                // Table Header
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF8FAFC),
                                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                                  ),
                                  child: const Row(
                                    children: [
                                      SizedBox(width: 100, child: Text('DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5))),
                                      Expanded(child: Text('VOUCHER / REFERENCE & REMARKS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5))),
                                      SizedBox(width: 110, child: Text('DEBIT (₹)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFDC2626), letterSpacing: 0.5), textAlign: TextAlign.right)),
                                      SizedBox(width: 110, child: Text('CREDIT (₹)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF15803D), letterSpacing: 0.5), textAlign: TextAlign.right)),
                                      SizedBox(width: 130, child: Text('BALANCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5), textAlign: TextAlign.right)),
                                    ],
                                  ),
                                ),

                                // Transaction List
                                SizedBox(
                                  height: 520,
                                  child: ListView.separated(
                                    controller: _scrollController,
                                    itemCount: _ledgerData.length + (_hasMore ? 1 : 0),
                                    separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                    itemBuilder: (context, index) {
                                      if (index == _ledgerData.length) {
                                        return Padding(
                                          padding: const EdgeInsets.all(24.0),
                                          child: Center(
                                            child: _isLoadingLedger
                                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: _themePrimary, strokeWidth: 2))
                                                : const Text('Scroll for more transactions', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                          ),
                                        );
                                      }
                                      
                                      final entry = _ledgerData[index];
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                        child: Row(
                                          children: [
                                            // Date
                                            SizedBox(
                                              width: 100,
                                              child: Text(
                                                entry.date.toIso8601String().split('T')[0],
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, fontFamily: 'monospace', color: Color(0xFF64748B)),
                                              ),
                                            ),

                                            // Reference & Remarks
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    entry.reference,
                                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                                                  ),
                                                  if (entry.remarks.isNotEmpty)
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 2),
                                                      child: Text(
                                                        entry.remarks,
                                                        style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade500, fontWeight: FontWeight.w500),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),

                                            // Debit
                                            SizedBox(
                                              width: 110,
                                              child: Text(
                                                entry.type == 'DEBIT' ? entry.amount.toStringAsFixed(2) : '-',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13,
                                                  color: entry.type == 'DEBIT' ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1),
                                                ),
                                                textAlign: TextAlign.right,
                                              ),
                                            ),

                                            // Credit
                                            SizedBox(
                                              width: 110,
                                              child: Text(
                                                entry.type == 'CREDIT' ? entry.amount.toStringAsFixed(2) : '-',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13,
                                                  color: entry.type == 'CREDIT' ? const Color(0xFF15803D) : const Color(0xFFCBD5E1),
                                                ),
                                                textAlign: TextAlign.right,
                                              ),
                                            ),

                                            // Running Balance
                                            SizedBox(
                                              width: 130,
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: entry.balance > 0
                                                          ? const Color(0xFFFEF2F2)
                                                          : (entry.balance < 0 ? const Color(0xFFF0FDF4) : const Color(0xFFF1F5F9)),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      '₹ ${entry.balance.abs().toStringAsFixed(2)} ${entry.balance > 0 ? 'Dr' : (entry.balance < 0 ? 'Cr' : '')}', 
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w900,
                                                        fontSize: 12,
                                                        color: entry.balance > 0
                                                            ? const Color(0xFFDC2626)
                                                            : (entry.balance < 0 ? const Color(0xFF15803D) : const Color(0xFF64748B)),
                                                      ), 
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
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

  Widget _buildToggleBtn(String title, IconData icon) {
    final isActive = _partyType == title;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _onPartyTypeChanged(title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isActive ? _themePrimary : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
                color: isActive ? _themePrimary : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
