import 'package:flutter/material.dart';
import '../models/consignor.dart';
import '../models/consignee.dart';
import '../models/gc.dart';
import '../services/api_service.dart';

class RetailGcEntryScreen extends StatefulWidget {
  const RetailGcEntryScreen({super.key});

  @override
  State<RetailGcEntryScreen> createState() => _RetailGcEntryScreenState();
}

class _RetailGcEntryScreenState extends State<RetailGcEntryScreen> {
  // Sender state
  Consignor? _selectedSender;
  final TextEditingController _senderContactPhoneController = TextEditingController();

  // Receiver state
  Consignee? _selectedReceiver;
  final TextEditingController _receiverContactPhoneController = TextEditingController();
  final TextEditingController _destinationCityController = TextEditingController();

  // Parcel & Freight state
  final TextEditingController _articlesController = TextEditingController(text: '1');
  final TextEditingController _freightTotalController = TextEditingController();
  String _freightType = 'To Pay';
  String _selectedGodown = '1';

  List<dynamic> _godowns = [];
  bool _isLoadingGodowns = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;
  Gc? _createdGc;

  @override
  void initState() {
    super.initState();
    _fetchGodowns();
  }

  @override
  void dispose() {
    _senderContactPhoneController.dispose();
    _receiverContactPhoneController.dispose();
    _destinationCityController.dispose();
    _articlesController.dispose();
    _freightTotalController.dispose();
    super.dispose();
  }

  Future<void> _fetchGodowns() async {
    setState(() => _isLoadingGodowns = true);
    try {
      final list = await ApiService.getGodowns();
      if (mounted) {
        setState(() {
          _godowns = list;
          if (_godowns.isNotEmpty) {
            _selectedGodown = _godowns.first['id']?.toString() ?? '1';
          }
          _isLoadingGodowns = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingGodowns = false);
    }
  }

  void _resetForm() {
    setState(() {
      _selectedSender = null;
      _senderContactPhoneController.clear();
      _selectedReceiver = null;
      _receiverContactPhoneController.clear();
      _destinationCityController.clear();
      _articlesController.text = '1';
      _freightTotalController.clear();
      _freightType = 'To Pay';
      _errorMessage = null;
      _successMessage = null;
      _createdGc = null;
    });
  }

  Future<void> _handleSave() async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    if (_selectedSender == null) {
      setState(() => _errorMessage = 'Please select a Sender (Consignor)');
      return;
    }
    if (_selectedReceiver == null) {
      setState(() => _errorMessage = 'Please select a Receiver (Consignee)');
      return;
    }
    if (_senderContactPhoneController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Sender contact phone is required for this parcel');
      return;
    }
    if (_receiverContactPhoneController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Receiver contact phone is required for this parcel');
      return;
    }
    final articles = int.tryParse(_articlesController.text.trim());
    if (articles == null || articles <= 0) {
      setState(() => _errorMessage = 'Please enter a valid number of articles');
      return;
    }
    final freightTotal = double.tryParse(_freightTotalController.text.trim());
    if (freightTotal == null || freightTotal <= 0) {
      setState(() => _errorMessage = 'Please enter a valid freight amount');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final branch = ApiService.activeBranch.isNotEmpty ? ApiService.activeBranch : 'MAIN';

      final String retSeq = await ApiService.getNextGcNumber(mode: 'RET');
      final isPaid = _freightType == 'Paid';

      final payload = {
        'gcNumber': 'RET-$retSeq',
        'branch': branch,
        'financialYear': '${now.year}-${now.year + 1}',
        'type': 'RETAIL',
        'date': dateStr,
        'time': timeStr,
        'status': 'Created',
        'godown': _selectedGodown,
        'consignorId': _selectedSender!.id,
        'consigneeId': _selectedReceiver!.id,
        'senderContactPhone': _senderContactPhoneController.text.trim(),
        'receiverContactPhone': _receiverContactPhoneController.text.trim(),
        'freightType': _freightType,
        'freightTotal': freightTotal,
        'freightRate': 0,
        'advancePaid': isPaid ? freightTotal : 0.0,
        'balanceFreight': isPaid ? 0.0 : freightTotal,
        'freightFixed': 'Yes',
        'actualWeight': 'FIXED',
        'invoiceValue': 0,
        'goods': [
          {
            'articles': articles,
            'units': 'Parcels',
            'description': 'Retail Goods',
            'weight': 10,
            'rate': 0,
            'amount': freightTotal,
          }
        ],
      };

      final gc = await ApiService.createGc(payload);

      if (mounted) {
        setState(() {
          _createdGc = gc;
          _successMessage = 'Retail Quick Bill #${gc.gcNumber} generated successfully!';
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isSaving = false;
        });
      }
    }
  }

  void _openCustomerSearchDialog({required bool isSender}) {
    showDialog(
      context: context,
      builder: (ctx) => _CustomerSearchModal(
        isSender: isSender,
        onSelected: (customer) {
          setState(() {
            if (isSender) {
              _selectedSender = customer as Consignor;
              if (customer.phone?.isNotEmpty == true) {
                _senderContactPhoneController.text = customer.phone!;
              }
            } else {
              _selectedReceiver = customer as Consignee;
              if (customer.phone?.isNotEmpty == true) {
                _receiverContactPhoneController.text = customer.phone!;
              }
              if (customer.city?.isNotEmpty == true) {
                _destinationCityController.text = customer.city!;
              }
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBranch = ApiService.activeBranch.isNotEmpty ? ApiService.activeBranch : 'MAIN';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Modern Swiss Midnight Slate Cockpit
            _buildCockpitHeader(activeBranch),

            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Error Banner
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            border: Border.all(color: const Color(0xFFFECDD3)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Color(0xFFBE123C),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: Color(0xFFBE123C)),
                                onPressed: () => setState(() => _errorMessage = null),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Success Confirmation Banner
                      if (_successMessage != null && _createdGc != null) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _successMessage!,
                                      style: const TextStyle(
                                        color: Color(0xFF065F46),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'From: ${_selectedSender?.name ?? ""} ➔ To: ${_selectedReceiver?.name ?? ""}',
                                      style: const TextStyle(color: Color(0xFF047857), fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _resetForm,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Book Next Parcel'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Main Form Container Card
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Sender and Receiver Dual Columns
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 700;
                                return Flex(
                                  direction: isNarrow ? Axis.vertical : Axis.horizontal,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Sender Card (FROM)
                                    Expanded(
                                      flex: isNarrow ? 0 : 1,
                                      child: _buildCustomerCard(
                                        title: 'SENDER (FROM)',
                                        icon: Icons.person_pin_circle_rounded,
                                        iconColor: const Color(0xFF6366F1),
                                        isSender: true,
                                        customer: _selectedSender,
                                        phoneController: _senderContactPhoneController,
                                        onSelect: () => _openCustomerSearchDialog(isSender: true),
                                        onClear: () {
                                          setState(() {
                                            _selectedSender = null;
                                            _senderContactPhoneController.clear();
                                          });
                                        },
                                        isDark: isDark,
                                      ),
                                    ),
                                    SizedBox(width: isNarrow ? 0 : 20, height: isNarrow ? 20 : 0),
                                    // Receiver Card (TO)
                                    Expanded(
                                      flex: isNarrow ? 0 : 1,
                                      child: _buildCustomerCard(
                                        title: 'RECEIVER (TO)',
                                        icon: Icons.location_on_rounded,
                                        iconColor: const Color(0xFF059669),
                                        isSender: false,
                                        customer: _selectedReceiver,
                                        phoneController: _receiverContactPhoneController,
                                        destinationCityController: _destinationCityController,
                                        onSelect: () => _openCustomerSearchDialog(isSender: false),
                                        onClear: () {
                                          setState(() {
                                            _selectedReceiver = null;
                                            _receiverContactPhoneController.clear();
                                            _destinationCityController.clear();
                                          });
                                        },
                                        isDark: isDark,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 28),
                            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 24),

                            // Parcel & Freight Configuration Section
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF059669), size: 18),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'PARCEL & VALUATION DETAILS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 700;
                                return Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Number of Articles
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'NO. OF ARTICLES *',
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                                              ),
                                              const SizedBox(height: 6),
                                              TextField(
                                                controller: _articlesController,
                                                keyboardType: TextInputType.number,
                                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                                                decoration: _inputDecoration(isDark, hint: '1'),
                                              ),
                                              const SizedBox(height: 8),
                                              // Quick Article increment pills
                                              Wrap(
                                                spacing: 6,
                                                children: [1, 2, 5, 10].map((val) {
                                                  return InkWell(
                                                    onTap: () {
                                                      setState(() => _articlesController.text = val.toString());
                                                    },
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0)),
                                                      ),
                                                      child: Text(
                                                        '+$val',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w800,
                                                          color: isDark ? Colors.white70 : const Color(0xFF475569),
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

                                        // Payment / Freight Type
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'PAYMENT / FREIGHT TYPE',
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                                              ),
                                              const SizedBox(height: 6),
                                              DropdownButtonFormField<String>(
                                                value: _freightType,
                                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                                decoration: _inputDecoration(isDark),
                                                items: const [
                                                  DropdownMenuItem(value: 'To Pay', child: Text('To Pay', style: TextStyle(fontWeight: FontWeight.bold))),
                                                  DropdownMenuItem(value: 'Paid', child: Text('Paid', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669)))),
                                                  DropdownMenuItem(value: 'Billed', child: Text('Billed (T.B.B.)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)))),
                                                ],
                                                onChanged: (val) {
                                                  if (val != null) setState(() => _freightType = val);
                                                },
                                              ),
                                            ],
                                          ),
                                        ),

                                        if (!isNarrow) ...[
                                          const SizedBox(width: 16),
                                          // Target Godown
                                          Expanded(
                                            flex: 2,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'TARGET GODOWN',
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                                                ),
                                                const SizedBox(height: 6),
                                                _isLoadingGodowns
                                                    ? const SizedBox(
                                                        height: 48,
                                                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                                      )
                                                    : DropdownButtonFormField<String>(
                                                        value: _godowns.any((g) => g['id'].toString() == _selectedGodown)
                                                            ? _selectedGodown
                                                            : (_godowns.isNotEmpty ? _godowns.first['id'].toString() : '1'),
                                                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                                        decoration: _inputDecoration(isDark),
                                                        items: _godowns.map((g) {
                                                          return DropdownMenuItem<String>(
                                                            value: g['id'].toString(),
                                                            child: Text(
                                                              g['name']?.toString() ?? 'Godown ${g['id']}',
                                                              overflow: TextOverflow.ellipsis,
                                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                                            ),
                                                          );
                                                        }).toList(),
                                                        onChanged: (val) {
                                                          if (val != null) setState(() => _selectedGodown = val);
                                                        },
                                                      ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 24),

                                    // Hero Freight Amount Card & Action
                                    Container(
                                      padding: const EdgeInsets.all(22),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: const Color(0xFFA7F3D0)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.08),
                                            blurRadius: 14,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF059669).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: const Icon(Icons.currency_rupee_rounded, color: Color(0xFF059669), size: 30),
                                          ),
                                          const SizedBox(width: 18),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'TOTAL FREIGHT AMOUNT (₹) *',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF065F46),
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                TextField(
                                                  controller: _freightTotalController,
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  style: const TextStyle(
                                                    fontSize: 28,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF065F46),
                                                  ),
                                                  decoration: InputDecoration(
                                                    border: InputBorder.none,
                                                    isDense: true,
                                                    contentPadding: EdgeInsets.zero,
                                                    hintText: '0.00',
                                                    hintStyle: TextStyle(
                                                      color: const Color(0xFF065F46).withValues(alpha: 0.35),
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: _isSaving ? null : _handleSave,
                                            icon: _isSaving
                                                ? const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                  )
                                                : const Icon(Icons.flash_on_rounded, size: 20),
                                            label: Text(
                                              _isSaving ? 'Generating Bill...' : 'Generate Quick Bill',
                                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF059669),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCockpitHeader(String activeBranch) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF059669), Color(0xFF10B981)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF059669).withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Retail Quick Bill',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
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
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt_rounded, size: 12, color: Color(0xFF34D399)),
                                SizedBox(width: 4),
                                Text(
                                  'FAST COUNTER POS',
                                  style: TextStyle(
                                    color: Color(0xFF34D399),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF334155),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'BRANCH: $activeBranch',
                              style: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        '1-Click instant parcel booking for walk-in retail customers with automatic contact verification',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _resetForm,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Reset Form', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFCBD5E1),
                    side: const BorderSide(color: Color(0xFF475569)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isSender,
    required dynamic customer,
    required TextEditingController phoneController,
    TextEditingController? destinationCityController,
    required VoidCallback onSelect,
    required VoidCallback onClear,
    required bool isDark,
  }) {
    if (customer == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: onSelect,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.person_search_rounded, size: 34, color: iconColor),
                    const SizedBox(height: 8),
                    Text(
                      'Search / Add ${isSender ? "Sender" : "Receiver"}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Fast lookup by phone, GSTIN, or name',
                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.close, size: 14),
                label: const Text('Change', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE11D48),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Selected Customer Info Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (customer.city != null && customer.city.isNotEmpty) ...[
                      const Icon(Icons.location_city_rounded, size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(customer.city, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: customer.gstin != null && customer.gstin != 'URP'
                            ? const Color(0xFFEEF2FF)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        customer.gstin != null && customer.gstin != 'URP' ? customer.gstin : 'URP (No GST)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: customer.gstin != null && customer.gstin != 'URP'
                              ? const Color(0xFF4338CA)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Parcel Contact Phone (Required)
          const Text(
            'PARCEL CONTACT PHONE *',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            decoration: _inputDecoration(isDark, hint: 'e.g. 9876543210'),
          ),

          if (destinationCityController != null) ...[
            const SizedBox(height: 12),
            const Text(
              'DESTINATION CITY',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: destinationCityController,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              decoration: _inputDecoration(isDark, hint: 'Destination city'),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(bool isDark, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
      ),
    );
  }
}

class _CustomerSearchModal extends StatefulWidget {
  final bool isSender;
  final Function(dynamic) onSelected;

  const _CustomerSearchModal({
    required this.isSender,
    required this.onSelected,
  });

  @override
  State<_CustomerSearchModal> createState() => _CustomerSearchModalState();
}

class _CustomerSearchModalState extends State<_CustomerSearchModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  // New Customer Form
  final _createFormKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _gstinController = TextEditingController();
  bool _isUnregistered = false;
  bool _isVerifyingGst = false;
  bool _isCreating = false;
  String? _createError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _performSearch('');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _gstinController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    try {
      if (widget.isSender) {
        final list = await ApiService.getConsignors(query: query);
        if (mounted) setState(() => _searchResults = list);
      } else {
        final list = await ApiService.getConsignees(query: query);
        if (mounted) setState(() => _searchResults = list);
      }
    } catch (_) {
      if (mounted) setState(() => _searchResults = []);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _verifyGst() async {
    final gstin = _gstinController.text.trim();
    if (gstin.isEmpty) return;

    setState(() {
      _isVerifyingGst = true;
      _createError = null;
    });

    try {
      final res = await ApiService.verifyGST(gstin);
      final taxpayer = res['taxpayerInfo'] ?? res['data'] ?? {};
      final tradeName = taxpayer['tradeNam']?.toString() ?? taxpayer['lgnm']?.toString();
      final addr = taxpayer['pradr']?['addr'] ?? {};
      final city = addr['loc']?.toString() ?? addr['city']?.toString() ?? addr['dst']?.toString();

      if (tradeName != null && tradeName.isNotEmpty) {
        _nameController.text = tradeName;
      }
      if (city != null && city.isNotEmpty) {
        _cityController.text = city;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _createError = 'Failed to verify GSTIN: ${e.toString().replaceAll("Exception:", "").trim()}');
      }
    } finally {
      if (mounted) setState(() => _isVerifyingGst = false);
    }
  }

  Future<void> _handleCreateCustomer() async {
    if (!_createFormKey.currentState!.validate()) return;

    setState(() {
      _isCreating = true;
      _createError = null;
    });

    final branch = ApiService.activeBranch.isNotEmpty ? ApiService.activeBranch : 'MAIN';
    final payload = {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'city': _cityController.text.trim(),
      'gstin': _isUnregistered ? 'URP' : _gstinController.text.trim().toUpperCase(),
      'migrationType': 'RETAIL_WITH_PHONE',
      'branch': branch,
    };

    try {
      dynamic created;
      if (widget.isSender) {
        created = await ApiService.saveConsignor(payload);
      } else {
        created = await ApiService.saveConsignee(payload);
      }
      if (mounted) {
        widget.onSelected(created);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _createError = e.toString().replaceAll('Exception:', '').trim();
          _isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = widget.isSender ? 'Sender' : 'Receiver';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 620),
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person_search_rounded, color: Color(0xFF059669), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Select or Add $label',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: const Color(0xFF94A3B8),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF059669),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF059669),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              tabs: [
                Tab(icon: const Icon(Icons.search_rounded, size: 18), text: 'Search Existing $label'),
                Tab(icon: const Icon(Icons.person_add_rounded, size: 18), text: 'Create New $label'),
              ],
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Search Existing
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => _performSearch(val),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                            hintText: 'Search $label by name, phone or GSTIN...',
                            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _isSearching
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFF059669)))
                            : _searchResults.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.search_off_rounded, size: 40, color: Color(0xFF94A3B8)),
                                        const SizedBox(height: 8),
                                        Text('No $label found', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text('Switch to "Create New" tab to register.', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    itemCount: _searchResults.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                    itemBuilder: (ctx, idx) {
                                      final item = _searchResults[idx];
                                      return ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                        subtitle: Text(
                                          '${item.phone ?? "No phone"} • ${item.city ?? "No city"}',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                        ),
                                        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF059669)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        onTap: () {
                                          widget.onSelected(item);
                                          Navigator.pop(context);
                                        },
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),

                  // Tab 2: Create New
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: Form(
                      key: _createFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_createError != null) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFECDD3)),
                              ),
                              child: Text(_createError!, style: const TextStyle(color: Color(0xFF9F1239), fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // GSTIN with Unregistered Checkbox
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('GSTIN (OPTIONAL)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                              Row(
                                children: [
                                  Checkbox(
                                    value: _isUnregistered,
                                    activeColor: const Color(0xFF059669),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    onChanged: (val) {
                                      setState(() {
                                        _isUnregistered = val ?? false;
                                        if (_isUnregistered) _gstinController.clear();
                                      });
                                    },
                                  ),
                                  const Text('Unregistered (URP)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _gstinController,
                                  enabled: !_isUnregistered,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. 27AADCB2230M1Z2',
                                    filled: true,
                                    fillColor: _isUnregistered
                                        ? (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))
                                        : (isDark ? const Color(0xFF0F172A) : Colors.white),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: (_isUnregistered || _isVerifyingGst) ? null : _verifyGst,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: _isVerifyingGst
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('Verify GST', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Name
                          const Text('CUSTOMER NAME *', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              hintText: 'Company or personal name',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                          ),
                          const SizedBox(height: 14),

                          // Phone & City
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('PHONE NUMBER *', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      decoration: InputDecoration(
                                        hintText: '10-digit mobile',
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      validator: (v) => v == null || v.trim().isEmpty ? 'Phone required' : null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('CITY / DESTINATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      controller: _cityController,
                                      decoration: InputDecoration(
                                        hintText: 'City name',
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isCreating ? null : _handleCreateCustomer,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isCreating
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text('Register & Select $label', style: const TextStyle(fontWeight: FontWeight.w900)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
