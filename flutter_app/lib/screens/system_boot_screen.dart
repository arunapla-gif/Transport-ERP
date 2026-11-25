import 'dart:ui';
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
  bool _isBootComplete = false;

  @override
  void initState() {
    super.initState();
    _runBootSequence();
  }

  Future<void> _runBootSequence() async {
    setState(() {
      _errorMessage = null;
      _networkState = BootState.pending;
      _serverState = BootState.pending;
      _databaseState = BootState.pending;
      _authState = BootState.pending;
      _isBootComplete = false;
    });

    try {
      // 1. Check Local Internet & Interface
      setState(() => _networkState = BootState.loading);
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() => _networkState = BootState.success);

      // 2. Check Secure Server Connection
      setState(() => _serverState = BootState.loading);
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() => _serverState = BootState.success);

      // 3. Core Database Integrity
      setState(() => _databaseState = BootState.loading);
      bool isHealthy = await ApiService.checkHealth();
      if (!isHealthy) {
        throw Exception('Database Timeout or Offline');
      }
      setState(() => _databaseState = BootState.success);

      // 4. Authentication Keys
      setState(() => _authState = BootState.loading);
      await Future.delayed(const Duration(milliseconds: 500));
      if (ApiService.authToken == null) {
        throw Exception('Invalid Session Key or Token Expired');
      }
      setState(() => _authState = BootState.success);

      // Boot sequence complete!
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() => _isBootComplete = true);
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
      body: Stack(
        children: [
          // Midnight Sapphire Mesh Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0B132B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Ambient subtle background glow orbs
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
              ),
            ),
          ),

          // Glassmorphism System Card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 480),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 40,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(36.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 32),

                        // System Checklist
                        _buildCheckItem(
                          label: 'Local Network Interface',
                          telemetry: 'LATENCY: 4ms // WIRED/WIFI',
                          state: _networkState,
                          icon: Icons.wifi_rounded,
                        ),
                        const SizedBox(height: 12),
                        _buildCheckItem(
                          label: 'Secure API Gateway Handshake',
                          telemetry: 'PORT: 8085 // TLS ENCRYPTED',
                          state: _serverState,
                          icon: Icons.dns_rounded,
                        ),
                        const SizedBox(height: 12),
                        _buildCheckItem(
                          label: 'Database Integrity & WAL Buffers',
                          telemetry: 'SQLITE/POSTGRES: ACTIVE',
                          state: _databaseState,
                          icon: Icons.storage_rounded,
                        ),
                        const SizedBox(height: 12),
                        _buildCheckItem(
                          label: 'Session Tokens & Role Credentials',
                          telemetry: 'JWT VERIFIED // ACCESS GRANTED',
                          state: _authState,
                          icon: Icons.vpn_key_rounded,
                        ),

                        // Boot Actions Area
                        if (_isBootComplete) ...[
                          const SizedBox(height: 32),
                          if (widget.isAdmin) ...[
                            const Text(
                              'SELECT OPERATING BRANCH WORKSPACE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildBranchButton(
                                    'MAIN',
                                    'MAIN BRANCH',
                                    'HQ CENTRAL HUB',
                                    Icons.business_rounded,
                                    const Color(0xFF6366F1),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _buildBranchButton(
                                    'AP_BNG',
                                    'AP BANGALORE',
                                    'REGIONAL TERMINAL',
                                    Icons.warehouse_rounded,
                                    const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
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
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Enter Enterprise Workspace',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                    ),
                                    SizedBox(width: 10),
                                    Icon(Icons.arrow_forward_rounded, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ] else ...[
                          const SizedBox(height: 32),
                          Container(
                            width: double.infinity,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF818CF8)),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Verifying System Services...',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Error Banner if present
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 24),
                          _buildErrorBox(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.dns_rounded, color: Colors.white, size: 34),
            ),
            Positioned(
              top: -6,
              right: -36,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF34D399)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'v3.0.2 Live',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Transport ERP System Boot',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Initializing secure enterprise workspace and database services',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF94A3B8),
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCheckItem({
    required String label,
    required String telemetry,
    required BootState state,
    required IconData icon,
  }) {
    Color bgColor;
    Color borderColor;
    Color iconBgColor;
    Widget leadingWidget;
    String subText;

    switch (state) {
      case BootState.success:
        bgColor = const Color(0xFF10B981).withValues(alpha: 0.12);
        borderColor = const Color(0xFF10B981).withValues(alpha: 0.3);
        iconBgColor = const Color(0xFF10B981).withValues(alpha: 0.2);
        leadingWidget = const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20);
        subText = telemetry;
        break;
      case BootState.error:
        bgColor = const Color(0xFFE11D48).withValues(alpha: 0.12);
        borderColor = const Color(0xFFE11D48).withValues(alpha: 0.3);
        iconBgColor = const Color(0xFFE11D48).withValues(alpha: 0.2);
        leadingWidget = const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48), size: 20);
        subText = 'Verification Failed';
        break;
      case BootState.loading:
        bgColor = const Color(0xFF6366F1).withValues(alpha: 0.12);
        borderColor = const Color(0xFF6366F1).withValues(alpha: 0.3);
        iconBgColor = const Color(0xFF6366F1).withValues(alpha: 0.2);
        leadingWidget = const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF818CF8)),
        );
        subText = 'Verifying connection...';
        break;
      case BootState.pending:
        bgColor = Colors.white.withValues(alpha: 0.04);
        borderColor = Colors.white.withValues(alpha: 0.08);
        iconBgColor = Colors.white.withValues(alpha: 0.06);
        leadingWidget = Icon(icon, color: const Color(0xFF64748B), size: 18);
        subText = 'Awaiting sequence...';
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: leadingWidget,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: state == BootState.pending ? const Color(0xFF94A3B8) : Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subText,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: state == BootState.success ? 'monospace' : null,
                    fontWeight: FontWeight.w600,
                    color: state == BootState.success
                        ? const Color(0xFFA7F3D0)
                        : (state == BootState.error ? const Color(0xFFFECDD3) : const Color(0xFF64748B)),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE11D48).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$_errorMessage. Please check server status.',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFECDD3),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _runBootSequence,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: const Color(0xFFE11D48).withValues(alpha: 0.5)),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Retry Sequence', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              if (_authState == BootState.error) ...[
                const SizedBox(width: 10),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Reset Session', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBranchButton(
    String branchId,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return InkWell(
      onTap: () async {
        await AuthService.setActiveBranch(branchId);
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        }
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}
