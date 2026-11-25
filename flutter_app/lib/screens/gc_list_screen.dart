import 'package:flutter/material.dart';
import '../models/gc.dart';
import '../services/api_service.dart';

class GcListScreen extends StatefulWidget {
  const GcListScreen({super.key});

  @override
  State<GcListScreen> createState() => _GcListScreenState();
}

class _GcListScreenState extends State<GcListScreen> {
  late Future<List<Gc>> _gcsFuture;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadGcs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadGcs({String query = ''}) {
    setState(() {
      _gcsFuture = ApiService.getGcs(query: query);
    });
  }

  Color _getPaymentColor(String paymentType) {
    switch (paymentType.toUpperCase()) {
      case 'PAID':
        return const Color(0xFF10B981);
      case 'TO_PAY':
        return const Color(0xFFF59E0B);
      case 'ACCOUNT':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF64748B);
    }
  }

  void _showGcDetailModal(Gc item) {
    final paymentColor = _getPaymentColor(item.paymentType);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Container(
          width: 620,
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          item.gcNumber,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1D4ED8)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: paymentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: paymentColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          item.paymentType.replaceAll('_', ' '),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: paymentColor),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Route
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.route_rounded, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Text(item.fromLocation, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF94A3B8)),
                    ),
                    Text(item.toLocation, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A))),
                    const Spacer(),
                    Text(
                      'Date: ${item.date.split('T').first}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Parties
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CONSIGNOR (SENDER)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
                          const SizedBox(height: 4),
                          Text(item.consignorName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                          if (item.senderPhone != null)
                            Text(item.senderPhone!, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CONSIGNEE (RECEIVER)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
                          const SizedBox(height: 4),
                          Text(item.consigneeName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                          if (item.receiverPhone != null)
                            Text(item.receiverPhone!, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Goods Summary
              if (item.goods.isNotEmpty) ...[
                const Text('GOODS DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: item.goods.map((g) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3.0),
                      child: Row(
                        children: [
                          Text('${g.articleCount ?? 1}x', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                          const SizedBox(width: 8),
                          Expanded(child: Text(g.description, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)))),
                          if (g.hsn != null)
                            Text('HSN: ${g.hsn}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontFamily: 'monospace')),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Freight Breakdown
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TOTAL FREIGHT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF))),
                        Text('₹${item.freightTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1D4ED8))),
                      ],
                    ),
                    if (item.balanceFreight > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('BALANCE DUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFDC2626))),
                          Text('₹${item.balanceFreight.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFFDC2626))),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF059669)),
                            SizedBox(width: 4),
                            Text('PAID IN FULL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatPill(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            margin: const EdgeInsets.only(bottom: 20),
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
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Consignment Register (GC)',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Live ledger of goods receipt notes, payment states & route consignments',
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
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
                    onPressed: () => _loadGcs(query: _searchController.text),
                    tooltip: 'Refresh Register',
                  ),
                ),
              ],
            ),
          ),

          // Live Stats KPI Row
          FutureBuilder<List<Gc>>(
            future: _gcsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }
              final gcs = snapshot.data!;
              final totalCount = gcs.length;
              final totalFreight = gcs.fold<double>(0, (sum, item) => sum + item.freightTotal);
              final totalBalance = gcs.fold<double>(0, (sum, item) => sum + item.balanceFreight);

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: Row(
                  children: [
                    _buildStatPill('TOTAL BILTY / GCs', '$totalCount', Icons.receipt_long_rounded, const Color(0xFF2563EB)),
                    const SizedBox(width: 14),
                    _buildStatPill('TOTAL FREIGHT', '₹${totalFreight.toStringAsFixed(0)}', Icons.currency_rupee_rounded, const Color(0xFF059669)),
                    const SizedBox(width: 14),
                    _buildStatPill('BALANCE DUE', '₹${totalBalance.toStringAsFixed(0)}', Icons.pending_actions_rounded, const Color(0xFFE11D48)),
                  ],
                ),
              );
            },
          ),

          // Search & Filter Card
          Container(
            padding: const EdgeInsets.all(20.0),
            margin: const EdgeInsets.only(bottom: 20),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Search GCs by Receipt #, Consignor, Consignee or Vehicle...',
                    hintStyle: TextStyle(color: Colors.blueGrey.shade400, fontWeight: FontWeight.normal),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF2563EB)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.8),
                    ),
                  ),
                  onChanged: (val) => _loadGcs(query: val),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Filter Payment:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF64748B), letterSpacing: 0.5)),
                    const SizedBox(width: 12),
                    Wrap(
                      spacing: 8,
                      children: ['ALL', 'TO_PAY', 'PAID', 'ACCOUNT'].map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return ChoiceChip(
                          label: Text(
                            filter == 'ALL' ? 'All Consignments' : filter.replaceAll('_', ' '),
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 12,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF2563EB),
                          backgroundColor: const Color(0xFFF1F5F9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0))),
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedFilter = filter);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // List View
          Expanded(
            child: FutureBuilder<List<Gc>>(
              future: _gcsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
                } else if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Center(
                      child: Text(
                        'Error loading GCs: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Center(
                      child: Text('No Goods Consignments found in register',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  );
                }

                final filteredList = snapshot.data!.where((gc) {
                  if (_selectedFilter == 'ALL') return true;
                  return gc.paymentType.toUpperCase() == _selectedFilter;
                }).toList();

                if (filteredList.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Center(
                      child: Text('No matching GCs for selected filter', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final item = filteredList[index];
                    final paymentColor = _getPaymentColor(item.paymentType);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _showGcDetailModal(item),
                          hoverColor: const Color(0xFF2563EB).withValues(alpha: 0.02),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            item.gcNumber,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1D4ED8)),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Row(
                                          children: [
                                            Text(
                                              item.fromLocation,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                                            ),
                                            const Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 6.0),
                                              child: Icon(Icons.east_rounded, size: 16, color: Color(0xFF2563EB)),
                                            ),
                                            Text(
                                              item.toLocation,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: paymentColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: paymentColor.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        item.paymentType.replaceAll('_', ' '),
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: paymentColor),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('CONSIGNOR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
                                          const SizedBox(height: 2),
                                          Text(item.consignorName,
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B))),
                                          if (item.senderPhone != null)
                                            Text(item.senderPhone!,
                                                style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 12, fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('CONSIGNEE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
                                          const SizedBox(height: 2),
                                          Text(item.consigneeName,
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B))),
                                          if (item.receiverPhone != null)
                                            Text(item.receiverPhone!,
                                                style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 12, fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '₹${item.freightTotal.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A)),
                                            ),
                                            if (item.balanceFreight > 0)
                                              Text('Bal: ₹${item.balanceFreight.toStringAsFixed(2)}',
                                                  style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w800)),
                                          ],
                                        ),
                                        const SizedBox(width: 14),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
