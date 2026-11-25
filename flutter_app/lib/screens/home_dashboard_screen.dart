import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HomeDashboardScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const HomeDashboardScreen({super.key, required this.onNavigate});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  void _openGdmSearchDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _GdmSearchDialog(onNavigate: widget.onNavigate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14.0 : 28.0,
        vertical: isMobile ? 14.0 : 24.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Section Label (responsive - no overflow on mobile)
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'CORE OPERATIONS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Color(0xFF475569),
                ),
              ),
              if (!isMobile) ...[
                const Spacer(),
                Text(
                  'Select an operation to begin',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // The Essential Action Cards (now including Warehouse Inward & Quick Bill)
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 768;
              const spacing = 16.0;
              final cardWidth = isDesktop
                  ? (constraints.maxWidth - spacing) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  // CARD 1: WAREHOUSE INWARD (Primary Mobile Floor Action)
                  SizedBox(
                    width: cardWidth,
                    child: _CoreActionCard(
                      title: 'WAREHOUSE INWARD & DOCK',
                      subtitle:
                          'Barcode scanning, E-Way Bill decoder, godown bay allocation & instant consignee WhatsApp receipts',
                      icon: Icons.qr_code_scanner_rounded,
                      tag: 'MOBILE DOCK',
                      gradient: const [Color(0xFF312E81), Color(0xFF4F46E5)],
                      accentColor: const Color(0xFF6366F1),
                      onTap: () => widget.onNavigate(1),
                    ),
                  ),

                  // CARD 2: NEW GC ENTRY
                  SizedBox(
                    width: cardWidth,
                    child: _CoreActionCard(
                      title: 'NEW GC ENTRY',
                      subtitle:
                          'Create new Goods Consignment note (Bilty), calculate freight & generate thermal receipts',
                      icon: Icons.note_add_rounded,
                      tag: 'CREATE GC',
                      gradient: const [Color(0xFF1E40AF), Color(0xFF2563EB)],
                      accentColor: const Color(0xFF2563EB),
                      onTap: () => widget.onNavigate(0),
                    ),
                  ),

                  // CARD 3: RETAIL QUICK BILL
                  SizedBox(
                    width: cardWidth,
                    child: _CoreActionCard(
                      title: 'RETAIL QUICK BILL',
                      subtitle:
                          'Walk-in parcel fast POS counter billing with instant thermal receipt generation',
                      icon: Icons.flash_on_rounded,
                      tag: 'FAST BILL',
                      gradient: const [Color(0xFF9A3412), Color(0xFFEA580C)],
                      accentColor: const Color(0xFFEA580C),
                      onTap: () => widget.onNavigate(23),
                    ),
                  ),

                  // CARD 4: GC SEARCH / REGISTER
                  SizedBox(
                    width: cardWidth,
                    child: _CoreActionCard(
                      title: 'GC SEARCH & REGISTER',
                      subtitle:
                          'Quickly search, filter & view all issued consignments by GC Number, Party name, or Date',
                      icon: Icons.search_rounded,
                      tag: 'GC REGISTER',
                      gradient: const [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                      accentColor: const Color(0xFF0EA5E9),
                      onTap: () => widget.onNavigate(9),
                    ),
                  ),

                  // CARD 5: GDM DISPATCH MANIFEST
                  SizedBox(
                    width: cardWidth,
                    child: _CoreActionCard(
                      title: 'GDM MANIFEST',
                      subtitle:
                          'Create Goods Despatch Manifest, assign lorry, attach consignments & dispatch vehicle',
                      icon: Icons.local_shipping_rounded,
                      tag: 'DISPATCH',
                      gradient: const [Color(0xFF065F46), Color(0xFF10B981)],
                      accentColor: const Color(0xFF10B981),
                      onTap: () => widget.onNavigate(2),
                    ),
                  ),

                  // CARD 6: GDM SEARCH
                  SizedBox(
                    width: cardWidth,
                    child: _CoreActionCard(
                      title: 'GDM SEARCH & STATUS',
                      subtitle:
                          'Lookup vehicle loading manifests, verify attached GCs, check status & thermal print manifests',
                      icon: Icons.manage_search_rounded,
                      tag: 'FIND MANIFEST',
                      gradient: const [Color(0xFF5B21B6), Color(0xFF8B5CF6)],
                      accentColor: const Color(0xFF8B5CF6),
                      onTap: _openGdmSearchDialog,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // 3. Clean Quick Footer Note
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 18, color: Color(0xFF64748B)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'All masters, accounts, lorry hire, and reports can be accessed at any time using the top navigation bar.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- High-Quality Core Action Card with Smooth Mouse Hover Animation ---
class _CoreActionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String tag;
  final List<Color> gradient;
  final Color accentColor;
  final VoidCallback onTap;

  const _CoreActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tag,
    required this.gradient,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_CoreActionCard> createState() => _CoreActionCardState();
}

class _CoreActionCardState extends State<_CoreActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: _isHovered
              ? Matrix4.translationValues(0, -6, 0)
              : Matrix4.identity(),
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.all(isMobile ? 10 : 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: widget.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: widget.accentColor
                              .withValues(alpha: _isHovered ? 0.45 : 0.28),
                          blurRadius: _isHovered ? 14 : 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(widget.icon, size: isMobile ? 22 : 28, color: Colors.white),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      widget.tag,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: widget.accentColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 14 : 18),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
                maxLines: isMobile ? 2 : 3,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: isMobile ? 14 : 18),
              Row(
                children: [
                  Text(
                    'OPEN NOW',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: widget.accentColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedPadding(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.only(left: _isHovered ? 6 : 0),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: widget.accentColor,
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
}

// --- Instant GDM Quick Search Dialog ---
class _GdmSearchDialog extends StatefulWidget {
  final Function(int) onNavigate;

  const _GdmSearchDialog({required this.onNavigate});

  @override
  State<_GdmSearchDialog> createState() => _GdmSearchDialogState();
}

class _GdmSearchDialogState extends State<_GdmSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _performSearch('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      final q = query.trim().isEmpty ? 'limit=15' : 'q=$query&limit=15';
      final res = await ApiService.getReportGdms(q);
      final rawList = res['data'] as List? ?? [];
      final List<Map<String, dynamic>> parsed = [];
      for (var item in rawList) {
        parsed.add({
          'id': item['id'],
          'gdmNumber': item['gdmNumber'] ?? '-',
          'date': item['date']?.toString().split('T').first ?? '-',
          'vehicle': item['vehicle']?['vehicleNumber'] ?? '-',
          'destination': item['destination'] ?? item['toName'] ?? '-',
          'totalGcs': (item['gcs'] as List?)?.length ?? 0,
          'status': item['status'] ?? 'Active',
        });
      }
      setState(() => _results = parsed);
    } catch (_) {
      setState(() => _results = []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 700,
        height: 580,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5B21B6), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.manage_search_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GDM Search & Registry',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Search by GDM Number, Vehicle, or Destination',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Search Input
            TextField(
              controller: _searchController,
              onChanged: (val) => _performSearch(val),
              decoration: InputDecoration(
                hintText: 'Type GDM number (e.g. AP-1001) or vehicle number...',
                hintStyle:
                    const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 20, color: Color(0xFF64748B)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
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
                  borderSide:
                      const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            const SizedBox(height: 14),
            // Results List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF8B5CF6), strokeWidth: 2))
                  : _results.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 40, color: Color(0xFFCBD5E1)),
                              SizedBox(height: 8),
                              Text('No matching GDMs found',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B))),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (ctx, i) {
                            final gdm = _results[i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.description_outlined,
                                    size: 18, color: Color(0xFF8B5CF6)),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    gdm['gdmNumber'],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      gdm['status'],
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    gdm['date'],
                                    style: const TextStyle(
                                        fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.directions_bus_rounded,
                                        size: 14, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(
                                      gdm['vehicle'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Icon(Icons.location_on_outlined,
                                        size: 14, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        gdm['destination'],
                                        style: const TextStyle(
                                            fontSize: 12, color: Color(0xFF64748B)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${gdm['totalGcs']} GCs',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF8B5CF6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${_results.length} results',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onNavigate(17); // Go to full Reports screen
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Open Full Reports'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF8B5CF6),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
