import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DailyTransaction {
  final int id;
  final String type; // 'EXPENSE' or 'INCOME'
  final String category;
  final double amount;
  final String paymentMode;
  final String description;
  final String reference;
  final DateTime date;

  DailyTransaction({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.paymentMode,
    required this.description,
    required this.reference,
    required this.date,
  });

  factory DailyTransaction.fromJson(Map<String, dynamic> json) {
    return DailyTransaction(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      type: json['type']?.toString().toUpperCase() ?? 'EXPENSE',
      category: json['category']?.toString() ?? 'General',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      paymentMode: json['paymentMode']?.toString() ?? 'Cash',
      description: json['description']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class DailyAccountsScreen extends StatefulWidget {
  const DailyAccountsScreen({super.key});

  @override
  State<DailyAccountsScreen> createState() => _DailyAccountsScreenState();
}

class _DailyAccountsScreenState extends State<DailyAccountsScreen> {
  List<DailyTransaction> _transactions = [];
  bool _isLoading = false;
  int _page = 1;
  bool _hasMore = true;

  double _totalIncome = 0;
  double _totalExpense = 0;
  double _netBalance = 0;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilterTab = 'ALL'; // 'ALL', 'EXPENSE', 'INCOME'
  String _searchQuery = '';

  // Form State
  String _type = 'EXPENSE';
  String _category = 'Fuel / Diesel';
  final TextEditingController _amountController = TextEditingController();
  String _paymentMode = 'Cash';
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _dateController = TextEditingController(
    text: DateTime.now().toIso8601String().split('T')[0],
  );

  bool _isSaving = false;

  final Map<String, List<String>> _categories = {
    'EXPENSE': [
      'Fuel / Diesel',
      'Vehicle Maintenance',
      'Driver Bata / Advance',
      'Loading / Hamali',
      'Toll / FASTag Cash',
      'Office Supplies & Stationery',
      'Tea & Refreshments',
      'Branch Rent & Utilities',
      'Staff Salary & Wages',
      'Other Expense',
    ],
    'INCOME': [
      'Freight Cash Collected',
      'Demurrage & Hamali Charge',
      'Customer Advance / Deposit',
      'Scrap & Tyre Sale',
      'Miscellaneous Income',
      'Other Income',
    ]
  };

  @override
  void initState() {
    super.initState();
    _fetchTransactions(1);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _referenceController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _fetchTransactions(_page + 1);
    }
  }

  Future<void> _fetchTransactions(int pageNum) async {
    setState(() => _isLoading = true);

    try {
      final res = await ApiService.getDailyTransactions(page: pageNum, limit: 50);
      final List data = res['data'] ?? [];
      final newItems = data.map((e) => DailyTransaction.fromJson(e)).toList();

      setState(() {
        if (pageNum == 1) {
          _transactions = newItems;
        } else {
          _transactions.addAll(newItems);
        }
        _page = pageNum;
        final totalPages = int.tryParse(res['totalPages']?.toString() ?? '1') ?? 1;
        _hasMore = (res['hasMore'] == true) || (pageNum < totalPages);

        if (res['totalIncome'] != null || res['totalExpense'] != null) {
          _totalIncome = double.tryParse(res['totalIncome']?.toString() ?? '0') ?? 0;
          _totalExpense = double.tryParse(res['totalExpense']?.toString() ?? '0') ?? 0;
          _netBalance = double.tryParse(res['netBalance']?.toString() ?? '0') ?? (_totalIncome - _totalExpense);
        } else if (res['summary'] != null) {
          _totalIncome = double.tryParse(res['summary']['totalIncome']?.toString() ?? '0') ?? 0;
          _totalExpense = double.tryParse(res['summary']['totalExpense']?.toString() ?? '0') ?? 0;
          _netBalance = double.tryParse(res['summary']['netBalance']?.toString() ?? '0') ?? 0;
        } else {
          _recomputeTotals();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load transactions: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _recomputeTotals() {
    double income = 0;
    double expense = 0;
    for (final t in _transactions) {
      if (t.type == 'INCOME') {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    _totalIncome = income;
    _totalExpense = expense;
    _netBalance = income - expense;
  }

  Future<void> _handleSave() async {
    final amt = double.tryParse(_amountController.text.trim());
    if (amt == null || amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount greater than zero.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = {
        'type': _type,
        'category': _category,
        'amount': amt,
        'paymentMode': _paymentMode,
        'description': _descriptionController.text.trim(),
        'reference': _referenceController.text.trim(),
        'date': _dateController.text.trim(),
      };

      await ApiService.saveDailyTransaction(payload);

      _amountController.clear();
      _descriptionController.clear();
      _referenceController.clear();

      await _fetchTransactions(1);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  '${_type == 'INCOME' ? 'Income' : 'Expense'} voucher of ₹${amt.toStringAsFixed(2)} recorded!',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
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
            content: Text('Failed to save voucher: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDelete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 10),
            Text('Void Voucher Transaction', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this cashbook entry? This action updates running petty cash totals immediately.',
          style: TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Void & Delete', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.deleteDailyTransaction(id);
      await _fetchTransactions(1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction successfully voided and removed.'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete transaction: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _showTransactionDetailModal(DailyTransaction t) {
    final isIncome = t.type == 'INCOME';
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isIncome
                              ? const Color(0xFF10B981).withValues(alpha: 0.12)
                              : const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          color: isIncome ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isIncome ? 'CASH RECEIPT VOUCHER' : 'PAYMENT VOUCHER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: isIncome ? const Color(0xFF059669) : const Color(0xFFDC2626),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Voucher #${t.id.toString().padLeft(5, '0')}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Amount Hero Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isIncome
                        ? [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)]
                        : [const Color(0xFFFEF2F2), const Color(0xFFFEE2E2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isIncome
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : const Color(0xFFEF4444).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isIncome ? 'TOTAL AMOUNT RECEIVED' : 'TOTAL AMOUNT PAID',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isIncome ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '₹ ${t.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: isIncome ? const Color(0xFF059669) : const Color(0xFFDC2626),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Details Grid
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildModalRow('Date of Entry', t.date.toIso8601String().split('T')[0]),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    _buildModalRow('Category', t.category),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    _buildModalRow('Payment Instrument', t.paymentMode),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    _buildModalRow(
                      'Reference / Bill No.',
                      t.reference.isNotEmpty ? t.reference : 'N/A (Direct Cash)',
                    ),
                    if (t.description.isNotEmpty) ...[
                      const Divider(height: 16, color: Color(0xFFE2E8F0)),
                      _buildModalRow('Particulars / Narration', t.description),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Voucher slip generated for printing.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.print_rounded, size: 18, color: Color(0xFF334155)),
                      label: const Text(
                        'PRINT SLIP',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF334155)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleDelete(t.id);
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text(
                        'VOID ENTRY',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }

  List<DailyTransaction> get _filteredTransactions {
    return _transactions.where((t) {
      if (_selectedFilterTab == 'EXPENSE' && t.type != 'EXPENSE') return false;
      if (_selectedFilterTab == 'INCOME' && t.type != 'INCOME') return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchCategory = t.category.toLowerCase().contains(q);
        final matchDesc = t.description.toLowerCase().contains(q);
        final matchRef = t.reference.toLowerCase().contains(q);
        final matchMode = t.paymentMode.toLowerCase().contains(q);
        final matchAmt = t.amount.toString().contains(q);
        if (!matchCategory && !matchDesc && !matchRef && !matchMode && !matchAmt) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Widget _buildGlassCard({required Widget child, Color? bgColor, Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
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

  Widget _buildInflowCard() {
    return _buildGlassCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.arrow_downward_rounded, color: Color(0xFF10B981), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TOTAL CASH INFLOW (RECEIPTS)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '₹ ${_totalIncome.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF10B981),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutflowCard() {
    return _buildGlassCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFFEF4444), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TOTAL CASH OUTFLOW (EXPENSES)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '₹ ${_totalExpense.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFEF4444),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return _buildGlassCard(
      bgColor: _netBalance >= 0
          ? const Color(0xFF2563EB).withValues(alpha: 0.04)
          : const Color(0xFFD97706).withValues(alpha: 0.04),
      borderColor: _netBalance >= 0
          ? const Color(0xFF2563EB).withValues(alpha: 0.25)
          : const Color(0xFFD97706).withValues(alpha: 0.25),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _netBalance >= 0
                  ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                  : const Color(0xFFD97706).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _netBalance >= 0 ? Icons.savings_rounded : Icons.warning_amber_rounded,
              color: _netBalance >= 0 ? const Color(0xFF2563EB) : const Color(0xFFD97706),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _netBalance >= 0 ? 'NET PETTY CASH IN HAND' : 'PETTY DEFICIT / ADVANCE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _netBalance >= 0 ? const Color(0xFF1E40AF) : const Color(0xFFB45309),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '₹ ${_netBalance.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _netBalance >= 0 ? const Color(0xFF2563EB) : const Color(0xFFD97706),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredTransactions;
    final primaryColor = _type == 'EXPENSE' ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Cockpit Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF064E3B), Color(0xFF065F46), Color(0xFF0F766E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF064E3B).withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 680;
                final infoColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        const Text(
                          'Daily Cashbook & Petty Accounts',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.storefront_rounded, size: 12, color: Color(0xFFA7F3D0)),
                              SizedBox(width: 5),
                              Text(
                                'CBE-01 PETTY REGISTER',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  color: Color(0xFFA7F3D0),
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
                      'Live station petty cash tracking, categorized operational vouchers & daily balance audit',
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFFA7F3D0).withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );

                final actionControls = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_note_rounded, size: 16, color: Colors.white70),
                          const SizedBox(width: 8),
                          Text(
                            _dateController.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Material(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _fetchTransactions(1),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                const Text(
                                  'Daily Cashbook',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'CBE-01',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: Color(0xFFA7F3D0)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      actionControls,
                    ],
                  );
                }

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 18),
                    Expanded(child: infoColumn),
                    const SizedBox(width: 14),
                    actionControls,
                  ],
                );
              },
            ),
          ),

          // Top Financial KPI Stat Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 768;
              if (isSmall) {
                return Column(
                  children: [
                    _buildInflowCard(),
                    const SizedBox(height: 12),
                    _buildOutflowCard(),
                    const SizedBox(height: 12),
                    _buildBalanceCard(),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: _buildInflowCard()),
                  const SizedBox(width: 18),
                  Expanded(child: _buildOutflowCard()),
                  const SizedBox(width: 18),
                  Expanded(child: _buildBalanceCard()),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Two-Column Work Area (Responsive)
          LayoutBuilder(
            builder: (context, constraints) {
              final isStacked = constraints.maxWidth < 960;
              final formCard = _buildVoucherFormCard(primaryColor);
              final ledgerCard = _buildLedgerCard(filteredList);

              if (isStacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    formCard,
                    const SizedBox(height: 24),
                    ledgerCard,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: formCard),
                  const SizedBox(width: 24),
                  Expanded(flex: 8, child: ledgerCard),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherFormCard(Color primaryColor) {
    return _buildGlassCard(
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
                                  color: primaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'CASH VOUCHER',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    color: primaryColor,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'NEW ENTRY',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          Icon(Icons.edit_note_rounded, color: primaryColor, size: 22),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // High Contrast Type Toggle (Expense vs Income)
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => setState(() {
                                  _type = 'EXPENSE';
                                  _category = _categories['EXPENSE']!.first;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  decoration: BoxDecoration(
                                    color: _type == 'EXPENSE' ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: _type == 'EXPENSE'
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.arrow_upward_rounded,
                                        size: 16,
                                        color: _type == 'EXPENSE'
                                            ? const Color(0xFFEF4444)
                                            : Colors.blueGrey.shade400,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'EXPENSE (OUT)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          color: _type == 'EXPENSE'
                                              ? const Color(0xFFEF4444)
                                              : Colors.blueGrey.shade600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => setState(() {
                                  _type = 'INCOME';
                                  _category = _categories['INCOME']!.first;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  decoration: BoxDecoration(
                                    color: _type == 'INCOME' ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: _type == 'INCOME'
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.arrow_downward_rounded,
                                        size: 16,
                                        color: _type == 'INCOME'
                                            ? const Color(0xFF10B981)
                                            : Colors.blueGrey.shade400,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'INCOME (IN)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          color: _type == 'INCOME'
                                              ? const Color(0xFF10B981)
                                              : Colors.blueGrey.shade600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Category Dropdown
                      const Text(
                        'EXPENSE / INCOME CATEGORY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _categories[_type]!.contains(_category) ? _category : _categories[_type]!.first,
                        decoration: InputDecoration(
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
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryColor, width: 1.8),
                          ),
                        ),
                        items: _categories[_type]!
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    s,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _category = v!),
                      ),
                      const SizedBox(height: 16),

                      // Bold Amount Field
                      const Text(
                        'TRANSACTION AMOUNT (₹)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 14, right: 8),
                            child: Text(
                              '₹',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: primaryColor,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                          hintText: '0.00',
                          hintStyle: TextStyle(
                            color: Colors.blueGrey.shade300,
                            fontWeight: FontWeight.w700,
                          ),
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
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryColor, width: 1.8),
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Quick Cash Chips (+100, +500, +1000, +2000)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [100, 500, 1000, 2000, 5000].map((quickAmt) {
                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              final current = double.tryParse(_amountController.text.trim()) ?? 0;
                              _amountController.text = (current + quickAmt).toStringAsFixed(0);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                '+₹$quickAmt',
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
                      const SizedBox(height: 16),

                      // Date & Mode in 1 Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DATE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _dateController,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                                      borderSide: BorderSide(color: primaryColor, width: 1.8),
                                    ),
                                    suffixIcon: IconButton(
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
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PAYMENT MODE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: _paymentMode,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                                      borderSide: BorderSide(color: primaryColor, width: 1.8),
                                    ),
                                  ),
                                  items: ['Cash', 'UPI / QR', 'Bank Transfer', 'Cheque']
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
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Reference / Bill No
                      const Text(
                        'REFERENCE / VOUCHER / BILL NO.',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _referenceController,
                        decoration: InputDecoration(
                          hintText: 'e.g., BILL-9921 / PETTY-44',
                          hintStyle: TextStyle(color: Colors.blueGrey.shade300, fontWeight: FontWeight.normal),
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
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryColor, width: 1.8),
                          ),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const SizedBox(height: 16),

                      // Description / Narration
                      const Text(
                        'PARTICULARS / NARRATION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Enter specific purpose (e.g., Diesel 50L for TN 38 BJ 1234)',
                          hintStyle: TextStyle(color: Colors.blueGrey.shade300, fontWeight: FontWeight.normal),
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
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryColor, width: 1.8),
                          ),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _handleSave,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Icon(
                                  _type == 'INCOME' ? Icons.add_circle_rounded : Icons.check_circle_rounded,
                                  size: 20,
                                ),
                          label: Text(_isSaving
                              ? 'RECORDING VOUCHER...'
                              : 'RECORD ${_type == 'INCOME' ? 'RECEIPT' : 'EXPENSE'} VOUCHER'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                            shadowColor: primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
  }

  Widget _buildLedgerCard(List<DailyTransaction> filteredList) {
    return _buildGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Table Header Controls: Search & Tabs (Responsive)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 620;
                          final searchWidget = TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _searchQuery = v),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                              hintText: 'Search by category, particulars, ref no or amount...',
                              hintStyle: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
                                borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8),
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                            ),
                          );

                          final tabsWidget = Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildFilterTab('ALL', 'All (${_transactions.length})'),
                                _buildFilterTab('EXPENSE', 'Expenses'),
                                _buildFilterTab('INCOME', 'Income'),
                              ],
                            ),
                          );

                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                searchWidget,
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: tabsWidget,
                                  ),
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: searchWidget),
                              const SizedBox(width: 14),
                              tabsWidget,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),

                      // Scrollable Ledger Table
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: 820,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Column Headers
                              Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                'DATE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 150,
                              child: Text(
                                'CATEGORY',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'PARTICULARS & REFERENCE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 110,
                              child: Text(
                                'PAYMENT MODE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 130,
                              child: Text(
                                'AMOUNT (₹)',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: Text(
                                'ACTION',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Transactions List
                      if (filteredList.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(54.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 48, color: Colors.blueGrey.shade200),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No transactions matching "$_searchQuery"'
                                      : 'No petty cash vouchers recorded yet.',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Use the left panel to record your first operational voucher.',
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade400,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 520,
                          child: ListView.separated(
                            controller: _scrollController,
                            itemCount: filteredList.length + (_hasMore ? 1 : 0),
                            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, index) {
                              if (index == filteredList.length) {
                                return Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Center(
                                    child: _isLoading
                                        ? const CircularProgressIndicator(color: Color(0xFF10B981))
                                        : const Text(
                                            'Scroll for older entries',
                                            style: TextStyle(color: Colors.grey, fontSize: 12),
                                          ),
                                  ),
                                );
                              }

                              final t = filteredList[index];
                              final isIncome = t.type == 'INCOME';

                              return InkWell(
                                onTap: () => _showTransactionDetailModal(t),
                                hoverColor: const Color(0xFFF8FAFC),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      // Date
                                      SizedBox(
                                        width: 100,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t.date.toIso8601String().split('T')[0],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            Text(
                                              '#${t.id.toString().padLeft(4, '0')}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Category Pill
                                      SizedBox(
                                        width: 150,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isIncome
                                                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                                  : const Color(0xFFEF4444).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isIncome
                                                    ? const Color(0xFF10B981).withValues(alpha: 0.25)
                                                    : const Color(0xFFEF4444).withValues(alpha: 0.25),
                                              ),
                                            ),
                                            child: Text(
                                              t.category,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: isIncome
                                                    ? const Color(0xFF059669)
                                                    : const Color(0xFFDC2626),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Particulars & Reference
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t.description.isNotEmpty ? t.description : 'Direct cash transaction',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF1E293B),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (t.reference.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.tag_rounded, size: 12, color: Color(0xFF64748B)),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      t.reference,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Color(0xFF64748B),
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),

                                      // Payment Mode Pill
                                      SizedBox(
                                        width: 110,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            t.paymentMode,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF475569),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Amount
                                      SizedBox(
                                        width: 130,
                                        child: Text(
                                          '${isIncome ? '+' : '-'} ₹${t.amount.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: isIncome ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),

                                      // Actions
                                      SizedBox(
                                        width: 80,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.visibility_outlined, size: 18),
                                              color: const Color(0xFF64748B),
                                              tooltip: 'View Slip',
                                              onPressed: () => _showTransactionDetailModal(t),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                              color: const Color(0xFFEF4444),
                                              tooltip: 'Void Entry',
                                              onPressed: () => _handleDelete(t.id),
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
                        ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
  }

  Widget _buildFilterTab(String key, String label) {
    final isSelected = _selectedFilterTab == key;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _selectedFilterTab = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
