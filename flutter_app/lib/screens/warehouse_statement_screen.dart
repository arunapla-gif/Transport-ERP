import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/api_service.dart';

class WarehouseStatementScreen extends StatefulWidget {
  const WarehouseStatementScreen({super.key});

  @override
  State<WarehouseStatementScreen> createState() => _WarehouseStatementScreenState();
}

class _WarehouseStatementScreenState extends State<WarehouseStatementScreen> {
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _inwards = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _totalRecords = 0;

  final TextEditingController _searchFilterController = TextEditingController();
  String _searchFilter = '';
  String _selectedBayFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchInwards(1);
    _searchFilterController.addListener(() {
      setState(() {
        _searchFilter = _searchFilterController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchFilterController.dispose();
    super.dispose();
  }

  String get _formattedDateParam =>
      '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

  String get _displayDate =>
      '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';

  Future<void> _fetchInwards(int page) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService.getWarehouseStatement(
        date: _formattedDateParam,
        page: page,
        limit: 100,
      );

      final list = res['data'] is List ? res['data'] as List<dynamic> : [];
      setState(() {
        _inwards = list;
        _totalRecords = int.tryParse((res['total'] ?? list.length).toString()) ?? list.length;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load warehouse statement: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _totalArticles {
    int sum = 0;
    for (var item in _filteredInwards) {
      sum += int.tryParse((item['articles'] ?? item['articleCount'] ?? 0).toString()) ?? 0;
    }
    return sum;
  }

  Set<String> get _allGodownBays {
    final set = <String>{};
    for (var item in _inwards) {
      final bay = (item['godownNo'] ?? '').toString().trim();
      if (bay.isNotEmpty) set.add(bay);
    }
    return set;
  }

  int get _ewbCoveredCount {
    return _filteredInwards
        .where((item) => (item['ewayBillNo'] ?? '').toString().trim().isNotEmpty)
        .length;
  }

  List<dynamic> get _filteredInwards {
    return _inwards.where((item) {
      if (_selectedBayFilter != 'ALL') {
        final bay = (item['godownNo'] ?? '').toString().trim();
        if (bay != _selectedBayFilter) return false;
      }

      if (_searchFilter.isNotEmpty) {
        final cnor = (item['consignorName'] ?? '').toString().toLowerCase();
        final cnee = (item['consigneeName'] ?? '').toString().toLowerCase();
        final recNo = (item['receiptNo'] ?? '').toString().toLowerCase();
        final city = (item['consigneeCity'] ?? '').toString().toLowerCase();
        final ewb = (item['ewayBillNo'] ?? '').toString().toLowerCase();
        final match = cnor.contains(_searchFilter) ||
            cnee.contains(_searchFilter) ||
            recNo.contains(_searchFilter) ||
            city.contains(_searchFilter) ||
            ewb.contains(_searchFilter);
        if (!match) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF059669),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchInwards(1);
    }
  }

  Future<void> _printReport() async {
    final pdf = pw.Document();
    final items = _filteredInwards;
    final totalArts = _totalArticles;
    final dateStr = _displayDate;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TRANSPORT ERP',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'DAILY WAREHOUSE INWARD STATEMENT',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Date: $dateStr', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Total Inwards: ${items.length} | Articles: $totalArts',
                        style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1, color: PdfColors.black),
            pw.SizedBox(height: 6),

            // Table
            pw.TableHelper.fromTextArray(
              headers: ['Rec No.', 'Consignor (From)', 'Consignee (To)', 'City', 'Articles', 'Bay', 'Remarks'],
              data: items.map((item) {
                final recNo = (item['receiptNo'] ?? '-').toString();
                final cnor = (item['consignorName'] ?? '-').toString();
                final ewb = item['ewayBillNo'] != null && item['ewayBillNo'].toString().isNotEmpty
                    ? ' (EWB: ${item['ewayBillNo']})'
                    : '';
                final cnee = (item['consigneeName'] ?? '-').toString();
                final city = (item['consigneeCity'] ?? '-').toString();
                final articles = (item['articles'] ?? '0').toString();
                final bay = (item['godownNo'] ?? '-').toString();
                final remarks = (item['remarks'] ?? '-').toString();

                return [
                  recNo,
                  '$cnor$ewb',
                  cnee,
                  city,
                  articles,
                  bay,
                  remarks,
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.center,
                6: pw.Alignment.centerLeft,
              },
              columnWidths: {
                0: const pw.FixedColumnWidth(60),
                1: const pw.FlexColumnWidth(2.5),
                2: const pw.FlexColumnWidth(2.5),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FixedColumnWidth(55),
                5: const pw.FixedColumnWidth(45),
                6: const pw.FlexColumnWidth(2),
              },
            ),

            pw.SizedBox(height: 10),

            // Total Bar
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('TOTAL ARTICLES INWARDED: ',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('$totalArts',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
              ],
            ),

            pw.SizedBox(height: 30),

            // Signatures
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  children: [
                    pw.Container(width: 140, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text('Warehouse Inward Clerk', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Container(width: 140, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text('Branch Manager', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Warehouse_Statement_$_formattedDateParam.pdf',
    );
  }

  void _showInwardDetailModal(dynamic item) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.warehouse_rounded, color: Color(0xFF059669), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'WAREHOUSE INWARD AUDIT SLIP',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF64748B),
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Receipt #${(item['receiptNo'] ?? 'N/A').toString().padLeft(5, '0')}',
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

              // Quantity Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL ARTICLES STORED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF065F46),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      '${item['articles'] ?? item['articleCount'] ?? 0} Box(es)',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF059669),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Particulars Grid
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildModalRow('Date Received', _displayDate),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    _buildModalRow('Consignor (Sender)', (item['consignorName'] ?? '-').toString()),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    _buildModalRow('Consignee (Receiver)', (item['consigneeName'] ?? '-').toString()),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    _buildModalRow('Destination City', (item['consigneeCity'] ?? '-').toString()),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    _buildModalRow('Allocated Godown Bay', (item['godownNo'] ?? '-').toString()),
                    if (item['ewayBillNo'] != null && item['ewayBillNo'].toString().isNotEmpty) ...[
                      const Divider(height: 16, color: Color(0xFFE2E8F0)),
                      _buildModalRow('E-Way Bill No.', item['ewayBillNo'].toString()),
                    ],
                    if (item['remarks'] != null && item['remarks'].toString().isNotEmpty) ...[
                      const Divider(height: 16, color: Color(0xFFE2E8F0)),
                      _buildModalRow('Handling Remarks', item['remarks'].toString()),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    ),
                    child: const Text('CLOSE'),
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

  Widget _buildSwissCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(22),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Cockpit
              _buildHeaderCockpit(),

              const SizedBox(height: 20),

              // 2. Executive Stock KPI Cards
              _buildKpiSummaryRow(),

              const SizedBox(height: 20),

              // 3. Search & Bay Filter bar
              _buildFilterBar(),

              const SizedBox(height: 20),

              // 4. Main Statement Table
              _buildStatementTableCard(),
            ],
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
          colors: [Color(0xFF064E3B), Color(0xFF065F46), Color(0xFF047857)],
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.warehouse_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Warehouse Daily Stock Statement',
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
                        color: const Color(0xFFA7F3D0).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF6EE7B7).withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_rounded, size: 12, color: Color(0xFFA7F3D0)),
                          SizedBox(width: 5),
                          Text(
                            'STOCK LEDGER',
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
                  'Review and audit all inward parcels received on $_displayDate across godown storage bays',
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFFA7F3D0).withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Date Selector & Print Buttons
          Row(
            children: [
              // Date picker capsule
              InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        _displayDate,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white70),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Print Report Button
              ElevatedButton.icon(
                onPressed: _inwards.isEmpty ? null : _printReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF065F46),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text('PRINT A4 SHEET', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryRow() {
    return Row(
      children: [
        // Total Inward Records
        Expanded(
          child: _buildSwissCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.format_list_numbered_rounded, color: Color(0xFF2563EB), size: 24),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL INWARD ENTRIES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_totalRecords',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E3A8A),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Total Articles Inwarded
        Expanded(
          child: _buildSwissCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF059669), size: 24),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL ARTICLES INWARDED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_totalArticles',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF065F46),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),

        // EWB Verified Coverage
        Expanded(
          child: _buildSwissCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.verified_user_rounded, color: Color(0xFFD97706), size: 24),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'E-WAY BILL VERIFIED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_ewbCoveredCount Consignments',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF92400E),
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
    );
  }

  Widget _buildFilterBar() {
    final bays = ['ALL', ..._allGodownBays];

    return _buildSwissCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchFilterController,
                  decoration: const InputDecoration(
                    hintText: 'Filter by Consignor, Consignee, Receipt No, EWB or Destination City...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_searchFilter.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                  onPressed: () => _searchFilterController.clear(),
                ),
            ],
          ),
          if (bays.length > 2) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'FILTER BY BAY:',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: bays.map((bay) {
                        final isSelected = _selectedBayFilter == bay;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setState(() => _selectedBayFilter = bay),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF059669) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                bay == 'ALL' ? 'All Bays' : bay,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildStatementTableCard() {
    final items = _filteredInwards;

    return _buildSwissCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(60.0),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF059669)),
              ),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Text(_errorMessage!,
                    style: const TextStyle(color: Color(0xFFBE123C), fontWeight: FontWeight.w700)),
              ),
            )
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(54.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      _searchFilter.isNotEmpty
                          ? 'No inward entries match "$_searchFilter".'
                          : 'No warehouse inward entries recorded for $_displayDate.',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B), fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: const Row(
                children: [
                  SizedBox(
                      width: 90,
                      child: Text('REC NO',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B)))),
                  Expanded(
                      flex: 3,
                      child: Text('CONSIGNOR (SENDER)',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B)))),
                  Expanded(
                      flex: 3,
                      child: Text('CONSIGNEE (RECEIVER)',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B)))),
                  Expanded(
                      flex: 2,
                      child: Text('CITY',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B)))),
                  SizedBox(
                      width: 85,
                      child: Text('ARTICLES',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B)))),
                  SizedBox(
                      width: 80,
                      child: Text('BAY',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B)))),
                  Expanded(
                      flex: 2,
                      child: Text('REMARKS',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF64748B)))),
                ],
              ),
            ),

            // Rows
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final item = items[index];
                final recNo = (item['receiptNo'] ?? '-').toString();
                final cnor = (item['consignorName'] ?? '-').toString();
                final ewb = (item['ewayBillNo'] ?? '').toString();
                final cnee = (item['consigneeName'] ?? '-').toString();
                final city = (item['consigneeCity'] ?? '-').toString();
                final articles = (item['articles'] ?? '0').toString();
                final godown = (item['godownNo'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
                final remarks = (item['remarks'] ?? '-').toString();

                return InkWell(
                  onTap: () => _showInwardDetailModal(item),
                  hoverColor: const Color(0xFFF8FAFC),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        // Rec No Badge
                        SizedBox(
                          width: 90,
                          child: Text(
                            '#$recNo',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 13),
                          ),
                        ),

                        // Consignor + EWB
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.local_shipping_outlined, size: 14, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      cnor,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                ],
                              ),
                              if (ewb.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text('EWB: $ewb',
                                    style: const TextStyle(
                                        fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                              ],
                            ],
                          ),
                        ),

                        // Consignee
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              const Icon(Icons.storefront_outlined, size: 14, color: Color(0xFF10B981)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  cnee,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // City
                        Expanded(
                          flex: 2,
                          child: Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                          ),
                        ),

                        // Articles Badge
                        SizedBox(
                          width: 85,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Text(
                                '$articles Pkgs',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                              ),
                            ),
                          ),
                        ),

                        // Godown Bay Badge
                        SizedBox(
                          width: 80,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Text(
                                godown.isNotEmpty ? 'Bay $godown' : (item['godownNo'] ?? '-'),
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                              ),
                            ),
                          ),
                        ),

                        // Remarks
                        Expanded(
                          flex: 2,
                          child: Text(
                            remarks,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Footer Total
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${items.length} of $_totalRecords entries on $_displayDate',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  Row(
                    children: [
                      const Text(
                        'TOTAL ARTICLES INWARDED: ',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Text(
                          '$_totalArticles',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF047857)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
