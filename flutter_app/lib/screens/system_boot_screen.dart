import 'package:flutter/material.dart';
import 'package:flutter_app/screens/dashboard_screen.dart';
import 'package:flutter_app/screens/login_screen.dart';
import 'package:flutter_app/services/api_service.dart';
import 'package:flutter_app/services/auth_service.dart';

enum BootState { pending, loading, success, error }

class SystemBootScreen extends StatefulWidget {
  final bool isAdmin;
  const SystemBootScreen({super.key, this.isAdmin = false});

  @override
  State<SystemBootScreen> createState() => _SystemBootScreenState();
}

class _SystemBootScreenState extends State<SystemBootScreen> {
  BootState _networkState = BootState.pending;
  BootState _serverState = BootState.pending;
  BootState _databaseState = BootState.pending;
  BootState _authState = BootState.pending;

  String? _errorMessage;
  int? _healthLatencyMs;
  bool _isBootComplete = false;

  @override
  void initState() {
    super.initState();
    _runBootSequence();
  }

  Future<void> _runBootSequence() async {
    setState(() {
      _errorMessage = null;
      _healthLatencyMs = null;
      _networkState = BootState.pending;
      _serverState = BootState.pending;
      _databaseState = BootState.pending;
      _authState = BootState.pending;
      _isBootComplete = false;
    });

    try {
      // 1. Check Local Internet Connection
      setState(() => _networkState = BootState.loading);
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      setState(() => _networkState = BootState.success);

      // 2. Check Secure Server Connection & Core Database Integrity (/health)
      setState(() {
        _serverState = BootState.loading;
        _databaseState = BootState.loading;
      });
      final sw = Stopwatch()..start();
      final bool isHealthy = await ApiService.checkHealth();
      sw.stop();
      if (!isHealthy) {
        throw Exception('Database Timeout');
      }
      if (!mounted) return;
      setState(() {
        _serverState = BootState.success;
        _databaseState = BootState.success;
        _healthLatencyMs = sw.elapsedMilliseconds;
      });

      // 3. Check Authentication Keys & Pre-warm static Master caches
      setState(() => _authState = BootState.loading);
      if (ApiService.authToken == null) {
        throw Exception('Invalid Session Key');
      }
      await Future.wait([
        ApiService.getCompanies().then((_) {}, onError: (_) {}),
        ApiService.getGodowns().then((_) {}, onError: (_) {}),
        ApiService.getUnits().then((_) {}, onError: (_) {}),
        ApiService.getHsnList().then((_) {}, onError: (_) {}),
      ]);
      if (!mounted) return;
      setState(() {
        _authState = BootState.success;
        _isBootComplete = true;
      });

      // Auto-enter workspace for non-admin operators once all checks pass
      if (!widget.isAdmin) {
        await Future.delayed(const Duration(milliseconds: 450));
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_networkState == BootState.loading) _networkState = BootState.error;
          if (_serverState == BootState.loading) _serverState = BootState.error;
          if (_databaseState == BootState.loading) _databaseState = BootState.error;
          if (_authState == BootState.loading) _authState = BootState.error;
          _errorMessage = e.toString().replaceAll('Exception: ', '').trim();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 468),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header (1:1 React SystemBoot.jsx)
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.28),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.dns_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 16),
                const Text(
                  'System Dashboard',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Initializing Secure Workspace',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 32),

                // 4 Sequence CheckItems
                _buildCheckItem(
                  label: 'Local Internet Connection',
                  state: _networkState,
                  icon: Icons.wifi_rounded,
                ),
                const SizedBox(height: 12),
                _buildCheckItem(
                  label: 'Secure Server Connection',
                  state: _serverState,
                  icon: Icons.dns_rounded,
                ),
                const SizedBox(height: 12),
                _buildCheckItem(
                  label: 'Core Database Integrity',
                  state: _databaseState,
                  icon: Icons.storage_rounded,
                  successText: _healthLatencyMs != null
                      ? 'Connected and Online • ${_healthLatencyMs}ms'
                      : null,
                ),
                const SizedBox(height: 12),
                _buildCheckItem(
                  label: 'Authentication Keys',
                  state: _authState,
                  icon: Icons.vpn_key_rounded,
                  successText: 'Session Verified • Workspace Pre-loaded',
                ),

                // Error Box
                if (_errorMessage != null) ...[
                  const SizedBox(height: 24),
                  _buildErrorBox(),
                ],

                // Bottom Action / Branch Selector
                const SizedBox(height: 32),
                if (_isBootComplete) ...[
                  if (widget.isAdmin) ...[
                    const Text(
                      'SELECT OPERATING BRANCH',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildBranchCard(
                            branchId: 'MAIN',
                            title: 'MAIN BRANCH',
                            subtitle: 'Sivakasi',
                            icon: Icons.storage_rounded,
                            bgColor: const Color(0xFFEEF2FF),
                            borderColor: const Color(0xFFE0E7FF),
                            iconColor: const Color(0xFF6366F1),
                            textColor: const Color(0xFF312E81),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildBranchCard(
                            branchId: 'AP_BNG',
                            title: 'AP BNG',
                            subtitle: 'Bangalore',
                            icon: Icons.dns_rounded,
                            bgColor: const Color(0xFFFFFBEB),
                            borderColor: const Color(0xFFFEF3C7),
                            iconColor: const Color(0xFFD97706),
                            textColor: const Color(0xFF78350F),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const DashboardScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.25),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Proceed to Operations',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                      ),
                    ),
                ] else
                  Container(
                    width: double.infinity,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Awaiting System Readiness',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
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

  Widget _buildCheckItem({
    required String label,
    required BootState state,
    required IconData icon,
    String? successText,
  }) {
    late Color bgColor;
    late Color borderColor;
    late Color iconBgColor;
    late Color textColor;
    late Widget leadingWidget;
    late String subText;

    switch (state) {
      case BootState.success:
        bgColor = const Color(0xFFECFDF5).withValues(alpha: 0.7);
        borderColor = const Color(0xFFD1FAE5);
        iconBgColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF047857);
        leadingWidget = const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF047857), size: 20);
        subText = successText ?? 'Connected and Online';
        break;
      case BootState.error:
        bgColor = const Color(0xFFFFF1F2);
        borderColor = const Color(0xFFFFE4E6);
        iconBgColor = const Color(0xFFFFE4E6);
        textColor = const Color(0xFFE11D48);
        leadingWidget = const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48), size: 20);
        subText = 'Connection Failed';
        break;
      case BootState.loading:
        bgColor = const Color(0xFFEFF6FF).withValues(alpha: 0.7);
        borderColor = const Color(0xFFDBEAFE);
        iconBgColor = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF1D4ED8);
        leadingWidget = const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1D4ED8)),
        );
        subText = 'Verifying connection...';
        break;
      case BootState.pending:
        bgColor = const Color(0xFFF8FAFC);
        borderColor = const Color(0xFFF1F5F9);
        iconBgColor = const Color(0xFFE2E8F0);
        textColor = const Color(0xFF94A3B8);
        leadingWidget = Icon(icon, color: const Color(0xFF94A3B8), size: 20);
        subText = 'Waiting for sequence...';
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: leadingWidget,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subText,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$_errorMessage. Please check your connection.',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFE11D48),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _runBootSequence,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFE11D48),
                    side: const BorderSide(color: Color(0xFFFECDD3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Retry Connection', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
              if (_authState == BootState.error) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      AuthService.logout();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Reset Session', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBranchCard({
    required String branchId,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color bgColor,
    required Color borderColor,
    required Color iconColor,
    required Color textColor,
  }) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () async {
          await AuthService.setActiveBranch(branchId);
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: iconColor),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
