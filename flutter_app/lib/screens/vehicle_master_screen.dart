import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/vehicle.dart';

class VehicleMasterScreen extends StatefulWidget {
  const VehicleMasterScreen({super.key});

  @override
  State<VehicleMasterScreen> createState() => _VehicleMasterScreenState();
}

class _VehicleMasterScreenState extends State<VehicleMasterScreen> {
  List<Vehicle> _vehicles = [];
  bool _isLoading = false;
  int _page = 1;
  bool _hasMore = true;
  int _totalRecords = 0;
  final ScrollController _scrollController = ScrollController();
  
  String _searchTerm = '';
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _vahanData;
  bool _isFetchingRc = false;

  // Form State
  int? _id;
  final TextEditingController _vehicleNumberController = TextEditingController();
  String _type = '6 Wheel (Lorry/Truck)';
  String _ladenType = 'Open Body';
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _ownerPhoneController = TextEditingController();
  final TextEditingController _ownerPhone2Controller = TextEditingController();
  final TextEditingController _makeModelController = TextEditingController();
  
  DateTime? _fitnessExpiry;
  DateTime? _insuranceExpiry;
  DateTime? _npExpiry;
  int? _grossWeight;
  String? _rcStatus;
  bool _rcVerified = false;

  final List<String> _vehicleTypes = [
    '6 Wheel (Lorry/Truck)', '10 Wheel (Taurus)', '12 Wheeler', 
    '14 Wheeler', '18 Wheeler', '22 Wheeler', '4 Wheel (Van/Minidor)'
  ];

  final List<String> _ladenTypes = ['Open Body', 'Container'];

  @override
  void initState() {
    super.initState();
    _fetchVehicles(1);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _vehicleNumberController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    _ownerPhone2Controller.dispose();
    _makeModelController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading && _hasMore) {
      _fetchVehicles(_page + 1);
    }
  }

  Future<void> _fetchVehicles(int pageNum) async {
    setState(() => _isLoading = true);
    
    try {
      final res = await ApiService.getVehiclesPaginated(page: pageNum, limit: 50, q: _searchTerm);
      if (mounted) {
        setState(() {
          _page = pageNum;
          if (res['data'] != null) {
            final List<Vehicle> newEntries = (res['data'] as List).map((e) => Vehicle.fromJson(e)).toList();
            if (pageNum == 1) {
              _vehicles = newEntries;
            } else {
              _vehicles.addAll(newEntries);
            }
            _hasMore = res['hasMore'] ?? false;
            _totalRecords = res['total'] ?? 0;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load fleet vehicles: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getVehicleTypeFromWheels(String? axlesStr, String? gvwStr) {
    final axles = int.tryParse(axlesStr ?? '') ?? 0;
    final gvw = int.tryParse(gvwStr ?? '') ?? 0;
    if (axles == 0) return '6 Wheel (Lorry/Truck)';
    if (axles == 2) return gvw <= 3500 ? '4 Wheel (Van/Minidor)' : '6 Wheel (Lorry/Truck)';
    if (axles == 3) return '10 Wheel (Taurus)';
    if (axles == 4) return '12 Wheeler';
    if (axles == 5) return '14 Wheeler';
    if (axles == 6) return '18 Wheeler';
    if (axles == 7) return '22 Wheeler';
    return '${axles * 4 - 6} Wheeler';
  }

  Future<void> _handleFetchRC() async {
    final vNum = _vehicleNumberController.text.trim();
    if (vNum.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a vehicle number first'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() {
      _isFetchingRc = true;
      _vahanData = null;
    });

    try {
      final cleanNo = vNum.replaceAll(RegExp(r'\s+'), '').toUpperCase();
      final res = await ApiService.fetchRcDetails(cleanNo);

      setState(() {
        _vahanData = res;
        _type = _getVehicleTypeFromWheels(res['rc_no_of_axle']?.toString(), res['rc_gvw']?.toString());
        _ownerNameController.text = res['rc_owner_name'] ?? '';
        _makeModelController.text = '${res['rc_maker_desc'] ?? ''} ${res['rc_maker_model'] ?? ''}'.trim();
        _fitnessExpiry = DateTime.tryParse(res['rc_fit_upto']?.toString() ?? '');
        _insuranceExpiry = DateTime.tryParse(res['rc_insurance_upto']?.toString() ?? '');
        _npExpiry = DateTime.tryParse(res['rc_np_upto']?.toString() ?? '');
        _grossWeight = int.tryParse(res['rc_gvw']?.toString() ?? '');
        _rcStatus = res['rc_status'];
        _rcVerified = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text('RC details verified for $cleanNo via VAHAN!'),
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
            content: Text('Failed to fetch RC details from VAHAN: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingRc = false);
    }
  }

  Future<void> _handleSave() async {
    final vNum = _vehicleNumberController.text.trim().toUpperCase();
    if (vNum.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vehicle Number is required'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final payload = {
        if (_id != null) 'id': _id,
        'vehicleNumber': vNum,
        'type': _type,
        'ladenType': _ladenType,
        'ownerName': _ownerNameController.text.trim(),
        'ownerPhone': _ownerPhoneController.text.trim(),
        'ownerPhone2': _ownerPhone2Controller.text.trim(),
        'makeModel': _makeModelController.text.trim(),
        'fitnessExpiry': _fitnessExpiry?.toIso8601String(),
        'insuranceExpiry': _insuranceExpiry?.toIso8601String(),
        'npExpiry': _npExpiry?.toIso8601String(),
        'grossWeight': _grossWeight,
        'rcStatus': _rcStatus,
        'rcVerified': _rcVerified,
      };

      if (_id != null) {
        await ApiService.updateVehicle(_id!, payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text('Vehicle $vNum record updated successfully!'),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else {
        await ApiService.createVehicle(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text('Vehicle $vNum registered into fleet!'),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }

      _clearForm();
      _fetchVehicles(1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save vehicle: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleEdit(Vehicle v) {
    setState(() {
      _id = v.id;
      _vehicleNumberController.text = v.vehicleNumber;
      _type = v.type ?? '6 Wheel (Lorry/Truck)';
      _ladenType = v.ladenType ?? 'Open Body';
      _ownerNameController.text = v.ownerName ?? '';
      _ownerPhoneController.text = v.ownerPhone ?? '';
      _ownerPhone2Controller.text = v.ownerPhone2 ?? '';
      _makeModelController.text = v.makeModel ?? '';
      _fitnessExpiry = v.fitnessExpiry;
      _insuranceExpiry = v.insuranceExpiry;
      _npExpiry = v.npExpiry;
      _grossWeight = v.grossWeight;
      _rcStatus = v.rcStatus;
      _rcVerified = v.rcVerified;
      _vahanData = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Editing "${v.vehicleNumber}" (ID #${v.id})'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _handleDelete(Vehicle v) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Delete Vehicle Record', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove truck "${v.vehicleNumber}" from the fleet registry?\nThis action cannot be undone.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.deleteVehicle(v.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vehicle ${v.vehicleNumber} deleted'),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      _fetchVehicles(1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete vehicle: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _clearForm() {
    setState(() {
      _id = null;
      _vehicleNumberController.clear();
      _type = '6 Wheel (Lorry/Truck)';
      _ladenType = 'Open Body';
      _ownerNameController.clear();
      _ownerPhoneController.clear();
      _ownerPhone2Controller.clear();
      _makeModelController.clear();
      _fitnessExpiry = null;
      _insuranceExpiry = null;
      _npExpiry = null;
      _grossWeight = null;
      _rcStatus = null;
      _rcVerified = false;
      _vahanData = null;
    });
  }

  void _showVehicleDetailModal(Vehicle v) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          width: 580,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.16),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'FLEET VEHICLE PROFILE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('ID #${v.id}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            v.vehicleNumber,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // Body Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Status & Specs Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: v.rcVerified ? const Color(0xFFF0FDF4) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: v.rcVerified ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: v.rcVerified ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              v.rcVerified ? Icons.verified_rounded : Icons.pending_rounded,
                              color: v.rcVerified ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  v.rcVerified ? 'VAHAN RTO VERIFIED RECORD' : 'UNVERIFIED / PENDING RC',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: v.rcVerified ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${v.type ?? 'Standard'} • ${v.ladenType ?? 'Open Body'}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (v.grossWeight != null && v.grossWeight! > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('GVW', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                                  Text('${v.grossWeight} KG', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Make & Owner Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildModalInfoBox(
                            icon: Icons.person_rounded,
                            label: 'REGISTERED OWNER',
                            value: v.ownerName?.trim().isNotEmpty == true ? v.ownerName! : 'Not specified',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildModalInfoBox(
                            icon: Icons.build_circle_rounded,
                            label: 'MAKE & MODEL',
                            value: v.makeModel?.trim().isNotEmpty == true ? v.makeModel! : 'Not specified',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Phone Contact Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildModalInfoBox(
                            icon: Icons.phone_rounded,
                            label: 'PRIMARY CONTACT',
                            value: v.ownerPhone?.trim().isNotEmpty == true ? v.ownerPhone! : 'No phone',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildModalInfoBox(
                            icon: Icons.phone_android_rounded,
                            label: 'ALTERNATE CONTACT',
                            value: v.ownerPhone2?.trim().isNotEmpty == true ? v.ownerPhone2! : 'No phone',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Compliance Expiry Dates Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('STATUTORY COMPLIANCE EXPIRIES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildExpiryChip(
                                  label: 'Fitness (FC)',
                                  date: v.fitnessExpiry,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildExpiryChip(
                                  label: 'Insurance',
                                  date: v.insuranceExpiry,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildExpiryChip(
                                  label: 'Permit (NP)',
                                  date: v.npExpiry,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Modal Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RC Status: ${v.rcStatus ?? 'ACTIVE'}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF475569),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _handleEdit(v);
                          },
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: const Text('Edit Vehicle'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalInfoBox({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryChip({required String label, DateTime? date}) {
    final bool isExpired = date != null && date.isBefore(DateTime.now());
    final bool isExpiringSoon = date != null && !isExpired && date.difference(DateTime.now()).inDays < 30;

    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF334155);

    if (date != null) {
      if (isExpired) {
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
      } else if (isExpiringSoon) {
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
      } else {
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(height: 2),
          Text(
            date != null ? date.toIso8601String().split('T')[0] : 'N/A',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: fg, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: padding ?? const EdgeInsets.all(24),
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

  Widget _buildDenseInput({
    required String label,
    required Widget child,
    String? tooltip,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF475569),
                letterSpacing: 0.5,
              ),
            ),
            if (tooltip != null) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: tooltip,
                child: const Icon(Icons.help_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  InputDecoration _inputDeco({
    String? hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: const Color(0xFF64748B)) : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.6),
      ),
    );
  }

  Widget _buildVahanDataPreview() {
    if (_vahanData == null) return const SizedBox.shrink();

    final gvw = int.tryParse(_vahanData!['rc_gvw']?.toString() ?? '0') ?? 0;
    final unld = int.tryParse(_vahanData!['rc_unld_wt']?.toString() ?? '0') ?? 0;
    final payload = gvw - unld;

    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 14, color: Color(0xFF1D4ED8)),
                    SizedBox(width: 6),
                    Text('VAHAN GOVT VERIFIED DATA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF1E40AF), letterSpacing: 0.5)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _vahanData!['rc_status'] == 'ACTIVE' ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2), 
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'STATUS: ${_vahanData!['rc_status'] ?? 'ACTIVE'}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: _vahanData!['rc_status'] == 'ACTIVE' ? const Color(0xFF15803D) : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isNarrow = constraints.maxWidth < 700;

              final col1 = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('OWNERSHIP & REGISTRATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF), letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  const Divider(color: Color(0xFFBFDBFE)),
                  Text('Owner: ${_vahanData!['rc_owner_name'] ?? '-'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                  const SizedBox(height: 2),
                  Text('Reg Date: ${_vahanData!['rc_regn_dt'] ?? '-'}', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                  const SizedBox(height: 2),
                  Text('RTO: ${_vahanData!['rc_registered_at'] ?? '-'}', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                ],
              );

              final col2 = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('VEHICLE & PAYLOAD SPECS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFD97706), letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  const Divider(color: Color(0xFFBFDBFE)),
                  Text('Make/Model: ${_vahanData!['rc_maker_desc'] ?? ''} ${_vahanData!['rc_maker_model'] ?? ''}'.trim(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                  const SizedBox(height: 2),
                  Text('Max Payload: $payload KG (Gross: $gvw, Unladen: $unld)', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                  const SizedBox(height: 2),
                  Text('Axles: ${_vahanData!['rc_no_of_axle'] ?? '-'}', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                ],
              );

              final col3 = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CERTIFICATES & COMPLIANCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF15803D), letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  const Divider(color: Color(0xFFBFDBFE)),
                  Text('Fitness Expiry: ${_vahanData!['rc_fit_upto'] ?? '-'}', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                  const SizedBox(height: 2),
                  Text('Insurance Expiry: ${_vahanData!['rc_insurance_upto'] ?? '-'}', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                  const SizedBox(height: 2),
                  Text('Permit Expiry: ${_vahanData!['rc_permit_valid_upto'] ?? '-'}', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    col1,
                    const SizedBox(height: 14),
                    col2,
                    const SizedBox(height: 14),
                    col3,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: col1),
                  const SizedBox(width: 20),
                  Expanded(child: col2),
                  const SizedBox(width: 20),
                  Expanded(child: col3),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int verifiedCount = _vehicles.where((v) => v.rcVerified).length;

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
                // Header Card
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isCompact = constraints.maxWidth < 680;
                      final headerInfo = Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
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
                            child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Vehicle Fleet Master & VAHAN Hub',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'VAHAN-verified transport fleet, statutory fitness, national permits & gross weight allowances',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blueGrey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );

                      final kpiPills = Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _totalRecords > 0 ? '$_totalRecords Fleet Units' : '${_vehicles.length} Fleet Units',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF16A34A)),
                                const SizedBox(width: 6),
                                Text(
                                  '$verifiedCount VAHAN Verified',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );

                      if (isCompact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            headerInfo,
                            const SizedBox(height: 14),
                            kpiPills,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: headerInfo),
                          const SizedBox(width: 16),
                          kpiPills,
                        ],
                      );
                    },
                  ),
                ),

                // Form Card
                _buildGlassCard(
                  child: LayoutBuilder(
                    builder: (context, formConstraints) {
                      final bool isNarrow = formConstraints.maxWidth < 750;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _id != null ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        _id != null ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
                                        color: _id != null ? const Color(0xFFD97706) : const Color(0xFF2563EB),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _id != null ? 'Editing Fleet Vehicle #$_id' : 'Register New Fleet Vehicle',
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                                          ),
                                          Text(
                                            _id != null
                                                ? 'Update vehicle parameters or re-verify with VAHAN.'
                                                : 'Enter vehicle number to autofill owner name, axle specs & statutory compliance via VAHAN',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_id != null)
                                TextButton.icon(
                                  onPressed: _clearForm,
                                  icon: const Icon(Icons.close_rounded, size: 16),
                                  label: const Text('Cancel Edit'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC2626),
                                    backgroundColor: const Color(0xFFFEE2E2),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // VAHAN RC Verification Bar
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: isNarrow
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildDenseInput(
                                        label: 'VEHICLE NUMBER * (VAHAN LOOKUP)',
                                        tooltip: 'Enter Indian registration plate e.g. TN38CR9999',
                                        child: TextFormField(
                                          controller: _vehicleNumberController,
                                          decoration: _inputDeco(
                                            hintText: 'e.g. TN 38 CR 9999',
                                            prefixIcon: Icons.badge_outlined,
                                            suffixIcon: _rcVerified
                                                ? const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 20)
                                                : null,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontFamily: 'monospace',
                                            letterSpacing: 1.0,
                                            color: Color(0xFF0F172A),
                                          ),
                                          textCapitalization: TextCapitalization.characters,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        height: 44,
                                        child: ElevatedButton.icon(
                                          onPressed: _isFetchingRc ? null : _handleFetchRC,
                                          icon: _isFetchingRc
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                                )
                                              : const Icon(Icons.cloud_download_rounded, size: 18),
                                          label: const Text('Verify VAHAN RC', style: TextStyle(fontWeight: FontWeight.w700)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF1E3A8A),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 18),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildDenseInput(
                                              label: 'VEHICLE TYPE',
                                              child: DropdownButtonFormField<String>(
                                                value: _type,
                                                decoration: _inputDeco(),
                                                items: _vehicleTypes.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
                                                onChanged: (v) => setState(() => _type = v!),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _buildDenseInput(
                                              label: 'LADEN TYPE',
                                              child: DropdownButtonFormField<String>(
                                                value: _ladenType,
                                                decoration: _inputDeco(),
                                                items: _ladenTypes.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
                                                onChanged: (v) => setState(() => _ladenType = v!),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                : Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: _buildDenseInput(
                                          label: 'VEHICLE NUMBER * (VAHAN LOOKUP)',
                                          tooltip: 'Enter Indian registration plate e.g. TN38CR9999',
                                          child: TextFormField(
                                            controller: _vehicleNumberController,
                                            decoration: _inputDeco(
                                              hintText: 'e.g. TN 38 CR 9999',
                                              prefixIcon: Icons.badge_outlined,
                                              suffixIcon: _rcVerified
                                                  ? const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 20)
                                                  : null,
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontFamily: 'monospace',
                                              letterSpacing: 1.0,
                                              color: Color(0xFF0F172A),
                                            ),
                                            textCapitalization: TextCapitalization.characters,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        height: 44,
                                        child: ElevatedButton.icon(
                                          onPressed: _isFetchingRc ? null : _handleFetchRC,
                                          icon: _isFetchingRc
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                                )
                                              : const Icon(Icons.cloud_download_rounded, size: 18),
                                          label: const Text('Verify VAHAN RC', style: TextStyle(fontWeight: FontWeight.w700)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF1E3A8A),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 18),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: _buildDenseInput(
                                          label: 'VEHICLE TYPE',
                                          child: DropdownButtonFormField<String>(
                                            value: _type,
                                            decoration: _inputDeco(),
                                            items: _vehicleTypes.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
                                            onChanged: (v) => setState(() => _type = v!),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: _buildDenseInput(
                                          label: 'LADEN TYPE',
                                          child: DropdownButtonFormField<String>(
                                            value: _ladenType,
                                            decoration: _inputDeco(),
                                            items: _ladenTypes.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
                                            onChanged: (v) => setState(() => _ladenType = v!),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 18),

                          // Row 2: Owner & Contacts
                          if (isNarrow) ...[
                            _buildDenseInput(
                              label: 'OWNER LEGAL NAME',
                              child: TextFormField(
                                controller: _ownerNameController,
                                decoration: _inputDeco(hintText: 'Vehicle owner name as in RC', prefixIcon: Icons.person_rounded),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDenseInput(
                                    label: 'OWNER PHONE 1',
                                    child: TextFormField(
                                      controller: _ownerPhoneController,
                                      decoration: _inputDeco(hintText: 'Primary phone', prefixIcon: Icons.phone_rounded),
                                      keyboardType: TextInputType.phone,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDenseInput(
                                    label: 'DRIVER / PHONE 2',
                                    child: TextFormField(
                                      controller: _ownerPhone2Controller,
                                      decoration: _inputDeco(hintText: 'Alternate phone', prefixIcon: Icons.phone_android_rounded),
                                      keyboardType: TextInputType.phone,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _buildDenseInput(
                              label: 'MAKE & MODEL',
                              child: TextFormField(
                                controller: _makeModelController,
                                decoration: _inputDeco(hintText: 'e.g. Tata Motors Prima 5530', prefixIcon: Icons.directions_car_rounded),
                              ),
                            ),
                          ] else
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildDenseInput(
                                    label: 'OWNER LEGAL NAME',
                                    child: TextFormField(
                                      controller: _ownerNameController,
                                      decoration: _inputDeco(hintText: 'Vehicle owner name as in RC', prefixIcon: Icons.person_rounded),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 1,
                                  child: _buildDenseInput(
                                    label: 'OWNER PHONE 1',
                                    child: TextFormField(
                                      controller: _ownerPhoneController,
                                      decoration: _inputDeco(hintText: 'Primary phone', prefixIcon: Icons.phone_rounded),
                                      keyboardType: TextInputType.phone,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 1,
                                  child: _buildDenseInput(
                                    label: 'DRIVER / PHONE 2',
                                    child: TextFormField(
                                      controller: _ownerPhone2Controller,
                                      decoration: _inputDeco(hintText: 'Alternate phone', prefixIcon: Icons.phone_android_rounded),
                                      keyboardType: TextInputType.phone,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: _buildDenseInput(
                                    label: 'MAKE & MODEL',
                                    child: TextFormField(
                                      controller: _makeModelController,
                                      decoration: _inputDeco(hintText: 'e.g. Tata Motors Prima 5530', prefixIcon: Icons.directions_car_rounded),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          _buildVahanDataPreview(),
                          const SizedBox(height: 24),

                          // Actions
                          Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              TextButton.icon(
                                onPressed: _clearForm,
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Clear Form'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF64748B),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _handleSave,
                                  icon: _isLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : Icon(_id != null ? Icons.save_rounded : Icons.add_circle_outline_rounded, size: 18),
                                  label: Text(
                                    _id != null ? 'Update Vehicle Record' : 'Register Vehicle to Fleet',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Directory Header & Search Bar
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 680;
                    return isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Fleet Vehicle Directory',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    'Showing ${_vehicles.length} loaded fleet units • Scroll for lazy pagination',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search Vehicles by Number, Owner...',
                                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded, size: 16),
                                          onPressed: () {
                                            _searchController.clear();
                                            _searchTerm = '';
                                            _fetchVehicles(1);
                                          },
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: Colors.white,
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
                                    borderSide: const BorderSide(color: Color(0xFF2563EB)),
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                onChanged: (val) {
                                  _searchTerm = val;
                                  _fetchVehicles(1);
                                },
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Fleet Vehicle Directory',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    'Showing ${_vehicles.length} loaded fleet units • Scroll for lazy pagination',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              SizedBox(
                                width: 340,
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search Vehicles by Number, Owner...',
                                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                                    suffixIcon: _searchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear_rounded, size: 16),
                                            onPressed: () {
                                              _searchController.clear();
                                              _searchTerm = '';
                                              _fetchVehicles(1);
                                            },
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: Colors.white,
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
                                      borderSide: const BorderSide(color: Color(0xFF2563EB)),
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  onChanged: (val) {
                                    _searchTerm = val;
                                    _fetchVehicles(1);
                                  },
                                ),
                              ),
                            ],
                          );
                  },
                ),
                const SizedBox(height: 14),

                // Table
                _buildGlassCard(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LayoutBuilder(
                      builder: (context, tableConstraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: tableConstraints.maxWidth < 860 ? 860 : tableConstraints.maxWidth,
                            child: Column(
                              children: [
                        // Table Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          child: const Row(
                            children: [
                              Expanded(flex: 2, child: Text('VEHICLE REGISTRATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5))),
                              Expanded(flex: 2, child: Text('OWNER & CONTACT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5))),
                              Expanded(flex: 3, child: Text('COMPLIANCE EXPIRIES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5))),
                              Expanded(flex: 2, child: Text('VAHAN STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5))),
                              SizedBox(width: 140, child: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5), textAlign: TextAlign.right)),
                            ],
                          ),
                        ),

                        // Table Body
                        if (_vehicles.isEmpty && !_isLoading)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
                            child: Center(
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF1F5F9),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.local_shipping_outlined, size: 40, color: Color(0xFF94A3B8)),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('No vehicles found in fleet directory.', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF334155))),
                                  const SizedBox(height: 4),
                                  const Text('Register your first truck or adjust your search filter above.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: 440,
                            child: ListView.separated(
                              controller: _scrollController,
                              itemCount: _vehicles.length + (_hasMore ? 1 : 0),
                              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (context, index) {
                                if (index == _vehicles.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: Center(child: Text('Scroll for more vehicles', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12))),
                                  );
                                }
                                final v = _vehicles[index];

                                return InkWell(
                                  onTap: () => _showVehicleDetailModal(v),
                                  hoverColor: const Color(0xFFF8FAFC),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                    child: Row(
                                      children: [
                                        // Vehicle Plate & Type
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFEF3C7),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                                                ),
                                                child: Text(
                                                  v.vehicleNumber,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 12,
                                                    fontFamily: 'monospace',
                                                    color: Color(0xFF0F172A),
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${v.type ?? 'Unknown'} • ${v.ladenType ?? 'Open Body'}',
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Owner
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                v.ownerName?.trim().isNotEmpty == true ? v.ownerName! : 'N/A',
                                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E293B)),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                v.ownerPhone?.trim().isNotEmpty == true ? v.ownerPhone! : '-',
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Compliance Expiries
                                        Expanded(
                                          flex: 3,
                                          child: Row(
                                            children: [
                                              if (v.fitnessExpiry != null)
                                                _buildExpiryChip(label: 'FC', date: v.fitnessExpiry),
                                              if (v.insuranceExpiry != null) ...[
                                                const SizedBox(width: 6),
                                                _buildExpiryChip(label: 'INS', date: v.insuranceExpiry),
                                              ],
                                              if (v.fitnessExpiry == null && v.insuranceExpiry == null)
                                                const Text('No records', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                            ],
                                          ),
                                        ),

                                        // VAHAN Status
                                        Expanded(
                                          flex: 2,
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: v.rcVerified ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: v.rcVerified ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      v.rcVerified ? Icons.check_circle_rounded : Icons.schedule_rounded,
                                                      size: 11,
                                                      color: v.rcVerified ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      v.rcVerified ? 'VAHAN VERIFIED' : 'PENDING RC',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w800,
                                                        color: v.rcVerified ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Actions
                                        SizedBox(
                                          width: 140,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF64748B)),
                                                tooltip: 'Inspect Vehicle',
                                                onPressed: () => _showVehicleDetailModal(v),
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.all(6),
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF2563EB)),
                                                tooltip: 'Edit Vehicle',
                                                onPressed: () => _handleEdit(v),
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.all(6),
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                                tooltip: 'Delete Vehicle',
                                                onPressed: () => _handleDelete(v),
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.all(6),
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
                        );
                      },
                    ),
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
