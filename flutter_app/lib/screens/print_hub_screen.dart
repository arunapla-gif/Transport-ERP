import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../services/api_service.dart';
import '../services/pdf_service.dart';

class PrintHubScreen extends StatefulWidget {
  const PrintHubScreen({super.key});

  @override
  State<PrintHubScreen> createState() => _PrintHubScreenState();
}

class _PrintHubScreenState extends State<PrintHubScreen> {
  // Top Card Controllers
  final TextEditingController _gcInputController = TextEditingController();
  final TextEditingController _gdmInputController = TextEditingController();
  
  String _gcSearchMode = 'gc'; // 'gc' or 'gdm'
  String _gcPrefix = 'BELL';
  String _gdmPrefix = 'AP';
  String _gdmPrintType = 'gdm'; // 'gdm', 'cewb', 'gdm-combined'

  // Batch Printing Section
  String _activeTab = 'GC'; // 'GC' or 'GDM'
  final TextEditingController _gcSearchController = TextEditingController();
  final TextEditingController _gdmSearchController = TextEditingController();

  List<dynamic> _recentGcs = [];
  List<dynamic> _recentGdms = [];
  List<String> _selectedGcs = [];
  List<String> _selectedGdms = [];

  bool _isLoading = false;
  bool _hasMoreGcs = true;
  bool _hasMoreGdms = true;
  int _gcPage = 1;
  int _gdmPage = 1;
  Timer? _debounce;

  final ScrollController _gcScrollController = ScrollController();
  final ScrollController _gdmScrollController = ScrollController();

  // Modals state
  bool _isPrinting = false;
  Printer? _cachedPrinter;

  @override
  void initState() {
    super.initState();
    _fetchGcs(1);
    _fetchGdms(1);

    _gcScrollController.addListener(() {
      if (_gcScrollController.position.pixels >= _gcScrollController.position.maxScrollExtent - 200 && !_isLoading && _hasMoreGcs) {
        _gcPage++;
        _fetchGcs(_gcPage);
      }
    });

    _gdmScrollController.addListener(() {
      if (_gdmScrollController.position.pixels >= _gdmScrollController.position.maxScrollExtent - 200 && !_isLoading && _hasMoreGdms) {
        _gdmPage++;
        _fetchGdms(_gdmPage);
      }
    });
  }

  @override
  void dispose() {
    _gcInputController.dispose();
    _gdmInputController.dispose();
    _gcSearchController.dispose();
    _gdmSearchController.dispose();
    _gcScrollController.dispose();
    _gdmScrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onGcSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _gcPage = 1;
      _recentGcs.clear();
      _hasMoreGcs = true;
      _fetchGcs(_gcPage);
    });
  }

  void _onGdmSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _gdmPage = 1;
      _recentGdms.clear();
      _hasMoreGdms = true;
      _fetchGdms(_gdmPage);
    });
  }

  Future<void> _fetchGcs(int page) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getGcsRaw(page: page, limit: 20, query: _gcSearchController.text);
      if (mounted) {
        setState(() {
          if (page == 1) {
            _recentGcs = res;
          } else {
            // Avoid duplicates
            final existingIds = _recentGcs.map((g) => g['id']).toSet();
            _recentGcs.addAll(res.where((g) => !existingIds.contains(g['id'])));
          }
          _hasMoreGcs = res.length >= 20;
        });
      }
    } catch (e) {
      debugPrint('Error fetching GCs: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchGdms(int page) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getRecentGdms(page: page, limit: 20, query: _gdmSearchController.text);
      if (mounted) {
        setState(() {
          if (page == 1) {
            _recentGdms = res;
          } else {
            final existingIds = _recentGdms.map((g) => g['id']).toSet();
            _recentGdms.addAll(res.where((g) => !existingIds.contains(g['id'])));
          }
          _hasMoreGdms = res.length >= 20;
        });
      }
    } catch (e) {
      debugPrint('Error fetching GDMs: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showGcCopiesModal(List<String> gcNumbers, {List<String>? initialCopies}) {
    List<String> selectedCopies = List<String>.from(initialCopies ?? ['CONSIGNOR COPY']);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Print GC Copies', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select which copies you want to print.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 16),
                  ...['CONSIGNOR COPY', 'CONSIGNEE COPY', 'LORRY COPY'].map((copy) {
                    final isSelected = selectedCopies.contains(copy);
                    return InkWell(
                      onTap: () {
                        setModalState(() {
                          if (isSelected) {
                            selectedCopies.remove(copy);
                          } else {
                            selectedCopies.add(copy);
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.indigo.shade50 : Colors.transparent,
                          border: Border.all(color: isSelected ? Colors.indigo : Colors.grey.shade300, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank, color: isSelected ? Colors.indigo : Colors.grey),
                            const SizedBox(width: 12),
                            Text(copy, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.indigo.shade900 : Colors.grey.shade700)),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton.icon(
                  onPressed: selectedCopies.isEmpty ? null : () async {
                    Navigator.pop(context);
                    await _printGcs(gcNumbers, selectedCopies, directPrint: false);
                  },
                  icon: const Icon(Icons.picture_as_pdf, size: 16),
                  label: const Text('Preview / PDF'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                ),
                ElevatedButton.icon(
                  onPressed: selectedCopies.isEmpty ? null : () async {
                    Navigator.pop(context);
                    await _printGcs(gcNumbers, selectedCopies, directPrint: true);
                  },
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('Silent Print'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade600, foregroundColor: Colors.white),
                ),
              ],
            );
          },
        );
      }
    );
  }

  Future<void> _dispatchPdfBytes(Uint8List pdfBytes, {required bool directPrint}) async {
    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);

    if (directPrint && isDesktop) {
      _cachedPrinter ??= await Printing.pickPrinter(context: context);
      if (_cachedPrinter != null) {
        await Printing.directPrintPdf(
          printer: _cachedPrinter!,
          onLayout: (format) => pdfBytes,
        );
        return;
      }
    }
    await Printing.layoutPdf(onLayout: (format) => pdfBytes);
  }

  Future<void> _printGcs(List<String> gcNumbers, List<String> copies, {required bool directPrint}) async {
    setState(() => _isPrinting = true);
    try {
      if (gcNumbers.isEmpty) return;

      final gcFutures = gcNumbers.map((id) => ApiService.fetchGcRaw(id));
      final gcs = await Future.wait(gcFutures);

      final pdfBytes = await PdfService.generateGcPdf(gcs, copies);
      await _dispatchPdfBytes(pdfBytes, directPrint: directPrint);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error printing GC: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  void _showGdmFormatModal(List<String> gdmNumbers) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Select Print Format', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Choose the format for your Delivery Memo.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 16),
                  ...[
                    {'id': 'gdm', 'label': 'Standard GDM'},
                    {'id': 'cewb', 'label': 'CEWB Format'},
                    {'id': 'gdm-combined', 'label': 'Combined (Both)'}
                  ].map((format) {
                    final isSelected = _gdmPrintType == format['id'];
                    return InkWell(
                      onTap: () {
                        setModalState(() {
                          _gdmPrintType = format['id']!;
                        });
                        setState(() {});
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.teal.shade50 : Colors.transparent,
                          border: Border.all(color: isSelected ? Colors.teal : Colors.grey.shade300, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? Colors.teal : Colors.grey),
                            const SizedBox(width: 12),
                            Text(format['label']!, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.teal.shade900 : Colors.grey.shade700)),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _printGdms(gdmNumbers, directPrint: false);
                  },
                  icon: const Icon(Icons.picture_as_pdf, size: 16),
                  label: const Text('Preview / PDF'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _printGdms(gdmNumbers, directPrint: true);
                  },
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('Silent Print'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade600, foregroundColor: Colors.white),
                ),
              ],
            );
          },
        );
      }
    );
  }

  Future<void> _printGdms(List<String> gdmNumbers, {required bool directPrint}) async {
    setState(() => _isPrinting = true);
    try {
      if (gdmNumbers.isEmpty) return;
      final gdmFutures = gdmNumbers.map((num) => ApiService.getGdmDetails(num));
      final gdms = await Future.wait(gdmFutures);
      final pdfBytes = await PdfService.generateGdmsPdf(gdms, format: _gdmPrintType);
      await _dispatchPdfBytes(pdfBytes, directPrint: directPrint);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error printing GDM: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Widget _buildTopCard({
    required IconData icon,
    required Color color,
    required List<Color> gradient,
    required String title,
    required String subtitle,
    required String prefix,
    required Function(String) onPrefixChange,
    required TextEditingController controller,
    required VoidCallback onPrint,
    required bool disabled,
    Widget? extraOptions,
  }) {
    return Expanded(
      child: _HoverCard(
        accentColor: color,
        builder: (context, isHovered) {
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: isHovered ? 0.45 : 0.28),
                      blurRadius: isHovered ? 14 : 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, size: 30, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              if (extraOptions != null) ...[
                extraOptions,
                const SizedBox(height: 16),
              ],

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        _buildPrefixBtn('AP', prefix == 'AP', color, () => onPrefixChange('AP')),
                        _buildPrefixBtn('BELL', prefix == 'BELL', color, () => onPrefixChange('BELL')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HoverInput(
                      controller: controller,
                      activeColor: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: _HoverButton(
                  onPressed: disabled ? null : onPrint,
                  color: color,
                  label: 'Choose Format & Print',
                  icon: Icons.print,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPrefixBtn(String text, bool isSelected, Color activeColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : [],
        ),
        child: Text(text, style: TextStyle(fontWeight: FontWeight.w900, color: isSelected ? activeColor : Colors.grey.shade500)),
      ),
    );
  }

  Widget _buildBatchSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Tabs
          Container(
            padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                _buildTabBtn('All GCs', _activeTab == 'GC', Colors.indigo, () => setState(() => _activeTab = 'GC')),
                const SizedBox(width: 8),
                _buildTabBtn('All GDMs', _activeTab == 'GDM', Colors.teal, () => setState(() => _activeTab = 'GDM')),
              ],
            ),
          ),
          
          // Toolbar
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_activeTab == 'GC' ? Icons.check_box : Icons.check_box, color: _activeTab == 'GC' ? Colors.indigo : Colors.teal),
                          const SizedBox(width: 8),
                          Text('Batch Print ${_activeTab}s', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Select multiple documents to print them all in one go.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 250,
                  child: TextField(
                    controller: _activeTab == 'GC' ? _gcSearchController : _gdmSearchController,
                    onChanged: _activeTab == 'GC' ? _onGcSearchChanged : _onGdmSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _activeTab == 'GC' 
                    ? (_selectedGcs.isEmpty ? null : () => _showGcCopiesModal(_selectedGcs))
                    : (_selectedGdms.isEmpty ? null : () => _showGdmFormatModal(_selectedGdms)),
                  icon: const Icon(Icons.print, size: 16),
                  label: Text('Print Selected (${_activeTab == 'GC' ? _selectedGcs.length : _selectedGdms.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _activeTab == 'GC' ? Colors.indigo : Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),

          // Select All Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                Checkbox(
                  value: _activeTab == 'GC'
                      ? (_recentGcs.isNotEmpty && _selectedGcs.length == _recentGcs.length)
                      : (_recentGdms.isNotEmpty && _selectedGdms.length == _recentGdms.length),
                  activeColor: _activeTab == 'GC' ? Colors.indigo : Colors.teal,
                  onChanged: (val) {
                    setState(() {
                      if (_activeTab == 'GC') {
                        _selectedGcs = val == true
                            ? _recentGcs.map((g) => g['gcNumber']?.toString() ?? '').where((s) => s.isNotEmpty).toList()
                            : [];
                      } else {
                        _selectedGdms = val == true
                            ? _recentGdms.map((g) => g['gdmNumber']?.toString() ?? '').where((s) => s.isNotEmpty).toList()
                            : [];
                      }
                    });
                  },
                ),
                Text(
                  'Select All Loaded ${_activeTab}s',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          SizedBox(
            height: 400,
            child: _activeTab == 'GC' ? _buildGcTable() : _buildGdmTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBtn(String title, bool isSelected, Color activeColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: isSelected ? activeColor : Colors.transparent, width: 3),
          ),
        ),
        child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? activeColor : Colors.grey.shade600)),
      ),
    );
  }

  Widget _buildGcTable() {
    return ListView.separated(
      controller: _gcScrollController,
      padding: EdgeInsets.zero,
      itemCount: _recentGcs.length + (_hasMoreGcs ? 1 : 0),
      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
      itemBuilder: (context, index) {
        if (index == _recentGcs.length) {
          return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        }
        final gc = _recentGcs[index];
        final number = gc['gcNumber']?.toString() ?? '';
        final isSelected = _selectedGcs.contains(number);
        return ListTile(
          tileColor: isSelected ? Colors.indigo.shade50.withValues(alpha: 0.5) : Colors.white,
          leading: Checkbox(
            value: isSelected,
            activeColor: Colors.indigo,
            onChanged: (val) {
              setState(() {
                if (val == true) _selectedGcs.add(number);
                else _selectedGcs.remove(number);
              });
            },
          ),
          title: Text(number, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text('${gc['date']?.toString().split('T').first ?? ''} | ${gc['consignor']?['name'] ?? gc['consignorName'] ?? '-'}'),
          trailing: Text('₹${gc['freightTotal'] ?? '0.00'}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          onTap: () {
            setState(() {
              if (isSelected) _selectedGcs.remove(number);
              else _selectedGcs.add(number);
            });
          },
        );
      },
    );
  }

  Widget _buildGdmTable() {
    return ListView.separated(
      controller: _gdmScrollController,
      padding: EdgeInsets.zero,
      itemCount: _recentGdms.length + (_hasMoreGdms ? 1 : 0),
      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
      itemBuilder: (context, index) {
        if (index == _recentGdms.length) {
          return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        }
        final gdm = _recentGdms[index];
        final number = gdm['gdmNumber']?.toString() ?? '';
        final isSelected = _selectedGdms.contains(number);
        return ListTile(
          tileColor: isSelected ? Colors.teal.shade50.withValues(alpha: 0.5) : Colors.white,
          leading: Checkbox(
            value: isSelected,
            activeColor: Colors.teal,
            onChanged: (val) {
              setState(() {
                if (val == true) _selectedGdms.add(number);
                else _selectedGdms.remove(number);
              });
            },
          ),
          title: Text(number, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text('${gdm['date']?.toString().split('T').first ?? ''} | ${gdm['vehicle']?['vehicleNumber'] ?? '-'}'),
          trailing: Text('${gdm['gcs']?.length ?? 0} GCs', style: const TextStyle(fontWeight: FontWeight.bold)),
          onTap: () {
            setState(() {
              if (isSelected) _selectedGdms.remove(number);
              else _selectedGdms.add(number);
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF5B21B6), Color(0xFF8B5CF6)]),
                        borderRadius: BorderRadius.circular(12)
                      ),
                      child: const Icon(Icons.print, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Print Hub', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                        const Text('Quickly print Lorry Receipts and Delivery Memos', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Top Cards
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopCard(
                      icon: Icons.note_add_rounded,
                      color: const Color(0xFFF59E0B), // Amber-500
                      gradient: const [Color(0xFFD97706), Color(0xFFF59E0B)], // Amber-600 to Amber-500
                      title: 'Lorry Receipt (GC)',
                      subtitle: 'Print A5 Lorry Receipts.',
                      prefix: _gcPrefix,
                      onPrefixChange: (p) => setState(() => _gcPrefix = p),
                      controller: _gcInputController,
                      disabled: false,
                      onPrint: () async {
                        if (_gcInputController.text.trim().isEmpty) return;
                        final num = '$_gcPrefix-${_gcInputController.text.trim()}';
                        if (_gcSearchMode == 'gdm') {
                          try {
                            final gdm = await ApiService.getGdmDetails(num);
                            final attachedGcs = (gdm['gcs'] as List? ?? [])
                                .map((g) => g['gcNumber']?.toString() ?? '')
                                .where((s) => s.isNotEmpty)
                                .toList();
                            if (attachedGcs.isEmpty) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('No GCs attached to GDM $num')),
                                );
                              }
                              return;
                            }
                            if (mounted) {
                              _showGcCopiesModal(attachedGcs, initialCopies: ['LORRY COPY']);
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to load GDM $num: $e')),
                              );
                            }
                          }
                        } else {
                          _showGcCopiesModal([num]);
                        }
                      },
                      extraOptions: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Radio<String>(value: 'gc', groupValue: _gcSearchMode, activeColor: const Color(0xFFF59E0B), onChanged: (v) => setState(() => _gcSearchMode = v!)),
                          const Text('By GC Number', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 16),
                          Radio<String>(value: 'gdm', groupValue: _gcSearchMode, activeColor: const Color(0xFFF59E0B), onChanged: (v) => setState(() => _gcSearchMode = v!)),
                          const Text('Bulk by GDM', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    _buildTopCard(
                      icon: Icons.local_shipping_rounded,
                      color: const Color(0xFF10B981), // Emerald-500
                      gradient: const [Color(0xFF059669), Color(0xFF10B981)], // Emerald-600 to Emerald-500
                      title: 'Delivery Memo (GDM)',
                      subtitle: 'Print an A4 size Goods Despatch Memo.',
                      prefix: _gdmPrefix,
                      onPrefixChange: (p) => setState(() => _gdmPrefix = p),
                      controller: _gdmInputController,
                      disabled: false,
                      onPrint: () {
                        if (_gdmInputController.text.trim().isEmpty) return;
                        final num = '$_gdmPrefix-${_gdmInputController.text.trim()}';
                        _showGdmFormatModal([num]);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Batch Printing
                _buildBatchSection(),
                const SizedBox(height: 32),

                // Hardware Print Agent
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.print, color: Colors.amber.shade400, size: 28),
                                const SizedBox(width: 12),
                                const Text('Hardware Print Agent', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'To use the "Silent Hardware Print" feature without browser popups, you must run this tiny background app on your computer. Download the agent below and leave it running in the background.',
                              style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Download Agent (Win/Mac)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade500,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HoverCard extends StatefulWidget {
  final Widget Function(BuildContext context, bool isHovered) builder;
  final Color accentColor;
  const _HoverCard({required this.builder, required this.accentColor});
  @override
  State<_HoverCard> createState() => _HoverCardState();
}
class _HoverCardState extends State<_HoverCard> {
  bool _isHovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: _isHovered
            ? Matrix4.translationValues(0, -6, 0)
            : Matrix4.identity(),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _isHovered
                ? widget.accentColor.withValues(alpha: 0.5)
                : const Color(0xFFE2E8F0),
            width: _isHovered ? 1.6 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? widget.accentColor.withValues(alpha: 0.16)
                  : const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: _isHovered ? 24 : 16,
              offset: _isHovered ? const Offset(0, 10) : const Offset(0, 4),
            ),
            if (_isHovered)
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: widget.builder(context, _isHovered),
      ),
    );
  }
}

class _HoverInput extends StatefulWidget {
  final TextEditingController controller;
  final Color activeColor;
  const _HoverInput({required this.controller, required this.activeColor});
  @override
  State<_HoverInput> createState() => _HoverInputState();
}
class _HoverInputState extends State<_HoverInput> {
  bool _isFocused = false;
  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (_isFocused)
              BoxShadow(color: widget.activeColor.withOpacity(0.2), blurRadius: 0, spreadRadius: 3),
          ],
        ),
        child: TextField(
          controller: widget.controller,
          decoration: InputDecoration(
            hintText: "1001",
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.activeColor, width: 1)),
          ),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _HoverButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Color color;
  final String label;
  final IconData icon;
  const _HoverButton({required this.onPressed, required this.color, required this.label, required this.icon});
  @override
  State<_HoverButton> createState() => _HoverButtonState();
}
class _HoverButtonState extends State<_HoverButton> {
  bool _isHovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (_isHovered && widget.onPressed != null)
              BoxShadow(color: widget.color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
            else if (widget.onPressed != null)
              BoxShadow(color: widget.color.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: widget.onPressed,
          icon: Icon(widget.icon, size: 20),
          label: Text(widget.label),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
            textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
        ),
      ),
    );
  }
}
