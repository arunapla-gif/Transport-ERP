import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/web_speech.dart';

class GodownPlannerScreen extends StatefulWidget {
  const GodownPlannerScreen({super.key});

  @override
  State<GodownPlannerScreen> createState() => _GodownPlannerScreenState();
}

class _GodownPlannerScreenState extends State<GodownPlannerScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _stock = [];
  String _searchQuery = '';
  List<String> _visualFilter = [];
  String _selectedWeightFilter = 'ALL'; // ALL, HEAVY (>500KG), LIGHT (<=500KG)

  bool _isSpeaking = false;
  String _activeSpeechText = '';
  String? _aiResponse;
  String? _lastQuery;
  final TextEditingController _aiQueryController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _isAiQuerying = false;

  @override
  void initState() {
    super.initState();
    _loadGodownStock();
  }

  @override
  void dispose() {
    _stopSpeaking();
    _aiQueryController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGodownStock() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ApiService.getGodownStock();
      if (mounted) {
        setState(() {
          _stock = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'கோடவுன் டேட்டா எடுக்க முடியவில்லை (Failed to load godown stock): $e';
          _isLoading = false;
        });
      }
    }
  }

  void _speakTamil(String text) {
    _activeSpeechText = text;
    setState(() => _isSpeaking = true);

    if (kIsWeb) {
      speakWebTamil(text);
    }

    final wordCount = text.split(' ').length;
    final durationSeconds = (wordCount * 0.45).clamp(3, 30).toInt();
    Future.delayed(Duration(seconds: durationSeconds), () {
      if (mounted && _isSpeaking) {
        setState(() => _isSpeaking = false);
      }
    });
  }

  void _stopSpeaking() {
    setState(() => _isSpeaking = false);
    if (kIsWeb) {
      stopWebSpeech();
    }
  }

  void _handleReadAllVoice() {
    if (_isSpeaking) {
      _stopSpeaking();
      return;
    }

    if (_stock.isEmpty) {
      _speakTamil("கோடவுனில் எந்த சரக்கும் இல்லை.");
      return;
    }

    final buffer = StringBuffer();
    buffer.write("ஐயா வணக்கம். இன்று கோடவுனில் உள்ள சரக்கு விவரங்கள். ");

    for (var item in _stock) {
      final name = item['consigneeName'] ?? 'தெரியாத வாடிக்கையாளர்';
      final parcels = (item['totalArticles'] ?? 0) > 0 ? "${item['totalArticles']} பார்சல், " : "";
      final weight = (item['totalWeight'] ?? 0) > 0 ? "${item['totalWeight']} கிலோ " : "";
      final gcs = "${item['totalGCs'] ?? 0} பில்";

      buffer.write("$name க்கு, $parcels $weight சரக்கு இருக்கு. மொத்தம் $gcs. ");
    }

    buffer.write("நன்றி.");
    _speakTamil(buffer.toString());
  }

  void _speakSingleConsignee(Map<String, dynamic> item) {
    final name = item['consigneeName'] ?? '';
    final parcels = item['totalArticles'] ?? 0;
    final weight = item['totalWeight'] ?? 0;
    final gcs = item['totalGCs'] ?? 0;

    final speech = "$name க்கு $parcels பார்சல், $weight கிலோ சரக்கு உள்ளது. மொத்தம் $gcs பில்.";
    _speakTamil(speech);
  }

  Future<void> _handleAiQuery(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    setState(() {
      _isAiQuerying = true;
      _lastQuery = cleanQuery;
      _aiResponse = null;
    });

    try {
      final lower = cleanQuery.toLowerCase();
      final matchedConsignees = _stock.where((s) {
        final name = (s['consigneeName'] ?? '').toString().toLowerCase();
        return name.contains(lower) || lower.contains(name);
      }).map((s) => s['consigneeName'].toString()).toList();

      if (matchedConsignees.isNotEmpty) {
        _visualFilter = matchedConsignees;
      }

      final payload = {
        'audioData': '',
        'mimeType': 'text/plain',
        'queryText': cleanQuery,
        'stockContext': _stock,
      };

      try {
        final res = await ApiService.queryGodownAi(payload);
        if (mounted) {
          final reply = res['reply']?.toString() ?? 'விவரங்கள் திரையில் காட்டப்பட்டுள்ளன.';
          final filtered = res['filteredConsignees'];
          if (filtered is List && filtered.isNotEmpty) {
            _visualFilter = filtered.map((e) => e.toString()).toList();
          }

          setState(() {
            _aiResponse = reply;
            _isAiQuerying = false;
          });
          _speakTamil(reply);
        }
      } catch (_) {
        if (mounted) {
          String localReply;
          if (matchedConsignees.isNotEmpty) {
            final match = _stock.firstWhere((s) => s['consigneeName'].toString() == matchedConsignees.first);
            localReply = "${match['consigneeName']}க்கு மொத்தம் ${match['totalArticles']} பார்சல், ${match['totalWeight']} கிலோ சரக்கு உள்ளது.";
          } else {
            localReply = "கோடவுனில் மொத்தம் ${_stock.length} வாடிக்கையாளர் சரக்குகள் காத்திருப்பில் உள்ளன.";
          }

          setState(() {
            _aiResponse = localReply;
            _isAiQuerying = false;
          });
          _speakTamil(localReply);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isAiQuerying = false);
      }
    }
  }

  void _showConsigneeDetailModal(Map<String, dynamic> item) {
    final consigneeName = (item['consigneeName'] ?? 'Consignee').toString();
    final totalGcs = (item['totalGCs'] as num?)?.toInt() ?? 0;
    final totalArticles = (item['totalArticles'] as num?)?.toInt() ?? 0;
    final totalWeight = (item['totalWeight'] as num?)?.toDouble() ?? 0.0;
    final gcs = (item['gcs'] as List?)?.map((e) => e.toString()).toList() ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: 680,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        consigneeName.isNotEmpty ? consigneeName[0].toUpperCase() : 'C',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          consigneeName.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Godown Stock Item Details & Manifest Breakdown',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFFEF3C7),
                      padding: const EdgeInsets.all(10),
                    ),
                    tooltip: 'Speak in Tamil',
                    icon: const Icon(Icons.volume_up_rounded, color: Color(0xFFD97706), size: 22),
                    onPressed: () {
                      _speakSingleConsignee(item);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Summary KPI Row
              Row(
                children: [
                  Expanded(
                    child: _buildModalStatCard(
                      label: 'PENDING GCS',
                      value: '$totalGcs Bills',
                      icon: Icons.receipt_long_rounded,
                      color: const Color(0xFF6366F1),
                      bg: const Color(0xFFEEF2FF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildModalStatCard(
                      label: 'TOTAL PARCELS',
                      value: '$totalArticles Pcs',
                      icon: Icons.inventory_2_rounded,
                      color: const Color(0xFF0284C7),
                      bg: const Color(0xFFF0F9FF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildModalStatCard(
                      label: 'TOTAL WEIGHT',
                      value: '${totalWeight.toStringAsFixed(0)} KG',
                      icon: Icons.scale_rounded,
                      color: const Color(0xFF10B981),
                      bg: const Color(0xFFECFDF5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Associated Consignment Notes (GCs):',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334155),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),
              if (gcs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text('No individual GC numbers recorded for this entry.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: gcs.map((gc) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.tag_rounded, size: 14, color: Color(0xFF475569)),
                              const SizedBox(width: 6),
                              Text(
                                gc,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.volume_up_rounded, size: 18),
                      label: const Text('Speak Details', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _speakSingleConsignee(item);
                      },
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

  Widget _buildModalStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredStock = _stock.where((item) {
      final name = (item['consigneeName'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase().trim();

      if (_visualFilter.isNotEmpty && !_visualFilter.contains(item['consigneeName'])) {
        return false;
      }

      if (_selectedWeightFilter == 'HEAVY') {
        final w = (item['totalWeight'] as num?)?.toDouble() ?? 0.0;
        if (w < 500) return false;
      } else if (_selectedWeightFilter == 'LIGHT') {
        final w = (item['totalWeight'] as num?)?.toDouble() ?? 0.0;
        if (w >= 500) return false;
      }

      if (query.isEmpty) return true;
      return name.contains(query);
    }).toList();

    int totalGcs = 0;
    int totalParcels = 0;
    double totalWeight = 0;
    for (var s in _stock) {
      totalGcs += (s['totalGCs'] as num?)?.toInt() ?? 0;
      totalParcels += (s['totalArticles'] as num?)?.toInt() ?? 0;
      totalWeight += (s['totalWeight'] as num?)?.toDouble() ?? 0.0;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading && _stock.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
            )
          : RefreshIndicator(
              onRefresh: _loadGodownStock,
              color: const Color(0xFFF59E0B),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Modern Swiss Slate Gradient Cockpit Header
                    _buildCockpitHeader(totalGcs, totalParcels, totalWeight),

                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Error banner if any
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

                              // Metrics Overview Cards
                              _buildMetricsOverview(totalGcs, totalParcels, totalWeight),
                              const SizedBox(height: 20),

                              // Interactive Voice & AI Terminal
                              _buildVoiceAndAiTerminal(),
                              const SizedBox(height: 20),

                              // Filter & Search Controls Bar
                              _buildSearchAndFilters(filteredStock.length),
                              const SizedBox(height: 16),

                              // Stock Cards List or Empty State
                              if (filteredStock.isEmpty)
                                _buildEmptyState()
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: filteredStock.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final item = filteredStock[index] as Map<String, dynamic>;
                                    return _buildStockCard(item);
                                  },
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
            ),
    );
  }

  Widget _buildCockpitHeader(int totalGcs, int totalParcels, double totalWeight) {
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
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.warehouse_rounded, color: Colors.white, size: 28),
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
                            'கோடவுன் இருப்பு',
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
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.record_voice_over_rounded, size: 12, color: Color(0xFFFBBF24)),
                                SizedBox(width: 4),
                                Text(
                                  'AI VOICE ASSISTED',
                                  style: TextStyle(
                                    color: Color(0xFFFBBF24),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Live Warehouse Inventory, Parcels Manifest & Bilingual Audio Dispatch Assistant',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSpeaking ? const Color(0xFFE11D48) : const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: Icon(
                        _isSpeaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _isSpeaking ? 'நிறுத்து (Stop)' : 'முழு விவரம் படி (Read All)',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      onPressed: _handleReadAllVoice,
                    ),
                    IconButton(
                      tooltip: 'Refresh Inventory',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF334155),
                        padding: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                      onPressed: _isLoading ? null : _loadGodownStock,
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

  Widget _buildMetricsOverview(int totalGcs, int totalParcels, double totalWeight) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        final cardWidth = isNarrow ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 36) / 4;

        final metrics = [
          {
            'label': 'Consignees (வாடிக்கையாளர்)',
            'value': '${_stock.length}',
            'sub': 'Active In Godown',
            'icon': Icons.business_rounded,
            'color': const Color(0xFF8B5CF6),
            'bg': const Color(0xFFF5F3FF),
            'border': const Color(0xFFDDD6FE),
          },
          {
            'label': 'Pending GCs (பில்கள்)',
            'value': '$totalGcs',
            'sub': 'Awaiting Delivery',
            'icon': Icons.receipt_long_rounded,
            'color': const Color(0xFFF59E0B),
            'bg': const Color(0xFFFFFBEB),
            'border': const Color(0xFFFDE68A),
          },
          {
            'label': 'Total Articles (பார்சல்)',
            'value': '$totalParcels',
            'sub': 'In Stock Count',
            'icon': Icons.inventory_2_rounded,
            'color': const Color(0xFF0284C7),
            'bg': const Color(0xFFF0F9FF),
            'border': const Color(0xFFBAE6FD),
          },
          {
            'label': 'Total Weight (கிலோ)',
            'value': '${totalWeight.toStringAsFixed(0)} KG',
            'sub': '${(totalWeight / 1000).toStringAsFixed(2)} Metric Tons',
            'icon': Icons.scale_rounded,
            'color': const Color(0xFF10B981),
            'bg': const Color(0xFFECFDF5),
            'border': const Color(0xFFA7F3D0),
          },
        ];

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: metrics.map((m) {
            return Container(
              width: cardWidth,
              padding: const EdgeInsets.all(18),
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
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: m['bg'] as Color,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: m['border'] as Color),
                        ),
                        child: Icon(m['icon'] as IconData, color: m['color'] as Color, size: 20),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          m['sub'] as String,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    m['value'] as String,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m['label'] as String,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildVoiceAndAiTerminal() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.record_voice_over_rounded, color: Color(0xFFFBBF24), size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI குரல் மற்றும் தகவல் முனையம் (Voice & AI Terminal)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Ask questions in Tamil or English to filter godown stock, check weight, or find parcels',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isSpeaking)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE11D48)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.graphic_eq_rounded, size: 14, color: Color(0xFFFB7185)),
                      SizedBox(width: 6),
                      Text(
                        'SPEAKING',
                        style: TextStyle(color: Color(0xFFFB7185), fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Speaking live text banner
          if (_isSpeaking) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF59E0B)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ஒலிபரப்பாகிறது (Speaking): "$_activeSpeechText"',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFDE68A),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _stopSpeaking,
                    icon: const Icon(Icons.stop_rounded, size: 16, color: Color(0xFFF87171)),
                    label: const Text('Stop', style: TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // AI Query Output Box
          if (_aiResponse != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0369A1).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology_rounded, color: Color(0xFF38BDF8), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'கேள்வி: "${_lastQuery ?? ''}"',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF7DD3FC)),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Replay in Voice',
                        icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF38BDF8), size: 18),
                        onPressed: () => _speakTamil(_aiResponse!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _aiResponse!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Quick Question Chips Row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildTerminalChip('மொத்த பார்சல் எத்தனை?', () {
                _aiQueryController.text = 'மொத்த பார்சல் எத்தனை?';
                _handleAiQuery('மொத்த பார்சல் எத்தனை?');
              }),
              _buildTerminalChip('அதிக எடை உள்ள சரக்கு எது?', () {
                _aiQueryController.text = 'அதிக எடை உள்ள சரக்கு எது?';
                _handleAiQuery('அதிக எடை உள்ள சரக்கு எது?');
              }),
              if (_stock.isNotEmpty)
                _buildTerminalChip('${_stock.first['consigneeName']} சரக்கு விவரம்', () {
                  final name = _stock.first['consigneeName'];
                  _aiQueryController.text = '$name சரக்கு விவரம்';
                  _handleAiQuery('$name சரக்கு விவரம்');
                }),
            ],
          ),
          const SizedBox(height: 14),

          // Interactive Question Bar
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF64748B)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _aiQueryController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Ask in Tamil or English (e.g. பார்சல் எத்தனை?)...',
                      hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    onSubmitted: (val) => _handleAiQuery(val),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    icon: _isAiQuerying
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 14),
                    label: const Text('Ask', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: _isAiQuerying ? null : () => _handleAiQuery(_aiQueryController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalChip(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, size: 13, color: Color(0xFFF59E0B)),
            const SizedBox(width: 4),
            Text(
              text,
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(int matchCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'வாடிக்கையாளர் பெயர் தேடு (Search Consignee name)...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Weight filter chips
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  _buildWeightFilterOption('ALL', 'All Stock'),
                  _buildWeightFilterOption('HEAVY', '>500 KG'),
                  _buildWeightFilterOption('LIGHT', '≤500 KG'),
                ],
              ),
            ),
          ],
        ),

        // Visual Filter Active Bar if AI filter applied
        if (_visualFilter.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.filter_alt_rounded, size: 18, color: Color(0xFF4F46E5)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI வடிகட்டிய வாடிக்கையாளர்கள் (Filtered): ${_visualFilter.join(', ')}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF3730A3)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _visualFilter = []);
                  },
                  child: const Text(
                    'அனைத்தும் காட்டு (Show All)',
                    style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4F46E5), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing $matchCount Consignees',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
              ),
              const Text(
                'Click card to inspect GCs',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeightFilterOption(String code, String label) {
    final isSelected = _selectedWeightFilter == code;
    return InkWell(
      onTap: () => setState(() => _selectedWeightFilter = code),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildStockCard(Map<String, dynamic> item) {
    final consigneeName = (item['consigneeName'] ?? 'Unknown Consignee').toString();
    final totalGcs = (item['totalGCs'] as num?)?.toInt() ?? 0;
    final totalArticles = (item['totalArticles'] as num?)?.toInt() ?? 0;
    final totalWeight = (item['totalWeight'] as num?)?.toDouble() ?? 0.0;
    final gcs = (item['gcs'] as List?)?.map((e) => e.toString()).toList() ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showConsigneeDetailModal(item),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Consignee Initials Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF0284C7).withValues(alpha: 0.1),
                            const Color(0xFF0369A1).withValues(alpha: 0.2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Center(
                        child: Text(
                          consigneeName.isNotEmpty ? consigneeName[0].toUpperCase() : 'C',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Consignee title and Pending GCs tag
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            consigneeName.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  '$totalGcs GCs Pending',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '• Tap to inspect',
                                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Read Voice button for this item
                    IconButton(
                      tooltip: 'Read this Consignee in Tamil',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFFEF3C7),
                        padding: const EdgeInsets.all(10),
                      ),
                      icon: const Icon(Icons.volume_up_rounded, color: Color(0xFFD97706), size: 20),
                      onPressed: () => _speakSingleConsignee(item),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(color: Color(0xFFF1F5F9), height: 1),
                const SizedBox(height: 16),

                // Metrics row: Parcels and Weight
                Row(
                  children: [
                    // Parcels Badge
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE0F2FE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined, color: Color(0xFF0284C7), size: 20),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'பார்சல் (Parcels)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0284C7),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                Text(
                                  '$totalArticles',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0C4A6E),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Weight Badge
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFD1FAE5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.scale_outlined, color: Color(0xFF10B981), size: 20),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'கிலோ (Weight)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF059669),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                Text(
                                  '${totalWeight.toStringAsFixed(0)} KG',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF064E3B),
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

                // GC list preview chips
                if (gcs.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: gcs.take(6).map((gc) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          gc,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      );
                    }).toList()
                      ..addAll(
                        gcs.length > 6
                            ? [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '+${gcs.length - 6} more',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                ),
                              ]
                            : [],
                      ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 20),
          const Text(
            'கோடவுனில் சரக்கு இல்லை',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 6),
          const Text(
            'No matching pending stock available in godown.',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
          ),
          if (_searchQuery.isNotEmpty || _visualFilter.isNotEmpty || _selectedWeightFilter != 'ALL') ...[
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _visualFilter = [];
                  _selectedWeightFilter = 'ALL';
                });
              },
              child: const Text('Reset All Filters'),
            ),
          ],
        ],
      ),
    );
  }
}
