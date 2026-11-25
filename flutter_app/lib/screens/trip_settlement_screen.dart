import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../models/gdm.dart';
import '../models/gc.dart';
import '../services/api_service.dart';
import 'dart:math' as math;

class ConsigneeGroup {
  final String consigneeId;
  final String name;
  double totalFreightDue;
  final List<Gc> gcs;

  ConsigneeGroup({
    required this.consigneeId,
    required this.name,
    this.totalFreightDue = 0.0,
    required this.gcs,
  });
}

class Allocation {
  double paidToDriver;
  double paidToTransport;

  Allocation({this.paidToDriver = 0.0, this.paidToTransport = 0.0});
}

class TripSettlementScreen extends StatefulWidget {
  const TripSettlementScreen({super.key});

  @override
  State<TripSettlementScreen> createState() => _TripSettlementScreenState();
}

class _TripSettlementScreenState extends State<TripSettlementScreen> {
  bool _isLoading = true;
  bool _isSettling = false;

  List<Trip> _activeTrips = [];
  List<Gdm> _unassignedGdms = [];

  Trip? _selectedTrip;
  final Set<int> _selectedGdmIds = {};

  // consigneeId -> Allocation
  final Map<String, Allocation> _allocations = {};
  final Set<String> _expandedGroups = {};
  int _quickFillEpoch = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final futures = await Future.wait([
        ApiService.getTrips(),
        ApiService.getGdmsUnassigned(),
      ]);

      setState(() {
        final allTrips = futures[0].map((e) => Trip.fromJson(e)).toList();
        _activeTrips = allTrips.where((t) => t.status == 'Active').toList();
        _unassignedGdms = futures[1].map((e) => Gdm.fromJson(e)).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading trip data: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Gdm> get _gdmsForVehicle {
    if (_selectedTrip == null || _selectedTrip!.vehicleId == null) return [];
    return _unassignedGdms.where((g) => g.vehicleId == _selectedTrip!.vehicleId).toList();
  }

  List<ConsigneeGroup> get _consigneeGroups {
    final selectedGdms = _gdmsForVehicle.where((g) => _selectedGdmIds.contains(g.id)).toList();
    final Map<String, ConsigneeGroup> groups = {};

    for (var gdm in selectedGdms) {
      if (gdm.gcs == null) continue;
      for (var rawGc in gdm.gcs!) {
        final Gc gc = rawGc is Gc ? rawGc : Gc.fromJson(rawGc as Map<String, dynamic>);
        final cId = gc.consigneeId?.toString() ?? 'unknown';
        if (!groups.containsKey(cId)) {
          groups[cId] = ConsigneeGroup(
            consigneeId: cId,
            name: gc.consigneeName.isNotEmpty ? gc.consigneeName : 'Retail / Cash Party',
            gcs: [],
          );
        }
        groups[cId]!.totalFreightDue += gc.freightTotal;
        groups[cId]!.gcs.add(gc);
      }
    }
    return groups.values.toList();
  }

  double get _tripBalance => _selectedTrip?.balanceAmount ?? 0.0;

  double get _totalPaidToDriver {
    return _allocations.values.fold(0.0, (sum, alloc) => sum + alloc.paidToDriver);
  }

  double get _totalPaidToUs {
    return _allocations.values.fold(0.0, (sum, alloc) => sum + alloc.paidToTransport);
  }

  double get _difference => _totalPaidToDriver - _tripBalance;
  bool get _isCrossing => _difference > 0;
  bool get _isReturn => _difference < 0;
  double get _absoluteDifference => _difference.abs();

  void _handleAllocationChange(String cId, String field, String value) {
    final val = double.tryParse(value) ?? 0.0;
    setState(() {
      _allocations.putIfAbsent(cId, () => Allocation());
      if (field == 'driver') {
        _allocations[cId]!.paidToDriver = val;
      } else {
        _allocations[cId]!.paidToTransport = val;
      }
    });
  }

  void _handleFullToDriver(String cId, double totalFreightDue) {
    setState(() {
      _allocations.putIfAbsent(cId, () => Allocation());
      _allocations[cId]!.paidToDriver = totalFreightDue;
      _allocations[cId]!.paidToTransport = 0.0;
      _quickFillEpoch++;
    });
  }

  void _handleFullToTransport(String cId, double totalFreightDue) {
    setState(() {
      _allocations.putIfAbsent(cId, () => Allocation());
      _allocations[cId]!.paidToDriver = 0.0;
      _allocations[cId]!.paidToTransport = totalFreightDue;
      _quickFillEpoch++;
    });
  }

  Future<void> _handleSettleTrip() async {
    if (_selectedTrip == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an active trip to settle.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    if (_selectedGdmIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please attach at least one GDM manifest to this settlement.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSettling = true);

    try {
      final gcAllocations = [];
      for (var group in _consigneeGroups) {
        final alloc = _allocations[group.consigneeId] ?? Allocation();
        double remainingToDriver = alloc.paidToDriver;
        double remainingToTransport = alloc.paidToTransport;

        for (var gc in group.gcs) {
          final freight = gc.freightTotal > 0 ? gc.freightTotal : gc.balanceFreight;

          final toDriver = math.min(freight, remainingToDriver);
          remainingToDriver -= toDriver;

          final remainingFreight = freight - toDriver;
          final toTransport = math.min(remainingFreight, remainingToTransport);
          remainingToTransport -= toTransport;

          gcAllocations.add({
            'gcId': gc.id,
            'paidToDriver': toDriver,
            'paidToTransport': toTransport,
          });
        }
      }

      final payload = {
        'gdmIds': _selectedGdmIds.toList(),
        'allocations': gcAllocations,
        'crossingAmount': _isCrossing ? _absoluteDifference : 0,
        'returnAmount': _isReturn ? _absoluteDifference : 0,
      };

      await ApiService.settleTrip(_selectedTrip!.id, payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Trip ${_selectedTrip!.tripNumber} Settled & Closed Successfully!',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        setState(() {
          _selectedTrip = null;
          _selectedGdmIds.clear();
          _allocations.clear();
          _expandedGroups.clear();
        });
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to settle trip: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSettling = false);
      }
    }
  }

  Widget _buildSwissCard({required Widget child, bool noPadding = false, Color? borderColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: noPadding ? EdgeInsets.zero : const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: (borderColor ?? const Color(0xFF0F172A)).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Cockpit Banner
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 750;
              return Container(
                padding: EdgeInsets.symmetric(horizontal: isNarrow ? 16 : 24, vertical: isNarrow ? 16 : 20),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF31104B), Color(0xFF4C1D95), Color(0xFF6D28D9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4C1D95).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: isNarrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        const Text(
                                          'Trip Settlement',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFA78BFA).withValues(alpha: 0.25),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFDDD6FE).withValues(alpha: 0.4)),
                                          ),
                                          child: const Text(
                                            'CLEARANCE',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 9,
                                              color: Color(0xFFE9D5FF),
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Freight reconciliations & balance settlement',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: const Color(0xFFDDD6FE).withValues(alpha: 0.85),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: _activeTrips.isNotEmpty ? const Color(0xFF34D399) : Colors.amberAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${_activeTrips.length} Active Trips',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Material(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    setState(() => _isLoading = true);
                                    _loadData();
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text(
                                      'Trip Settlement & Reconciliation Engine',
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
                                        color: const Color(0xFFA78BFA).withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFDDD6FE).withValues(alpha: 0.4)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.handshake_rounded, size: 12, color: Color(0xFFE9D5FF)),
                                          SizedBox(width: 5),
                                          Text(
                                            'CLEARANCE ENGINE',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 10,
                                              color: Color(0xFFE9D5FF),
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
                                  'Multi-GDM freight reconciliations, To-Pay collection tracking, crossing & return balance settlement',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: const Color(0xFFDDD6FE).withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Active Trips Counter Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _activeTrips.isNotEmpty ? const Color(0xFF34D399) : Colors.amberAccent,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_activeTrips.isNotEmpty ? const Color(0xFF34D399) : Colors.amberAccent)
                                            .withValues(alpha: 0.6),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_activeTrips.length} Active Trips',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Refresh Button
                          Material(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() => _isLoading = true);
                                _loadData();
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(10),
                                child: Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
              );
            },
          ),

          // Main 2-column layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT COLUMN: Step 1 (Trip Selection) & Step 2 (Attach GDMs)
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // STEP 1 CARD: Trip Selector
                    _buildSwissCard(
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
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'STEP 1',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 10,
                                        color: Color(0xFF2563EB),
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'SELECT ACTIVE TRIP',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const Icon(Icons.local_shipping_outlined, color: Color(0xFF2563EB), size: 20),
                            ],
                          ),
                          const SizedBox(height: 16),

                          DropdownButtonFormField<Trip>(
                            value: _selectedTrip,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.8),
                              ),
                              hintText: 'Select or search active trip...',
                              hintStyle: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13),
                            ),
                            isExpanded: true,
                            items: _activeTrips
                                .map((t) => DropdownMenuItem(
                                      value: t,
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE2E8F0),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              t.tripNumber,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 11,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${t.vehicle?.vehicleNumber ?? 'No Vehicle'} • Due: ₹${t.balanceAmount ?? 0}',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                            onChanged: (t) {
                              setState(() {
                                _selectedTrip = t;
                                _selectedGdmIds.clear();
                                _allocations.clear();
                              });
                            },
                          ),

                          if (_selectedTrip != null) ...[
                            const SizedBox(height: 16),
                            // Trip Identity Preview Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // License Plate Chip
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF08A),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFCA8A04), width: 1.2),
                                        ),
                                        child: Text(
                                          _selectedTrip!.vehicle?.vehicleNumber ?? 'UNKNOWN RC',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                            color: Color(0xFF713F12),
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'ACTIVE TRIP',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF059669),
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (_selectedTrip!.driverName != null && _selectedTrip!.driverName!.isNotEmpty)
                                    Row(
                                      children: [
                                        const Icon(Icons.person_pin_rounded, size: 14, color: Color(0xFF64748B)),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Driver: ${_selectedTrip!.driverName!} ${_selectedTrip!.driverPhone != null ? "(${_selectedTrip!.driverPhone})" : ""}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 10),
                                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                  const SizedBox(height: 10),
                                  _buildTripRow('Lorry Hire Total:', '₹${_selectedTrip!.lorryHire ?? 0}'),
                                  _buildTripRow(
                                    'Advance Paid:',
                                    '₹${_selectedTrip!.advancePaid ?? 0}',
                                    valColor: const Color(0xFF0D9488),
                                  ),
                                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                                  _buildTripRow(
                                    'Trip Balance Due:',
                                    '₹${_tripBalance.toStringAsFixed(2)}',
                                    isTotal: true,
                                    valColor: const Color(0xFF2563EB),
                                  ),
                                ],
                              ),
                            )
                          ]
                        ],
                      ),
                    ),

                    // STEP 2 CARD: Attach Despatch GDMs
                    if (_selectedTrip != null)
                      _buildSwissCard(
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
                                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'STEP 2',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 10,
                                          color: Color(0xFF7C3AED),
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'ATTACH DESPATCH GDMs',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_gdmsForVehicle.isNotEmpty)
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        if (_selectedGdmIds.length == _gdmsForVehicle.length) {
                                          _selectedGdmIds.clear();
                                        } else {
                                          _selectedGdmIds.addAll(_gdmsForVehicle.map((g) => g.id!));
                                        }
                                      });
                                    },
                                    child: Text(
                                      _selectedGdmIds.length == _gdmsForVehicle.length
                                          ? 'Deselect All'
                                          : 'Select All',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                        color: Color(0xFF7C3AED),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            if (_gdmsForVehicle.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 22),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'No Unassigned GDMs Found',
                                            style: TextStyle(
                                              color: Color(0xFF92400E),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Vehicle ${_selectedTrip!.vehicle?.vehicleNumber ?? ''} does not have any pending unassigned manifests.',
                                            style: const TextStyle(color: Color(0xFFB45309), fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ..._gdmsForVehicle.map((gdm) {
                                final isSelected = _selectedGdmIds.contains(gdm.id);
                                final gcCount = gdm.gcs?.length ?? 0;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedGdmIds.remove(gdm.id);
                                      } else {
                                        _selectedGdmIds.add(gdm.id!);
                                      }
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFFE2E8F0),
                                        width: isSelected ? 2.0 : 1.2,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      color: isSelected
                                          ? const Color(0xFF7C3AED).withValues(alpha: 0.05)
                                          : const Color(0xFFF8FAFC),
                                    ),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: isSelected,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          onChanged: (v) {
                                            setState(() {
                                              if (v == true) {
                                                _selectedGdmIds.add(gdm.id!);
                                              } else {
                                                _selectedGdmIds.remove(gdm.id);
                                              }
                                            });
                                          },
                                          activeColor: const Color(0xFF7C3AED),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    gdm.gdmNumber,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 14,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFE2E8F0),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      gdm.date.split('T')[0],
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w700,
                                                        color: Color(0xFF475569),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '$gcCount GC(s) Attached • ${gdm.deliveryAt ?? 'Direct Delivery'}',
                                                style: TextStyle(
                                                  color: Colors.blueGrey.shade600,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.arrow_forward_ios_rounded,
                                            size: 14, color: Color(0xFF94A3B8)),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 24),

              // RIGHT COLUMN: Step 3 (Consignee Allocation Matrix) & Master Settlement Cockpit
              Expanded(
                flex: 8,
                child: _buildSwissCard(
                  borderColor:
                      _selectedTrip != null && _selectedGdmIds.isNotEmpty ? const Color(0xFF7C3AED) : null,
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
                                  'STEP 3',
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
                                'CONSIGNEE FREIGHT ALLOCATION MATRIX',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          if (_consigneeGroups.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                '${_consigneeGroups.length} Consignees • ${_selectedGdmIds.length} GDMs',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      if (_selectedTrip == null || _selectedGdmIds.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.calculate_outlined,
                                    size: 48,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Select an Active Trip & Attach GDMs',
                                  style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Consignee freight clearance rows will populate here automatically for To-Pay split.',
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade500,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ..._consigneeGroups.map((group) {
                              final alloc = _allocations[group.consigneeId] ?? Allocation();
                              final isExpanded = _expandedGroups.contains(group.consigneeId);
                              final totalAllocated = alloc.paidToDriver + alloc.paidToTransport;
                              final isBalanced = (totalAllocated - group.totalFreightDue).abs() < 0.01;
                              final isOver = totalAllocated > group.totalFreightDue;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isBalanced
                                        ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                        : const Color(0xFFE2E8F0),
                                    width: isBalanced ? 1.5 : 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: LayoutBuilder(
                                        builder: (context, cConstraints) {
                                          final isNarrow = cConstraints.maxWidth < 640;
                                          final nameSection = InkWell(
                                            borderRadius: BorderRadius.circular(8),
                                            onTap: () {
                                              setState(() {
                                                if (isExpanded) {
                                                  _expandedGroups.remove(group.consigneeId);
                                                } else {
                                                  _expandedGroups.add(group.consigneeId);
                                                }
                                              });
                                            },
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(Icons.business_rounded,
                                                        color: Color(0xFF7C3AED), size: 18),
                                                    const SizedBox(width: 8),
                                                    Flexible(
                                                      child: Text(
                                                        group.name,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w900,
                                                          fontSize: 14,
                                                          color: Color(0xFF0F172A),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Text(
                                                      '${group.gcs.length} Consignment Notes Attached',
                                                      style: TextStyle(
                                                        color: Colors.blueGrey.shade500,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Icon(
                                                      isExpanded
                                                          ? Icons.keyboard_arrow_up_rounded
                                                          : Icons.keyboard_arrow_down_rounded,
                                                      size: 16,
                                                      color: const Color(0xFF7C3AED),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );

                                          final dueBadge = Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFC),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Column(
                                              children: [
                                                const Text(
                                                  'TOTAL FREIGHT DUE',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF64748B),
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '₹${group.totalFreightDue.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 15,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );

                                          final controlBox = Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _buildMiniInput(
                                                  'PAID TO DRIVER',
                                                  alloc.paidToDriver,
                                                  (v) => _handleAllocationChange(group.consigneeId, 'driver', v),
                                                  color: const Color(0xFF7C3AED),
                                                  bgColor: const Color(0xFFEDE9FE),
                                                ),
                                                const SizedBox(width: 10),
                                                _buildMiniInput(
                                                  'PAID TO TRANSPORT',
                                                  alloc.paidToTransport,
                                                  (v) => _handleAllocationChange(group.consigneeId, 'transport', v),
                                                  color: const Color(0xFF0D9488),
                                                  bgColor: const Color(0xFFCCFBF1),
                                                ),
                                                const SizedBox(width: 10),

                                                // Quick Allocation Buttons
                                                Column(
                                                  children: [
                                                    ElevatedButton(
                                                      onPressed: () =>
                                                          _handleFullToDriver(group.consigneeId, group.totalFreightDue),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: const Color(0xFF7C3AED),
                                                        foregroundColor: Colors.white,
                                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                                        minimumSize: const Size(0, 30),
                                                        elevation: 0,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                      ),
                                                      child: const Text(
                                                        'ALL DRIVER',
                                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    OutlinedButton(
                                                      onPressed: () =>
                                                          _handleFullToTransport(group.consigneeId, group.totalFreightDue),
                                                      style: OutlinedButton.styleFrom(
                                                        foregroundColor: const Color(0xFF0D9488),
                                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                                        minimumSize: const Size(0, 30),
                                                        side: const BorderSide(color: Color(0xFF0D9488)),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                      ),
                                                      child: const Text(
                                                        'ALL BANK',
                                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );

                                          if (isNarrow) {
                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                nameSection,
                                                const SizedBox(height: 12),
                                                Wrap(
                                                  alignment: WrapAlignment.spaceBetween,
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  spacing: 12,
                                                  runSpacing: 10,
                                                  children: [
                                                    dueBadge,
                                                    SingleChildScrollView(
                                                      scrollDirection: Axis.horizontal,
                                                      child: controlBox,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            );
                                          }

                                          return Row(
                                            children: [
                                              Expanded(child: nameSection),
                                              dueBadge,
                                              const SizedBox(width: 14),
                                              controlBox,
                                            ],
                                          );
                                        },
                                      ),
                                    ),

                                    // Allocation Status Chip Bar
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isBalanced
                                            ? const Color(0xFFECFDF5)
                                            : (isOver ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB)),
                                        borderRadius: isExpanded
                                            ? BorderRadius.zero
                                            : const BorderRadius.only(
                                                bottomLeft: Radius.circular(16),
                                                bottomRight: Radius.circular(16),
                                              ),
                                      ),
                                      child: Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            isBalanced
                                                ? '✓ 100% Freight Reconciled'
                                                : (isOver
                                                    ? '⚠️ Over-allocated by ₹${(totalAllocated - group.totalFreightDue).toStringAsFixed(2)}'
                                                    : 'Unallocated Remaining: ₹${(group.totalFreightDue - totalAllocated).toStringAsFixed(2)}'),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: isBalanced
                                                  ? const Color(0xFF059669)
                                                  : (isOver ? const Color(0xFFDC2626) : const Color(0xFFB45309)),
                                            ),
                                          ),
                                          Text(
                                            'Allocated: ₹${totalAllocated.toStringAsFixed(2)} / ₹${group.totalFreightDue.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isBalanced
                                                  ? const Color(0xFF059669)
                                                  : (isOver ? const Color(0xFFDC2626) : const Color(0xFFB45309)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Expandable Accordion: Individual GCs Table
                                    if (isExpanded)
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.only(
                                            bottomLeft: Radius.circular(16),
                                            bottomRight: Radius.circular(16),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: group.gcs
                                              .map((gc) => Container(
                                                    margin: const EdgeInsets.only(bottom: 8),
                                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            const Icon(Icons.receipt_rounded,
                                                                size: 16, color: Color(0xFF7C3AED)),
                                                            const SizedBox(width: 8),
                                                            Text(
                                                              gc.gcNumber,
                                                              style: const TextStyle(
                                                                fontWeight: FontWeight.w900,
                                                                color: Color(0xFF0F172A),
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 10),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                  horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: gc.paymentType.toUpperCase() == 'TO-PAY'
                                                                    ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                                                                    : const Color(0xFF10B981).withValues(alpha: 0.1),
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: Text(
                                                                gc.paymentType,
                                                                style: TextStyle(
                                                                  color: gc.paymentType.toUpperCase() == 'TO-PAY'
                                                                      ? const Color(0xFFDC2626)
                                                                      : const Color(0xFF059669),
                                                                  fontSize: 10,
                                                                  fontWeight: FontWeight.w800,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        Text(
                                                          '₹${gc.freightTotal.toStringAsFixed(2)}',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.w900,
                                                            fontSize: 14,
                                                            color: Color(0xFF0F172A),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ))
                                              .toList(),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),

                            const SizedBox(height: 24),

                            // STEP 4: Master Settlement Cockpit Banner
                            Container(
                              padding: const EdgeInsets.all(26),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF090D1A), Color(0xFF0F172A), Color(0xFF1E293B)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF090D1A).withValues(alpha: 0.4),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF38BDF8),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'SETTLEMENT SUMMARY AUDIT',
                                            style: TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.2,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                        ),
                                        child: Text(
                                          'TRIP: ${_selectedTrip!.tripNumber}',
                                          style: const TextStyle(
                                            color: Color(0xFF38BDF8),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),

                                  // Financial KPI Cards inside dark summary
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDarkSummary(
                                          'Trip Balance Due',
                                          '₹${_tripBalance.toStringAsFixed(2)}',
                                          Colors.white,
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildDarkSummary(
                                          'Driver Collected (Cash)',
                                          '₹${_totalPaidToDriver.toStringAsFixed(2)}',
                                          const Color(0xFFA78BFA),
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildDarkSummary(
                                          'Transport Direct (Bank)',
                                          '₹${_totalPaidToUs.toStringAsFixed(2)}',
                                          const Color(0xFF2DD4BF),
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildDarkSummary(
                                          'Total Freight Cleared',
                                          '₹${(_totalPaidToDriver + _totalPaidToUs).toStringAsFixed(2)}',
                                          const Color(0xFFFBBF24),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 22),
                                    child: Divider(color: Colors.white12, height: 1),
                                  ),

                                  // Settlement Verdict & Action Button
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Verdict Box
                                      if (_isCrossing)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.arrow_downward_rounded,
                                                  color: Color(0xFF34D399), size: 28),
                                              const SizedBox(width: 14),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'CROSSING BALANCE (DRIVER OWES TRANSPORT)',
                                                    style: TextStyle(
                                                      color: Color(0xFF34D399),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w900,
                                                      letterSpacing: 1,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Driver deposits: ₹${_absoluteDifference.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      color: Color(0xFF34D399),
                                                      fontSize: 22,
                                                      fontWeight: FontWeight.w900,
                                                      letterSpacing: -0.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        )
                                      else if (_isReturn)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.arrow_upward_rounded,
                                                  color: Color(0xFFF87171), size: 28),
                                              const SizedBox(width: 14),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'RETURN BALANCE (TRANSPORT OWES DRIVER)',
                                                    style: TextStyle(
                                                      color: Color(0xFFF87171),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w900,
                                                      letterSpacing: 1,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Pay Driver balance: ₹${_absoluteDifference.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      color: Color(0xFFF87171),
                                                      fontSize: 22,
                                                      fontWeight: FontWeight.w900,
                                                      letterSpacing: -0.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.08),
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(Icons.check_circle_rounded, color: Color(0xFF38BDF8), size: 28),
                                              SizedBox(width: 14),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'PERFECT EQUILIBRIUM',
                                                    style: TextStyle(
                                                      color: Color(0xFF94A3B8),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w900,
                                                      letterSpacing: 1,
                                                    ),
                                                  ),
                                                  SizedBox(height: 2),
                                                  Text(
                                                    'Settled Even: ₹0.00',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 22,
                                                      fontWeight: FontWeight.w900,
                                                      letterSpacing: -0.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                      // Finalize Settlement Button
                                      ElevatedButton.icon(
                                        icon: _isSettling
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(Icons.check_circle_rounded, size: 20),
                                        label: Text(_isSettling ? 'FINALIZING...' : 'FINALIZE & CLOSE TRIP'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                                          backgroundColor: const Color(0xFF7C3AED),
                                          foregroundColor: Colors.white,
                                          textStyle: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                            letterSpacing: 0.5,
                                          ),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                        onPressed: _isSettling ? null : _handleSettleTrip,
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTripRow(String label, String value, {Color? valColor, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isTotal ? const Color(0xFF0F172A) : Colors.blueGrey.shade600,
              fontSize: isTotal ? 14 : 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: valColor ?? (isTotal ? const Color(0xFF0F172A) : const Color(0xFF0F172A)),
              fontSize: isTotal ? 16 : 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniInput(
    String label,
    double val,
    Function(String) onChanged, {
    required Color color,
    required Color bgColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 105,
          height: 38,
          child: TextFormField(
            key: ValueKey('${label}_$_quickFillEpoch'),
            initialValue: val == 0 ? '' : val.toString(),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 12),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: color, width: 2),
              ),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 13),
            onChanged: onChanged,
          ),
        )
      ],
    );
  }

  Widget _buildDarkSummary(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
